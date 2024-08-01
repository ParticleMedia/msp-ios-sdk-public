import SwiftUI

public extension Image {
    static let NovaEmoji = NovaImageEmoji()
    
    class NovaImageEmoji {
        public let angry = Image("angry", bundle: NovaAsset.getBundle())
        public let haha = Image("haha", bundle: NovaAsset.getBundle())
        public let like = Image("like", bundle: NovaAsset.getBundle())
        public let love = Image("love", bundle: NovaAsset.getBundle())
        public let sad = Image("sad", bundle: NovaAsset.getBundle())
        public let wow = Image("wow", bundle: NovaAsset.getBundle())
    }
}
