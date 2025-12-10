//
//  MSPDevice.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 7/14/25.
//
import UIKit
import Network
import CoreTelephony
import AppTrackingTransparency
import AVFAudio
import MSPiOSCore
import PrebidMobile

fileprivate let cellGeneration: [String: Com_Newsbreak_Monetization_Signals_ConnectionType] = [
    CTRadioAccessTechnologyGPRS:            Com_Newsbreak_Monetization_Signals_ConnectionType.cell2G,
    CTRadioAccessTechnologyEdge:            Com_Newsbreak_Monetization_Signals_ConnectionType.cell2G,
    CTRadioAccessTechnologyCDMA1x:          Com_Newsbreak_Monetization_Signals_ConnectionType.cell2G,
    
    CTRadioAccessTechnologyWCDMA:           Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    CTRadioAccessTechnologyHSDPA:           Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    CTRadioAccessTechnologyHSUPA:           Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    CTRadioAccessTechnologyCDMAEVDORev0:    Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    CTRadioAccessTechnologyCDMAEVDORevA:    Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    CTRadioAccessTechnologyCDMAEVDORevB:    Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    CTRadioAccessTechnologyeHRPD:           Com_Newsbreak_Monetization_Signals_ConnectionType.cell3G,
    
    CTRadioAccessTechnologyLTE:             Com_Newsbreak_Monetization_Signals_ConnectionType.cell4G,
]


public class MSPDevice {
    
    public static let shared = MSPDevice()
    
    public init() {
        
    }
    
    private(set) var orientation: UIDeviceOrientation?
    private(set) var batteryLevel: Float?
    private(set) var batteryStatus: UIDevice.BatteryState?
    private(set) var isLowPowerMode: Bool?
    private(set) var isLowDataMode: Bool?
    private(set) var availableMemory: Int?
    
    var isInForeground: Bool?
    var fontSize: UIContentSizeCategory?
    
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
        UIDevice.current.isBatteryMonitoringEnabled = true
        self.batteryLevel = UIDevice.current.batteryLevel
        self.batteryStatus = UIDevice.current.batteryState
        self.isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        fetchLowDataModeStatus { path in
            self.isLowDataMode = path.isConstrained
        }

        self.availableMemory = os_proc_available_memory()
    }
    
    private func getCellGeneration() -> Com_Newsbreak_Monetization_Signals_ConnectionType {
        let tel = CTTelephonyNetworkInfo()
        
        if let techs = tel.serviceCurrentRadioAccessTechnology?.values,
        let rat = techs.first {
            if #available(iOS 14.1, *),
               rat == CTRadioAccessTechnologyNRNSA || rat == CTRadioAccessTechnologyNR {
                return Com_Newsbreak_Monetization_Signals_ConnectionType.cell5G
            }
            
            return cellGeneration[rat] ?? Com_Newsbreak_Monetization_Signals_ConnectionType.cellUnknown
        }
        
        return Com_Newsbreak_Monetization_Signals_ConnectionType.cellUnknown
    }
    
    private func fetchLowDataModeStatus(completion: @escaping (NWPath) -> Void) {
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            completion(path)
            monitor.cancel()
        }
        monitor.start(queue: DispatchQueue.global(qos: .background))
    }
    
    internal func getOrientationString(orientation: UIDeviceOrientation?) -> String {
        guard let orientation = self.orientation else {return ""}
        switch orientation {
        case .unknown:
            return ""
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
            return ""
        }
    }
    
    private func getStringFromStatusInBool(state: Bool?) -> String {
        if let state = state {
            return state ? "true" : "false"
        } else {
            return ""
        }
    }
    
    private func getBatteryLevelString() -> String {
        if let batteryLevel = self.batteryLevel {
            return String(batteryLevel)
        }
        return ""
    }
    
    public func getBatteryStatusString() -> String {
        guard let batteryStatus = self.batteryStatus else { return "" }
        switch batteryStatus {
        case .unknown:
            return ""
        case .unplugged:
            return "unplugged"
        case .charging:
            return "charging"
        case .full:
            return "full"
        default:
            return ""
        }
    }
    
    public func getFontSizeString() -> String {
        guard let fontSize = self.fontSize else { return "" }
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
        default: return ""
        }
    }
    
    public func getAvailableMemoryString() -> String {
        if let availableMemory = self.availableMemory {
            return String(availableMemory)
        } else {
            return ""
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
    
    internal func getDeviceModel() -> String {
        var sysInfo = utsname()
        guard uname(&sysInfo) == 0 else {
            MSPLogger.shared.info(message: "Failed to get device model via uname")
            return ""
        }
        
        return withUnsafePointer(to: &sysInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
    
    internal func isIDFAAuthorized() -> Bool {
        if #available(iOS 14, *), case .authorized = ATTrackingManager.trackingAuthorizationStatus {
            return true
        } else {
            return false
        }
    }
    
    internal func getCountry() -> String {
        if #available(iOS 16, *) {
            return Locale.current.region?.identifier ?? ""
        }
        
        return Locale.current.regionCode ?? ""
    }
    
    internal func getConnectionType() -> Com_Newsbreak_Monetization_Signals_ConnectionType {
        switch Reachability.shared.currentReachabilityStatus {
        case .celluar:
            return getCellGeneration()
        case .wifi:
            return Com_Newsbreak_Monetization_Signals_ConnectionType.wifi
        case .unknown, .offline:
            return Com_Newsbreak_Monetization_Signals_ConnectionType.unspecified
        @unknown default:
            return Com_Newsbreak_Monetization_Signals_ConnectionType.unspecified
        }
    }
    
    internal func getVolumeLevel() -> Int32 {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setActive(true)
            let volume = audioSession.outputVolume
            return Int32(volume * 100)
        } catch {
            return -1
        }
    }
}
