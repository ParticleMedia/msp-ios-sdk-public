//
//  MSPBidder.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/18/24.
//

import Foundation
import MSPiOSCore
import PrebidMobile
import UIKit

public class MSPBidder: MSPiOSCore.Bidder {
    public weak var auctionBidListener: AuctionBidListener?
    public weak var adListener: AdListener?
    public var adRequest: AdRequest?
    public var adNetworkAdapter: AdNetworkAdapter?
    public var bidLoader: BidLoader?
    
    public override func requestBid(adRequest: AdRequest, bidListener: any AuctionBidListener, adListener: any AdListener) {
        let prebidBidLoader = MSP.shared.bidLoaderProvider.getBidLoader()
        self.auctionBidListener = bidListener
        self.adListener = adListener
        self.adRequest = adRequest
        self.bidLoader = prebidBidLoader
        adRequest.customParams["adn_sdk_versions"] = getSDKVersions()
        for (key,value) in MSPDevice.shared.getDeviceSignalsDictionary() {
            adRequest.customParams[key] = value
        }
        prebidBidLoader.loadBid(placementId: bidderPlacementId, adParams: adRequest.customParams, bidListener: self, adRequest: adRequest)
    }
    
    private func getSDKVersions() -> String {
        let versions: [String: String] = [
            "google": MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: .google)?.getSDKVersion() ?? "",
            "facebook": MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: .facebook)?.getSDKVersion() ?? "",
            "nova": MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: .nova)?.getSDKVersion() ?? "",
            "msp": getMSPVersion()
        ]

        if let jsonData = try? JSONSerialization.data(withJSONObject: versions, options: []),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        return ""
    }
    
    private func getMSPVersion() -> String {
        let bundle = Bundle(for: MSPBidder.self)
        if let url = bundle.url(forResource: "MSPCoreResources", withExtension: "bundle"),
           let resourceBundle = Bundle(url: url),
           let plistURL = resourceBundle.url(forResource: "Config", withExtension: "plist"),
           let dict = NSDictionary(contentsOf: plistURL),
           let version = dict["SDKVersion"] as? String {
            return version
        }
        return ""
    }
}

extension MSPBidder: BidListener {
    public func onBidResponse(bidResponse: Any, adNetwork: MSPiOSCore.AdNetwork) {
        if let adListener = self.adListener,
           let adRequest = self.adRequest,
           let auctionBidListener = auctionBidListener {
            if let adNetworkAdapter = MSP.shared.adNetworkAdapterProvider.getAdNetworkAdapter(adNetwork: adNetwork) {
                MSPLogger.shared.info(message: "\(adNetwork): adapter instance created successfully")
                self.adNetworkAdapter = adNetworkAdapter
                DispatchQueue.main.async {
                    adNetworkAdapter.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
                    adNetworkAdapter.loadAdCreative(bidResponse: bidResponse, auctionBidListener: auctionBidListener, adListener: adListener, context: self, adRequest: adRequest, bidderPlacementId: self.bidderPlacementId, bidderFormat: nil, params: self.params)
                }
            } else {
                MSPLogger.shared.info(message: "\(adNetwork): adapter not found")
                auctionBidListener.onError(error: "Ad network is not supported")
            }
        } else {
            auctionBidListener?.onError(error: "Invalid request")
        }
    }
    
    public func onError(msg: String) {
        auctionBidListener?.onError(error: msg)
    }
}
