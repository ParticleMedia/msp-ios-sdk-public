//
//  S2SLatencyInfo.swift
//  MSPiOSCore
//

import Foundation

public class S2SLatencyInfo {
    public var auctionBidderLatency: [String: Int32] = [:]
    public var bidTokenLatency: [String: Int32] = [:]
    public var bidRequestLatencyMs: Int32 = 0
    public var adLoadLatencyMs: Int32 = 0
}
