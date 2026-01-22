//
//  Geo.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public struct Geo {
    public let city: String
    public let stateCode: String
    public let zipCode: String
    public let lat: String
    public let lon: String

    public init(city: String = "", stateCode: String = "", zipCode: String = "", lat: String = "", lon: String = "") {
        self.city = city
        self.stateCode = stateCode
        self.zipCode = zipCode
        self.lat = lat
        self.lon = lon
    }
}
