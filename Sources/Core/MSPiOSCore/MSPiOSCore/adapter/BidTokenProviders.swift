//
//  BidTokenProviders.swift
//  MSPiOSCore
//
//  Created by Mingming Luo on 2025-12-15.
//

import Foundation

public class BidTokenProviders {
    public var googleQueryInfoFetcher: GoogleQueryInfoFetcher?
    public var facebookBidTokenProvider: FacebookBidTokenProvider?
    public var molocoBidTokenProvider: MolocoBidTokenProvider?
    public var liftoffBidTokenProvider: LiftoffBidTokenProvider?

    public init() {}

    @discardableResult
    public func with(googleQueryInfoFetcher: GoogleQueryInfoFetcher) -> Self {
        self.googleQueryInfoFetcher = googleQueryInfoFetcher
        return self
    }

    @discardableResult
    public func with(facebookBidTokenProvider: FacebookBidTokenProvider) -> Self {
        self.facebookBidTokenProvider = facebookBidTokenProvider
        return self
    }

    @discardableResult
    public func with(molocoBidTokenProvider: MolocoBidTokenProvider) -> Self {
        self.molocoBidTokenProvider = molocoBidTokenProvider
        return self
    }

    @discardableResult
    public func with(liftoffBidTokenProvider: LiftoffBidTokenProvider) -> Self {
        self.liftoffBidTokenProvider = liftoffBidTokenProvider
        return self
    }
}
