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


import XCTest
import zmessaging





class ChangedObjectSetTests: MessagingTest {

    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func testEquatable() {
        // given
        let a = NSObject()
        
        // then
        XCTAssertEqual(zmessaging.ChangedObjectSet(), zmessaging.ChangedObjectSet())
        XCTAssertEqual(zmessaging.ChangedObjectSet(element: a), zmessaging.ChangedObjectSet(element: a))
        XCTAssertNotEqual(zmessaging.ChangedObjectSet(), zmessaging.ChangedObjectSet(element: a))
        XCTAssertNotEqual(zmessaging.ChangedObjectSet(element: a), zmessaging.ChangedObjectSet())
    }
    
    func testThatPoppingAnEmptySet() {
        // given
        let sut = zmessaging.ChangedObjectSet()
        
        // when
        XCTAssert(sut.decompose() == nil)
    }
    
    func testThatPoppingASetWithASingleObjectReturnsThatObject() {
        // given
        let a = NSObject()
        let sut = zmessaging.ChangedObjectSet(element: a)
        
        // when
        if let (head, tail) = sut.decompose() {
            // then
            XCTAssertEqual(head.object, a)
            XCTAssertEqual(head.keys , AffectedKeys.All)
            XCTAssertEqual(tail, zmessaging.ChangedObjectSet())
        } else {
            XCTFail("decompose() returned nil")
        }
    }
    
    func testThatItCanUnionMultipleObjects() {
        // given
        let a = NSObject()
        let b = NSObject()
        let setA = zmessaging.ChangedObjectSet(element: a, affectedKeys: .Some(KeySet(key: "foo")))
        let setB = zmessaging.ChangedObjectSet(element: b, affectedKeys: .Some(KeySet(key: "bar")))
        
        let sut = setA.unionWithSet(setB)
        
        // when
        let owkA = zmessaging.ChangedObjectSet.ObjectWithKeys(object: a, keys:.Some(KeySet(key: "foo")))
        let owkB = zmessaging.ChangedObjectSet.ObjectWithKeys(object: b, keys:.Some(KeySet(key: "bar")))

        if let (head, tail) = sut.decompose() {
            // then
            if  head == owkA {
                XCTAssertEqual(tail, setB)
            } else if  head == owkB {
                XCTAssertEqual(tail, setA)
            } else {
                XCTFail("decompose() failed")
            }
        } else {
            XCTFail("decompose() returned nil")
        }
    }

    func testThatItCanUnionTheSameObjectWithMultipleKeys() {
        // given
        let a = NSObject()
        let setA = zmessaging.ChangedObjectSet(element: a, affectedKeys: .Some(KeySet(key: "foo")))
        let setB = zmessaging.ChangedObjectSet(element: a, affectedKeys: .Some(KeySet(key: "bar")))
        
        let sut = setA.unionWithSet(setB)

        // when
        if let (head, tail) = sut.decompose() {
            // then
            XCTAssertEqual(head.object, a)
            XCTAssertEqual(head.keys, AffectedKeys.Some(KeySet(["bar", "foo"])))
            XCTAssertEqual(tail, zmessaging.ChangedObjectSet())
        } else {
            XCTFail("decompose() returned nil")
        }
    }
    
    func testTestItCanBeCreatedFromAObjectsDidChangeNotification() {
        // given
        let fakeMOC = NSObject()
        let a = NSObject()
        let b = NSObject()
        let c = NSObject()
        let d = NSObject()
        let userInfo = [NSUpdatedObjectsKey: NSSet(objects: a, b), NSRefreshedObjectsKey: NSSet(objects: c, d)]
        let note = NSNotification(name: NSManagedObjectContextObjectsDidChangeNotification, object: fakeMOC, userInfo: userInfo)
        
        // when
        let sut = zmessaging.ChangedObjectSet(notification: note)
        let allObjects = NSMutableSet()
        
        // then
        for owk in sut {
            allObjects.addObject(owk.object)
            XCTAssertEqual(owk.keys, AffectedKeys.All)
        }
        XCTAssertEqual(allObjects, NSSet(objects: a, b, c, d))
    }
}
