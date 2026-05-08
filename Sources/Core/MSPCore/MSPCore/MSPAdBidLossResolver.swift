//
//  MSPAdBidLossResolver.swift
//  MSPCore
//
//  Created by Mingming Luo on 5/7/26.
//

import Foundation
import MSPiOSCore

enum MSPBidderName {
    static let msp = "msp"
}

struct MSPAuctionAdCandidate {
    let bidderName: String
    let bidderPlacementId: String
    let price: Double
    let ad: MSPAd
}

struct MSPBidLossNotification {
    let winnerBidderName: String
    let winnerPrice: Float
    let losingAd: MSPAd?
    let requestId: String?
}

struct MSPAdBidLossResolver {
    func winningCandidate(from candidates: [MSPAuctionAdCandidate]) -> MSPAuctionAdCandidate? {
        var winner: MSPAuctionAdCandidate?
        // Preserve existing getAd tie behavior: later equal-price bidders win.
        for candidate in candidates where winner == nil || candidate.price >= (winner?.price ?? 0) {
            winner = candidate
        }
        return winner
    }

    func resolveBidLossNotification(
        candidates: [MSPAuctionAdCandidate],
        winner: MSPAuctionAdCandidate
    ) -> MSPBidLossNotification? {
        let s2sCandidates = candidates.filter { isS2SBidder($0.bidderName) }
        let c2sCandidates = candidates.filter { !isS2SBidder($0.bidderName) }

        // Send ad_bid_lost only for getAd auctions where both s2s and c2s have valid candidates.
        guard !s2sCandidates.isEmpty, !c2sCandidates.isEmpty else { return nil }

        if isS2SBidder(winner.bidderName) {
            // s2s won: report the highest-priced c2s ad as lost, without request_id.
            guard let losingC2S = winningCandidate(from: c2sCandidates) else { return nil }
            return MSPBidLossNotification(
                winnerBidderName: winner.bidderName,
                winnerPrice: Float(winner.price),
                losingAd: losingC2S.ad,
                requestId: nil
            )
        }

        guard let losingS2S = winningCandidate(from: s2sCandidates),
            let requestId = requestId(from: losingS2S.ad)
        else { return nil }

        // c2s won: report the s2s ad as lost, including its bid request_id.
        return MSPBidLossNotification(
            winnerBidderName: winner.bidderName,
            winnerPrice: Float(winner.price),
            losingAd: losingS2S.ad,
            requestId: requestId
        )
    }

    private func isS2SBidder(_ bidderName: String) -> Bool {
        bidderName == MSPBidderName.msp
    }

    private func requestId(from ad: MSPAd) -> String? {
        guard let requestId = ad.adInfo[MSPConstants.AD_INFO_BID_REQUEST_ID] as? String,
            !requestId.isEmpty
        else { return nil }

        return requestId
    }
}
