//
//  NovaInterstitialHtmlPageController.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 10/30/25.
//

protocol NovaInterstitialMultiPageDelegate: AnyObject {
    
    func novaInterstitialDidSkipPage()
    
    func novaInterstitialDidDismissAd()
    
}
