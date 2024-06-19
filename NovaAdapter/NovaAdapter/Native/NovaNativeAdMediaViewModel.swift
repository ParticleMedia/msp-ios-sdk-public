public struct NovaNativeAdMediaViewModel {
    let imageUrlStr: String?
    let videoInfo: NovaNativeAdVideoInfo?
    let encryptedAdToken: String

    public init(encryptedAdToken: String,
                imageUrlStr: String?,
                videoInfo: NovaNativeAdVideoInfo?) {
        self.encryptedAdToken = encryptedAdToken
        self.imageUrlStr = imageUrlStr
        self.videoInfo = videoInfo
    }
}
