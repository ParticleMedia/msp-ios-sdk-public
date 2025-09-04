//
//  NovaAdVideoSubviewBehaviorDelegate.swift
//  Pods
//
//  Created by Shanyu Li on 2025/2/5.
//

import UIKit


protocol NovaAdVideoSubviewBehaviorDelegate: AnyObject {
    func didTapStartButton()

    func didTapPlayButton(_ gesture: UITapGestureRecognizer)

    func didTapMuteButton()

    func didTapCloseButton()

    func didTapAd(on clickArea: ClickableAdArea)
}
