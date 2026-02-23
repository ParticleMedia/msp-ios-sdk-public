//
//  NovaHtmlResource.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/29/25.
//

import Foundation

enum NovaAdHtmlResource: Equatable {
    case html(String, baseUrl: URL?)
    case url(URL)
}
