// DO NOT EDIT.
// swift-format-ignore-file
// swiftlint:disable all
//
// Generated by the Swift generator plugin for the protocol buffer compiler.
// Source: monetization/common.proto
//
// For information on using the generated types, please see the documentation:
//   https://github.com/apple/swift-protobuf/

import Foundation
import SwiftProtobuf

// If the compiler emits an error on this type, it is because this file
// was generated by a version of the `protoc` Swift plug-in that is
// incompatible with the version of SwiftProtobuf to which you are linking.
// Please ensure that you are building against the same version of the API
// that was used to generate this file.
fileprivate struct _GeneratedWithProtocGenSwiftVersion: SwiftProtobuf.ProtobufAPIVersionCheck {
  struct _2: SwiftProtobuf.ProtobufAPIVersion_2 {}
  typealias Version = _2
}

enum Com_Newsbreak_Monetization_Common_AdType: SwiftProtobuf.Enum, Swift.CaseIterable {
  typealias RawValue = Int
  case unspecified // = 0
  case native // = 1
  case display // = 2
  case interstitial // = 3
  case video // = 4
  case UNRECOGNIZED(Int)

  init() {
    self = .unspecified
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .unspecified
    case 1: self = .native
    case 2: self = .display
    case 3: self = .interstitial
    case 4: self = .video
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .unspecified: return 0
    case .native: return 1
    case .display: return 2
    case .interstitial: return 3
    case .video: return 4
    case .UNRECOGNIZED(let i): return i
    }
  }

  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static let allCases: [Com_Newsbreak_Monetization_Common_AdType] = [
    .unspecified,
    .native,
    .display,
    .interstitial,
    .video,
  ]

}

enum Com_Newsbreak_Monetization_Common_ImageType: SwiftProtobuf.Enum, Swift.CaseIterable {
  typealias RawValue = Int
  case unspecified // = 0

  /// .jpeg or .jpg
  case jpeg // = 1
  case png // = 2
  case gif // = 3
  case webp // = 4
  case UNRECOGNIZED(Int)

  init() {
    self = .unspecified
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .unspecified
    case 1: self = .jpeg
    case 2: self = .png
    case 3: self = .gif
    case 4: self = .webp
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .unspecified: return 0
    case .jpeg: return 1
    case .png: return 2
    case .gif: return 3
    case .webp: return 4
    case .UNRECOGNIZED(let i): return i
    }
  }

  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static let allCases: [Com_Newsbreak_Monetization_Common_ImageType] = [
    .unspecified,
    .jpeg,
    .png,
    .gif,
    .webp,
  ]

}

enum Com_Newsbreak_Monetization_Common_OsType: SwiftProtobuf.Enum, Swift.CaseIterable {
  typealias RawValue = Int
  case unspecified // = 0
  case ios // = 1
  case android // = 2
  case ipados // = 3
  case UNRECOGNIZED(Int)

  init() {
    self = .unspecified
  }

  init?(rawValue: Int) {
    switch rawValue {
    case 0: self = .unspecified
    case 1: self = .ios
    case 2: self = .android
    case 3: self = .ipados
    default: self = .UNRECOGNIZED(rawValue)
    }
  }

  var rawValue: Int {
    switch self {
    case .unspecified: return 0
    case .ios: return 1
    case .android: return 2
    case .ipados: return 3
    case .UNRECOGNIZED(let i): return i
    }
  }

  // The compiler won't synthesize support with the UNRECOGNIZED case.
  static let allCases: [Com_Newsbreak_Monetization_Common_OsType] = [
    .unspecified,
    .ios,
    .android,
    .ipados,
  ]

}

struct Com_Newsbreak_Monetization_Common_RequestContext: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// timestamp when request is sent
  var tsMs: UInt64 = 0

  var bidRequest: Com_Google_Openrtb_BidRequest {
    get {return _bidRequest ?? Com_Google_Openrtb_BidRequest()}
    set {_bidRequest = newValue}
  }
  /// Returns true if `bidRequest` has been explicitly set.
  var hasBidRequest: Bool {return self._bidRequest != nil}
  /// Clears the value of `bidRequest`. Subsequent reads from it will return its default value.
  mutating func clearBidRequest() {self._bidRequest = nil}

  var isOpenRtbRequest: Bool = false

  /// For application extension
  var ext: Com_Newsbreak_Monetization_Common_RequestContextExt {
    get {return _ext ?? Com_Newsbreak_Monetization_Common_RequestContextExt()}
    set {_ext = newValue}
  }
  /// Returns true if `ext` has been explicitly set.
  var hasExt: Bool {return self._ext != nil}
  /// Clears the value of `ext`. Subsequent reads from it will return its default value.
  mutating func clearExt() {self._ext = nil}

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _bidRequest: Com_Google_Openrtb_BidRequest? = nil
  fileprivate var _ext: Com_Newsbreak_Monetization_Common_RequestContextExt? = nil
}

/// This object is designed for application extension, fields are bound to one or more application.
/// Do not add common fields such as ts, os to this message, it is specifically designed for application extension.
struct Com_Newsbreak_Monetization_Common_RequestContextExt: Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// required by Newsbreak
  var docID: String = String()

  /// required by Newsbreak
  var sessionID: String = String()

  /// required by Newsbreak
  /// e.g. "article", "foryou", "local" ...
  var source: String = String()

  /// The index of the ads on certain slots such as in-feed, article-related and article-inside.
  var position: UInt32 = 0

  var placementID: String = String()

  var buckets: [String] = []

  var adSlotID: String = String()

  var userID: String = String()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}
}

struct Com_Newsbreak_Monetization_Common_Ad: @unchecked Sendable {
  // SwiftProtobuf.Message conformance is added in an extension below. See the
  // `Message` and `Message+*Additions` files in the SwiftProtobuf library for
  // methods supported on all messages.

  /// timestamp when bid is received
  var tsMs: UInt64 = 0

  var seatBid: Com_Google_Openrtb_BidResponse.SeatBid {
    get {return _seatBid ?? Com_Google_Openrtb_BidResponse.SeatBid()}
    set {_seatBid = newValue}
  }
  /// Returns true if `seatBid` has been explicitly set.
  var hasSeatBid: Bool {return self._seatBid != nil}
  /// Clears the value of `seatBid`. Subsequent reads from it will return its default value.
  mutating func clearSeatBid() {self._seatBid = nil}

  var title: String = String()

  var body: String = String()

  var type: Com_Newsbreak_Monetization_Common_AdType = .unspecified

  var advertiser: String = String()

  var fullScreenshot: Data = Data()

  var adScreenshot: Data = Data()

  var key: String = String()

  var fullScreenshotType: Com_Newsbreak_Monetization_Common_ImageType = .unspecified

  var adScreenshotType: Com_Newsbreak_Monetization_Common_ImageType = .unspecified

  var adsetID: String = String()

  var unknownFields = SwiftProtobuf.UnknownStorage()

  init() {}

  fileprivate var _seatBid: Com_Google_Openrtb_BidResponse.SeatBid? = nil
}

// MARK: - Code below here is support for the SwiftProtobuf runtime.

fileprivate let _protobuf_package = "com.newsbreak.monetization.common"

extension Com_Newsbreak_Monetization_Common_AdType: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "AD_TYPE_UNSPECIFIED"),
    1: .same(proto: "AD_TYPE_NATIVE"),
    2: .same(proto: "AD_TYPE_DISPLAY"),
    3: .same(proto: "AD_TYPE_INTERSTITIAL"),
    4: .same(proto: "AD_TYPE_VIDEO"),
  ]
}

extension Com_Newsbreak_Monetization_Common_ImageType: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "IMAGE_TYPE_UNSPECIFIED"),
    1: .same(proto: "IMAGE_TYPE_JPEG"),
    2: .same(proto: "IMAGE_TYPE_PNG"),
    3: .same(proto: "IMAGE_TYPE_GIF"),
    4: .same(proto: "IMAGE_TYPE_WEBP"),
  ]
}

extension Com_Newsbreak_Monetization_Common_OsType: SwiftProtobuf._ProtoNameProviding {
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    0: .same(proto: "OS_TYPE_UNSPECIFIED"),
    1: .same(proto: "OS_TYPE_IOS"),
    2: .same(proto: "OS_TYPE_ANDROID"),
    3: .same(proto: "OS_TYPE_IPADOS"),
  ]
}

extension Com_Newsbreak_Monetization_Common_RequestContext: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".RequestContext"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "ts_ms"),
    2: .standard(proto: "bid_request"),
    3: .standard(proto: "is_open_rtb_request"),
    17: .same(proto: "ext"),
  ]

  public var isInitialized: Bool {
    if let v = self._bidRequest, !v.isInitialized {return false}
    return true
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt64Field(value: &self.tsMs) }()
      case 2: try { try decoder.decodeSingularMessageField(value: &self._bidRequest) }()
      case 3: try { try decoder.decodeSingularBoolField(value: &self.isOpenRtbRequest) }()
      case 17: try { try decoder.decodeSingularMessageField(value: &self._ext) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if self.tsMs != 0 {
      try visitor.visitSingularUInt64Field(value: self.tsMs, fieldNumber: 1)
    }
    try { if let v = self._bidRequest {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    } }()
    if self.isOpenRtbRequest != false {
      try visitor.visitSingularBoolField(value: self.isOpenRtbRequest, fieldNumber: 3)
    }
    try { if let v = self._ext {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 17)
    } }()
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Com_Newsbreak_Monetization_Common_RequestContext, rhs: Com_Newsbreak_Monetization_Common_RequestContext) -> Bool {
    if lhs.tsMs != rhs.tsMs {return false}
    if lhs._bidRequest != rhs._bidRequest {return false}
    if lhs.isOpenRtbRequest != rhs.isOpenRtbRequest {return false}
    if lhs._ext != rhs._ext {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Com_Newsbreak_Monetization_Common_RequestContextExt: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".RequestContextExt"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "doc_id"),
    2: .standard(proto: "session_id"),
    3: .same(proto: "source"),
    4: .same(proto: "position"),
    5: .standard(proto: "placement_id"),
    6: .same(proto: "buckets"),
    7: .standard(proto: "ad_slot_id"),
    8: .standard(proto: "user_id"),
  ]

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularStringField(value: &self.docID) }()
      case 2: try { try decoder.decodeSingularStringField(value: &self.sessionID) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.source) }()
      case 4: try { try decoder.decodeSingularUInt32Field(value: &self.position) }()
      case 5: try { try decoder.decodeSingularStringField(value: &self.placementID) }()
      case 6: try { try decoder.decodeRepeatedStringField(value: &self.buckets) }()
      case 7: try { try decoder.decodeSingularStringField(value: &self.adSlotID) }()
      case 8: try { try decoder.decodeSingularStringField(value: &self.userID) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    if !self.docID.isEmpty {
      try visitor.visitSingularStringField(value: self.docID, fieldNumber: 1)
    }
    if !self.sessionID.isEmpty {
      try visitor.visitSingularStringField(value: self.sessionID, fieldNumber: 2)
    }
    if !self.source.isEmpty {
      try visitor.visitSingularStringField(value: self.source, fieldNumber: 3)
    }
    if self.position != 0 {
      try visitor.visitSingularUInt32Field(value: self.position, fieldNumber: 4)
    }
    if !self.placementID.isEmpty {
      try visitor.visitSingularStringField(value: self.placementID, fieldNumber: 5)
    }
    if !self.buckets.isEmpty {
      try visitor.visitRepeatedStringField(value: self.buckets, fieldNumber: 6)
    }
    if !self.adSlotID.isEmpty {
      try visitor.visitSingularStringField(value: self.adSlotID, fieldNumber: 7)
    }
    if !self.userID.isEmpty {
      try visitor.visitSingularStringField(value: self.userID, fieldNumber: 8)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Com_Newsbreak_Monetization_Common_RequestContextExt, rhs: Com_Newsbreak_Monetization_Common_RequestContextExt) -> Bool {
    if lhs.docID != rhs.docID {return false}
    if lhs.sessionID != rhs.sessionID {return false}
    if lhs.source != rhs.source {return false}
    if lhs.position != rhs.position {return false}
    if lhs.placementID != rhs.placementID {return false}
    if lhs.buckets != rhs.buckets {return false}
    if lhs.adSlotID != rhs.adSlotID {return false}
    if lhs.userID != rhs.userID {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}

extension Com_Newsbreak_Monetization_Common_Ad: SwiftProtobuf.Message, SwiftProtobuf._MessageImplementationBase, SwiftProtobuf._ProtoNameProviding {
  static let protoMessageName: String = _protobuf_package + ".Ad"
  static let _protobuf_nameMap: SwiftProtobuf._NameMap = [
    1: .standard(proto: "ts_ms"),
    2: .standard(proto: "seat_bid"),
    3: .same(proto: "title"),
    4: .same(proto: "body"),
    5: .same(proto: "type"),
    6: .same(proto: "advertiser"),
    7: .standard(proto: "full_screenshot"),
    8: .standard(proto: "ad_screenshot"),
    9: .same(proto: "key"),
    10: .standard(proto: "full_screenshot_type"),
    11: .standard(proto: "ad_screenshot_type"),
    12: .standard(proto: "adset_id"),
  ]

  public var isInitialized: Bool {
    if let v = self._seatBid, !v.isInitialized {return false}
    return true
  }

  mutating func decodeMessage<D: SwiftProtobuf.Decoder>(decoder: inout D) throws {
    while let fieldNumber = try decoder.nextFieldNumber() {
      // The use of inline closures is to circumvent an issue where the compiler
      // allocates stack space for every case branch when no optimizations are
      // enabled. https://github.com/apple/swift-protobuf/issues/1034
      switch fieldNumber {
      case 1: try { try decoder.decodeSingularUInt64Field(value: &self.tsMs) }()
      case 2: try { try decoder.decodeSingularMessageField(value: &self._seatBid) }()
      case 3: try { try decoder.decodeSingularStringField(value: &self.title) }()
      case 4: try { try decoder.decodeSingularStringField(value: &self.body) }()
      case 5: try { try decoder.decodeSingularEnumField(value: &self.type) }()
      case 6: try { try decoder.decodeSingularStringField(value: &self.advertiser) }()
      case 7: try { try decoder.decodeSingularBytesField(value: &self.fullScreenshot) }()
      case 8: try { try decoder.decodeSingularBytesField(value: &self.adScreenshot) }()
      case 9: try { try decoder.decodeSingularStringField(value: &self.key) }()
      case 10: try { try decoder.decodeSingularEnumField(value: &self.fullScreenshotType) }()
      case 11: try { try decoder.decodeSingularEnumField(value: &self.adScreenshotType) }()
      case 12: try { try decoder.decodeSingularStringField(value: &self.adsetID) }()
      default: break
      }
    }
  }

  func traverse<V: SwiftProtobuf.Visitor>(visitor: inout V) throws {
    // The use of inline closures is to circumvent an issue where the compiler
    // allocates stack space for every if/case branch local when no optimizations
    // are enabled. https://github.com/apple/swift-protobuf/issues/1034 and
    // https://github.com/apple/swift-protobuf/issues/1182
    if self.tsMs != 0 {
      try visitor.visitSingularUInt64Field(value: self.tsMs, fieldNumber: 1)
    }
    try { if let v = self._seatBid {
      try visitor.visitSingularMessageField(value: v, fieldNumber: 2)
    } }()
    if !self.title.isEmpty {
      try visitor.visitSingularStringField(value: self.title, fieldNumber: 3)
    }
    if !self.body.isEmpty {
      try visitor.visitSingularStringField(value: self.body, fieldNumber: 4)
    }
    if self.type != .unspecified {
      try visitor.visitSingularEnumField(value: self.type, fieldNumber: 5)
    }
    if !self.advertiser.isEmpty {
      try visitor.visitSingularStringField(value: self.advertiser, fieldNumber: 6)
    }
    if !self.fullScreenshot.isEmpty {
      try visitor.visitSingularBytesField(value: self.fullScreenshot, fieldNumber: 7)
    }
    if !self.adScreenshot.isEmpty {
      try visitor.visitSingularBytesField(value: self.adScreenshot, fieldNumber: 8)
    }
    if !self.key.isEmpty {
      try visitor.visitSingularStringField(value: self.key, fieldNumber: 9)
    }
    if self.fullScreenshotType != .unspecified {
      try visitor.visitSingularEnumField(value: self.fullScreenshotType, fieldNumber: 10)
    }
    if self.adScreenshotType != .unspecified {
      try visitor.visitSingularEnumField(value: self.adScreenshotType, fieldNumber: 11)
    }
    if !self.adsetID.isEmpty {
      try visitor.visitSingularStringField(value: self.adsetID, fieldNumber: 12)
    }
    try unknownFields.traverse(visitor: &visitor)
  }

  static func ==(lhs: Com_Newsbreak_Monetization_Common_Ad, rhs: Com_Newsbreak_Monetization_Common_Ad) -> Bool {
    if lhs.tsMs != rhs.tsMs {return false}
    if lhs._seatBid != rhs._seatBid {return false}
    if lhs.title != rhs.title {return false}
    if lhs.body != rhs.body {return false}
    if lhs.type != rhs.type {return false}
    if lhs.advertiser != rhs.advertiser {return false}
    if lhs.fullScreenshot != rhs.fullScreenshot {return false}
    if lhs.adScreenshot != rhs.adScreenshot {return false}
    if lhs.key != rhs.key {return false}
    if lhs.fullScreenshotType != rhs.fullScreenshotType {return false}
    if lhs.adScreenshotType != rhs.adScreenshotType {return false}
    if lhs.adsetID != rhs.adsetID {return false}
    if lhs.unknownFields != rhs.unknownFields {return false}
    return true
  }
}