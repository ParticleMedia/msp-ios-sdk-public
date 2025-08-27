//
//  UIImage.swift
//  Pods
//
//  Created by Wei Wu (iOS) on 11/7/23.
//
import UIKit
import Foundation

extension UIImage {
    static let Nova = NovaImage()
    
    class NovaImage {

        // MARK: - Components
        let bottomShadow = UIImage(named: "bottom_shadow", in: NovaAsset.getBundle(), compatibleWith: nil)

        // MARK: - Icons
        let chevronLeftLine = UIImage(named: "chevron_left_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let chevronRightLine = UIImage(named: "chevron_right_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossFilled = UIImage(named: "cross_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossOutline = UIImage(named: "cross_outline", in: NovaAsset.getBundle(), compatibleWith: nil)
        let ellipsisHorizontalOutline = UIImage(named: "ellipsis_horizontal_outline", in: NovaAsset.getBundle(), compatibleWith: nil)
        let pauseFilled = UIImage(named: "pause_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let pauseLine = UIImage(named: "pause_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let playFilled = UIImage(named: "play_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let playLine = UIImage(named: "play_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let playFilledNew = UIImage(named: "video_pause", in: NovaAsset.getBundle(), compatibleWith: nil)
        let volumeOffLine = UIImage(named: "volume_off_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let volumeOnLine = UIImage(named: "volume_on_line", in: NovaAsset.getBundle(), compatibleWith: nil)
    }
}
