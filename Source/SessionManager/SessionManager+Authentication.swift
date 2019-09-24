//
// Wire
// Copyright (C) 2019 Wire Swiss GmbH
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
// along with this program. If not, see http://www.gnu.org/licenses/.
//

public extension SessionManager {
    
    private static let previousSystemBootTimeContainer = "PreviousSystemBootTime"
    
    static var previousSystemBootTime: Date? {
        get {
            guard let data = ZMKeychain.data(forAccount: previousSystemBootTimeContainer),
                let string = String(data: data, encoding: .utf8),
                let timeInterval = TimeInterval(string) else {
                    return nil
            }
            return Date(timeIntervalSince1970: timeInterval)
        }
        set {
            guard let newValue = newValue,
                let data = "\(newValue.timeIntervalSince1970)".data(using: .utf8) else { return }
            
            ZMKeychain.setData(data, forAccount: previousSystemBootTimeContainer)
        }
    }
}