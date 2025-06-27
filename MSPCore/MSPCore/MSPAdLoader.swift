//
//  MSPAdLoader.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation
import MSPiOSCore

public class MSPAdLoader: NSObject {
    
    weak var adListener: AdListener?
    var adRequest: AdRequest?
    
    var bidLoader: BidLoader?
    var adNetworkAdapter: AdNetworkAdapter?
    
    var winnerBidderPlacementId: String?

    var mspAuction: MSPAuction?
    
    public override init() {}
    
    public func loadAd(placementId: String, adListener: AdListener, adRequest: AdRequest) {
        MESMetricReporter.shared.logAdRequest(adRequest: adRequest)
        self.adListener = adListener
        self.adRequest = adRequest
        
        let bidders: [MSPiOSCore.Bidder]
        let timeout: Double
        if let placement = getPlacement(placementId: placementId) {
            let adConfigBidders = getBidders(placement: placement)
            if adConfigBidders.isEmpty {
                bidders = getDefaultBidders(adRequest: adRequest)
            } else {
                bidders = adConfigBidders
            }
            timeout = Double(placement.auctionTimeout ?? 8)
        } else {
            bidders = getDefaultBidders(adRequest: adRequest)
            timeout = 8.0 // default timeout when placement is missing
        }
        
        let mspAuction = MSPAuction(bidders: bidders, cacheOnly: false, timeout: timeout)
        self.mspAuction = mspAuction
        mspAuction.adRequest = adRequest
        adRequest.requestStartTime = Date().timeIntervalSince1970
        mspAuction.startAuction(auctionListener: self, adListener: adListener)
    }
    
    public func getPlacement(placementId: String) -> Placement? {
        if let adConfig = MSPAdConfigManager.shared.adConfig,
           let placements = adConfig.placements {
            for placement in placements {
                if placement.placementId == placementId {
                    return placement
                }
            }
        }
        return nil
    }
    
    private func getDefaultBidders(adRequest: AdRequest) -> [MSPiOSCore.Bidder] {
        var bidders = [MSPiOSCore.Bidder]()
        let bidder = MSPBidder(name: "msp", bidderPlacementId: adRequest.placementId, bidderFormat: adRequest.adFormat)
        bidders.append(bidder)
        return bidders
    }
    
    public func getBidders(placement: Placement) -> [MSPiOSCore.Bidder] {
        var bidders = [MSPiOSCore.Bidder]()
        
        if let bidderInfoList = placement.bidders {
            for bidderInfo in bidderInfoList {
                if let bidder = getBidder(bidderInfo: bidderInfo) {
                    bidder.params = bidderInfo.params
                    bidders.append(bidder)
                }
            }
        }
        
        return bidders
    }
    
    public func getBidder(bidderInfo: BidderInfo) -> MSPiOSCore.Bidder? {
        var bidderFormat: AdFormat?
        switch bidderInfo.bidderFormat {
        case "banner":
            bidderFormat = .banner
        case "native":
            bidderFormat = .native
        case "interstitial":
            bidderFormat = .interstitial
        case "multi_format":
            bidderFormat = .multi_format
        default:
            bidderFormat = nil
            
        }
        
        switch bidderInfo.name {
        case "msp":
            return MSPBidder(name: "msp", bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
        case "unity":
            //let bidder = MSP.shared.adNetworkAdapterProvider.unityManager?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.unity]?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case "pubmatic":
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.pubmatic]?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case "inmobi":
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.inmobi]?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case "mobilefuse":
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.mobilefuse]?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case "mintegral":
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.mintegral]?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        default:
            return nil
        }
    }
    
    public func getAd(placementId: String) -> MSPAd? {
        MSPLogger.shared.info(message: "[Auction: Get Ad] started.")
        var winnerPlacementId = ""
        var winnerPrice = 0.0
        var winnerBidderName = ""
        if let placement = getPlacement(placementId: placementId),
           let bidderInfoList = placement.bidders,
           !bidderInfoList.isEmpty {
            for bidderInfo in bidderInfoList {
                let bidderPlacementId = bidderInfo.bidderPlacementId
                if let ad = AdCache.shared.peakAd(placementId: bidderPlacementId),
                   let price = ad.adInfo["price"] as? Double,
                   price > winnerPrice {
                    winnerPrice = price
                    winnerPlacementId = bidderPlacementId
                    winnerBidderName = bidderInfo.name
                }
            }
            if let ad = AdCache.shared.getAd(placementId: winnerPlacementId) {
                MSPLogger.shared.info(message: "[Auction: Get Ad] complete, winner: \(winnerBidderName),\(winnerPrice),\(winnerPlacementId)")
                return ad
            }
        } else {
            if let ad = AdCache.shared.getAd(placementId: placementId) {
                MSPLogger.shared.info(message: "[Auction: Get Ad] complete, winner: \(winnerBidderName),\(winnerPrice),\(winnerPlacementId)")
                return ad
            }
        }
        return nil
    }
}



extension MSPAdLoader: AuctionListener {
    public func onSuccess(winningBid: MSPiOSCore.AuctionBid) {
        DispatchQueue.main.async {
            self.winnerBidderPlacementId = winningBid.bidderPlacementId
            if let placementId = self.adRequest?.placementId {
                self.adListener?.onAdLoaded(placementId: placementId)
            }
        }
    }
    
    public func onError(error: String) {
        adListener?.onError(msg: error)
    }
    
    
}

