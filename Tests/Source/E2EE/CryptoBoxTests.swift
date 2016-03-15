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
@testable import zmessaging
import Cryptobox

class CryptoBoxTest: OtrBaseTest {
    
    func testThatCryptoBoxFolderIsForbiddenFromBackup() {
        // when
        UserClientKeysStore.setupBox()
        
        // then
        let values = try! UserClientKeysStore.otrDirectoryURL.resourceValuesForKeys([NSURLIsExcludedFromBackupKey])
        XCTAssertNotNil(values[NSURLIsExcludedFromBackupKey])
    }
    
    func testThatCryptoBoxFolderIsMarkedForEncryption() {
        #if (arch(i386) || arch(x86_64)) && os(iOS)
            // File protection API is not available on simulator
            XCTAssertTrue(true)
            return
        #else
            // when
            UserClientKeysStore.setupBox()
            
            // then
            let attrs = try! NSFileManager.defaultManager().attributesOfItemAtPath(UserClientKeysStore.otrDirectoryURL.path!)
            let fileProtectionAttr = (attrs[NSFileProtectionKey]! as! String)
            XCTAssertEqual(fileProtectionAttr, NSFileProtectionCompleteUntilFirstUserAuthentication)
        #endif
    }

}
