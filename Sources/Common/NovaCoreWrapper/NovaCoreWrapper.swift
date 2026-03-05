//
//  NovaCoreWrapper.swift
//  NovaCoreWrapper
//
//  Wrapper module that ensures Shimmer is linked with NovaCore.
//  NovaCore.xcframework contains undefined Shimmer symbols that must be
//  resolved at link time. This wrapper forces the linker to include them.
//

import Foundation
@_exported import NovaCore
import Shimmer

// Force Shimmer to be linked by referencing a symbol
private let _forceShimmerLink: AnyClass? = FBShimmeringView.self
