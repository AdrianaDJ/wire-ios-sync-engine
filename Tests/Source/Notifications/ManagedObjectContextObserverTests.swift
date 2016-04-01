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


import Foundation


class ManagedObjectContextObserverTests : MessagingTest {
    
    override func setUp(){
        super.setUp()
        NSNotificationCenter.defaultCenter().postNotificationName("ZMApplicationDidEnterEventProcessingStateNotification", object: nil)
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))

    }
    
    class TestObserver : NSObject, ZMConversationObserver, ZMUserObserver, ZMVoiceChannelStateObserver {
    
        var conversationNotes: [ConversationChangeInfo] = []
        var userNotes: [UserChangeInfo] = []
        var voiceChannelNotes: [VoiceChannelStateChangeInfo] = []

        func conversationDidChange(note: ConversationChangeInfo!) {
            conversationNotes.append(note)
        }
        func userDidChange(note: UserChangeInfo!) {
            userNotes.append(note)
        }
        
        func voiceChannelStateDidChange(note: VoiceChannelStateChangeInfo) {
            voiceChannelNotes.append(note)
        }
    }
    
    func testThatItDoesNotPropagateChangesWhenAppIsInTheBackground() {
        
        // given
        self.uiMOC.globalManagedObjectContextObserver.isTesting = true
        
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .Group
        self.uiMOC.saveOrRollback()
        
        let observer = TestObserver()
        let token = conversation.addConversationObserver(observer)
        
        // when
        // app goes into the background
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Background

        conversation.userDefinedName = "Hans"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.conversationNotes.count, 0)
        ZMConversation.removeConversationObserverForToken(token)
    }
    
    func testThatItNotifiesAllObserversWhenTheAppGoesBackInTheForeground() {
        
        // given
        self.uiMOC.globalManagedObjectContextObserver.isTesting = true

        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.name = "Hans"

        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .OneOnOne
        conversation.connection = ZMConnection.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.connection.to =  user
        conversation.connection.status = .Accepted
        self.uiMOC.saveOrRollback()
        
        let observer = TestObserver()
        let conversationToken = conversation.addConversationObserver(observer)
        let userToken = ZMUser.addUserObserver(observer, forUsers: [user], managedObjectContext: self.uiMOC)
        
        // when
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Background

        user.name = "Horst"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.conversationNotes.count, 0)
        XCTAssertEqual(observer.userNotes.count, 0)
        
        // and when
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Active
        NSNotificationCenter.defaultCenter().postNotificationName(UIApplicationDidBecomeActiveNotification, object: nil)
        XCTAssert(waitForAllGroupsToBeEmptyWithTimeout(0.5))

        // then
        XCTAssertEqual(observer.conversationNotes.count, 1)
        XCTAssertEqual(observer.userNotes.count, 1)

        ZMConversation.removeConversationObserverForToken(conversationToken)
        ZMUser.removeUserObserverForToken(userToken)
    }
    
    
    func testThatItAddsCallStateChangesAndProcessThemLater() {
        // given
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .Group
        self.uiMOC.saveOrRollback()
        
        let observer = TestObserver()
        let voiceChannelToken = conversation.voiceChannel.addVoiceChannelStateObserver(observer)
        
        // when
        conversation.callDeviceIsActive = true;
        self.uiMOC.globalManagedObjectContextObserver.notifyUpdatedCallState(Set(arrayLiteral:conversation), notifyDirectly: false)
        
        // then
        XCTAssertEqual(observer.voiceChannelNotes.count, 0)
        
        // and when
        NSNotificationCenter.defaultCenter().postNotificationName(NSManagedObjectContextObjectsDidChangeNotification, object: self.uiMOC)
        
        // then
        XCTAssertEqual(observer.voiceChannelNotes.count, 1)
        
        conversation.voiceChannel.removeVoiceChannelStateObserverForToken(voiceChannelToken)
    }
    
    func testThatItAddsCallStateChangesAndProcessesThemDirectly() {
        // given
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .Group
        self.uiMOC.saveOrRollback()
        
        let observer = TestObserver()
        let voiceChannelToken = conversation.voiceChannel.addVoiceChannelStateObserver(observer)
        
        // when
        conversation.callDeviceIsActive = true;
        self.uiMOC.globalManagedObjectContextObserver.notifyUpdatedCallState(Set(arrayLiteral:conversation), notifyDirectly: true)
        
        // then
        XCTAssertEqual(observer.voiceChannelNotes.count, 1)
        observer.voiceChannelNotes = []
        
        // and when
        NSNotificationCenter.defaultCenter().postNotificationName(NSManagedObjectContextObjectsDidChangeNotification, object: self.uiMOC)
        
        // then
        XCTAssertEqual(observer.voiceChannelNotes.count, 0)
        
        conversation.voiceChannel.removeVoiceChannelStateObserverForToken(voiceChannelToken)
    }
    
    func testThatItFiltersZombieObjectsFromManagedObjectChangesInsertedAndUpdated() {
        // given
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        let zombieConversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        let nonManagedObject = NSArray()
        let arrayContainingZombies = [nonManagedObject, conversation, zombieConversation]
        
        // when
        self.uiMOC.deleteObject(zombieConversation)
        self.uiMOC.saveOrRollback()
        XCTAssertTrue(zombieConversation.isZombieObject)
        
        let changes = ManagedObjectChanges(
            inserted: arrayContainingZombies,
            deleted: arrayContainingZombies,
            updated: arrayContainingZombies
        )
        
        let filteredChanges = changes.changesWithoutZombies
        
        // then
        for changeType in [filteredChanges.inserted, filteredChanges.updated] {
            XCTAssertEqual(changeType.count, 2)
            XCTAssertTrue(changeType.contains(nonManagedObject))
            XCTAssertTrue(changeType.contains(conversation))
            for object in changeType where object is ZMManagedObject {
                XCTAssertFalse((object as! ZMManagedObject).isZombieObject)
            }
        }
        
        // deleted objects are zombies but we still want to be notified
        XCTAssertTrue(filteredChanges.deleted.contains(zombieConversation))
        XCTAssertEqual(filteredChanges.deleted.count, 3)
    }
    
    func testThatItAddsTheGlobalConversationObserverToItsObserversWhenEnteringTheForeground()  {
    
        // given
        self.uiMOC.globalManagedObjectContextObserver.isTesting = true
        
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .Group
        self.uiMOC.saveOrRollback()
        
        let observer = TestObserver()
        let conversationToken = conversation.addConversationObserver(observer)
        
        // when
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Background
        conversation.userDefinedName = "New name"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.conversationNotes.count, 0)
        
        // when
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Active
        conversation.userDefinedName = "Newer name"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.conversationNotes.count, 1)
        
        ZMConversation.removeConversationObserverForToken(conversationToken)
    }
    
    
    func testThatItAddsTheGlobalUserObserverToItsObserversWhenEnteringTheForeground()  {
        
        // given
        self.uiMOC.globalManagedObjectContextObserver.isTesting = true
        
        let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)
        user.name = "Hans"
        
        let observer = TestObserver()
        let userToken = ZMUser.addUserObserver(observer, forUsers: [user], managedObjectContext: self.uiMOC)
        
        // when
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Background
        user.name = "New name"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.userNotes.count, 0)
        
        // when
        self.uiMOC.globalManagedObjectContextObserver.applicationStateForTesting = .Active
        user.name = "Newer name"
        self.uiMOC.saveOrRollback()
        
        // then
        XCTAssertEqual(observer.userNotes.count, 1)
        
        ZMUser.removeUserObserverForToken(userToken)
    }
    
}
