//
//  NovaInterstitialAdSubviewBehaviorDelegate.swift
//  NovaCore
//
//  Created by Pengyu Gou on 2025/8/15.
//

import Foundation

protocol NovaInterstitialAdSubviewBehaviorDelegate: AnyObject {
    func didTapFeedbackButton()

    func didTapCloseButton()

    func didTapPlayableAd(with playableModel: PlayableModel)

    func didTapCustomAdView(customUrl: URL?, clickArea: ClickableAdArea)
}
