//
//  MSPAdConfigManager.swift
//  MSPCore
//
//  Created by Huanzhi Zhang on 12/18/24.
//

import Foundation


public class MSPAdConfigManager {
    public static let shared = MSPAdConfigManager()
    
    public var adConfig: AdConfig?
    public var MSP_AD_CONFIG_KEY = "map_ad_config"
    
    public func initAdConfig() {
        if let configString = UserDefaults.standard.string(forKey: MSP_AD_CONFIG_KEY) {
            parseAdConfig(string: configString)
        }
        
        fetchAdConfigData { result in
            switch result {
            case .success(let configData):
                //if let adConfigString = configData["ad_config"] as? String {
                //    self.parseAdConfig(string: adConfigString)
                //    UserDefaults.standard.setValue(adConfigString, forKey: self.MSP_AD_CONFIG_KEY)
                //}
                
                self.parseAdConfig(string: testAdConfigString)
                UserDefaults.standard.setValue(testAdConfigString, forKey: self.MSP_AD_CONFIG_KEY)
                
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
    
    func fetchAdConfigData(completion: @escaping (Result<[String: Any], Error>) -> Void) {
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
            // Handle any errors
            if let error = error {
                completion(.failure(error)) // Pass error through completion
                return
            }
            
            // Ensure that we have data
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
                return
            }
            
            // Parse the JSON manually using JSONSerialization
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
                   let adConfigJson = json["ad_config_settings"] as? [String: Any] {
                    completion(.success(adConfigJson))
                } else {
                    let parsingError = NSError(domain: "Invalid JSON format", code: -2, userInfo: nil)
                    completion(.failure(parsingError))
                }
            } catch {
                completion(.failure(error))
            }
        }
        
        // Start the task
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
    
    enum CodingKeys: String, CodingKey {
        case name
        case bidderPlacementId = "bidder_placement_id"
        case bidderFormat = "bidder_format"
    }
}


let testAdConfigString = """
{"orgId":1061,"appId":1,"bundle":"com.demo.msp","placements":[{"placement_id":"demo-ios-article-top","auction_timeout":8000,"bidders":[{"name":"msp","bidder_placement_id":"demo-ios-article-top"}]},{"placement_id":"demo-ios-foryou-large","auction_timeout":8000,"bidders":[{"name":"msp","bidder_placement_id":"demo-ios-foryou-large"}]},{"placement_id":"demo-ios-launch-fullscreen","auction_timeout":8000,"bidders":[{"name":"msp","bidder_placement_id":"demo-ios-launch-fullscreen"}]},{"placement_id":"demo-ios-article-top-unity","auction_timeout":8000,"bidders":[{"name":"unity","bidder_placement_id":"iep3rxsyp9na3rw8"}]},{"placement_id":"demo-ios-article-top-client-bidding","auction_timeout":8000,"bidders":[{"name":"unity","bidder_placement_id":"iep3rxsyp9na3rw8"},{"name":"msp","bidder_placement_id":"demo-ios-article-top"}]}]}
"""
