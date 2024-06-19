public final class NovaDedupeManager {
    public static let shared = NovaDedupeManager()

    // MARK: - Proeprties

    private var unimpressedAds: [NovaBaseAd] = []
    private var serialQueue = DispatchQueue(label: "com.newsbreak.nova.dedupe")
}

// MARK: - Public methods

public extension NovaDedupeManager {
    func novaAdDidFill(_ novaAd: NovaBaseAd) {
        serialQueue.sync {
            unimpressedAds.append(novaAd)
        }
    }

    func novaAdDidShow(_ novaAd: NovaBaseAd) {
        serialQueue.sync {
            unimpressedAds = unimpressedAds.filter { $0.adUnitId != novaAd.adUnitId }
        }
    }

    func getServerDedupeKeys(first k: Int, prioritizedBy adUnitId: String) -> [String] {
        var sortedUnimpressedAds: [NovaBaseAd] = []
        serialQueue.sync {
            let unimpressedAdsForAdUnitId = unimpressedAds.filter { $0.adUnitId == adUnitId }
            let otherUnimpressedAds = unimpressedAds.filter { $0.adUnitId != adUnitId }
            sortedUnimpressedAds = unimpressedAdsForAdUnitId + otherUnimpressedAds
        }
        let firstKUnimpressedAds = Array(sortedUnimpressedAds.prefix(k))
        return firstKUnimpressedAds.compactMap { "\($0.adUnitId),\($0.adId),\($0.adSetId)" }
    }
}
