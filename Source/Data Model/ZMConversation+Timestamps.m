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


@import ZMTransport;

#import "ZMConversation+Timestamps.h"
#import "ZMConversation+Internal.h"
#import "ZMUpdateEvent.h"
#import "NSManagedObjectContext+zmessaging.h"

@implementation ZMConversation (Timestamps)


+ (NSDate *)updateTimeStamp:(NSDate *)timeToUpdate ifNeededWithTimeStamp:(NSDate *)newTimeStamp
{
    if ((newTimeStamp != nil) &&
        (timeToUpdate == nil || [timeToUpdate compare:newTimeStamp] == NSOrderedAscending))
    {
        return newTimeStamp;
    }
    return nil;
}

- (BOOL)updateLastServerTimeStampIfNeeded:(NSDate *)serverTimeStamp
{
    NSDate *newTime = [ZMConversation updateTimeStamp:self.lastServerTimeStamp ifNeededWithTimeStamp:serverTimeStamp];
    if (newTime != nil) {
        self.lastServerTimeStamp = newTime;
    }
    return (newTime != nil);
}

- (BOOL)updateLastReadServerTimeStampIfNeededWithTimeStamp:(NSDate *)timeStamp andSync:(BOOL)shouldSync
{
    NSDate *newTime = [ZMConversation updateTimeStamp:self.lastReadServerTimeStamp ifNeededWithTimeStamp:timeStamp];
    if (newTime != nil) {
        self.lastReadServerTimeStamp = newTime;
        BOOL isSyncContext = self.managedObjectContext.zm_isSyncContext; // modified keys are set "automatically" on the uiMOC
        if (shouldSync && self.lastReadServerTimeStamp != nil && isSyncContext) {
            [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationLastReadServerTimeStampKey]];
        }
    }
    return (newTime != nil);
}

- (BOOL)updateLastModifiedDateIfNeeded:(NSDate *)date
{
    NSDate *newTime =  [ZMConversation updateTimeStamp:self.lastModifiedDate ifNeededWithTimeStamp:date];
    if (newTime != nil) {
        self.lastModifiedDate = newTime;
    }
    return (newTime != nil);
}

- (BOOL)updateClearedServerTimeStampIfNeeded:(NSDate *)date andSync:(BOOL)shouldSync
{
    NSDate *newTime =  [ZMConversation updateTimeStamp:self.clearedTimeStamp ifNeededWithTimeStamp:date];
    if (newTime != nil) {
        self.clearedTimeStamp = newTime;
        if (shouldSync && self.managedObjectContext.zm_isSyncContext) {
            [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationClearedTimeStampKey]];
        }
    }
    return (newTime != nil);
}

- (BOOL)updateArchivedChangedTimeStampIfNeeded:(NSDate *)date andSync:(BOOL)shouldSync
{
    NSDate *newTime =  [ZMConversation updateTimeStamp:self.archivedChangedTimestamp ifNeededWithTimeStamp:date];
    if (newTime != nil) {
        self.archivedChangedTimestamp = newTime;
        if (shouldSync && self.managedObjectContext.zm_isSyncContext) {
            [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationArchivedChangedTimeStampKey]];
        }
    }
    BOOL sameTime = (self.archivedChangedTimestamp != nil && [self.archivedChangedTimestamp compare:date] == NSOrderedSame);
    if (sameTime && shouldSync) {
        [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationArchivedChangedTimeStampKey]];
    }
    return (newTime != nil) || sameTime;
}

- (BOOL)updateSilencedChangedTimeStampIfNeeded:(NSDate *)date andSync:(BOOL)shouldSync
{
    NSDate *newTime =  [ZMConversation updateTimeStamp:self.silencedChangedTimestamp ifNeededWithTimeStamp:date];
    if (newTime != nil) {
        self.silencedChangedTimestamp = newTime;
        if (shouldSync && self.managedObjectContext.zm_isSyncContext) {
            [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationSilencedChangedTimeStampKey]];
        }
    }
    BOOL sameTime = (self.silencedChangedTimestamp != nil && [self.silencedChangedTimestamp compare:date] == NSOrderedSame);
    if (sameTime && shouldSync) {
        [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationSilencedChangedTimeStampKey]];
    }
    return (newTime != nil) || sameTime;
}


- (ZMEventID *)updateEventID:(ZMEventID *)eventIDToUpdate ifNeededWithEventID:(ZMEventID *)newEventID
{
    if (newEventID != nil &&
        (eventIDToUpdate == nil || [eventIDToUpdate compare:newEventID] == NSOrderedAscending)) {
        return newEventID;
    }
    return nil;
}

- (BOOL)updateLastReadEventIDIfNeededWithEventID:(ZMEventID *)eventID
{
    ZMEventID *newID = [self updateEventID:self.lastReadEventID ifNeededWithEventID:eventID];
    if (newID != nil) {
        self.lastReadEventID = newID;
    }
    return (newID != nil);
}

- (BOOL)updateLastEventIDIfNeededWithEventID:(ZMEventID *)eventID
{
    ZMEventID *newID =  [self updateEventID:self.lastEventID ifNeededWithEventID:eventID];
    if (newID != nil) {
        self.lastEventID = newID;
    }
    return (newID != nil);
}


- (BOOL)updateClearedEventIDIfNeededWithEventID:(ZMEventID *)eventID andSync:(BOOL)shouldSync
{
    ZMEventID *newID =  [self updateEventID:self.clearedEventID ifNeededWithEventID:eventID];
    if (newID != nil) {
        self.clearedEventID = newID;
        if (shouldSync && self.managedObjectContext.zm_isSyncContext) {
            [self setLocallyModifiedKeys:[NSSet setWithObject:ZMConversationClearedEventIDDataKey]];
        }
    }
    return (newID != nil);
}


@end
