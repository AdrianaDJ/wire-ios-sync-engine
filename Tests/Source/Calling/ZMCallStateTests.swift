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


import CoreData
@testable import zmessaging


class ZMConversationCallStateTests: MessagingTest {
    
    func checkThatItSetsHasChanges(file: String = __FILE__, line: UInt = __LINE__, block: ZMConversationCallState -> ()) {
        // given
        let sut = ZMConversationCallState(contextType: .Main)
        XCTAssertFalse(sut.hasChanges, file: file, line: line)
        
        // when
        block(sut)
        
        // then
        XCTAssertTrue(sut.hasChanges, file: file, line: line)
    }
    
    func testThatItSetsHasChanges() {
        checkThatItSetsHasChanges {
            // when
            $0.isCallDeviceActive = true
        }
        checkThatItSetsHasChanges {
            // when
            $0.isCallDeviceActive = false
        }
        checkThatItSetsHasChanges {
            // when
            $0.isFlowActive = true
        }
        checkThatItSetsHasChanges {
            // when
            $0.isFlowActive = false
        }
        checkThatItSetsHasChanges {
            // when
            $0.isIgnoringCall = false
        }
        checkThatItSetsHasChanges {
            // when
            $0.isIgnoringCall = true
        }
        checkThatItSetsHasChanges {
            // when
            let user = ZMUser.insertNewObjectInManagedObjectContext(self.uiMOC)

            $0.activeFlowParticipants = NSOrderedSet(object: user)
        }
        checkThatItSetsHasChanges {
            // when
            $0.isOutgoingCall = true;
        }
        checkThatItSetsHasChanges {
            // when
            $0.isOutgoingCall = false;
        }
        checkThatItSetsHasChanges {
            // when
            $0.timedOut = true;
        }
        checkThatItSetsHasChanges {
            // when
            $0.timedOut = false;
        }
        checkThatItSetsHasChanges {
            $0.isVideoCall = true
        }
        checkThatItSetsHasChanges {
            $0.isVideoCall = false
        }
    }
    
    func testThatSettingIsCallDeviceActiveSetsHasLocalModificationsForCallDeviceActive() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Main)
        XCTAssertFalse(sut.hasLocalModificationsForCallDeviceActive)
        
        // when
        sut.isCallDeviceActive = true
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForCallDeviceActive)
    }
    
    func testThatSettingTimedOutSetsHasLocalModificationsForTimedOut_Main() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Main)
        XCTAssertFalse(sut.hasLocalModificationsForTimedOut)
        
        // when
        sut.timedOut = true
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForTimedOut)
    }
    
    func testThatSettingTimedOutSetsHasLocalModificationsForTimedOut_Sync() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Sync)
        XCTAssertFalse(sut.hasLocalModificationsForTimedOut)
        
        // when
        sut.timedOut = true
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForTimedOut)
    }

    func testThatSettingIsCallDeviceActiveDoesNotSetHasLocalModificationsForCallDeviceActiveOnTheSyncContext() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Sync)
        XCTAssertFalse(sut.hasLocalModificationsForCallDeviceActive)
        
        // when
        sut.isCallDeviceActive = true
        
        // then
        XCTAssertFalse(sut.hasLocalModificationsForCallDeviceActive)
    }
    
    func testThatSettingIsIgnoringCallSetsHasLocalModificationsForIsIgnoringCall() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Main)
        XCTAssertFalse(sut.hasLocalModificationsForIgnoringCall)
        
        // when
        sut.isIgnoringCall = true
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForIgnoringCall)
    }
    
    func testThatSettingIsIgnoringCallDoesNotSetHasLocalModificationsForIsIgnoringCallOnTheSyncContext() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Sync)
        XCTAssertFalse(sut.hasLocalModificationsForIgnoringCall)
        
        // when
        sut.isIgnoringCall = true
        
        // then
        XCTAssertFalse(sut.hasLocalModificationsForIgnoringCall)
    }
    
    func testThatSettingIsOutgoingCallSetsHasLocalModificationsForIsOutgoingCall() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Main)
        XCTAssertFalse(sut.hasLocalModificationsForIsOutgoingCall)
        
        // when
        sut.isOutgoingCall = true
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForIsOutgoingCall)
    }
    
    func testThatSettingIsOutgoingCallSetsHasLocalModificationsForIsOutgoingCallOnTheSyncContext() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Sync)
        XCTAssertFalse(sut.hasLocalModificationsForIsOutgoingCall)
        
        // when
        sut.isOutgoingCall = true
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForIsOutgoingCall)
    }
    
    func testThatSettingActiveFlowParticipantsSetsHasLocalModificationsForActiveParticipants() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Main)
        XCTAssertFalse(sut.hasLocalModificationsForActiveParticipants)
        
        // when
        sut.activeFlowParticipants = NSOrderedSet(object: "foo")
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForActiveParticipants)
    }
    
    func testThatSettingActiveFlowParticipantsSetsHasLocalModificationsForActiveParticipantsOnTheSyncContext() {
        
        // given
        let sut = ZMConversationCallState(contextType: .Sync)
        XCTAssertFalse(sut.hasLocalModificationsForActiveParticipants)
        
        // when
        sut.activeFlowParticipants = NSOrderedSet(object: "foo")
        
        // then
        XCTAssertTrue(sut.hasLocalModificationsForActiveParticipants)
    }
}



class ZMCallStateTests : MessagingTest {
    
    func testThatItReturnsTheSameStateForTheSameConversation() {
        // given
        let sut = ZMCallState(contextType: .Main)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        let conversationB = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        // when
        let a1 = sut.stateForConversation(conversationA)
        let a2 = sut.stateForConversation(conversationA)
        let b1 = sut.stateForConversation(conversationB)
        let b2 = sut.stateForConversation(conversationB)
        
        // then
        XCTAssertTrue(a1 === a2)
        XCTAssertTrue(b1 === b2)

        XCTAssertFalse(a1 === b1)
        XCTAssertFalse(a2 === b2)
    }

    func testThatItHasChanges() {
        // given
        let sut = ZMCallState(contextType: .Main)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssertFalse(sut.hasChanges)
        
        // when
        sut.stateForConversation(conversationA).isFlowActive = true
        
        // then
        XCTAssertTrue(sut.hasChanges)
    }
    
    func testThatItCopiesStatesChangesAndResetsHasChanges() {
        // given
        let sut = ZMCallState(contextType: .Main)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        sut.stateForConversation(conversationA).isFlowActive = true
        XCTAssertTrue(sut.hasChanges)
        
        // when
        let newState = sut.createCopyAndResetHasChanges()
        
        // then
        XCTAssertFalse(sut.hasChanges)
        XCTAssertFalse(newState == nil)
    }
    
    func testThatItCopiesLocalModificationsChangesAndResetsLocalModifications() {
        // given
        let sut = ZMCallState(contextType: .Main)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        sut.stateForConversation(conversationA).isCallDeviceActive = true
        XCTAssertTrue(sut.stateForConversation(conversationA).hasLocalModificationsForCallDeviceActive)
        
        // when
        let newState = sut.createCopyAndResetHasChanges()
        
        // then
        XCTAssertFalse(sut.stateForConversation(conversationA).hasLocalModificationsForCallDeviceActive)
        AssertOptionalNotNil(newState) {
            XCTAssertTrue($0.stateForConversation(conversationA).hasLocalModificationsForCallDeviceActive)
        }
    }
    
    func testThatItReturnsNilWhenCreatingACopyWithoutChanges() {
        // given
        let sut = ZMCallState(contextType: .Main)
        _ = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        XCTAssertFalse(sut.hasChanges)
        
        // when
        let newState = sut.createCopyAndResetHasChanges()
        
        // then
        XCTAssertFalse(sut.hasChanges)
        XCTAssertTrue(newState == nil)
    }

    func testThatChangingTheOriginalDoesNotAffectTheCopy() {
        // given
        let sut = ZMCallState(contextType: .Main)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        sut.stateForConversation(conversationA).isFlowActive = true
        XCTAssertTrue(sut.hasChanges)
        
        // when
        let newState = sut.createCopyAndResetHasChanges()
        sut.stateForConversation(conversationA).isFlowActive = false
        
        // then
        AssertOptionalNotNil(newState) {
			XCTAssertTrue($0.stateForConversation(conversationA).isFlowActive, "Should still be 'true' and not affected by the 2nd isFlowActive.")
        }
    }
}


//MARK: - Merging
extension ZMConversationCallStateTests {
    
    func testThatItMergesCallDeviceIsActiveFromMainToSyncWhenItHasLocalModifications_true() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        syncSut.isCallDeviceActive = false // strictly not needed
        mainSut.isCallDeviceActive = true
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertTrue(mainSut.isCallDeviceActive)
        XCTAssertTrue(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertTrue(syncSut.isCallDeviceActive)
        XCTAssertTrue(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItMergesCallDeviceIsActiveFromMainToSyncWhenItHasLocalModifications_false() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        syncSut.isCallDeviceActive = true
        mainSut.isCallDeviceActive = false
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertFalse(mainSut.isCallDeviceActive)
        XCTAssertTrue(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.isCallDeviceActive)
        XCTAssertTrue(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.hasChanges)
    }

    func testThatItDoesNotMergeCallDeviceIsActiveFromMainToSyncWhenItHasNoLocalModifications_true() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = true
        performIgnoringZMLogError {
            mainSut.resetHasLocalModificationsForCallDeviceActive()
        }
        syncSut.isCallDeviceActive = false
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertTrue(mainSut.isCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.isCallDeviceActive)
        XCTAssertFalse(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItDoesNotMergeCallDeviceIsActiveFromMainToSyncWhenItHasNoLocalModifications_false() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = false
        performIgnoringZMLogError {
            mainSut.resetHasLocalModificationsForCallDeviceActive()
        }
        syncSut.isCallDeviceActive = true
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertFalse(mainSut.isCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertTrue(syncSut.isCallDeviceActive)
        XCTAssertFalse(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItDoesNotMergeAnythingElseFromMainToSync_true() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isFlowActive = false
        syncSut.isFlowActive = true
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertFalse(mainSut.isFlowActive)
        XCTAssertTrue(syncSut.isFlowActive)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    
    func testThatItDoesNotMergeAnythingElseFromMainToSync_false() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isFlowActive = true
        syncSut.isFlowActive = false
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertTrue(mainSut.isFlowActive)
        XCTAssertFalse(syncSut.isFlowActive)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    
    func testThatItMergesIsVideoCallFromMainToSync_true() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isVideoCall = true
        syncSut.isVideoCall = false
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertTrue(mainSut.isVideoCall)
        XCTAssertTrue(syncSut.isVideoCall)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItMergesIsVideoCallFromMainToSync_false() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isVideoCall = false
        syncSut.isVideoCall = true
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertFalse(mainSut.isVideoCall)
        XCTAssertFalse(syncSut.isVideoCall)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItMergesIsOutgoingCallFromMainToSyncWhenItHasLocalModifications() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isOutgoingCall = true
        syncSut.isOutgoingCall = false
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        XCTAssertTrue(mainSut.hasLocalModificationsForIsOutgoingCall)
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertTrue(mainSut.isOutgoingCall)
        XCTAssertTrue(syncSut.isOutgoingCall)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItMergesIsOutgoingCallFromSyncToMainWhenItHasLocalModifications() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        var syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isOutgoingCall = false
        syncSut.isOutgoingCall = true
        syncSut = syncSut.createCopy() // Create a copy to reset 'hasChanges'
        XCTAssertTrue(syncSut.hasLocalModificationsForIsOutgoingCall)
        
        // when
        mainSut.mergeChangesFromState(syncSut)
        
        // then
        XCTAssertTrue(mainSut.isOutgoingCall)
        XCTAssertTrue(syncSut.isOutgoingCall)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    
    func testThatItMergesCallDeviceIsActiveFromSyncToMainWhenItHasNoLocalModifications() {
        // given
        var mainSut = ZMConversationCallState(contextType: .Main)
        let syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = false
        performIgnoringZMLogError {
            mainSut.resetHasLocalModificationsForCallDeviceActive()
        }
        syncSut.isCallDeviceActive = true
        mainSut = mainSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        mainSut.mergeChangesFromState(syncSut)
        
        // then
        XCTAssertTrue(mainSut.isCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertTrue(syncSut.isCallDeviceActive)
        XCTAssertFalse(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasChanges)
    }

    func testThatItDoesNotMergeCallDeviceIsActiveFromSyncToMainWhenItHasLocalModifications() {
        // given
        var mainSut = ZMConversationCallState(contextType: .Main)
        let syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = false
        syncSut.isCallDeviceActive = true
        mainSut = mainSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        mainSut.mergeChangesFromState(syncSut)
        
        // then
        XCTAssertFalse(mainSut.isCallDeviceActive)
        XCTAssertTrue(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertTrue(syncSut.isCallDeviceActive)
        XCTAssertFalse(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasChanges)
    }

    func testThatItDoesNotMerge_HasLocalModifications_FromSyncToMain_true() {
        // given
        var mainSut = ZMConversationCallState(contextType: .Main)
        let syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = false
        syncSut.mergeChangesFromState(mainSut)
        performIgnoringZMLogError {
            mainSut.resetHasLocalModificationsForCallDeviceActive()
        }
        syncSut.isCallDeviceActive = true
        mainSut = mainSut.createCopy() // Create a copy to reset 'hasChanges'
        XCTAssertTrue(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        
        // when
        mainSut.mergeChangesFromState(syncSut)
        
        // then
        XCTAssertTrue(mainSut.isCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertTrue(syncSut.isCallDeviceActive)
        XCTAssertTrue(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasChanges)
    }
    
    func testThatItDoesNotMerge_HasLocalModifications_FromSyncToMain_false() {
        // given
        var mainSut = ZMConversationCallState(contextType: .Main)
        let syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = true
        syncSut.mergeChangesFromState(mainSut)
        performIgnoringZMLogError {
            mainSut.resetHasLocalModificationsForCallDeviceActive()
        }
        syncSut.isCallDeviceActive = false
        mainSut = mainSut.createCopy() // Create a copy to reset 'hasChanges'
        XCTAssertTrue(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        
        // when
        mainSut.mergeChangesFromState(syncSut)
        
        // then
        XCTAssertFalse(mainSut.isCallDeviceActive)
        XCTAssertFalse(mainSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.isCallDeviceActive)
        XCTAssertTrue(syncSut.hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasChanges)
    }
    
// TODO: Enable and verify isVideoCall flag merging
    func DISABLED_testThatItMergesEverythingElseFromSyncToMain() {
        // given
        var mainSut = ZMConversationCallState(contextType: .Main)
        let syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isFlowActive = true
        syncSut.isFlowActive = false
        mainSut.isOutgoingCall = true
        syncSut.isOutgoingCall = false
        mainSut.isVideoCall = true
        syncSut.isVideoCall = false
        mainSut = mainSut.createCopy() // Create a copy to reset 'hasChanges'
        
        // when
        mainSut.mergeChangesFromState(syncSut)
        
        // then
        XCTAssertFalse(mainSut.isFlowActive)
        XCTAssertFalse(syncSut.isFlowActive)
        XCTAssertFalse(mainSut.isOutgoingCall)
        XCTAssertFalse(syncSut.isOutgoingCall)
        XCTAssertFalse(mainSut.isVideoCall)
        XCTAssertFalse(syncSut.isVideoCall)
        XCTAssertFalse(mainSut.hasChanges)
    }
    
    func testThatMergingDoesNotClearTheHasChangesFlag() {
        // given
        let mainSut = ZMConversationCallState(contextType: .Main)
        let syncSut = ZMConversationCallState(contextType: .Sync)
        mainSut.isCallDeviceActive = true
        syncSut.isFlowActive = true
        
        // when
        syncSut.mergeChangesFromState(mainSut)
        
        // then
        XCTAssertTrue(syncSut.isCallDeviceActive)
        XCTAssertTrue(syncSut.hasChanges)
    }
}

extension ZMCallStateTests {
    
    
    func testThatItReturnsAnEmptySetWhenReturningANilCallStateOnCreateCopy() {
        // given
        let syncSut = ZMCallState(contextType: .Sync)
        let mainSut = ZMCallState(contextType: .Main)
        
        XCTAssertFalse(syncSut.hasChanges)
        
        // when
        let newSyncState = syncSut.createCopyAndResetHasChanges()
        XCTAssertTrue(newSyncState == nil)
        let objectIDs = mainSut.mergeChangesFromState(newSyncState)
        
        // then
        XCTAssertNotNil(objectIDs)
        XCTAssertEqual(objectIDs, Set())
    }
    
    func testThatItMergesAllConversations_MainToSync() {
        // given
        let mainSut = ZMCallState(contextType: .Main)
        let syncSut = ZMCallState(contextType: .Sync)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        let conversationB = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        mainSut.stateForConversation(conversationA).isCallDeviceActive = false
        mainSut.stateForConversation(conversationB).isCallDeviceActive = true
        
        // when
        if let c = mainSut.createCopyAndResetHasChanges() {
            syncSut.mergeChangesFromState(c)
        }

        // then
        XCTAssertFalse(mainSut.stateForConversation(conversationA).isCallDeviceActive)
        XCTAssertTrue(mainSut.stateForConversation(conversationB).isCallDeviceActive)
        XCTAssertFalse(mainSut.stateForConversation(conversationA).hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.stateForConversation(conversationB).hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(mainSut.hasChanges)

        XCTAssertFalse(syncSut.stateForConversation(conversationA).isCallDeviceActive)
        XCTAssertTrue(syncSut.stateForConversation(conversationB).isCallDeviceActive)
        XCTAssertTrue(syncSut.stateForConversation(conversationA).hasLocalModificationsForCallDeviceActive)
        XCTAssertTrue(syncSut.stateForConversation(conversationB).hasLocalModificationsForCallDeviceActive)
        XCTAssertFalse(syncSut.hasChanges)
    }
    
    func testThatItReturnsAllConversationIDsThatChanged() {
        // given
        let mainSut = ZMCallState(contextType: .Main)
        let syncSut = ZMCallState(contextType: .Sync)
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        let conversationB = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        self.syncMOC.saveOrRollback()
        
        XCTAssertFalse(mainSut.stateForConversation(conversationA).isCallDeviceActive)
        XCTAssertFalse(mainSut.stateForConversation(conversationB).isCallDeviceActive)
        
        mainSut.stateForConversation(conversationA).isCallDeviceActive = false
        mainSut.stateForConversation(conversationB).isCallDeviceActive = true
        
        // when
        var changedConversations : Set<NSManagedObjectID> = Set()
        if let c = mainSut.createCopyAndResetHasChanges() {
            changedConversations = syncSut.mergeChangesFromState(c)
        }
        
        // then
        XCTAssertEqual(changedConversations.count, 2)
        XCTAssertTrue(changedConversations.contains(conversationA.objectID))
        XCTAssertTrue(changedConversations.contains(conversationB.objectID))
    }
    
    func testThatItReturnsAllConversationsThatAreChanged() {
        // given
        let mainSut = self.uiMOC.zm_callState
        
        let conversationA = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        let conversationB = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        self.uiMOC.saveOrRollback()
        
        mainSut.stateForConversation(conversationA).isCallDeviceActive = false
        mainSut.stateForConversation(conversationB).isCallDeviceActive = true
        
        XCTAssertTrue(self.uiMOC.zm_callState.hasChanges)
        XCTAssertTrue(self.uiMOC.zm_callState.hasChanges)

        // when
        let changedConversations = self.syncMOC.mergeCallStateChanges(self.uiMOC.zm_callState.createCopyAndResetHasChanges())
        
        // then
        XCTAssertEqual(changedConversations.count, 2)
        let objectIDs = Array(changedConversations).map{$0.objectID}
        XCTAssertTrue(objectIDs.contains(conversationA.objectID))
        XCTAssertTrue(objectIDs.contains(conversationB.objectID))
    }
    
    func testThatWhenMergingIsIgnoringCall_No_FromMainIntoSyncItDoesNotSetHasLocalmodifcations() {
        // given
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .OneOnOne
        self.uiMOC.saveOrRollback()

        // when
        conversation.isIgnoringCall = true
        let callState1 = self.uiMOC.zm_callState.createCopyAndResetHasChanges()
        self.syncMOC.mergeCallStateChanges(callState1)
        XCTAssertFalse(conversation.hasLocalModificationsForIsIgnoringCall)

        // then
        let syncConversation = self.syncMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(syncConversation)
        if let syncConversation = syncConversation {
            XCTAssertTrue(syncConversation.isIgnoringCall)
            XCTAssertTrue(syncConversation.hasLocalModificationsForIsIgnoringCall)
        } else {
            XCTFail()
        }
        
        // when
        conversation.isIgnoringCall = false
        let callState2 = self.uiMOC.zm_callState.createCopyAndResetHasChanges()
        self.syncMOC.mergeCallStateChanges(callState2)
        XCTAssertFalse(conversation.hasLocalModificationsForIsIgnoringCall)

        // then
        XCTAssertNotNil(syncConversation)
        if let syncConversation = syncConversation {
            XCTAssertFalse(syncConversation.isIgnoringCall)
            XCTAssertFalse(syncConversation.hasLocalModificationsForIsIgnoringCall)
        } else {
            XCTFail()
        }
    }
    
    func testThatWhenMergingIsIgnoringCallFromSyncIntoMainItDoesNotSetHasLocalmodifcations() {
        // given
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.syncMOC)
            conversation.conversationType = .OneOnOne
            self.syncMOC.saveOrRollback()
            
            // when
            conversation.isIgnoringCall = true
        }
        let callState1 = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState1)
        
        // then
        XCTAssertTrue(conversation.isIgnoringCall)
        XCTAssertFalse(conversation.hasLocalModificationsForIsIgnoringCall)
        
        let uiConversation = self.uiMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(uiConversation)
        if let uiConversation = uiConversation {
            XCTAssertTrue(uiConversation.isIgnoringCall)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsIgnoringCall)
            
        } else {
            XCTFail()
        }
        
        // when
        self.syncMOC.performGroupedBlockAndWait{
            conversation.isIgnoringCall = false
        }
        let callState2 = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState2)
        
        // then
        XCTAssertFalse(conversation.isIgnoringCall)
        XCTAssertFalse(conversation.hasLocalModificationsForIsIgnoringCall)
        
        XCTAssertNotNil(uiConversation)
        if let uiConversation = uiConversation {
            XCTAssertFalse(uiConversation.isIgnoringCall)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsIgnoringCall)
            
        } else {
            XCTFail()
        }
    }
}


// MARK: VideoCalling
extension ZMCallStateTests {
    
    func testThatItMergesChangesOnIsVideoCallFromMainIntoSync() {
        // given
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .OneOnOne
        self.uiMOC.saveOrRollback()
        
        // when
        try! conversation.voiceChannel.joinVideoCall()
        let callState = self.uiMOC.zm_callState.createCopyAndResetHasChanges()
        self.syncMOC.mergeCallStateChanges(callState)
        
        // then
        XCTAssertTrue(conversation.isVideoCall)
        XCTAssertFalse(conversation.hasLocalModificationsForIsVideoCall)

        let syncConversation = self.syncMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(syncConversation)
        if let syncConversation = syncConversation {
            XCTAssertTrue(syncConversation.isVideoCall)
            XCTAssertFalse(syncConversation.hasLocalModificationsForIsVideoCall)
        } else {
            XCTFail()
        }
    }
    
    func testThatItMergesChangesOnIsVideoCallFromSyncIntoMain() {
        // given
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.syncMOC)
            conversation.conversationType = .OneOnOne
            self.syncMOC.saveOrRollback()
            
            // when
            conversation.isVideoCall = true
        }
        let callState = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState)
        
        // then
        XCTAssertTrue(conversation.isVideoCall)
        XCTAssertFalse(conversation.hasLocalModificationsForIsVideoCall)

        let uiConversation = self.uiMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(uiConversation)
        if let uiConversation = uiConversation {
            XCTAssertTrue(uiConversation.isVideoCall)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsVideoCall)

        } else {
            XCTFail()
        }
    }
    
    
    func testThatItMergesChangesOnIsSendingVideoFromMainIntoSync() {
        // given
        let conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.uiMOC)
        conversation.conversationType = .OneOnOne
        self.uiMOC.saveOrRollback()
        
        // when
        conversation.isSendingVideo = true
        let callState = self.uiMOC.zm_callState.createCopyAndResetHasChanges()
        self.syncMOC.mergeCallStateChanges(callState)
        
        // then
        XCTAssertTrue(conversation.isSendingVideo)
        XCTAssertFalse(conversation.hasLocalModificationsForIsSendingVideo)
        
        let syncConversation = self.syncMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(syncConversation)
        if let syncConversation = syncConversation {
            XCTAssertTrue(syncConversation.isSendingVideo)
            // we want to send out a call.state event to sync changed state
            XCTAssertTrue(syncConversation.hasLocalModificationsForIsSendingVideo)
        } else {
            XCTFail()
        }
    }
    
    func testThatItMergesChangesOnIsSendingVideoFromSyncIntoMain() {
        // given
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.syncMOC)
            conversation.conversationType = .OneOnOne
            self.syncMOC.saveOrRollback()
            
            // when we force to sync changes made on the syncMOC
            conversation.isSendingVideo = true
            conversation.syncLocalModificationsOfIsSendingVideo()
            
            XCTAssertTrue(conversation.isSendingVideo)
            XCTAssertTrue(conversation.hasLocalModificationsForIsSendingVideo)
        }
        let callState = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState)
        
        // then hasLocalModifications on the SyncMoc are preserved
        XCTAssertTrue(conversation.isSendingVideo)
        XCTAssertTrue(conversation.hasLocalModificationsForIsSendingVideo)
        
        let uiConversation = self.uiMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(uiConversation)
        if let uiConversation = uiConversation {
            XCTAssertTrue(uiConversation.isSendingVideo)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsSendingVideo)
            
        } else {
            XCTFail()
        }
        
        self.syncMOC.performGroupedBlockAndWait{
            // when resetting haslocalModifications
            conversation.resetHasLocalModificationsForIsSendingVideo()
            XCTAssertFalse(conversation.hasLocalModificationsForIsSendingVideo)
        }
        let callState2 = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState2)
        
        // then hasLocalModfications on syncMOC are reset
        XCTAssertTrue(conversation.isSendingVideo)
        XCTAssertFalse(conversation.hasLocalModificationsForIsSendingVideo)
        
        if let uiConversation = uiConversation {
            XCTAssertTrue(uiConversation.isSendingVideo)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsSendingVideo)
            
        } else {
            XCTFail()
        }
    }
    
    
    func testThatItMergesChangesOnIsSendingVideoFromSyncIntoMain_UIMakesChanges() {
        // given
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.syncMOC)
            conversation.conversationType = .OneOnOne
            self.syncMOC.saveOrRollback()
            
            // when we force to sync changes made on the syncMOC
            conversation.isSendingVideo = true
            conversation.syncLocalModificationsOfIsSendingVideo()
            
            XCTAssertTrue(conversation.isSendingVideo)
            XCTAssertTrue(conversation.hasLocalModificationsForIsSendingVideo)
        }
        let callState = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState)
        
        // then hasLocalModifications on the SyncMoc are preserved
        XCTAssertTrue(conversation.isSendingVideo)
        XCTAssertTrue(conversation.hasLocalModificationsForIsSendingVideo)
        
        let uiConversation = self.uiMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(uiConversation)
        if let uiConversation = uiConversation {
            XCTAssertTrue(uiConversation.isSendingVideo)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsSendingVideo)
            
            // and when the UI stops sending video before changes where performed
            uiConversation.isSendingVideo = false
            
            XCTAssertFalse(uiConversation.isSendingVideo)
            XCTAssertTrue(uiConversation.hasLocalModificationsForIsSendingVideo)
        } else {
            XCTFail()
        }
        
        let callState2 = self.uiMOC.zm_callState.createCopyAndResetHasChanges()
        self.syncMOC.mergeCallStateChanges(callState2)
        
        // then hasLocalModfications on syncMOC not reset
        XCTAssertFalse(conversation.isSendingVideo)
        XCTAssertTrue(conversation.hasLocalModificationsForIsSendingVideo)
        
        if let uiConversation = uiConversation {
            XCTAssertFalse(uiConversation.isSendingVideo)
            XCTAssertFalse(uiConversation.hasLocalModificationsForIsSendingVideo)
            
        } else {
            XCTFail()
        }
    }
    
    func testThatItMergesActiveVideoCallParticipantsSyncIntoMain() {
        // given
        var conversation : ZMConversation!
        self.syncMOC.performGroupedBlockAndWait{
            conversation = ZMConversation.insertNewObjectInManagedObjectContext(self.syncMOC)
            conversation.conversationType = .OneOnOne
            let user = ZMUser.insertNewObjectInManagedObjectContext(self.syncMOC)
            self.syncMOC.saveOrRollback()
            
            // when
            conversation.isFlowActive = true
            conversation.addActiveVideoCallParticipant(user)
        }
        let callState = self.syncMOC.zm_callState.createCopyAndResetHasChanges()
        self.uiMOC.mergeCallStateChanges(callState)
        
        // then
        XCTAssertEqual(conversation.otherActiveVideoCallParticipants.count, 1)
        
        let uiConversation = self.uiMOC.objectWithID(conversation.objectID) as? ZMConversation
        XCTAssertNotNil(uiConversation)
        if let uiConversation = uiConversation {
            XCTAssertEqual(uiConversation.otherActiveVideoCallParticipants.count, 1)
        } else {
            XCTFail()
        }
    }
    
    
}
