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
                if let adConfigString = configData["ad_config"] as? String {
                    self.parseAdConfig(string: adConfigString)
                    UserDefaults.standard.setValue(adConfigString, forKey: self.MSP_AD_CONFIG_KEY)
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
            
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data else {
                completion(.failure(NSError(domain: "No data", code: -1, userInfo: nil)))
                return
            }
            
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


public let testAdConfigString = """
{
  "orgId": 1061,
  "appId": 1,
  "bundle": "com.demo.msp",
  "placements": [
    {
      "placement_id": "demo-ios-article-top",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "msp",
          "bidder_placement_id": "demo-ios-article-top"
        }
      ]
    },
    {
      "placement_id": "demo-ios-foryou-large",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "msp",
          "bidder_placement_id": "demo-ios-foryou-large"
        }
      ]
    },
    {
      "placement_id": "demo-ios-launch-fullscreen",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "msp",
          "bidder_placement_id": "demo-ios-launch-fullscreen"
        }
      ]
    },
    {
      "placement_id": "demo-ios-article-top-unity",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "unity",
          "bidder_format": "banner",
          "bidder_placement_id": "iep3rxsyp9na3rw8"
        }
      ]
    },
    {
      "placement_id": "demo-ios-foryou-large-unity",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "unity",
          "bidder_format": "native",
          "bidder_placement_id": "iep3rxsyp9na3rw8"
        }
      ]
    },
    {
      "placement_id": "demo-ios-launch-fullscreen-unity",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "unity",
          "bidder_format": "interstitial",
          "bidder_placement_id": "wmgt0712uuux8ju4"
        }
      ]
    },
    {
      "placement_id": "demo-ios-article-top-inmobi",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "inmobi",
          "bidder_format": "banner",
          "bidder_placement_id": "1672335615808"
        }
      ]
    },
    {
      "placement_id": "demo-ios-foryou-large-inmobi",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "inmobi",
          "bidder_format": "native",
          "bidder_placement_id": "1681413960173"
        }
      ]
    },
    {
      "placement_id": "demo-ios-launch-fullscreen-inmobi",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "inmobi",
          "bidder_format": "interstitial",
          "bidder_placement_id": "1672200162238"
        }
      ]
    },
    {
      "placement_id": "demo-ios-article-top-mintegral",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "mintegral",
          "bidder_format": "banner",
          "bidder_placement_id": "328859",
          "params":{"mintegralAdUnitAd":"1541917"}
        }
      ]
    },
    {
      "placement_id": "demo-ios-foryou-large-mintegral",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "mintegral",
          "bidder_format": "native",
          "bidder_placement_id": "328861",
          "params":{"mintegralAdUnitAd":"1541925"}
        }
      ]
    },
    {
      "placement_id": "demo-ios-launch-fullscreen-mintegral",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "mintegral",
          "bidder_format": "interstitial",
          "bidder_placement_id": "328874",
          "params":{"mintegralAdUnitAd":"1541950"}
        }
      ]
    },
    {
      "placement_id": "demo-ios-article-top-mobilefuse",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "mobilefuse",
          "bidder_format": "banner",
          "bidder_placement_id": "432097"
        }
      ]
    },
    {
      "placement_id": "demo-ios-foryou-large-mobilefuse",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "mobilefuse",
          "bidder_format": "native",
          "bidder_placement_id": "432097"
        }
      ]
    },
    {
      "placement_id": "demo-ios-launch-fullscreen-mobilefuse",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "mobilefuse",
          "bidder_format": "interstitial",
          "bidder_placement_id": "432102"
        }
      ]
    },
    {
      "placement_id": "demo-ios-article-top-pubmatic",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "pubmatic",
          "bidder_format": "banner",
          "bidder_placement_id": "OpenWrapBannerAdUnit",
          "params":{"pubmaticPublisherId":"156276","pubmaticProfileId":"1165"}
        }
      ]
    },
    {
      "placement_id": "demo-ios-foryou-large-pubmatic",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "pubmatic",
          "bidder_format": "native",
          "bidder_placement_id": "OpenWrapNativeAdUnit",
          "params":{"pubmaticPublisherId":"156276","pubmaticProfileId":"1165"}
        }
      ]
    },
    {
      "placement_id": "demo-ios-launch-fullscreen-pubmatic",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "pubmatic",
          "bidder_format": "interstitial",
          "bidder_placement_id": "OpenWrapInterstitialAdUnit",
          "params":{"pubmaticPublisherId":"156276","pubmaticProfileId":"1165"}
        }
      ]
    },
    {
      "placement_id": "demo-ios-article-top-client-bidding",
      "auction_timeout": 8000,
      "bidders": [
        {
          "name": "unity",
          "bidder_placement_id": "iep3rxsyp9na3rw8"
        },
        {
          "name": "msp",
          "bidder_placement_id": "demo-ios-article-top"
        }
      ]
    }
  ]
}
"""
