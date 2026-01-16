//
//  SimpleError.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/1/14.
//

import Foundation

struct SimpleError: Error, LocalizedError {
    let message: String
    var errorDescription: String? { message }
}
