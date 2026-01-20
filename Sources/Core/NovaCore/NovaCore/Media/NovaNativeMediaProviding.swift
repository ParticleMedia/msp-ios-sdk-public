//
//  NovaNativeMediaProviding.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/2/20.
//

import Foundation

public enum NovaNativeMediaLayoutOrientation: String, Codable {
    case horizontal
    case vertical
    case unknown
}

protocol NovaNativeMediaProviding: AnyObject {
    func makeImageModel() throws -> NovaAdImageMediaModel
    func makeVideoModel() throws -> NovaAdVideoMediaModel
}
