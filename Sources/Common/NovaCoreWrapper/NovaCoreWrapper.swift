//
//  NovaCoreWrapper.swift
//  NovaCoreWrapper
//
//  Wrapper module that ensures Lottie and Shimmer are linked with NovaCore.
//  NovaCore.xcframework contains undefined Lottie/Shimmer symbols that must be
//  resolved at link time. This wrapper forces the linker to include them.
//

import Foundation
@_exported import NovaCore
import Lottie
import Shimmer

// Force Lottie to be linked by referencing a symbol
private let _forceLottieLink: Any.Type = LottieAnimationView.self

// Force Shimmer to be linked by referencing a symbol
private let _forceShimmerLink: AnyClass? = FBShimmeringView.self

