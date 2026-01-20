//
//  MSPCoreWrapper.swift
//  MSPCoreWrapper
//
//  Wrapper module that ensures SwiftProtobuf is linked with MSPCore.
//  MSPCore.xcframework contains undefined SwiftProtobuf symbols that must be
//  resolved at link time. This wrapper forces the linker to include SwiftProtobuf.
//

import Foundation
@_exported import MSPCore
import SwiftProtobuf

// Force SwiftProtobuf to be linked by referencing a symbol
private let _forceSwiftProtobufLink: Any.Type = SwiftProtobuf.Message.self

