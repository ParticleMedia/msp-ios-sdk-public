//
//  NovaAdVideoCacheManager.swift
//  Pods
//
//  Created by Shanyu Li on 2025/8/11.
//

import Foundation
import AVFoundation
import Combine

private struct SendableTimeRange: Sendable {
    let start: Float64
    let duration: Float64

    init(timeRange: CMTimeRange) {
        self.start = CMTimeGetSeconds(timeRange.start)
        self.duration = CMTimeGetSeconds(timeRange.duration)
    }
}

actor NovaAdVideoCacheItem: NSObject {
    private let videoAdScheme = "videoadcaching"
    let asset: AVURLAsset
    private var data: Data?

    private var loaderDelegate: VideoAdLoaderDelegate

    private var preloadTask: Task<Void, Never>?
    private var cancellable: AnyCancellable?
    private var preloadPlayer: AVPlayer?

    func startObserving(playerItem: AVPlayerItem) {
        cancellable = playerItem.publisher(for: \.loadedTimeRanges)
            .sink { [weak self] loadedTimeRanges in
                guard let range = loadedTimeRanges.first.flatMap({ $0.timeRangeValue }) else {
                    return
                }
                let sendableRange = SendableTimeRange(timeRange: range)
                Task { [weak self] in
                    await self?.handleLoadedTimeRanges(sendableRange)
                }
            }
    }

    init(url: URL, data: Data? = nil) {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.scheme = videoAdScheme
        let replacedUrl = components?.url ?? url
        self.asset = AVURLAsset(url: replacedUrl)
        self.data = data
        self.loaderDelegate = VideoAdLoaderDelegate(originalURL: url, cachedData: nil)
        super.init()

        asset.resourceLoader.setDelegate(loaderDelegate, queue: DispatchQueue.main)
    }

    func preloadAsset() async {
        if preloadTask != nil {
            return
        }

        preloadTask = Task {
            let playerItem = AVPlayerItem(asset: asset)
            preloadPlayer = AVPlayer(playerItem: playerItem)

            startObserving(playerItem: playerItem)

            await preloadPlayer?.play()
            await preloadPlayer?.pause()
        }

        defer { preloadTask = nil }

        await preloadTask?.value
    }

    var videoNaturalSize: CGSize? {
        return asset.getLoadedTracksIfAvailable(withMediaType: .video)?.first?.naturalSize
    }

    var dataSize: Int? {
        data?.count
    }

    func setData(_ data: Data) {
        self.data = data
    }

    private func handleLoadedTimeRanges(_ timeRange: SendableTimeRange) {
        let bufferedDuration = timeRange.start + timeRange.duration
        if bufferedDuration > 2 {
            preloadPlayer = nil
        }
    }
}

actor NovaAdVideoCacheManager {
    static let shared = NovaAdVideoCacheManager()

    private let cache = NSCache<NSString, NovaAdVideoCacheItem>()

    private init() {
        cache.countLimit = 20
    }

    func loadAsset(url: URL) -> AVAsset {
        let cacheKey = url.absoluteString as NSString

        if let cacheItem = cache.object(forKey: cacheKey) {
            return cacheItem.asset
        }

        let cacheItem = NovaAdVideoCacheItem(url: url)
        cache.setObject(cacheItem, forKey: cacheKey)
        return cacheItem.asset
    }

    func getAssetNaturalSize(url: URL) async -> CGSize? {
        let cacheItem = cache.object(forKey: url.absoluteString as NSString)
        return await cacheItem?.videoNaturalSize
    }

    func preload(url: URL) async {
        let cacheKey = url.absoluteString as NSString

        let cacheItem: NovaAdVideoCacheItem
        if let existingItem = cache.object(forKey: cacheKey) {
            cacheItem = existingItem
        } else {
            cacheItem = NovaAdVideoCacheItem(url: url)
            cache.setObject(cacheItem, forKey: cacheKey)
        }

        await cacheItem.preloadAsset()
    }

    func update(data: Data, for url: URL) async {
        let cacheKey = url.absoluteString as NSString

        if let existingItem = cache.object(forKey: cacheKey) {
            await existingItem.setData(data)
        } else {
            let cacheItem = NovaAdVideoCacheItem(url: url, data: data)
            cache.setObject(cacheItem, forKey: cacheKey)
        }
    }
}

class VideoAdLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
    private let originalURL: URL
    private let cachedData: NSData?
    private var pendingRequests = [AVAssetResourceLoadingRequest]()
    private var mimeType: String?
    private var isDownloading = false

    init(originalURL: URL, cachedData: NSData?) {
        self.originalURL = originalURL
        self.cachedData = cachedData
        super.init()
    }

    func resourceLoader(
        _ resourceLoader: AVAssetResourceLoader,
        shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
    ) -> Bool {
        pendingRequests.append(loadingRequest)

        if let cachedData {
            processPendingRequests(with: cachedData as Data)
        } else if !isDownloading {
            Task {
                await downloadVideo()
            }
        }

        return true
    }

    private func downloadVideo() async {
        isDownloading = true

        do {
            let (data, response) = try await URLSession.shared.data(from: originalURL)
            if let httpResponse = response as? HTTPURLResponse {
                mimeType = httpResponse.mimeType ?? originalURL.videoMimeType
            }
            await NovaAdVideoCacheManager.shared.update(data: data, for: originalURL)
            processPendingRequests(with: data)
        } catch {
            finishPendingRequestsWithError(error)
        }

        isDownloading = false
    }

    private func processPendingRequests(with videoData: Data) {
        for loadingRequest in pendingRequests {
            if let contentInformationRequest = loadingRequest.contentInformationRequest {
                contentInformationRequest.contentType = mimeType ?? AVFileType.mp4.rawValue
                contentInformationRequest.contentLength = Int64(videoData.count)
                contentInformationRequest.isByteRangeAccessSupported = true
            }

            if let dataRequest = loadingRequest.dataRequest {
                let requestedOffset = Int(dataRequest.requestedOffset)
                let requestedLength = dataRequest.requestedLength
                let endOffset = min(requestedOffset + requestedLength, videoData.count)

                if requestedOffset < endOffset {
                    let responseData = videoData.subdata(in: requestedOffset..<endOffset)
                    dataRequest.respond(with: responseData)
                }
            }

            loadingRequest.finishLoading()
        }

        pendingRequests.removeAll()
    }

    private func finishPendingRequestsWithError(_ error: Error?) {
        for loadingRequest in pendingRequests {
            loadingRequest.finishLoading(with: error)
        }

        pendingRequests.removeAll()
    }

}

private extension URL {
    var videoMimeType: String? {
        switch pathExtension.lowercased() {
        case "mp4":
            return "video/mp4"
        case "mov":
            return "video/quicktime"
        case "m4v":
            return "video/x-m4v"
        case "m3u8":
            return "application/vnd.apple.mpegurl"
        default:
            return nil
        }
    }
}

extension AVAsset {
    func getLoadedTracksIfAvailable(withMediaType mediaType: AVMediaType) -> [AVAssetTrack]? {
        switch status(of: .tracks) {
        case .loaded(let tracks):
            return tracks.filter { $0.mediaType == mediaType }
        default:
            return nil
        }
    }
}

