//
//  NovaAdMediaContentAdapter.swift
//  NovaAdapter
//
//  Created by Shanyu Li on 2025/9/23.
//

import Foundation
import MSPiOSCore
import NovaCore

// MARK: - NovaAdMediaContentAdapter

class NovaAdMediaContainerAdapter: AdMediaContainer {
    // MARK: Lifecycle

    init(mediaContent: NovaAdMediaContent) {
        self.mediaContent = mediaContent
        if let videoController = mediaContent.videoController {
            self.videoControllerAdapter = NovaAdVideoControllerAdapter(videoController: videoController)
        } else {
            self.videoControllerAdapter = nil
        }
    }

    // MARK: Internal

    let mediaContent: NovaAdMediaContent
    let videoControllerAdapter: NovaAdVideoControllerAdapter?

    var videoController: (any MSPiOSCore.VideoController)? {
        return videoControllerAdapter
    }
}

// MARK: - NovaAdVideoControllerAdapter

class NovaAdVideoControllerAdapter: VideoController {
    // MARK: Lifecycle

    init(videoController: NovaAdVideoController) {
        self.videoController = videoController
        self.delegateAdapter = NovaAdVideoControllerDelegateAdapter(videoController: nil)
        videoController.delegate = delegateAdapter
        self.delegateAdapter.videoController = self
    }

    // MARK: Internal

    let videoController: NovaAdVideoController
    let delegateAdapter: NovaAdVideoControllerDelegateAdapter

    var delegate: (any MSPiOSCore.VideoControllerDelegate)? {
        get {
            delegateAdapter.videoControllerDelegate
        }
        set {
            delegateAdapter.videoControllerDelegate = newValue
        }
    }

    var muted: Bool {
        get {
            videoController.muted 
        }
        set {
            videoController.muted = newValue
        }
    }

    func play() {
        videoController.play()
    }

    func pause() {
        videoController.pause()
    }

    func stop() {
        videoController.stop()
    }
}

// MARK: - NovaAdVideoControllerDelegateAdapter

class NovaAdVideoControllerDelegateAdapter: NovaAdVideoViewDelegate {
    // MARK: Lifecycle

    init(videoController: (any VideoController)?) {
        self.videoController = videoController
    }

    // MARK: Internal

    weak var videoController: (any VideoController)?
    weak var videoControllerDelegate: VideoControllerDelegate?

    func videoViewCurrentTimeDidChange(loopCount: Int, currentTime: TimeInterval, videoLength: TimeInterval) {
        videoControllerDelegate?
            .videoController(
                videoController,
                loopCount: loopCount,
                didUpdateProgress: currentTime,
                videoLength: videoLength
            )
    }
}
