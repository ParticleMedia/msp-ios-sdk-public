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
    
    func didTapSkipButton()

    func didTapPlayableAd(with playableModel: PlayableModel)
}

extension NovaInterstitialAdSubviewBehaviorDelegate {
    func didTapSkipButton() {
        
    }
}
