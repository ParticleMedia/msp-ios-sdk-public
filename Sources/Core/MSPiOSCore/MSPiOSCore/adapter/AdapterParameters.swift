//
//  AdapterParameters.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol AdapterParameters: AnyObject {
    func getParameters() -> [String: Any]?

    func hasUserConsent() -> Bool

    func isAgeRestrictedUser() -> Bool

    func isDoNotSell() -> Bool

    func getConsentString() -> String

    func isInTestMode() -> Bool
}
