//
//  NovaMraidSupporting.swift
//  NovaCore
//
//  Created by Shanyu Li on 2026/2/2.
//

// Protocol extensions cannot declare nested types; keep associated-object keys at file scope.
import AVKit
import EventKit
import ObjectiveC
import Photos
import UIKit
import WebKit

private enum NovaMraidAssociatedKeys {
    static var eventStore: UInt8 = 0
    static var shimSource: UInt8 = 0
    static var hookSource: UInt8 = 0
    static var initSource: UInt8 = 0
    static var hasRequested: UInt8 = 0
    static var hasInjected: UInt8 = 0
    static var hasFinished: UInt8 = 0
}

protocol NovaMraidSupporting: AnyObject {
    var mraidWebView: WKWebView { get }
    var mraidShimSource: String { get }
    var mraidHookSource: String { get }
    var mraidInitSource: String { get }

    var hasRequestedMraidJs: Bool { get set }
    var hasInjectedMraidShim: Bool { get set }
    var hasFinishedLoad: Bool { get set }
    var eventStore: EKEventStore { get }
    var mraidCalendarEventDefaultTitle: String { get }

    func handleMraidOpen(params: [String: Any])
    func handleMraidOpen(url: URL)
    func handleMraidClose()
    func handleMraidPlayVideo(params: [String: Any])
    func handleMraidStorePicture(params: [String: Any])
    func handleMraidCreateCalendarEvent(params: [String: Any])
}

extension NovaMraidSupporting {
    var mraidCalendarEventDefaultTitle: String { "Event" }
    var eventStore: EKEventStore {
        if let store = objc_getAssociatedObject(self, &NovaMraidAssociatedKeys.eventStore) as? EKEventStore {
            return store
        }
        let store = EKEventStore()
        objc_setAssociatedObject(self, &NovaMraidAssociatedKeys.eventStore, store, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return store
    }

    var mraidShimSource: String {
        cachedString(key: &NovaMraidAssociatedKeys.shimSource) {
            loadJavaScriptResource(named: "novaMraid")
        }
    }

    var mraidHookSource: String {
        cachedString(key: &NovaMraidAssociatedKeys.hookSource) {
            loadJavaScriptResource(named: "novaMraidHook")
        }
    }

    var mraidInitSource: String {
        cachedString(key: &NovaMraidAssociatedKeys.initSource) {
            loadJavaScriptResource(named: "novaMraidInit")
        }
    }

    func mraidLogInfo(_ message: @autoclosure () -> String) {
        let value = message()
        DebugLogger.data.info("\(value, privacy: .public)")
    }

    func mraidLogDebug(_ message: @autoclosure () -> String) {
        let value = message()
        DebugLogger.data.debug("\(value, privacy: .public)")
    }

    func mraidLogError(_ message: @autoclosure () -> String) {
        let value = message()
        DebugLogger.data.error("\(value, privacy: .public)")
    }

    func loadJavaScriptResource(named resourceName: String) -> String {
        NovaJavaScriptResourceLoader.loadScript(named: resourceName)
    }

    func resetMraidState() {
        hasRequestedMraidJs = false
        hasInjectedMraidShim = false
        hasFinishedLoad = false
    }

    func injectMraidShimIfNeeded() {
        guard !hasInjectedMraidShim else { return }
        guard !mraidShimSource.isEmpty else { return }

        hasInjectedMraidShim = true
        mraidWebView.evaluateJavaScript(mraidShimSource) { _, error in
            if let error {
                self.mraidLogError("Failed to inject MRAID shim: \(error)")
            } else {
                self.mraidLogDebug("Injected MRAID shim (novaMraid.js)")
            }
        }
    }

    func initializeMraidState(in webView: WKWebView) {
        guard !mraidInitSource.isEmpty else { return }
        webView.evaluateJavaScript(mraidInitSource) { _, error in
            if let error = error {
                self.mraidLogError("Failed to initialize MRAID state: \(error)")
            }
        }
    }

    func handleMraidAction(action: String, params: [String: Any]) {
        switch action {
        case "open":
            handleMraidOpen(params: params)
        case "close":
            handleMraidClose()
        case "expand":
            handleMraidExpand(params: params)
        case "resize":
            handleMraidResize(params: params)
        case "playVideo":
            handleMraidPlayVideo(params: params)
        case "storePicture":
            handleMraidStorePicture(params: params)
        case "createCalendarEvent":
            handleMraidCreateCalendarEvent(params: params)
        case "mraidRequested":
            handleMraidRequested(params: params)
        default:
            break
        }
    }

    func handleMraidRequested(params: [String: Any]) {
        hasRequestedMraidJs = true
        injectMraidShimIfNeeded()
        if hasFinishedLoad {
            initializeMraidState(in: mraidWebView)
        }
        if let src = params["src"] as? String {
            mraidLogDebug("MRAID requested via script src: \(src)")
        } else {
            mraidLogDebug("MRAID requested via script src")
        }
    }

    func handleMraidClose() {
        mraidLogInfo("[MRAID Native] Received close action")
        updateMraidState("default")
    }

    func handleMraidExpand(params: [String: Any]) {
        mraidLogInfo("[MRAID Native] Received expand request: \(params)")
        fireMraidError(message: "Expand is not supported.", action: "expand")
    }

    func handleMraidResize(params: [String: Any]) {
        mraidLogInfo("[MRAID Native] Received resize request: \(params)")
        fireMraidError(message: "Resize is not supported.", action: "resize")
    }

    func defaultHandleMraidPlayVideo(params: [String: Any]) {
        guard let uri = params["uri"] as? String ?? params["url"] as? String,
            let url = URL(string: uri),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            mraidLogError("[MRAID Native] playVideo invalid or missing uri")
            return
        }
        mraidLogInfo("[MRAID Native] Opening video URL: \(url)")
        DispatchQueue.main.async {
            if let presenter = UIApplication.novaTopViewController {
                let player = AVPlayer(url: url)
                let controller = AVPlayerViewController()
                controller.player = player
                presenter.present(controller, animated: true) {
                    controller.player?.play()
                }
            } else {
                self.mraidLogError("[MRAID Native] Unable to find presenter for video playback")
            }
        }
    }

    func defaultHandleMraidStorePicture(params: [String: Any]) {
        let hasReadWriteKey = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryUsageDescription") != nil
        let hasAddOnlyKey = Bundle.main.object(forInfoDictionaryKey: "NSPhotoLibraryAddUsageDescription") != nil
        guard hasReadWriteKey || hasAddOnlyKey else {
            mraidLogError("[MRAID Native] App does not set photo library related keys in info.plist")
            return
        }
        guard let uri = params["uri"] as? String ?? params["url"] as? String,
            let url = URL(string: uri),
            let scheme = url.scheme?.lowercased(),
            scheme == "http" || scheme == "https"
        else {
            mraidLogError("[MRAID Native] storePicture invalid or missing uri")
            return
        }
        mraidLogInfo("[MRAID Native] Downloading image from: \(url)")
        URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                self.mraidLogError("[MRAID Native] storePicture download failed: \(error)")
                return
            }
            guard let data = data, let image = UIImage(data: data) else {
                self.mraidLogError("[MRAID Native] storePicture invalid data")
                return
            }

            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                let authorized = status == .authorized || status == .limited
                guard authorized else {
                    self.mraidLogError("[MRAID Native] storePicture not authorized")
                    return
                }
                PHPhotoLibrary.shared().performChanges({
                    PHAssetChangeRequest.creationRequestForAsset(from: image)
                }) { success, error in
                    if let error = error {
                        self.mraidLogError("[MRAID Native] storePicture save failed: \(error)")
                    } else {
                        self.mraidLogInfo("[MRAID Native] storePicture success: \(success)")
                    }
                }
            }
        }.resume()
    }

    func defaultHandleMraidCreateCalendarEvent(params: [String: Any]) {
        let hasOldFullAccessKey = Bundle.main.object(forInfoDictionaryKey: "NSCalendarsUsageDescription") != nil
        let hasReadWriteKey = Bundle.main.object(forInfoDictionaryKey: "NSCalendarsFullAccessUsageDescription") != nil
        let hasWriteOnlyKey =
            Bundle.main.object(forInfoDictionaryKey: "NSCalendarsWriteOnlyAccessUsageDescription") != nil
        guard hasOldFullAccessKey || hasReadWriteKey || hasWriteOnlyKey else {
            mraidLogError("[MRAID Native] App does not set calendar related keys in info.plist")
            return
        }

        mraidLogInfo("[MRAID Native] createCalendarEvent params: \(params)")
        requestCalendarAccess { [weak self] granted in
            guard let self = self else { return }
            guard granted else {
                self.mraidLogError("[MRAID Native] Calendar access denied")
                return
            }
            let event = EKEvent(eventStore: self.eventStore)
            event.title = params["description"] as? String ?? self.mraidCalendarEventDefaultTitle
            event.location = params["location"] as? String
            event.startDate = self.timestamp(from: params["start"]) ?? Date()
            event.endDate = self.timestamp(from: params["end"]) ?? event.startDate.addingTimeInterval(3600)
            self.mraidLogInfo(
                "[MRAID Native] Calendar event time: start=\(self.formatDate(event.startDate)), end=\(self.formatDate(event.endDate))"
            )
            event.calendar =
                self.eventStore.defaultCalendarForNewEvents
                ?? self.eventStore.calendars(for: .event).first
            do {
                try self.eventStore.save(event, span: .thisEvent)
                self.mraidLogInfo("[MRAID Native] Calendar event saved: \(event.eventIdentifier ?? "")")
            } catch {
                self.mraidLogError("[MRAID Native] Failed to save calendar event: \(error)")
            }
        }
    }

    func requestCalendarAccess(completion: @escaping (Bool) -> Void) {
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

    func timestamp(from value: Any?) -> Date? {
        if let doubleValue = value as? Double {
            return Date(timeIntervalSince1970: doubleValue / 1000)
        } else if let intValue = value as? Int {
            return Date(timeIntervalSince1970: Double(intValue) / 1000)
        }
        return nil
    }

    func updateMraidState(_ newState: String) {
        guard let jsonData = try? JSONEncoder().encode(newState),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            mraidLogError("[MRAID Native] Failed to encode state for JS: \(newState)")
            return
        }
        let script = "window.mraid && window.mraid._setState && window.mraid._setState(\(jsonString))"
        DispatchQueue.main.async { [weak self] in
            self?.mraidWebView.evaluateJavaScript(script) { _, error in
                if let error {
                    self?.mraidLogError("[MRAID Native] Failed to update JS state: \(error)")
                }
            }
        }
    }

    func fireMraidError(message: String, action: String?) {
        guard
            let messageData = try? JSONEncoder().encode(message),
            let messageString = String(data: messageData, encoding: .utf8)
        else {
            mraidLogError("[MRAID Native] Failed to encode error message for JS: \(message)")
            return
        }
        let actionString: String
        if let action,
            let actionData = try? JSONEncoder().encode(action),
            let encodedAction = String(data: actionData, encoding: .utf8)
        {
            actionString = encodedAction
        } else {
            actionString = "null"
        }
        let script =
            "window.mraid && window.mraid._fireEvent && window.mraid._fireEvent('error', \(messageString), \(actionString))"
        DispatchQueue.main.async { [weak self] in
            self?.mraidWebView.evaluateJavaScript(script) { _, error in
                if let error {
                    self?.mraidLogError("[MRAID Native] Failed to fire error event: \(error)")
                }
            }
        }
    }

    func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ"
        return formatter.string(from: date)
    }

    var hasRequestedMraidJs: Bool {
        get { cachedBool(key: &NovaMraidAssociatedKeys.hasRequested) }
        set { setCachedBool(key: &NovaMraidAssociatedKeys.hasRequested, value: newValue) }
    }

    var hasInjectedMraidShim: Bool {
        get { cachedBool(key: &NovaMraidAssociatedKeys.hasInjected) }
        set { setCachedBool(key: &NovaMraidAssociatedKeys.hasInjected, value: newValue) }
    }

    var hasFinishedLoad: Bool {
        get { cachedBool(key: &NovaMraidAssociatedKeys.hasFinished) }
        set { setCachedBool(key: &NovaMraidAssociatedKeys.hasFinished, value: newValue) }
    }

    private func cachedString(key: UnsafeRawPointer, loader: () -> String) -> String {
        if let value = objc_getAssociatedObject(self, key) as? String {
            return value
        }
        let value = loader()
        objc_setAssociatedObject(self, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        return value
    }

    private func cachedBool(key: UnsafeRawPointer) -> Bool {
        (objc_getAssociatedObject(self, key) as? NSNumber)?.boolValue ?? false
    }

    private func setCachedBool(key: UnsafeRawPointer, value: Bool) {
        objc_setAssociatedObject(self, key, NSNumber(value: value), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }
}
