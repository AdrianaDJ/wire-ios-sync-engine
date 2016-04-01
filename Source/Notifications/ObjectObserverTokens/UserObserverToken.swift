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
import ZMCSystem

extension ZMUser : ObjectInSnapshot {
    
    public var observableKeys : [String] {
        return ["name", "displayName", "accentColorValue", "imageMediumData", "imageSmallProfileData","emailAddress", "phoneNumber", "canBeConnected", "isConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser", "clients"]
    }

    public func keyPathsForValuesAffectingValueForKey(key: String) -> KeySet {
        return KeySet(ZMUser.keyPathsForValuesAffectingValueForKey(key))
    }
}


@objc public class UserChangeInfo : ObjectChangeInfo {

    public required init(object: NSObject) {
        self.user = object as! ZMBareUser
        super.init(object: object)
    }

    public var nameChanged : Bool {
        return !Set(arrayLiteral: "name", "displayName").isDisjointWith(changedKeysAndOldValues.keys)
    }
    
    public var accentColorValueChanged : Bool {
        return changedKeysAndOldValues.keys.contains("accentColorValue")
    }

    public var imageMediumDataChanged : Bool {
        return changedKeysAndOldValues.keys.contains("imageMediumData")
    }

    public var imageSmallProfileDataChanged : Bool {
        return changedKeysAndOldValues.keys.contains("imageSmallProfileData")
    }

    public var profileInformationChanged : Bool {
        return !Set(arrayLiteral: "emailAddress", "phoneNumber").isDisjointWith(changedKeysAndOldValues.keys)
    }

    public var connectionStateChanged : Bool {
        return !Set(arrayLiteral: "isConnected", "canBeConnected", "isPendingApprovalByOtherUser", "isPendingApprovalBySelfUser").isDisjointWith(changedKeysAndOldValues.keys)
    }

    public var trustLevelChanged : Bool {
        return userClientChangeInfo != nil
    }

    public var clientsChanged : Bool {
        return changedKeysAndOldValues.keys.contains("clients")
    }


    public let user: ZMBareUser
    public var userClientChangeInfo : UserClientChangeInfo?

}

/// This is either ZMUser or ZMSearchUser
//private typealias ObservableUser = protocol<ObjectInSnapshot, ZMBareUser>


/*

user             -> UserObserverToken
ObjectInSnapshot -> ObjectObserverTokenContainer

*/


/// For a single user.
class GenericUserObserverToken<T : NSObject where T: ObjectInSnapshot>: ObjectObserverTokenContainer {

    typealias InnerTokenType = ObjectObserverToken<UserChangeInfo, GenericUserObserverToken<T>>

    private let observedUser: T?
    private weak var observer : ZMUserObserver?
    private let managedObjectContext: NSManagedObjectContext
    private var clientTokens = [UserClient: UserClientObserverToken]()

    private static func objectDidChange(container: GenericUserObserverToken<T>, changeInfo: UserChangeInfo) {
        container.observer?.userDidChange(changeInfo)
    }

    init(observer: ZMUserObserver, user: T, managedObjectContext: NSManagedObjectContext, keyForDirectoryInUserInfo: String) {
        self.observer = observer
        self.managedObjectContext = managedObjectContext
        self.observedUser = user

        var changeHandler : (GenericUserObserverToken<T>, UserChangeInfo) -> Void = { _ in return }
        let innerToken = InnerTokenType.token(
            user,
            observableKeys: user.observableKeys,
            managedObjectContextObserver: managedObjectContext.globalManagedObjectContextObserver,
            changeHandler: { changeHandler($0, $1) }
        )
        
        super.init(object: user, token: innerToken)
        if let user = user as? ZMUser {
            // we initialy register observers for all of the users clients
            registerObserverForClients(user.clients)
        }
        
        // NB! The wrapper closure is created every time @c GenericUserObserverToken is created, but only the first one 
        // created is actually called, but for every container that been added.
        changeHandler = { [weak self] container, changeInfo in
            // clients might have been added or removed in the update, so we
            // need to add or remove observers for them accordingly
            self?.updateClientObserversIfNeeded(changeInfo)
            GenericUserObserverToken.objectDidChange(container, changeInfo: changeInfo)
        }
        innerToken.addContainer(self)
    }

    override func tearDown() {
        if let t = self.token as? InnerTokenType {
            t.removeContainer(self)
            if t.hasNoContainers {
                t.tearDown()
            }
        }
        removeObserverForClientTokens()
    }

    private func registerObserverForClients(clients: Set<UserClient>) {
        clients.forEach {
            clientTokens[$0] = UserClientObserverToken(observer: self, managedObjectContext: self.managedObjectContext, userClient: $0)
        }
    }

    private func removeObserverForClientTokens() {
        clientTokens.forEach { $0.1.tearDown() }
        clientTokens = [:]
    }

    private func updateClientObserversIfNeeded(changeInfo: UserChangeInfo) {
        guard let user = observedUser as? ZMUser where changeInfo.clientsChanged else { return }
        let observedClients = Set(clientTokens.map { $0.0 })
        let addedClients = user.clients.subtract(observedClients)
        registerObserverForClients(addedClients)
        
        observedClients.subtract(user.clients).forEach {
            clientTokens[$0]?.tearDown()
            clientTokens.removeValueForKey($0)
        }
    }
    
    func connectionDidChange(changedUsers: [ZMUser]) {
        guard let user = object as? ZMUser where changedUsers.indexOf(user) != nil,
              let token = token as? InnerTokenType
        else { return }
        
        token.keysHaveChanged(["connection"])
    }

}

extension GenericUserObserverToken: UserClientObserver {
    func userClientDidChange(changeInfo: UserClientChangeInfo) {
        guard let userChangeInfo = observedUser.map(UserChangeInfo.init)
        else { return }
        
        userChangeInfo.userClientChangeInfo = changeInfo
        (token as? InnerTokenType)?.notifyObservers(userChangeInfo)
    }
}


extension ObjectObserverTokenContainer  {
}

public func ==(lhs: ObjectObserverTokenContainer, rhs: ObjectObserverTokenContainer) -> Bool {
    return lhs === rhs
}


public class UserCollectionObserverToken: NSObject, ZMUserObserver  {
    var tokens : [UserObserverToken] = []
    weak var observer: ZMUserObserver?

    public init(observer: ZMUserObserver, users: [ZMBareUser], managedObjectContext:NSManagedObjectContext) {
        self.observer = observer
        super.init()
        users.forEach{
            if let token = managedObjectContext.globalManagedObjectContextObserver.addUserObserver(self, user:$0) as? UserObserverToken {
                tokens.append(token)
            }
        }
    }

    public func userDidChange(note: UserChangeInfo!) {
        observer?.userDidChange(note)
    }

    public func tearDown() {
        tokens.forEach{$0.tearDown()}
    }
}


class UserObserverToken : NSObject, ChangeNotifierToken {
    typealias Observer = ZMUserObserver
    typealias ChangeInfo = UserChangeInfo
    typealias GlobalObserver = GlobalUserObserver
    
    weak var observer : ZMUserObserver?
    weak var globalObserver : GlobalUserObserver?
    
    required init(observer: ZMUserObserver, globalObserver: GlobalUserObserver) {
        self.observer = observer
        self.globalObserver = globalObserver
        super.init()
    }
    
    func notifyObserver(note: UserChangeInfo) {
        observer?.userDidChange(note)
    }
    
    func tearDown() {
        globalObserver?.removeUserObserverForToken(self)
    }
}







