//
//  MraidDefaultHandler.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/5.
//

import AVKit
import EventKit
import Photos
import UIKit

final class MraidDefaultHandler {
    private let calendarEventDefaultTitle: String
    private let eventStore = EKEventStore()

    init(calendarEventTitle: String) {
        self.calendarEventDefaultTitle = calendarEventTitle
    }

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

    func storePicture(url: URL) {
        let hasReadWriteKey = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
        let hasAddOnlyKey = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil
        guard hasReadWriteKey || hasAddOnlyKey else {
            logError("[MRAID Native] App does not set photo library related keys in info.plist")
            return
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            logError("[MRAID Native] storePicture invalid or missing uri")
            return
        }
        logInfo("[MRAID Native] Downloading image from: \(url)")
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                self.logError("[MRAID Native] storePicture download failed: \(error)")
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                self.logError("[MRAID Native] storePicture invalid data")
                return
            }

            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                let authorized = status == .authorized || status == .limited
                guard authorized else {
                    self.logError("[MRAID Native] storePicture not authorized")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    if let error = error {
                        self.logError("[MRAID Native] storePicture save failed: \(error)")
                    } else {
                        self.logInfo("[MRAID Native] storePicture success: \(success)")
                    }
                }
            }
        }.resume()
    }

    func createCalendarEvent(params: [String: Any]) {
        let hasOldFullAccessKey = Bundle.main.object(forInfoDictionaryKey: "NSCalendarsUsageDescription") != nil
        let hasReadWriteKey = Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil
        let hasWriteOnlyKey =
            Bundle.main.object(forInfoDictionaryKey: "NSCalendarsWriteOnlyAccessUsageDescription") != nil
        guard hasOldFullAccessKey || hasReadWriteKey || hasWriteOnlyKey else {
            logError("[MRAID Native] App does not set calendar related keys in info.plist")
            return
        }

        logInfo("[MRAID Native] createCalendarEvent params: \(params)")
        requestCalendarAccess { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.logError("[MRAID Native] Calendar access denied")
                return
            }
            let event = EKEvent(eventStore: self.eventStore)
            event.title = params["description"] as? String ?? self.calendarEventDefaultTitle
            event.location = params["location"] as? String
            event.startDate = self.timestamp(from: params["start"]) ?? Date()
            event.endDate = self.timestamp(from: params["end"]) ?? event.startDate.addingTimeInterval(3600)
            self.logInfo(
                "[MRAID Native] Calendar event time: start=\(self.formatDate(event.startDate)), end=\(self.formatDate(event.endDate))"
            )
            event.calendar =
                self.eventStore.defaultCalendarForNewEvents
                ?? self.eventStore.calendars(for: .event).first
            do {
                try self.eventStore.save(event, span: .thisEvent)
                self.logInfo("[MRAID Native] Calendar event saved: \(event.eventIdentifier ?? "")")
            } catch {
                self.logError("[MRAID Native] Failed to save calendar event: \(error)")
            }
        }
    }

    private func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17, *) {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .fullAccess, .writeOnly:
                completion(true)
            case .notDetermined:
                eventStore.requestWriteOnlyAccessToEvents { granted, error in
                    completion(granted && error == nil)
                }
            case .restricted, .denied:
                completion(false)
            @unknown default:
                completion(false)
            }
        } else {
            switch EKEventStore.authorizationStatus(for: .event) {
            case .authorized:
                completion(true)
            case .notDetermined:
                eventStore.requestAccess(to: .event) { granted, _ in
                    completion(granted)
                }
            default:
                completion(false)
            }
        }
    }

    private func timestamp(from value: Any?) -> Date? {
        if let doubleValue = value as? Double {
            return Date(timeIntervalSince1970: doubleValue / 1000)
        } else if let intValue = value as? Int {
            return Date(timeIntervalSince1970: Double(intValue) / 1000)
        }
        return nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter.string(from: date)
    }

    private func logInfo(_ message: String) {
        DebugLogger.data.info("\(message, privacy: .public)")
    }

    private func logError(_ message: String) {
        DebugLogger.data.error("\(message, privacy: .public)")
    }
}
