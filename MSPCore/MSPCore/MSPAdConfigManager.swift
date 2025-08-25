//
//  MSPAdConfigManager.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/18/24.
//

import Foundation
import MSPiOSCore


public class MSPAdConfigManager {
    public static let shared = MSPAdConfigManager()
    
    public var adConfig: AdConfig?
    public var MSP_AD_CONFIG_KEY = "map_ad_config"
    public var MSP_LOG_SAMPLE_RATE_KEY = "log_sample_rate"
    public var MSP_LOG_WHITELIST_KEY = "msp_id_whitelist"
    
    public func initAdConfig() {
        if let configString = UserDefaults.standard.string(forKey: MSP_AD_CONFIG_KEY) {
            parseAdConfig(string: configString)
            MSPLogger.shared.info(message: "ad config loaded from local file: \(configString)")
        }
        
        fetchAdConfigData { result in
            switch result {
            case .success(let configData):
                if let adConfigJson = configData["ad_config_settings"] as? [String: Any],
                   let adConfigString = adConfigJson["ad_config"] as? String {
                    self.parseAdConfig(string: adConfigString)
                    UserDefaults.standard.setValue(adConfigString, forKey: self.MSP_AD_CONFIG_KEY)
                }
                if let logConfigJson = configData["log_config"] as? [String: Any] {
                    self.parseLogConfig(data: logConfigJson)
                }
                
            case .failure(let error):
                print("Error fetching data: \(error)")
            }
        }
    }
    
    public func parseAdConfig(string: String) {
        do {
            let decoder = JSONDecoder()
            let adConfig = try decoder.decode(AdConfig.self, from: Data(string.utf8))
            self.adConfig = adConfig
            
        } catch {
            
        }
    }
    
    public func parseLogConfig(data: [String: Any]) {
        let logSampleRate = (data[MSP_LOG_SAMPLE_RATE_KEY] as? Double) ?? 0.01
        MSP.shared.updateLogSample(sampleRate: logSampleRate)
        
        if let whiteList = data[MSP_LOG_WHITELIST_KEY] as? [String] {
            MSP.shared.logWhiteList = whiteList
        }
    }
    
    func fetchAdConfigData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
        MSPLogger.shared.info(message: "Fetching ad config from remote server....")
        let urlString = "https://msp-platform.newsbreak.com/getAdConfig"
        
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: -1, userInfo: nil)))
            return
        }
        
        let requestBody: [String: Any] = [
            "app_id": MSP.shared.appId,
            "org_id": MSP.shared.orgId,
            "token": MSP.shared.prebidAPIKey
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody, options: []) else {
            print("fetch ad config failed to serialize JSON request body")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type") // Specify JSON content type
        request.httpBody = jsonData
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    
                    completion(.success(json))
                } else {
                    let parsingError = NSError(domain: "Invalid JSON format", code: -2, userInfo: nil)
                    completion(.failure(parsingError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        task.resume()
    }
}

public struct AdConfig: Codable {
    public let orgId: Int
    public let appId: Int
    public let bundle: String?
    public let placements: [Placement]?
}

public struct Placement: Codable {
    public let placementId: String
    public let auctionTimeout: Int?
    public let bidders: [BidderInfo]?
    
    public enum CodingKeys: String, CodingKey {
        case placementId = "placement_id"
        case auctionTimeout = "auction_timeout"
        case bidders
    }
}

public struct BidderInfo: Codable {
    public let name: String
    public let bidderPlacementId: String
    public let bidderFormat: String?
    public let params: [String:String]?
    
    enum CodingKeys: String, CodingKey {
        case name
        case bidderPlacementId = "bidder_placement_id"
        case bidderFormat = "bidder_format"
        case params = "params"
    }
}
