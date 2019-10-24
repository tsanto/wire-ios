//
// Wire
// Copyright (C) 2017 Wire Swiss GmbH
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

import Foundation
import WireDataModel
import LocalAuthentication

private let zmLog = ZMSLog(tag: "UI")

final class AppLock {
    // Returns true if user enabled the app lock feature.
    
    static var rules = AppLockRules.fromBundle()

    static var isActive: Bool {
        get {
            guard !rules.forceAppLock else { return true }
            guard let data = ZMKeychain.data(forAccount: SettingsPropertyName.lockApp.rawValue),
                data.count != 0 else {
                    return false
            }
            
            return String(data: data, encoding: .utf8) == "YES"
        }
        set {
            guard !rules.forceAppLock else { return }
            let data = (newValue ? "YES" : "NO").data(using: .utf8)!
            ZMKeychain.setData(data, forAccount: SettingsPropertyName.lockApp.rawValue)
        }
    }
    
    // Returns the time since last lock happened.
    static var lastUnlockedDate: Date = Date(timeIntervalSince1970: 0)
    
    enum AuthenticationResult {
        /// User sucessfully authenticated
        case granted
        /// User failed to authenticate or cancelled the request
        case denied
        /// There's no authenticated method available (no passcode is set)
        case unavailable
    }
    
    // Creates a new LAContext and evaluates the authentication settings of the user.
    static func evaluateAuthentication(description: String, with callback: @escaping (AuthenticationResult) -> Void) {
    
        let context: LAContext = LAContext()
        var error: NSError?
        let policy = LAPolicy.deviceOwnerAuthenticationWithBiometrics
//        let policy = LAPolicy.deviceOwnerAuthentication

        if context.canEvaluatePolicy(policy, error: &error) {///TODO: press enter passcode -> not popup???
            context.evaluatePolicy(policy, localizedReason: description, reply: { (success, error) -> Void in
                callback(success ? .granted : .denied)///TODO: shown our passwd dialog
//                switch (error.) {
//                default:
//                    break
//                }

                if let laError = error as? LAError {
                    print(laError.code)
                }
            })
        } else {
            // If there's no passcode set automatically grant access unless app lock is a requirement to run the app
            callback(rules.forceAppLock ? .unavailable : .granted)
            zmLog.error("Local authentication error: \(String(describing: error?.localizedDescription))")
        }
    }
    
}


struct AppLockRules: Decodable {
    
    let forceAppLock: Bool
    let appLockTimeout: UInt
    
    static func fromBundle() -> AppLockRules {
        if let fileURL = Bundle.main.url(forResource: "session_manager", withExtension: "json"),
            let fileData = try? Data(contentsOf: fileURL) {
            return fromData(fileData)
        } else {
            fatalError("session_manager.json not exist")
        }
    }
    
    static func fromData(_ data: Data) -> AppLockRules {
        let decoder = JSONDecoder()
        return try! decoder.decode(AppLockRules.self, from: data)
    }
}
