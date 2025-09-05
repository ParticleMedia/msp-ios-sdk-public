import SwiftUI

extension Image {
    static let Nova = NovaImage()
    
    class NovaImage {
        // MARK: - Components
        let bottomShadow = Image("bottom_shadow", bundle: NovaAsset.getBundle())


        // MARK: - Icons
        let chevronLeftLine = Image("chevron_left_line", bundle: NovaAsset.getBundle())
        let chevronRightLine = Image("chevron_right_line", bundle: NovaAsset.getBundle())
        let crossFilled = Image("cross_filled", bundle: NovaAsset.getBundle())
        let crossOutline = Image("cross_outline", bundle: NovaAsset.getBundle())
        let ellipsisHorizontalOutline = Image("ellipsis_horizontal_outline", bundle: NovaAsset.getBundle())
        let pauseFilled = Image("pause_filled", bundle: NovaAsset.getBundle())
        let pauseLine = Image("pause_line", bundle: NovaAsset.getBundle())
        let playFilled = Image("play_filled", bundle: NovaAsset.getBundle())
        let playLine = Image("play_line", bundle: NovaAsset.getBundle())
        let playFilledNew = Image("video_pause", bundle: NovaAsset.getBundle())
        let volumeOffLine = Image("volume_off_line", bundle: NovaAsset.getBundle())
        let volumeOnLine = Image("volume_on_line", bundle: NovaAsset.getBundle())
    }
}
