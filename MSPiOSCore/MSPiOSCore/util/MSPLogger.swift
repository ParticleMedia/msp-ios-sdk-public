//
//  Logger.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 3/21/25.
//
import os

public class MSPLogger {
    public static let shared = MSPLogger()
    private let BASE_TAG = "MSPMobile"
    
    //iOS Logger four levels: debug, info, error, fault
    public static let DEBUG = 3
    public static let INFO = 4
    public static let ERROR = 5
    public static let FAULT = 6
    public static let NONE = Int.max
    
    private var logLevel = MSPLogger.NONE
    
    @available(iOS 14.0, *)
    private var logger: Logger {
        Logger(subsystem: "MSP", category: BASE_TAG)
    }
    
    public func setLogLevel(level: Int) {
        logLevel = level
    }
    
  
    
    public func debug(message: String) {
        debug(tag: BASE_TAG, message: message)
    }
    
    public func info(message: String) {
        info(tag: BASE_TAG, message: message)
    }
    
    public func error(message: String) {
        error(tag: BASE_TAG, message: message)
    }
    
    public func fault(message: String) {
        fault(tag: BASE_TAG, message: message)
    }
    
    public func debug(tag: String, message: String) {
        mspPrint(messagePriority: MSPLogger.DEBUG, tag: tag, message: message)
    }
    
    public func info(tag: String, message: String) {
        mspPrint(messagePriority: MSPLogger.INFO, tag: tag, message: message)
    }
    
    public func error(tag: String, message: String) {
        mspPrint(messagePriority: MSPLogger.ERROR, tag: tag, message: message)
    }
    
    public func fault(tag: String, message: String) {
        mspPrint(messagePriority: MSPLogger.FAULT, tag: tag, message: message)
    }
    
    private func mspPrint(messagePriority: Int, tag: String, message: String) {
        if (messagePriority >= logLevel) {
            if #available(iOS 14.0, *) {
                logger.log(level: getLogLevel(messagePriority: messagePriority), "\(message)")
            }
        }
    }
    
    private func getLogLevel(messagePriority: Int) -> OSLogType {
        switch messagePriority {
        case 3:
            return .debug
        case 4:
            return .info
        case 5:
            return .error
        case 6:
            return .fault
        default:
            return .debug
        }
    }
}
