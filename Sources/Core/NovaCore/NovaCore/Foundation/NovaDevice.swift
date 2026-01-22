//
//  NovaDevice.swift
//  NovaCore
//
//  Created by Huanzhi Zhang on 1/6/26.
//
import UIKit

public class NovaDevice {
    public static let shared = NovaDevice()

    public var appStoreId: String?

    public var make = "Apple"

    internal func getDeviceModel() -> String {
        var sysInfo = utsname()
        guard uname(&sysInfo) == 0 else {
            return ""
        }

        return withUnsafePointer(to: &sysInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(cString: $0)
            }
        }
    }
}
