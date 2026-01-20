//
//  BidTokens.swift
//  PrebidAdapter
//
//  Created by Mingming Luo on 2025/12/15.
//

import Foundation

public class BidTokens {
    public var googleQueryInfo: String?
    public var facebookBidToken: String?
    public var molocoBidToken: String?
    public var liftoffBidToken: String?

    public init() {}

    @discardableResult
    public func with(googleQueryInfo: String?) -> Self {
        self.googleQueryInfo = googleQueryInfo
        return self
    }

    @discardableResult
    public func with(facebookBidToken: String?) -> Self {
        self.facebookBidToken = facebookBidToken
        return self
    }

    @discardableResult
    public func with(molocoBidToken: String?) -> Self {
        self.molocoBidToken = molocoBidToken
        return self
    }
    
    @discardableResult
    public func with(liftoffBidToken: String?) -> Self {
        self.liftoffBidToken = liftoffBidToken
        return self
    }
 }
