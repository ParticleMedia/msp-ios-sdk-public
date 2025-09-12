//
//  MSPDevice.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 7/14/25.
//
import UIKit
import Network

public class MSPDevice {
    
    public static let shared = MSPDevice()
    
    public init() {
        
    }
    
    private(set) var orientation: UIDeviceOrientation?
    private(set) var isInForeground: Bool?
    private(set) var batteryLevel: Float?
    private(set) var batteryStatus: UIDevice.BatteryState?
    private(set) var isLowPowerMode: Bool?
    private(set) var isLowDataMode: Bool?
    private(set) var fontSize: UIContentSizeCategory?
    private(set) var availableMemory: Int?
    
    private let DEIVCE_SIGNAL_ORIENTATION = "orientation"
    private let DEIVCE_SIGNAL_IS_IN_FOREGROUND = "is_in_foreground"
    private let DEIVCE_SIGNAL_BATTERY_LEVEL = "battery_level"
    private let DEIVCE_SIGNAL_BATTERY_STATUS = "battery_status"
    private let DEIVCE_SIGNAL_IS_LOW_POWER_MODE = "is_low_power_mode"
    private let DEIVCE_SIGNAL_IS_LOW_DATA_MODE = "is_low_data_mode"
    private let DEIVCE_SIGNAL_FONT_SIZE = "font_size"
    private let DEIVCE_SIGNAL_AVAILABLE_MEMORY = "available_memory"
    private let DEVICE_SIGNAL_TIMEZONE = "timezone"
    
    public func getDeviceSignalsDictionary() -> [String:String] {
        self.collectDeviceInfo()
        var dict = [String:String]()
        dict[DEIVCE_SIGNAL_ORIENTATION] = getOrientationString(orientation: orientation)
        dict[DEIVCE_SIGNAL_IS_IN_FOREGROUND] = getStringFromStatusInBool(state: self.isInForeground)
        dict[DEIVCE_SIGNAL_BATTERY_LEVEL] = getBatteryLevelString()
        dict[DEIVCE_SIGNAL_BATTERY_STATUS] = getBatteryStatusString()
        dict[DEIVCE_SIGNAL_IS_LOW_POWER_MODE] = getStringFromStatusInBool(state: self.isLowPowerMode)
        dict[DEIVCE_SIGNAL_IS_LOW_DATA_MODE] = getStringFromStatusInBool(state: self.isLowDataMode)
        dict[DEIVCE_SIGNAL_FONT_SIZE] = getFontSizeString()
        dict[DEIVCE_SIGNAL_AVAILABLE_MEMORY] = getAvailableMemoryString()
        dict[DEVICE_SIGNAL_TIMEZONE] = getTimezoneString()
        
        return dict
    }
    
    public func collectDeviceInfo() {
        self.orientation = UIDevice.current.orientation
        self.isInForeground = UIApplication.shared.applicationState == .active
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.batteryLevel = UIDevice.current.batteryLevel
        self.batteryStatus = UIDevice.current.batteryState
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        fetchLowDataModeStatus { isLowDataMode in
            self.isLowDataMode = isLowDataMode
        }
        self.fontSize = UIApplication.shared.preferredContentSizeCategory
        self.availableMemory = os_proc_available_memory()
    }
    
    private func fetchLowDataModeStatus(completion: @escaping (Bool) -> Void) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            completion(path.isConstrained)
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    private func getOrientationString(orientation: UIDeviceOrientation?) -> String {
        guard let orientation = self.orientation else {return "unknown"}
        switch orientation {
        case .unknown:
            return "unknown"
        case .portrait:
            return "portrait"
        case .portraitUpsideDown:
            return "portraitUpsideDown"
        case .landscapeLeft:
            return "landscapeLeft"
        case .landscapeRight:
            return "landscapeRight"
        case .faceUp:
            return "faceUp"
        case .faceDown:
            return "faceDown"
        default:
            return "unknown"
        }
    }
    
    private func getStringFromStatusInBool(state: Bool?) -> String {
        if let state = state {
            return state ? "true" : "false"
        } else {
            return "unknown"
        }
    }
    
    private func getBatteryLevelString() -> String {
        if let batteryLevel = self.batteryLevel {
            return String(batteryLevel)
        }
        return "unknown"
    }
    
    public func getBatteryStatusString() -> String {
        guard let batteryStatus = self.batteryStatus else { return "unknown" }
        switch batteryStatus {
        case .unknown:
            return "unknown"
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        default:
            return "unknown"
        }
    }
    
    public func getFontSizeString() -> String {
        guard let fontSize = self.fontSize else { return "unknown" }
        switch fontSize {
        case .extraSmall: return "xs"
        case .small: return "s"
        case .medium: return "m"
        case .large: return "l"
        case .extraLarge: return "xl"
        case .extraExtraLarge: return "xxl"
        case .extraExtraExtraLarge: return "xxxl"
        case .accessibilityMedium: return "a-m"
        case .accessibilityLarge: return "a-l"
        case .accessibilityExtraLarge: return "a-xl"
        case .accessibilityExtraExtraLarge: return "a-xxl"
        case .accessibilityExtraExtraExtraLarge: return "a-xxxl"
        default: return "unknown"
        }
    }
    
    public func getAvailableMemoryString() -> String {
        if let availableMemory = self.availableMemory {
            return String(availableMemory)
        } else {
            return "unknown"
        }
    }
    
    public func getTimezoneString() -> String {
        let secondsFromGMT = TimeZone.current.secondsFromGMT()
        let hoursFromGMT = secondsFromGMT / 3600
        let hoursAbs = abs(hoursFromGMT)
        
        // Convert to hours and minutes
       let hours = secondsFromGMT / 3600
       let minutes = abs((secondsFromGMT % 3600) / 60)
       
       // Format the string with +HH:mm or -HH:mm
       return String(format: "%+03d:%02d", hours, minutes)
    }
    
}
