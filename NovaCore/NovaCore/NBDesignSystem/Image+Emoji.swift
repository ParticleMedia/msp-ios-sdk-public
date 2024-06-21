import SwiftUI

public extension Image {
    static let NBEmoji = NBImageEmoji()
    
    class NBImageEmoji {
        public let angry = Image("angry", bundle: Asset.getBundle())
        public let haha = Image("haha", bundle: Asset.getBundle())
        public let like = Image("like", bundle: Asset.getBundle())
        public let love = Image("love", bundle: Asset.getBundle())
        public let sad = Image("sad", bundle: Asset.getBundle())
        public let wow = Image("wow", bundle: Asset.getBundle())
    }
}
