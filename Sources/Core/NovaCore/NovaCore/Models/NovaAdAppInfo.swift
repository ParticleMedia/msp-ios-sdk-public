//
//  NovaAdAppInfo.swift
//  NovaCore
//
//  Created by Shanyu Li on 2025/2/13.
//

import Foundation

private struct ITunesRequestResponse: Codable {
    let resultCount: Int
    let results: [ITunesResult]
}

private struct ITunesResult: Codable {
    let artworkUrl60: String?
    let artworkUrl100: String?
    let artworkUrl512: String?
    let trackName: String
    let description: String?
}

enum NovaAdAppInfoError: LocalizedError {
    case invalidUrl
    case noResult(appId: Int)

    var errorDescription: String? {
        switch self {
        case .invalidUrl:
            return "The constructed URL is invalid."
        case .noResult(let appId):
            return "No results found for the given app ID: \(appId)."
        }
    }
}

struct NovaAdAppInfo {
    static func appInfo(for appId: Int) async throws -> NovaAdAppInfo {
        guard let itunesLookupUrl = URL(string: String(format: NovaAdAppInfo.searchUrlFormat, appId)) else {
            throw NovaAdAppInfoError.invalidUrl
        }
        let (data, _) = try await URLSession.shared.data(from: itunesLookupUrl)
        let response = try JSONDecoder().decode(ITunesRequestResponse.self, from: data)
        guard response.resultCount > 0, let firstItunesResult = response.results.first else {
            throw NovaAdAppInfoError.noResult(appId: appId)
        }
        return NovaAdAppInfo(
            appIconUrl: URL(
                string: firstItunesResult.artworkUrl512 ?? firstItunesResult.artworkUrl100 ?? firstItunesResult
                    .artworkUrl60 ?? ""
            ),
            appName: firstItunesResult.trackName,
            appDescription: firstItunesResult.description
        )
    }

    let appIconUrl: URL?
    let appName: String
    let appDescription: String?
}

private extension NovaAdAppInfo {
    private static let searchUrlFormat = "https://itunes.apple.com/lookup?entity=software&id=%ld"
}
