//
//  UIImage.swift
//  Pods
//
//  Created by Wei Wu (iOS) on 11/7/23.
//
import UIKit

extension UIImage {
    static let Nova = NovaImage()
    
    class NovaImage {

        // MARK: - Components
        let isolationMode = UIImage(named: "isolation_mode", in: NovaAsset.getBundle(), compatibleWith: nil)
        let popOver = UIImage(named: "pop_over", in: NovaAsset.getBundle(), compatibleWith: nil)
        let popOverFilledBlue = UIImage(named: "pop_over_filled_blue", in: NovaAsset.getBundle(), compatibleWith: nil)

        // MARK: - Icons
        let arrowClockwiseLine = UIImage(named: "arrow_clockwise_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let chevronLeftLine = UIImage(named: "chevron_left_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let chevronRightCircleFilled = UIImage(named: "chevron_right_circle_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let chevronRightLine = UIImage(named: "chevron_right_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let contextFilled = UIImage(named: "context_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossCircleFilled = UIImage(named: "cross_circle_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossCircleLine = UIImage(named: "cross_circle_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossFilled = UIImage(named: "cross_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossLine = UIImage(named: "cross_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let crossOutline = UIImage(named: "cross_outline", in: NovaAsset.getBundle(), compatibleWith: nil)
        let downloadLine = UIImage(named: "download_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let ellipsisHorizontalCircleLine = UIImage(named: "ellipsis_horizontal_circle_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let ellipsisHorizontalOutline = UIImage(named: "ellipsis_horizontal_outline", in: NovaAsset.getBundle(), compatibleWith: nil)
        let pauseFilled = UIImage(named: "pause_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let pauseLine = UIImage(named: "pause_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let playFilled = UIImage(named: "play_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
        let playLine = UIImage(named: "play_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let videoPause = UIImage(named: "video_pause", in: NovaAsset.getBundle(), compatibleWith: nil)
        let volumeOffLine = UIImage(named: "volume_off_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let volumeOnLine = UIImage(named: "volume_on_line", in: NovaAsset.getBundle(), compatibleWith: nil)
        let gameFilled = UIImage(named: "game_filled", in: NovaAsset.getBundle(), compatibleWith: nil)
    }
}
