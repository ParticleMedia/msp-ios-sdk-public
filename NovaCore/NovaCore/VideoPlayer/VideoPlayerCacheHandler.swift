import Foundation

@objc public class VideoPlayerCacheHandler: NSObject {

    @objc public static let shared = VideoPlayerCacheHandler()

    private var videoMap = [String: VideoPlayer]()

    //get the video player for url
    public func getCachedVideoControllerForURL(_ url: URL, cacheKey: String) -> VideoPlayer? {
        if let playerController = videoMap[cacheKey] {
            return playerController
        } else {
            getControllerToPreload(cacheKey: cacheKey, url: url)
            return videoMap[cacheKey]
        }
    }

    //get the player to preload the url
    @objc public func getControllerToPreload(cacheKey: String, url: URL) {
        let controller: VideoPlayer

        if let c = videoMap[cacheKey] {
            controller = c
        } else {
            controller = VideoPlayer()
            self.videoMap[cacheKey] = controller
        }

        if !controller.isPlaying(urlString: url.absoluteString) {
            controller.preload(with: url)
        }
    }

    public func removePlayer(cacheKey: String) {
        videoMap.removeValue(forKey: cacheKey)
    }
}
