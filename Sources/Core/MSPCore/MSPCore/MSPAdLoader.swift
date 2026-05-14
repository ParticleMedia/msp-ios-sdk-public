//
//  MSPAdLoader.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/17/24.
//

import Foundation
import MSPiOSCore

public class MSPAdLoader: NSObject {
    private static let DEFAULT_AUCTION_TIMEOUT_MS: Double = 30 * 1000

    weak var adListener: AdListener?
    var adRequest: AdRequest?
    var rewardedAdapterRolloutPolicy: any RewardedAdapterRolloutPolicy = ClientRewardedAdapterRolloutPolicy()
    private let bidLossResolver = MSPAdBidLossResolver()
    var bidLossNotifier: (MSPBidLossNotification) -> Void = { notification in
        MSP.shared.notifyLoss(
            winnerBidderName: notification.winnerBidderName,
            winnerPrice: notification.winnerPrice,
            ad: notification.losingAd,
            requestId: notification.requestId
        )
    }

    var bidLoader: BidLoader?
    var adNetworkAdapter: AdNetworkAdapter?

    var winnerBidderPlacementId: String?

    var mspAuction: MSPAuction?
    var loadStartTime: TimeInterval?

    public override init() {}

    public func loadAd(placementId: String, adListener: AdListener, adRequest: AdRequest) {
        MESMetricReporter.shared.logAdRequest(adRequest: adRequest)
        self.adListener = adListener
        self.adRequest = adRequest
        self.loadStartTime = Date().timeIntervalSince1970

        let bidders: [MSPiOSCore.Bidder]
        let timeout: Double

        if let placementString = adRequest.customParams["msp_ad_config"] as? String {
            MSPAdConfigManager.shared.parseExrernalPlacement(string: placementString)
        }

        if let placement = getPlacement(placementId: placementId) {
            let adConfigBidders = getBidders(placement: placement, adRequest: adRequest)
            if adConfigBidders.isEmpty {
                bidders = getDefaultBidders(adRequest: adRequest)
            } else {
                bidders = adConfigBidders
            }
            timeout = Double(placement.auctionTimeout ?? Int(Self.DEFAULT_AUCTION_TIMEOUT_MS))
        } else {
            bidders = getDefaultBidders(adRequest: adRequest)
            timeout = Self.DEFAULT_AUCTION_TIMEOUT_MS  // default timeout when placement is missing
        }

        let mspAuction = MSPAuction(bidders: bidders, cacheOnly: false, timeout: timeout)
        self.mspAuction = mspAuction
        mspAuction.adRequest = adRequest
        adRequest.requestStartTime = Date().timeIntervalSince1970
        mspAuction.startAuction(auctionListener: self, adListener: adListener)
    }

    public func getPlacement(placementId: String) -> Placement? {
        if let placement = MSPAdConfigManager.shared.externalAdConfigPlacements[placementId] {
            return placement
        }
        if let adConfig = MSPAdConfigManager.shared.adConfig,
            let placements = adConfig.placements
        {
            for placement in placements where placement.placementId == placementId {
                return placement
            }
        }
        return nil
    }

    private func getDefaultBidders(adRequest: AdRequest) -> [MSPiOSCore.Bidder] {
        var bidders: [MSPiOSCore.Bidder] = []
        let bidder = MSPBidder(
            name: MSPBidderName.msp, bidderPlacementId: adRequest.placementId, bidderFormat: adRequest.adFormat)
        bidders.append(bidder)
        return bidders
    }

    public func getBidders(placement: Placement, adRequest: AdRequest? = nil) -> [MSPiOSCore.Bidder] {
        var bidders: [MSPiOSCore.Bidder] = []

        if let bidderInfoList = placement.bidders {
            for bidderInfo in bidderInfoList {
                MSPLogger.shared.info(
                    message:
                        "[MSPAdLoader] Inspect bidder. placementId=\(placement.placementId), requestFormat=\(adRequest.map { String(describing: $0.adFormat) } ?? "nil"), bidderName=\(bidderInfo.name), bidderPlacementId=\(bidderInfo.bidderPlacementId), rawBidderFormat=\(bidderInfo.bidderFormat ?? "nil")"
                )
                if shouldFilterRewardedBidder(
                    named: bidderInfo.name, adRequest: adRequest, placementId: placement.placementId)
                {
                    MSPLogger.shared.info(
                        message:
                            "[Rewarded Gate] filter bidder \(bidderInfo.name) for placement \(placement.placementId)")
                    continue
                }
                if let bidder = getBidder(bidderInfo: bidderInfo, requestFormat: adRequest?.adFormat) {
                    bidder.params = bidderInfo.params
                    bidders.append(bidder)
                }
            }
        }

        return bidders
    }

    private func shouldFilterRewardedBidder(named bidderName: String, adRequest: AdRequest?, placementId: String)
        -> Bool
    {
        guard adRequest?.adFormat == .rewarded else {
            return false
        }
        return !rewardedAdapterRolloutPolicy.isEnabled(networkName: bidderName, placementId: placementId)
    }

    public func getBidder(bidderInfo: BidderInfo, requestFormat: AdFormat? = nil) -> MSPiOSCore.Bidder? {
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
        case "rewarded", "rewarded_video":
            bidderFormat = .rewarded
        default:
            bidderFormat = nil
        }

        MSPLogger.shared.info(
            message:
                "[MSPAdLoader] Resolved bidder format. bidderName=\(bidderInfo.name), bidderPlacementId=\(bidderInfo.bidderPlacementId), rawBidderFormat=\(bidderInfo.bidderFormat ?? "nil"), resolvedBidderFormat=\(bidderFormat.map { String(describing: $0) } ?? "nil"), requestFormat=\(requestFormat.map { String(describing: $0) } ?? "nil")"
        )

        switch bidderInfo.name {
        case MSPBidderName.msp:
            return MSPBidder(
                name: MSPBidderName.msp, bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
        case AdNetwork.unity.rawValue:
            //let bidder = MSP.shared.adNetworkAdapterProvider.unityManager?.getAdBidder(bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.unity]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.pubmatic.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.pubmatic]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.inmobi.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.inmobi]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.mobilefuse.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.mobilefuse]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.mintegral.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.mintegral]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.amazon.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.amazon]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.google.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.google]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.moloco.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.moloco]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        case AdNetwork.applovin.rawValue:
            let bidder = MSP.shared.adNetworkAdapterProvider.adNetworkManagerDict[.applovin]?.getAdBidder(
                bidderPlacementId: bidderInfo.bidderPlacementId, bidderFormat: bidderFormat)
            bidder?.setAdMetricReporter(adMetricReporter: AdMetricReporterImp())
            return bidder
        default:
            return nil
        }
    }

    public func getAd(placementId: String) -> MSPAd? {
        MSPLogger.shared.info(message: "[Auction: Get Ad] started.")
        if let placement = getPlacement(placementId: placementId),
            let bidderInfoList = placement.bidders,
            !bidderInfoList.isEmpty
        {
            let candidates = getAuctionAdCandidates(placement: placement)
            if let winner = bidLossResolver.winningCandidate(from: candidates),
                let ad = AdCache.shared.getAd(placementId: winner.bidderPlacementId)
            {
                MSPLogger.shared.info(
                    message:
                        "[Auction: Get Ad] complete, winner: \(winner.bidderName),\(winner.price),\(winner.bidderPlacementId)"
                )
                notifyAdBidLossIfNeeded(candidates: candidates, winner: winner)
                MESMetricReporter.shared.logGetAd(ad: ad, placementId: placementId)
                return ad
            }
        } else {
            if let ad = AdCache.shared.getAd(placementId: placementId) {
                MSPLogger.shared.info(
                    message:
                        "[Auction: Get Ad] complete, winner: \(ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] ?? ""),\(ad.adInfo[MSPConstants.AD_INFO_PRICE] ?? ""),\(placementId)"
                )
                MESMetricReporter.shared.logGetAd(ad: ad, placementId: placementId)
                return ad
            }
        }
        MESMetricReporter.shared.logGetAd(ad: nil, placementId: placementId)
        return nil
    }

    func getAuctionAdCandidates(placement: Placement) -> [MSPAuctionAdCandidate] {
        guard let bidderInfoList = placement.bidders else { return [] }

        return bidderInfoList.compactMap { bidderInfo in
            // Keep losing ads in cache; only the selected winner is consumed by getAd.
            guard let ad = AdCache.shared.peakAd(placementId: bidderInfo.bidderPlacementId),
                let price = ad.adInfo[MSPConstants.AD_INFO_PRICE] as? Double
            else { return nil }

            return MSPAuctionAdCandidate(
                bidderName: bidderInfo.name,
                bidderPlacementId: bidderInfo.bidderPlacementId,
                price: price,
                ad: ad
            )
        }
    }

    private func notifyAdBidLossIfNeeded(candidates: [MSPAuctionAdCandidate], winner: MSPAuctionAdCandidate) {
        guard let notification = bidLossResolver.resolveBidLossNotification(candidates: candidates, winner: winner)
        else { return }

        bidLossNotifier(notification)
    }
}


extension MSPAdLoader: AuctionListener {
    public func onSuccess(winningBid: MSPiOSCore.AuctionBid, loadInfo: [String: Any]) {
        DispatchQueue.main.async {
            self.winnerBidderPlacementId = winningBid.bidderPlacementId
            if let placementId = self.adRequest?.placementId {
                self.adListener?.onAdLoaded(placementId: placementId, loadInfo: loadInfo)
                if let adRequest = self.adRequest,
                    let ad = winningBid.ad,
                    let loadStartTime = self.loadStartTime
                {
                    MESMetricReporter.shared.logLoadAd(
                        adRequest: adRequest, ad: ad, filledFromCache: winningBid.fromCache,
                        latency: (Date().timeIntervalSince1970 - loadStartTime) * 1000, errorMessage: nil)
                }
            }
        }
    }

    public func onError(error: String, loadInfo: [String: Any]) {
        adListener?.onError(msg: error, loadInfo: loadInfo)
        if let adRequest = self.adRequest,
            let loadStartTime = self.loadStartTime
        {
            MESMetricReporter.shared.logLoadAd(
                adRequest: adRequest, ad: nil, filledFromCache: false,
                latency: (Date().timeIntervalSince1970 - loadStartTime) * 1000, errorMessage: error)
        }
    }
}
