//
//  MraidDefaultHandler.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/5.
//

import AVKit
import UIKit

final class MraidDefaultHandler {
    init() {}

    func playVideo(url: URL) {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            logError("[MRAID Native] playVideo invalid or missing uri")
            return
        }
        logInfo("[MRAID Native] Opening video URL: \(url)")
        DispatchQueue.main.async {
            if let presenter = UIApplication.novaTopViewController {
                let player = AVPlayer(url: url)
                let controller = AVPlayerViewController()
                controller.player = player
                presenter.present(controller, animated: true) {
                    controller.player?.play()
                }
            } else {
                self.logError("[MRAID Native] Unable to find presenter for video playback")
            }
        }
    }

    private func logInfo(_ message: String) {
        DebugLogger.data.info("\(message, privacy: .public)")
    }

    private func logError(_ message: String) {
        DebugLogger.data.error("\(message, privacy: .public)")
    }
}
