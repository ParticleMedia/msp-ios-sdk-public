//
//  GoogleQueryInfoFetcher.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 5/12/24.
//

import Foundation

public protocol GoogleQueryInfoFetcher: AnyObject {
    func fetch(completeListener: GoogleQueryInfoListener, adRequest: AdRequest)
}
