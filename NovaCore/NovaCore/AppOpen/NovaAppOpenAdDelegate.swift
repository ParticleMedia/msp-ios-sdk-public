//
//  NovaAppOpenAdDelegate.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/2/24.
//

import Foundation

@objc public protocol NovaAppOpenAdDelegate: AnyObject {
    func appOpenAdDidDisplay(_ appOpenAd: NovaAppOpenAd)
    func appOpenAdDidDismiss(_ appOpenAd: NovaAppOpenAd)
    func appOpenAdDidLogClick(_ appOpenAd: NovaAppOpenAd)
    @objc optional func appOpenAdDidFailToDisplay(_ appOpenAd: NovaAppOpenAd)
}
