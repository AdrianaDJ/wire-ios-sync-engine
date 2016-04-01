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

extension String {

    func upperCasePreservingCamelCase() -> String {
        var aString = self
        let capitalfirstLetter = String(aString[aString.startIndex]).capitalizedString
        let range = Range(start: aString.startIndex, end: aString.startIndex.advancedBy(1))
        aString.replaceRange(range, with: capitalfirstLetter)
        return aString
    }
}

/// MARK: Base class for observer / change info
public protocol ObjectChangeInfoProtocol : NSObjectProtocol {
    
    init(object: NSObject)
    func setValue(value: AnyObject?, forKey key: String)
    func valueForKey(key: String) -> AnyObject?
    var changedKeysAndOldValues : [String : NSObject?] {get set}

}

public class ObjectChangeInfo : NSObject, ObjectChangeInfoProtocol {
    
    let object : NSObject
    
    public required init(object: NSObject) {
        self.object = object
    }
    public var changedKeysAndOldValues : [String : NSObject?] = [:]
    
    public func previousValueForKey(key: String) -> NSObject? {
        return changedKeysAndOldValues[key] ?? nil
    }
}

/// This is used to wrap UI observers
///
/// The token is read-only, but reset when tearDown() is called.
@objc public class ObjectObserverTokenContainer : NSObject {

    private(set) var token : AnyObject?
    private(set) var object : ObjectInSnapshot?

    public init(object: ObjectInSnapshot, token: AnyObject) {
        self.token = token
        self.object = object
    }
    
    public func tearDown() {
        self.token = nil
    }
}


/// MARK: Common behaviour for all observer tokens
final class ObjectObserverToken<T : ObjectChangeInfoProtocol, B: ObjectObserverTokenContainer>: NSObject {
    
    typealias ObserverCallback = (B, T) -> Void
    
    /// List of keys for which we want to store a previous value
    private let token : ObjectDependencyToken?
    private let observedObject : NSObject
    private var parentChangeHandler : ObserverCallback!
    private var tokenContainers: NSHashTable = NSHashTable.weakObjectsHashTable()
    private var isTornDown : Bool = false

    
    static func token(
        observedObject: NSObject,
        observableKeys: [String],
        managedObjectContextObserver: ManagedObjectContextObserver,
        changeHandler: ObserverCallback)
        -> ObjectObserverToken<T, B>
    {
        return ObjectObserverToken(observedObject: observedObject, observableKeys:observableKeys, managedObjectContextObserver: managedObjectContextObserver, changeHandler: changeHandler)
            
    }
    
    private init(
        observedObject: NSObject,
        observableKeys : [String],
        managedObjectContextObserver: ManagedObjectContextObserver,
        changeHandler: ObserverCallback
        )
    {
        self.parentChangeHandler = changeHandler
        self.observedObject = observedObject
        var internalChangeHandler : ([KeyPath:NSObject?]) -> () = { _ in return }
        
        self.token = ObjectDependencyToken(
            keyFromParentObjectToObservedObject: nil,
            observedObject: observedObject,
            keysToObserve: KeySet(observableKeys),
            managedObjectContextObserver: managedObjectContextObserver,
            changeHandler : { internalChangeHandler($0) }
        )
        
        super.init()
        
        internalChangeHandler = {
            [weak self] (changedKeys) in
            self?.keysDidChange(changedKeys)
        }
    }

    func keysDidChange(affectedKeys: [KeyPath:NSObject?]) {
        let objectChangeInfo = T(object: self.observedObject)
        affectedKeys.forEach { objectChangeInfo.changedKeysAndOldValues[$0.0.rawValue] = $0.1 }
        
        notifyObservers(objectChangeInfo)
    }
    
    // Sends the given changeInfo to all registered observers for this object
    func notifyObservers(changeInfo: T) {
        for container in tokenContainers.allObjects {
            self.parentChangeHandler(container as! B, changeInfo)
        }
    }
    
    func addContainer(container: B) {
        tokenContainers.addObject(container)
    }
    func removeContainer(container: B) {
        tokenContainers.removeObject(container)
        if self.hasNoContainers {
            self.tearDown()
        }
    }
	
    var hasNoContainers: Bool {
		return tokenContainers.count == 0
	}
    
    func keysHaveChanged(keys: [String]) {
        self.token?.keysHaveChanged(keys)
    }
    

    func tearDown() {
        if isTornDown {return}
        isTornDown = true
        tokenContainers.removeAllObjects()
        parentChangeHandler = nil
        token?.tearDown()
    }
    
    deinit {
        assert(isTornDown)
    }
}


