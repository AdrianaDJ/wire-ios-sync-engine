// 
// Wire
// Copyright (C) 2016 Wire Swiss GmbH
// 
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
// 
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
// 
// You should have received a copy of the GNU General Public License
// along with this program. If not, see <http://www.gnu.org/licenses/>.
// 


@import ZMTesting;
#import "ZMConversationTests.h"
#import "ZMConversation+UnreadCount.h"


@interface ZMConversationTests (UnreadCount)
@end


@implementation ZMConversationTests (UnreadCount)


- (ZMMessage *)insertMessageIntoConversation:(ZMConversation *)conversation sender:(ZMUser *)sender  timeSinceLastRead:(NSTimeInterval)intervalSinceLastRead
{
    ZMMessage *message = [conversation appendMessagesWithText:@"holla"].firstObject;
    message.serverTimestamp = [conversation.lastReadServerTimeStamp dateByAddingTimeInterval:intervalSinceLastRead];
    message.sender = sender;
    conversation.lastServerTimeStamp = message.serverTimestamp;
    return message;
}


- (void)testThatItSortsTimeStampsWhenFetchingMessages
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conv = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conv.lastReadServerTimeStamp = [NSDate date];
        ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        ZMMessage *excludedMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:-5];
        ZMMessage *lastMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:15];
        ZMMessage *firstMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:5];
        ZMMessage *middleMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:10];
        [self.syncMOC saveOrRollback];
        
        NSOrderedSet *expectedTimeStamps = [NSOrderedSet orderedSetWithArray:@[firstMessage.serverTimestamp, middleMessage.serverTimestamp, lastMessage.serverTimestamp]];
        
        // when
        [conv awakeFromFetch];
        
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 3u);
        XCTAssertFalse([conv.unreadTimeStamps containsObject:excludedMessage.serverTimestamp]);
        XCTAssertEqualObjects(conv.unreadTimeStamps, expectedTimeStamps);
    }];
    
}


- (void)testThatItAddsNewTimeStampsToTheEndIfTheyAreNewerThanTheLastUnread
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conv = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conv.lastReadServerTimeStamp = [NSDate date];
        ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        ZMMessage *firstMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:5];
        [self.syncMOC saveOrRollback];
        
        NSDate *newDate = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:10];
        NSOrderedSet *expectedTimeStamps = [NSOrderedSet orderedSetWithArray:@[firstMessage.serverTimestamp, newDate]];
        
        [conv awakeFromFetch];
        XCTAssertEqual(conv.estimatedUnreadCount, 1u);
        
        // when
        [conv insertTimeStamp:newDate];
        
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 2u);
        XCTAssertEqualObjects(conv.unreadTimeStamps, expectedTimeStamps);
    }];
}

- (void)testThatItAddsTimeStamps
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        
        ZMConversation *conv = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conv.lastReadServerTimeStamp = [NSDate date];
        
        XCTAssertEqual(conv.estimatedUnreadCount, 0u);
        
        NSDate *olderDate = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:-5];
        NSDate *newerDate = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:5];
        NSDate *sameDate = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:0];
        
        // when
        [conv insertTimeStamp:olderDate];
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 0u);
        
        // when
        [conv insertTimeStamp:sameDate];
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 0u);
        
        // when
        [conv insertTimeStamp:newerDate];
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 1u);
    }];
}

- (void)testThatItSortInsertsTimeStamps
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        
        ZMConversation *conv = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conv.lastReadServerTimeStamp = [NSDate date];
        
        XCTAssertEqual(conv.estimatedUnreadCount, 0u);
        
        NSDate *lastDate = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:15];
        NSDate *firstDate = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:5];
        NSDate *middleDate1 = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:10];
        NSDate *middleDate2 = [conv.lastReadServerTimeStamp dateByAddingTimeInterval:10];
        
        NSOrderedSet *expectedTimeStamps = [NSOrderedSet orderedSetWithArray:@[firstDate, middleDate1, lastDate]];
        
        // when
        [conv insertTimeStamp:firstDate];
        [conv insertTimeStamp:lastDate];
        [conv insertTimeStamp:middleDate1];
        [conv insertTimeStamp:middleDate2];
        
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 3u);
        XCTAssertEqualObjects(conv.unreadTimeStamps, expectedTimeStamps);
    }];
}


- (void)testThatItUpdatesTheUnreadCount
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        
        ZMConversation *conv = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        conv.lastReadServerTimeStamp = [NSDate date];
        ZMUser *sender = [ZMUser insertNewObjectInManagedObjectContext:self.syncMOC];
        
        [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:5];
        ZMMessage *middleMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:10];
        ZMMessage *lastMessage = [self insertMessageIntoConversation:conv sender:sender timeSinceLastRead:15];
        
        [self.syncMOC saveOrRollback];
        
        [conv awakeFromFetch];
        XCTAssertEqual(conv.estimatedUnreadCount, 3u);
        
        // expect
        NSOrderedSet *expectedTimeStamps = [NSOrderedSet orderedSetWithArray:@[lastMessage.serverTimestamp]];
        
        // when
        conv.lastReadServerTimeStamp = middleMessage.serverTimestamp;
        [conv updateUnread]; // this is done by the conversationStatusTranscoder after merging the lastRead
        
        // then
        XCTAssertEqual(conv.estimatedUnreadCount, 1u);
        XCTAssertEqualObjects(conv.unreadTimeStamps, expectedTimeStamps);
    }];

}


@end




@implementation ZMConversationTests (HasUnreadMissedCall)

- (void)testThatItSetsHasUnreadMissedCallToNoWhenLastReadEqualsLastEventID
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
        message1.serverTimestamp = [NSDate date];
        ZMTextMessage *message2 = [conversation appendMessagesWithText:@"huhu"].firstObject;
        message2.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:10];
        
        ZMSystemMessage *missedCallMessage = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        missedCallMessage.systemMessageType = ZMSystemMessageTypeMissedCall;
        missedCallMessage.visibleInConversation = conversation;
        missedCallMessage.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:20];
        
        conversation.lastServerTimeStamp =  [message1.serverTimestamp dateByAddingTimeInterval:30];
        
        [conversation fetchUnreadMessages];
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorMissedCall);

        // when
        conversation.lastReadServerTimeStamp = conversation.lastServerTimeStamp;
        
        // then
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorNone);
    }];
}


- (void)testThatItDoesNotClearHasUnreadMissedCallWhenMissedCallMessageIsNewerThanLastReadMessage
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{

        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
        message1.serverTimestamp = [NSDate date];
        ZMTextMessage *message2 = [conversation appendMessagesWithText:@"huhu"].firstObject;
        message2.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:10];
        
        ZMSystemMessage *missedCallMessage = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        missedCallMessage.systemMessageType = ZMSystemMessageTypeMissedCall;
        missedCallMessage.visibleInConversation = conversation;
        missedCallMessage.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:20];
        conversation.lastServerTimeStamp = missedCallMessage.serverTimestamp;
        
        [conversation fetchUnreadMessages];
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorMissedCall);
        
        // when
        conversation.lastReadServerTimeStamp = message2.serverTimestamp;
        
        // then
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorMissedCall);
    }];
}

- (void)testThatItDoesNotSetHasUnreadMissedCallToNoWhenTheSystemMessageTypeIsNotOfMissedCall
{
    [self.syncMOC performGroupedBlockAndWait:^{
        // given
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
        message1.serverTimestamp = [NSDate date];
        ZMTextMessage *message2 = [conversation appendMessagesWithText:@"huhu"].firstObject;
        message2.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:10];
        
        ZMSystemMessage *systemMessage = [ZMSystemMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        systemMessage.systemMessageType = ZMSystemMessageTypeConversationNameChanged;
        systemMessage.visibleInConversation = conversation;
        systemMessage.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:20];
        
        // when
        conversation.lastReadServerTimeStamp = message2.serverTimestamp;
        conversation.lastServerTimeStamp = systemMessage.serverTimestamp;
        [conversation fetchUnreadMessages];
        
        // then
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorUnreadMessages);
    }];
}

@end



@implementation ZMConversationTests (HasUnreadKnock)

- (void)testThatItSetsHasUnreadKnockToNoWhenLastReadEqualsLastEventID
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
        message1.serverTimestamp = [NSDate date];
        ZMTextMessage *message2 = [conversation appendMessagesWithText:@"huhu"].firstObject;
        message2.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:10];
        
        ZMKnockMessage *knockMessage = [ZMKnockMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        knockMessage.visibleInConversation = conversation;
        message2.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:20];
        
        conversation.lastServerTimeStamp = [message1.serverTimestamp dateByAddingTimeInterval:30];
        
        [conversation fetchUnreadMessages];
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorKnock);
        
        // when
        conversation.lastReadServerTimeStamp = conversation.lastServerTimeStamp;
        
        // then
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorNone);
    }];
}


- (void)testThatItDoesNotClearHasUnreadKnockWhenKnockMessageIsNewerThanLastReadMessage
{
    // given
    [self.syncMOC performGroupedBlockAndWait:^{
        
        ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.syncMOC];
        ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
        message1.serverTimestamp = [NSDate date];
        ZMTextMessage *message2 = [conversation appendMessagesWithText:@"huhu"].firstObject;
        message2.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:10];
        
        ZMKnockMessage *knockMessage = [ZMKnockMessage insertNewObjectInManagedObjectContext:self.syncMOC];
        knockMessage.visibleInConversation = conversation;
        knockMessage.serverTimestamp = [message1.serverTimestamp dateByAddingTimeInterval:20];
        conversation.lastServerTimeStamp = knockMessage.serverTimestamp;
        
        [conversation fetchUnreadMessages];
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorKnock);
        
        // when
        conversation.lastReadServerTimeStamp = message2.serverTimestamp;
        
        // then
        XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorKnock);
    }];
}

@end



@implementation ZMConversationTests (HasUnreadUnsentMessage)

- (void)testThatItResetsHasUnreadUnsentMessage
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
    message1.eventID = self.createEventID;
    ZMTextMessage *message2 = [conversation appendMessagesWithText:@"haha"].firstObject;
    [message2 expire];
    
    XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorExpiredMessage);
    [self.uiMOC saveOrRollback];
    
    conversation.lastEventID = message1.eventID;
    
    // when
    [conversation setVisibleWindowFromMessage:message1 toMessage:message2];
    WaitForAllGroupsToBeEmpty(1.0);
    
    // then
    XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorNone);
}

- (void)testThatItResetsHasUnreadUnsentMessageWhenThereAreAdditionalSentMessages
{
    // given
    ZMConversation *conversation = [ZMConversation insertNewObjectInManagedObjectContext:self.uiMOC];
    ZMTextMessage *message1 = [conversation appendMessagesWithText:@"haha"].firstObject;
    message1.eventID = self.createEventID;
    ZMTextMessage *message2 = [conversation appendMessagesWithText:@"haha"].firstObject;
    [message2 expire];
    ZMTextMessage *message3 = [conversation appendMessagesWithText:@"haha"].firstObject;
    message3.eventID = [ZMEventID eventIDWithMajor:message1.eventID.major + 2 minor:self.createEventID.minor];
    
    XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorExpiredMessage);
    [self.uiMOC saveOrRollback];
    
    conversation.lastEventID = message3.eventID;
    
    // when
    [conversation setVisibleWindowFromMessage:message1 toMessage:message2];
    WaitForAllGroupsToBeEmpty(1.0);
    
    // then
    XCTAssertEqual(conversation.conversationListIndicator, ZMConversationListIndicatorNone);
}

@end


