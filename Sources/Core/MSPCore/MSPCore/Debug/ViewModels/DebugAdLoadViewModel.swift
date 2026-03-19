// Import SectionTitles from DebugSectionData
import Combine
import Foundation
import MSPiOSCore
import UIKit

private typealias SectionTitles = DebugSectionData.SectionTitles
private typealias SectionIds = DebugSectionData.SectionIds

private enum Strings {
    // Toast messages
    static let failedToGeneratePlacementId = "Failed to generate placement ID"
    static let loading = "Loading..."
    static let noAdFoundForPlacementId = "No ad found for placementId"
    static let adLoadedSuccessfully = "Ad loaded successfully"
    // Debug log prefixes
    static let adError = "[DebugAdLoadViewModel] Ad error: "
    static let noAdFound = "[DebugAdLoadViewModel] No ad found for placementId: "
    static let adLoaded = "[DebugAdLoadViewModel] Ad loaded for placementId: "
    static let adPrice = "[DebugAdLoadViewModel] Ad price: "
    static let adNetwork = "[DebugAdLoadViewModel] Ad network: "
    static let adUnitId = "[DebugAdLoadViewModel] Ad unit id: "
    static let creativeId = "[DebugAdLoadViewModel] Creative id: "
    static let interstitialDismissed = "[DebugAdLoadViewModel] Interstitial ad dismissed: "
    static let rewardReceived = "[DebugAdLoadViewModel] Reward received: "
    static let loadRequested = "[DebugAdLoadViewModel] Load requested: "
    static let selectedOptions = "[DebugAdLoadViewModel] Selected options: "
    static let scopedMode = "[DebugAdLoadViewModel] Scoped network mode: "
    static let notifyLoss = "[DebugAdLoadViewModel] notifyLoss: "
    static let adImpression = "[DebugAdLoadViewModel] Ad impression: "
    static let adClick = "[DebugAdLoadViewModel] Ad click: "
    static let rewardToast = "✓ Reward received"
}

struct ToastSignal {
    let message: String
    let style: DebugToastStyle
    let duration: TimeInterval?
}

enum DebugAdPresentationSignal {
    case native(nativeAd: NativeAd)
    case banner(bannerAd: BannerAd)
    case interstitial(interstitialAd: InterstitialAd)
    case rewarded(rewardedAd: RewardedAd)
}

class DebugAdLoadViewModel: AdListener {
    @Published private(set) var sections: [DebugAdLoadSectionViewModel] = []
    private let originalSectionData: [DebugSection]
    let placements: [String]
    private(set) var isPlacementSectionVisible = true  // Toggle state for placement section
    var visibleSectionsPublisher: AnyPublisher<[DebugAdLoadSectionViewModel], Never> {
        $sections.map { $0.filter { $0.visible } }.eraseToAnyPublisher()
    }

    private let debugSectionsRepository: DebugSectionsRepository
    private let placementsRepository: PlacementsRepository
    private let auctionLoadAdRepository: LoadAdRepository
    private let scopedLoadAdRepository: LoadAdRepository
    private(set) var ad: MSPAd?
    private weak var debugAdLoadViewController: DebugAdLoadViewController?
    private var rewardReceivedBeforeDismiss = false

    // Toast signal publisher
    private let toastSignalSubject = PassthroughSubject<ToastSignal, Never>()
    var toastSignalPublisher: AnyPublisher<ToastSignal, Never> {
        toastSignalSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }
    // Ad presentation signal publisher
    private let adPresentationSubject = PassthroughSubject<DebugAdPresentationSignal, Never>()
    var adPresentationPublisher: AnyPublisher<DebugAdPresentationSignal, Never> {
        adPresentationSubject.receive(on: DispatchQueue.main).eraseToAnyPublisher()
    }

    init(
        debugSectionsRepository: DebugSectionsRepository = TestDebugSectionsService(),
        placementsRepository: PlacementsRepository = AdConfigPlacementsService(),
        auctionLoadAdRepository: LoadAdRepository = TestLoadAdService(),
        scopedLoadAdRepository: LoadAdRepository = ScopedNetworkLoadAdService()
    ) {
        self.debugSectionsRepository = debugSectionsRepository
        self.placementsRepository = placementsRepository
        self.placements = placementsRepository.fetchPlacementIDs()
        self.originalSectionData = debugSectionsRepository.fetchDebugSections(placements: self.placements)
        self.auctionLoadAdRepository = auctionLoadAdRepository
        self.scopedLoadAdRepository = scopedLoadAdRepository
        self.sections = createSectionViewModels()
        setDefaultSelections()
        updateSectionVisibility()
    }

    private func createSectionViewModels() -> [DebugAdLoadSectionViewModel] {
        originalSectionData.enumerated().map { index, data in
            let sectionViewModel = DebugAdLoadSectionViewModel(from: data)

            // Set initial visibility based on showCondition
            sectionViewModel.visible = shouldShowSection(data)

            return sectionViewModel
        }
    }

    private func shouldShowSection(_ section: DebugSection) -> Bool {
        guard let showCondition = section.showCondition else {
            // If showCondition is nil, section is always visible
            return true
        }

        // Check if all required option IDs are in the current selection
        let selectedOptionIds = getSelectedOptionIds()
        return showCondition.isSubset(of: selectedOptionIds)
    }

    private func getSelectedOptionIds() -> Set<String> {
        var selectedIds: Set<String> = []

        for section in sections {
            if let selectedCell = section.selectedCell() {
                selectedIds.insert(selectedCell.id)
            }
        }

        return selectedIds
    }

    private func setDefaultSelections() {
        // Set default selections based on showCondition requirements
        for (index, section) in sections.enumerated() where index < originalSectionData.count {
            let sectionData = originalSectionData[index]

            // Skip default selection for placement section
            guard sectionData.id != SectionIds.placement else {
                continue
            }

            // If this section has a showCondition, set the first available option as default
            if let showCondition = sectionData.showCondition {
                for requiredId in showCondition {
                    for i in 0..<section.numberOfCells {
                        if let cell = section.cellViewModel(at: i), cell.id == requiredId {
                            section.selectCell(at: i)
                            break
                        }
                    }
                }
            } else {
                // For sections without showCondition, set the first option as default
                if section.numberOfCells > 0 {
                    section.selectCell(at: 0)
                }
            }
        }
    }

    func selectOption(section: Int, row: Int) {
        let sectionVM = sections[section]
        sectionVM.selectCell(at: row)
        updateSectionVisibility()
        // Trigger Combine update
        sections = sections
    }

    private func updateSectionVisibility() {
        updateDynamicSectionOptions()

        // Update visibility for all sections based on their showCondition
        for (index, section) in sections.enumerated() where index < originalSectionData.count {
            let sectionData = originalSectionData[index]
            if sectionData.id == SectionIds.placement {
                section.visible = true
                continue
            }

            section.visible = shouldShowSection(sectionData)
        }
    }

    private func updateDynamicSectionOptions() {
        let loadMode = currentLoadMode()
        updateAdNetworkOptions(for: loadMode)
        updateAdFormatOptions(for: loadMode)
    }

    private func updateAdNetworkOptions(for loadMode: DebugLoadMode) {
        guard let section = sectionViewModel(for: SectionIds.adNetwork) else {
            return
        }

        let options: [DebugOption]
        switch loadMode {
        case .mspAuction:
            var allOptions: [DebugOption] = [DebugAllNetworksOption()]
            allOptions.append(contentsOf: AdNetwork.allCases.filter { $0.isVisible })
            options = allOptions
        case .scopedNetwork:
            options = AdNetwork.allCases.filter { $0.isVisible && $0.supportsDebugScopedC2S }
        }

        section.replaceOptions(options)
    }

    private func updateAdFormatOptions(for loadMode: DebugLoadMode) {
        guard let section = sectionViewModel(for: SectionIds.adFormat) else {
            return
        }

        let options: [DebugOption]
        switch loadMode {
        case .mspAuction:
            options = AdFormat.allCases.filter { $0.isVisible }
        case .scopedNetwork:
            options = AdFormat.allCases.filter { $0.isVisible && $0.supportsDebugScopedC2S }
        }

        section.replaceOptions(options)
    }

    private func currentLoadMode() -> DebugLoadMode {
        sectionViewModel(for: SectionIds.mode)?
            .selectedCell()?
            .debugOption as? DebugLoadMode ?? .mspAuction
    }

    private func sectionViewModel(for sectionId: String) -> DebugAdLoadSectionViewModel? {
        sections.first(where: { $0.id == sectionId })
    }

    // Get test parameters from selected options
    func getTestParameters() -> [String: String] {
        var testParamsDict: [String: Any] = [:]
        for (index, section) in sections.enumerated() {
            if let selectedCell = section.selectedCell(),
                index < originalSectionData.count
            {
                let originalOptions = originalSectionData[index].options
                if let selectedOption = originalOptions.first(where: { $0.id == selectedCell.id }) {
                    if let testParamOption = selectedOption as? TestParamPresentable {
                        for (key, value) in testParamOption.keyValuePairs {
                            // Try to convert "true"/"false" to Bool, otherwise keep as String
                            if value == "true" {
                                testParamsDict[key] = true
                            } else if value == "false" {
                                testParamsDict[key] = false
                            } else {
                                testParamsDict[key] = value
                            }
                        }
                    }
                }
            }
        }
        testParamsDict["test_ad"] = true
        guard let jsonData = try? JSONSerialization.data(withJSONObject: testParamsDict, options: []),
            let jsonString = String(data: jsonData, encoding: .utf8)
        else {
            return [:]
        }
        return ["test": jsonString]
    }

    func getSelectedOptions() -> [String: DebugOption] {
        var selectedOptions: [String: DebugOption] = [:]

        for section in sections {
            if let selectedCell = section.selectedCell() {
                selectedOptions[section.title] = selectedCell.debugOption
            }
        }

        return selectedOptions
    }

    /// Loads an ad using the current selections
    func loadAd() {
        // Get selected placement option
        let selectedOptions = getSelectedOptions()
        let loadMode = selectedOptions.values.compactMap { $0 as? DebugLoadMode }.first ?? .mspAuction
        let placementOption = selectedOptions.values.compactMap { $0 as? PlacementOption }.first
        let selectedNetwork = selectedOptions.values.compactMap { $0 as? AdNetwork }.first

        let adFormat = selectedOptions.values.compactMap { $0 as? AdFormat }.first ?? .banner
        let testParams = getTestParameters()
        let selectedOptionSummary = selectedOptions.map { key, value in
            "\(key)=\(value.id)"
        }.sorted().joined(separator: ", ")
        let resolvedPlacementId: String
        let loadRepository: LoadAdRepository
        var customParams: [String: Any]?

        switch loadMode {
        case .mspAuction:
            guard let placementOption else {
                toastSignalSubject.send(
                    ToastSignal(message: "You must choose a placement", style: .error, duration: nil))
                return
            }
            resolvedPlacementId = placementOption.placementId
            loadRepository = auctionLoadAdRepository
        case .scopedNetwork:
            if adFormat == .rewarded {
                guard let placementOption else {
                    toastSignalSubject.send(
                        ToastSignal(message: "Rewarded is S2S only. Choose a rewarded placement.", style: .error, duration: nil))
                    return
                }
                resolvedPlacementId = placementOption.placementId
                loadRepository = auctionLoadAdRepository
                MSPLogger.shared.info(
                    message:
                        Strings.scopedMode
                        + "rewarded is S2S only. placementId=\(resolvedPlacementId), selectedNetwork=\(selectedNetwork?.rawValue ?? "nil")")
                break
            }
            guard let selectedNetwork else {
                toastSignalSubject.send(
                    ToastSignal(message: "Scoped Network mode requires a network", style: .error, duration: nil))
                return
            }
            resolvedPlacementId = "__scoped__\(selectedNetwork.rawValue)__\(adFormat.id)"
            loadRepository = scopedLoadAdRepository
            customParams = ["debug_selected_network": selectedNetwork.rawValue]
            MSPLogger.shared.info(
                message:
                    Strings.scopedMode
                    + "network=\(selectedNetwork.rawValue), adFormat=\(adFormat), placeholderPlacementId=\(resolvedPlacementId)")
        }

        MSPLogger.shared.info(
            message:
                Strings.loadRequested
                + "placementId=\(resolvedPlacementId), adFormat=\(adFormat), mode=\(loadMode.id), testParams=\(testParams)")
        MSPLogger.shared.info(
            message:
                Strings.selectedOptions
                + "placementId=\(resolvedPlacementId), options=[\(selectedOptionSummary)]")
        toastSignalSubject.send(ToastSignal(message: Strings.loading, style: .loading, duration: nil))
        loadRepository.loadAd(
            placementId: resolvedPlacementId,
            adFormat: adFormat,
            testParams: testParams,
            adListener: self,
            customParams: buildCustomParams()
        )
        rewardReceivedBeforeDismiss = false
    }

    /// Builds custom params from visible toggle items in the Custom Params section.
    /// Returns nil when the section is not visible (non-Nova network), preserving service defaults.
    private func buildCustomParams() -> [String: Any]? {
        guard let customParamsSection = sections.first(where: { $0.id == SectionIds.customParams }),
            customParamsSection.visible
        else {
            return nil
        }
        var params: [String: Any] = [:]
        for toggleVM in customParamsSection.toggleCellViewModels where toggleVM.id == MSPConstants.USE_NOVA_SANDBOX {
            params[MSPConstants.USE_NOVA_SANDBOX] = toggleVM.isOn ? "true" : "false"
        }
        return params
    }

    // MARK: - AdListener
    func onError(msg: String, loadInfo: [String: Any]) {
        MSPLogger.shared.error(message: Strings.adError + "\(msg), loadInfo=\(loadInfo)")
        tryNotifyLoss(loadInfo: loadInfo, loadSuccess: false, ad: nil)
        toastSignalSubject.send(ToastSignal(message: msg, style: .error, duration: nil))
    }
    func onAdImpression(ad: MSPAd) {
        MSPLogger.shared.info(message: Strings.adImpression + "\(ad)")
    }
    func onAdClick(ad: MSPAd) {
        MSPLogger.shared.info(message: Strings.adClick + "\(ad)")
    }
    func onAdLoaded(placementId: String, loadInfo: [String: Any]) {
        guard let ad = getLoadedAd(placementId: placementId) else {
            MSPLogger.shared.error(message: Strings.noAdFound + placementId)
            toastSignalSubject.send(ToastSignal(message: Strings.noAdFoundForPlacementId, style: .error, duration: nil))
            return
        }
        self.ad = ad
        tryNotifyLoss(loadInfo: loadInfo, loadSuccess: true, ad: ad)
        MSPLogger.shared.info(message: Strings.adLoaded + "\(placementId), loadInfo=\(loadInfo)")
        toastSignalSubject.send(ToastSignal(message: Strings.adLoadedSuccessfully, style: .success, duration: 2.0))
        if let price = ad.adInfo[MSPConstants.AD_INFO_PRICE] as? Double {
            MSPLogger.shared.info(message: Strings.adPrice + "\(price)")
        }
        if let adNetworkName = ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String {
            MSPLogger.shared.info(message: Strings.adNetwork + adNetworkName)
        }
        if let adUnitId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] {
            MSPLogger.shared.info(message: Strings.adUnitId + "\(adUnitId)")
        }
        if let creativeId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] {
            MSPLogger.shared.info(message: Strings.creativeId + "\(creativeId)")
        }
        if let nativeAd = ad as? NativeAd {
            adPresentationSubject.send(.native(nativeAd: nativeAd))
        } else if let bannerAd = ad as? BannerAd {
            adPresentationSubject.send(.banner(bannerAd: bannerAd))
        } else if let rewardedAd = ad as? RewardedAd {
            adPresentationSubject.send(.rewarded(rewardedAd: rewardedAd))
        } else if let interstitialAd = ad as? InterstitialAd {
            adPresentationSubject.send(.interstitial(interstitialAd: interstitialAd))
        }
    }
    func onAdDismissed(ad: MSPAd) {
        MSPLogger.shared.info(
            message: Strings.interstitialDismissed + "\(ad), rewardReceivedBeforeDismiss=\(rewardReceivedBeforeDismiss)")
        let message = rewardReceivedBeforeDismiss ? "Ad closed: reward before dismiss" : "Ad closed: reward missing"
        toastSignalSubject.send(ToastSignal(message: message, style: .success, duration: 2.0))
    }
    func onAdRewardReceived(ad: MSPAd) {
        rewardReceivedBeforeDismiss = true
        MSPLogger.shared.info(message: Strings.rewardReceived + "\(ad)")
        toastSignalSubject.send(ToastSignal(message: Strings.rewardToast, style: .success, duration: 2.0))
    }
    func getRootViewController() -> UIViewController? {
        debugAdLoadViewController
    }

    func setViewController(_ viewController: DebugAdLoadViewController) {
        self.debugAdLoadViewController = viewController
    }

    // Toggle placement section visibility
    func togglePlacementSection() {
        isPlacementSectionVisible.toggle()
        // Update the section's visible cells without affecting section visibility
        sections = sections  // Trigger Combine update
    }

    /// `MSP.shared.notifyLoss` should only called
    /// when msp ad failed in bid with other bidder.
    /// This method is only for test purpose.
    private func tryNotifyLoss(loadInfo: [String: Any], loadSuccess: Bool, ad: MSPAd?) {
        let requestId = loadInfo["request_id"] as? String
        let statusString = loadSuccess ? "succeeded" : "failed"
        MSPLogger.shared.info(
            message: Strings.notifyLoss + "ad load \(statusString), requestId=\(requestId ?? "no valid requestId")")
        MSP.shared.notifyLoss(
            winnerBidderName: "demo_app_test", winnerPrice: 0.1, ad: ad, requestId: ad != nil ? nil : requestId)
    }

    private func getLoadedAd(placementId: String) -> MSPAd? {
        if let ad = scopedLoadAdRepository.getAd(placementId: placementId) {
            return ad
        }
        return auctionLoadAdRepository.getAd(placementId: placementId)
    }
}
