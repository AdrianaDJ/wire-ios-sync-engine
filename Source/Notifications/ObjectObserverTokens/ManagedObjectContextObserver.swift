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


import Foundation
#if os(iOS)
    import CoreTelephony
#endif
import ZMCSystem


public enum ObjectObserverType: Int {
    case Invalid = 0
    case Connection
    case Client
    case User
    case SearchUser
    case Message
    case Conversation
    case VoiceChannel
    case ConversationMessageWindow
    case ConversationList
    
    static func observerTypeForObject(object: NSObject) -> ObjectObserverType {
        if object is ZMConnection {
            return .Connection
        } else if object is ZMUser {
            return .User
        } else if object is ZMMessage {
            return .Message
        } else if object is ZMConversation {
            return .Conversation
        } else if object is ZMSearchUser {
            return .SearchUser
        } else if object is UserClient {
            return .Client
        }
        return .Invalid
    }
    
    func observedObjectType() -> ObjectObserverType {
        switch self {
        case .VoiceChannel:
            return .Conversation
        case .ConversationMessageWindow:
            return .Conversation
        case .ConversationList:
            return .Conversation
        default:
            return self
        }
    }
    
    func printDescription() -> String {
        switch self {
        case Invalid:
            return "Invalid"
        case Connection:
            return "Connection"
        case User:
            return "User"
        case SearchUser:
            return "SearchUser"
        case Message:
            return "Message"
        case Conversation:
            return "Conversation"
        case .VoiceChannel:
            return "VoiceChannel"
        case ConversationMessageWindow:
            return "ConversationMessageWindow"
        case ConversationList:
            return "ConversationList"
        case Client:
            return "UserClient"
        }
    }
}

public struct ManagedObjectChangesByObserverType {
    private let inserted: [ObjectObserverType : [NSObject]]
    private let deleted: [ObjectObserverType : [NSObject]]
    private let updated: [ObjectObserverType : [NSObject]]
    
    static func mapByObjectObserverType(set: [NSObject]) -> [ObjectObserverType : [NSObject]] {
        var mapping : [ObjectObserverType : [NSObject]] = [:]
        for obj in set {
            let observerType = ObjectObserverType.observerTypeForObject(obj)
            let previous = mapping[observerType] ?? []
            mapping[observerType] = previous + [obj]
        }
        return mapping
    }
    
    init(inserted: [NSObject], deleted: [NSObject], updated: [NSObject]){
        self.inserted = ManagedObjectChangesByObserverType.mapByObjectObserverType(inserted)
        self.deleted = ManagedObjectChangesByObserverType.mapByObjectObserverType(deleted)
        self.updated = ManagedObjectChangesByObserverType.mapByObjectObserverType(updated)
    }
    
    init(changes: ManagedObjectChanges) {
        self.init(inserted: changes.inserted, deleted: changes.deleted, updated: changes.updated)
    }
    
    func changesForObserverType(observerType : ObjectObserverType) -> ManagedObjectChanges {
        
        let objectType = observerType.observedObjectType()
        
        let filterInserted = inserted[objectType] ?? []
        let filterDeleted = deleted[objectType] ?? []
        let filterUpdated = updated[objectType] ?? []
        
        return ManagedObjectChanges(
            inserted: filterInserted,
            deleted: filterDeleted,
            updated: filterUpdated
        )
    }
}

public struct ManagedObjectChanges: CustomDebugStringConvertible {
    
    public let inserted: [NSObject]
    public let deleted: [NSObject]
    public let updated: [NSObject]
    
    public init(inserted: [NSObject], deleted: [NSObject], updated: [NSObject]){
        self.inserted = inserted
        self.deleted = deleted
        self.updated = updated
    }
    
    init() {
        self.inserted = []
        self.deleted = []
        self.updated = []
    }
    
    func changesByAppendingChanges(changes: ManagedObjectChanges) -> ManagedObjectChanges {
        let inserted = self.inserted + changes.inserted
        let deleted = self.deleted + changes.deleted
        let updated = self.updated + changes.updated
        
        return ManagedObjectChanges(inserted: inserted, deleted: deleted, updated: updated)
    }
    
    public var changesWithoutZombies: ManagedObjectChanges {
        let isNoZombie: NSObject -> Bool = {
            guard let managedObject = $0 as? ZMManagedObject else { return true }
            return !managedObject.isZombieObject
        }

        return ManagedObjectChanges(
            inserted: inserted.filter(isNoZombie),
            deleted: deleted,
            updated: updated.filter(isNoZombie)
        )
    }
    
    init(note: NSNotification) {

        var inserted, deleted: [NSObject]?
        var updatedAndRefreshed = [NSObject]()
        
        if let insertedSet = note.userInfo?[NSInsertedObjectsKey] as? Set<NSObject> {
            inserted = Array(insertedSet)
        }
        
        if let deletedSet = note.userInfo?[NSDeletedObjectsKey] as? Set<NSObject> {
            deleted = Array(deletedSet)
        }
        
        if let updatedSet = note.userInfo?[NSUpdatedObjectsKey] as? Set<NSObject> {
            updatedAndRefreshed.appendContentsOf(updatedSet)
        }
        
        if let refreshedSet = note.userInfo?[NSRefreshedObjectsKey] as? Set<NSObject> {
            updatedAndRefreshed.appendContentsOf(refreshedSet)
        }
        
        self.init(inserted: inserted ?? [], deleted: deleted ?? [], updated: updatedAndRefreshed)
    }
    
    public var debugDescription : String { return "Inserted: \(SwiftDebugging.shortDescription(inserted)), updated: \(SwiftDebugging.shortDescription(updated)), deleted: \(SwiftDebugging.shortDescription(deleted))" }
    public var description : String { return debugDescription }
    
    public var isEmpty : Bool {
        return self.inserted.count + self.updated.count + self.deleted.count == 0
    }
}

public func +(lhs: ManagedObjectChanges, rhs: ManagedObjectChanges) -> ManagedObjectChanges {
    return lhs.changesByAppendingChanges(rhs)
}

public protocol ObjectsDidChangeDelegate: NSObjectProtocol {
    func objectsDidChange(changes: ManagedObjectChanges)
    func tearDown()
}




// MARK: - ManagedObjectContextObserver

let ManagedObjectContextObserverKey = "ManagedObjectContextObserverKey"

extension NSManagedObjectContext {
    
    public var globalManagedObjectContextObserver : ManagedObjectContextObserver {
        if let observer = self.userInfo[ManagedObjectContextObserverKey] as? ManagedObjectContextObserver {
            return observer
        }
        
        let newObserver = ManagedObjectContextObserver(managedObjectContext: self)
        self.userInfo[ManagedObjectContextObserverKey] = newObserver
        newObserver.setup()
        return newObserver
    }
}

public final class ManagedObjectContextObserver: NSObject {
    
    typealias ObserversCollection = [ObjectObserverType : NSHashTable]
    
    private var observers : ObserversCollection = [:]
    
    private let managedObjectContext : NSManagedObjectContext
    
    private var globalConversationObserver : GlobalConversationObserver?
    
    private var accumulatedChanges = ManagedObjectChanges()
    private var changedCallStateConversations = ManagedObjectChanges()

    #if os(iOS)
    public var isTesting = false
    public var applicationStateForTesting : UIApplicationState = .Active
    
    public let callCenter = CTCallCenter()
    #endif

    private var isInForeground : Bool {
        #if os(iOS)
            if isTesting {
                return applicationStateForTesting == .Active
            }
            return UIApplication.sharedApplication().applicationState == .Active
        #else
            return true
        #endif
    }
    
    public init(managedObjectContext: NSManagedObjectContext) {
        self.managedObjectContext = managedObjectContext
        super.init()
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "managedObjectsDidChange:", name: NSManagedObjectContextObjectsDidChangeNotification, object: self.managedObjectContext)
        
        #if os(iOS)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "didBecomeActive:", name: UIApplicationDidBecomeActiveNotification, object: nil)
        #endif
    }
    
    func setup() {
        self.globalConversationObserver = GlobalConversationObserver(managedObjectContext: managedObjectContext)
        let weakConversationListTable = NSHashTable.weakObjectsHashTable()
        weakConversationListTable.addObject(self.globalConversationObserver!)
        self.observers[.ConversationList] = weakConversationListTable
    }
    
    public func tearDown() {
        self.globalConversationObserver?.tearDown()
        for hashTable in self.observers.values {
            for observer in hashTable.allObjects {
                if let observer = observer as? ObjectsDidChangeDelegate {
                    observer.tearDown()
                }
            }
        }
        self.observers = [:]
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    deinit {
       tearDown()
    }
    
    func changesFromDisplayNameGenerator(note: NSNotification) -> ManagedObjectChanges {
        let updatedUsers = managedObjectContext.updateDisplayNameGeneratorWithChanges(note)
        let changes = ManagedObjectChanges(inserted: [], deleted: [], updated: Array(updatedUsers))
        return changes
    }
    
    func processChanges(changes: ManagedObjectChanges) {
        if isInForeground {
            propagateChangesToObservers(changes)
        } else {
            accumulatedChanges = accumulatedChanges + changes
        }
    }
    
    func managedObjectsDidChange(note: NSNotification) {
        let changes = ManagedObjectChanges(note: note)
            + changesFromDisplayNameGenerator(note)
            + changedCallStateConversations
        
        changedCallStateConversations = ManagedObjectChanges()
        processChanges(changes)
    }
    
    private func propagateChangesToObservers(changes: ManagedObjectChanges) {
        
        let tp = ZMSTimePoint(interval: 10, label: "ManagedObjectContextObserver propagateChangesToObserver");
        let changesByType = ManagedObjectChangesByObserverType(changes: changes)
        
        var index = 1
        while let observerType = ObjectObserverType(rawValue: index) {
            
            let changesForObservers = changesByType.changesForObserverType(observerType)
            propagateChangesForObservers(changesForObservers, observerType: observerType)
            index++
        }
        tp.warnIfLongerThanInterval()
    }
    
    func didBecomeActive(note: NSNotification) {
        let changes = self.accumulatedChanges
        self.accumulatedChanges = ManagedObjectChanges()
        
        propagateChangesToObservers(changes)
    }
    
    @objc public func notifyUpdatedSearchUser(user: ZMSearchUser) {
        
        let changes = ManagedObjectChanges(inserted: [], deleted: [], updated: [user])
        propagateChangesForObservers(changes, observerType: .SearchUser)
    }
        
    @objc public func notifyUpdatedCallState(conversations: Set<ZMConversation>, notifyDirectly: Bool) {
        let changes = ManagedObjectChanges(inserted: [], deleted: [], updated: Array(conversations))

        if notifyDirectly {
            processChanges(changes)
        } else {
            changedCallStateConversations = changedCallStateConversations + changes
        }
    }
    
    
    func propagateChangesForObservers(changes: ManagedObjectChanges, observerType: ObjectObserverType) {
        if let observersOfType = self.observers[observerType] {
            for observer in observersOfType.allObjects {
                (observer as? ObjectsDidChangeDelegate)?.objectsDidChange(changes.changesWithoutZombies)
            }
        }
    }
}


// MARK: - ConversationList
extension ManagedObjectContextObserver {
    
    public func addConversationListForAutoupdating(conversationList: ZMConversationList) {
        self.globalConversationObserver!.addConversationList(conversationList)
    }
    
    public func removeConversationListForAutoupdating(conversationList: ZMConversationList) {
        self.globalConversationObserver!.removeConversationList(conversationList)
    }
    
}



// MARK: - Add/remove observer
extension ManagedObjectContextObserver  {
    
    /// Adds a generic observer for a given object
    public func addChangeObserver(observer: ObjectsDidChangeDelegate, object: NSObject) {
        let type = ObjectObserverType.observerTypeForObject(object)
        self.addChangeObserver(observer, type: type)
    }
    
    /// Adds an observer of the given type
    public func addChangeObserver(observer: ObjectsDidChangeDelegate, type: ObjectObserverType) {
        assert(type != .Invalid)
        if let table = self.observers[type] {
            table.addObject(observer)
        }
        else {
            let table = NSHashTable.weakObjectsHashTable()
            table.addObject(observer)
            self.observers[type] = table
        }
        let table = self.observers[type] ?? NSHashTable.weakObjectsHashTable()
        table.addObject(observer)
        self.observers[type] = table
    }
    
    /// Adds a conversation list observer
    public func addConversationListObserver(observer: ZMConversationListObserver, conversationList: ZMConversationList) -> AnyObject
    {
        return self.globalConversationObserver!.addObserver(observer, conversationList: conversationList)
    }
    
    /// Adds a global voiceChannel observer
    public func addGlobalVoiceChannelObserver(observer: ZMVoiceChannelStateObserver) -> AnyObject
    {
        return self.globalConversationObserver!.addGlobalVoiceChannelStateObserver(observer)
    }
    
    /// Adds a voiceChannel participant observer
    public func addCallParticipantsObserver(observer: ZMVoiceChannelParticipantsObserver, voiceChannel: ZMVoiceChannel) -> AnyObject
    {
        let token = VoiceChannelParticipantsObserverToken(observer: observer, voiceChannel: voiceChannel)
        self.addChangeObserver(token, type: ObjectObserverType.VoiceChannel)
        return token
    }
    
    /// Adds a conversation window observer
    public func addConversationWindowObserver(observer: ZMConversationMessageWindowObserver, window: ZMConversationMessageWindow) -> MessageWindowChangeToken {
        let token = MessageWindowChangeToken(window: window, observer: observer)
        self.addChangeObserver(token, type: ObjectObserverType.ConversationMessageWindow)
        return token
    }
    
    /// Adds a new unread messages observer
    public func addNewUnreadMessagesObserver(observer: ZMNewUnreadMessagesObserver) -> NewUnreadMessagesObserverToken {
        let token = NewUnreadMessagesObserverToken(observer: observer)
        self.addChangeObserver(token, type: .Message)
        return token
    }
    
    /// Adds a new unread knockmessages observer
    public func addNewUnreadKnocksObserver(observer: ZMNewUnreadKnocksObserver) -> NewUnreadKnockMessagesObserverToken {
        let token = NewUnreadKnockMessagesObserverToken(observer: observer)
        self.addChangeObserver(token, type: .Message)
        return token
    }
    
    /// Adds a new unread unsent observer
    public func addNewUnreadUnsentMessagesObserver(observer: ZMNewUnreadUnsentMessageObserver) -> NewUnreadUnsentMessageObserverToken {
        let token = NewUnreadUnsentMessageObserverToken(observer: observer)
        self.addChangeObserver(token, type: .Message)
        return token
    }
    
    /// Removes a generic observer for a given object
    public func removeChangeObserver(observer: ObjectsDidChangeDelegate, object: NSObject){
        let type = ObjectObserverType.observerTypeForObject(object)
        self.removeChangeObserver(observer, type: type)
    }
    
    /// Removes a generic observer for a given type
    public func removeChangeObserver(observer: ObjectsDidChangeDelegate, type: ObjectObserverType){
        if let observersOfType : NSHashTable = self.observers[type] {
            observersOfType.removeObject(observer)
        }
    }
    
    /// Removes a conversation list observer
    public func removeConversationListObserverForToken(token: AnyObject) {
        if let observerToken = token as? ConversationListObserverToken {
            self.globalConversationObserver!.removeObserver(observerToken)
        }
    }
    
    /// Removes a global voiceChannel observer
    public func removeGlobalVoiceChannelStateObserverForToken(token: AnyObject) {
        if let observerToken = token as? GlobalVoiceChannelStateObserverToken {
            self.globalConversationObserver!.removeGlobalVoiceChannelStateObserver(observerToken)
        }
    }
    
    /// Removes a voiceChannel participant observer
    public func removeCallParticipantsObserverForToken(token: AnyObject) {
        if let observerToken = token as? VoiceChannelParticipantsObserverToken {
            self.removeChangeObserver(observerToken, type: ObjectObserverType.VoiceChannel)
        }
    }
    
    /// Removes a message window observer
    public func removeConversationWindowObserverForToken(token: AnyObject) {
        if let observerToken = token as? MessageWindowChangeToken {
            self.removeChangeObserver(observerToken, type: ObjectObserverType.ConversationMessageWindow)
        }
    }
    
    /// Removes a message observer
    public func removeMessageObserver(token: AnyObject) {
        if let token = token as? MessageToken {
            self.removeChangeObserver(token, type: .Message)
        }
    }
}

