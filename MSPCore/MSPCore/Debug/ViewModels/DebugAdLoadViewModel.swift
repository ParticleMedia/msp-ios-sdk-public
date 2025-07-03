import Foundation
import Combine
import MSPiOSCore
import UIKit

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
    static let adImpression = "[DebugAdLoadViewModel] Ad impression: "
    static let adClick = "[DebugAdLoadViewModel] Ad click: "
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
}

class DebugAdLoadViewModel: AdListener {
    @Published private(set) var sections: [DebugAdLoadSectionViewModel] = []
    private let originalSectionData: [DebugSection]
    let placements: [String]
    var visibleSectionsPublisher: AnyPublisher<[DebugAdLoadSectionViewModel], Never> {
        $sections.map { $0.filter { $0.visible } }.eraseToAnyPublisher()
    }
    
    private let debugSectionsRepository: DebugSectionsRepository
    private let placementsRepository: PlacementsRepository
    private let loadAdRepository: LoadAdRepository
    private(set) var ad: MSPAd?
    private weak var debugAdLoadViewController: DebugAdLoadViewController?
    
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
        placementsRepository: PlacementsRepository = TestPlacementsService(),
        loadAdRepository: LoadAdRepository = TestLoadAdService()
    ) {
        self.debugSectionsRepository = debugSectionsRepository
        self.placementsRepository = placementsRepository
        self.placements = placementsRepository.fetchPlacements()
        self.originalSectionData = debugSectionsRepository.fetchDebugSections(placements: self.placements)
        self.loadAdRepository = loadAdRepository
        self.sections = createSectionViewModels()
        setDefaultSelections()
        updateSectionVisibility()
    }
    
    private func createSectionViewModels() -> [DebugAdLoadSectionViewModel] {
        return originalSectionData.enumerated().map { index, data in
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
        for (index, section) in sections.enumerated() {
            if index < originalSectionData.count {
                let sectionData = originalSectionData[index]
                
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
    }
    
    func selectOption(section: Int, row: Int) {
        let sectionVM = sections[section]
        sectionVM.selectCell(at: row)
        updateSectionVisibility()
        // Trigger Combine update
        sections = sections
    }
    
    func updateSectionVisibility() {
        // Update visibility for all sections based on their showCondition
        for (index, section) in sections.enumerated() {
            if index < originalSectionData.count {
                let shouldShow = shouldShowSection(originalSectionData[index])
                section.visible = shouldShow
            }
        }
    }
    
    // Get test parameters from selected options
    func getTestParameters() -> [String: String] {
        var testParamsDict: [String: Any] = [:]
        for (index, section) in sections.enumerated() {
            if let selectedCell = section.selectedCell(),
               index < originalSectionData.count {
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
              let jsonString = String(data: jsonData, encoding: .utf8) else {
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
    
    /// Generates placement ID based on current selections
    func generatePlacementId() -> String? {
        let selectedOptions = Array(getSelectedOptions().values)
        return placementsRepository.fetchPlacements(from: selectedOptions)
    }
    
    /// Loads an ad using the current selections
    func loadAd() {
        guard let placementId = generatePlacementId() else {
            toastSignalSubject.send(ToastSignal(message: Strings.failedToGeneratePlacementId, style: .error, duration: nil))
            return
        }
        let selectedOptions = getSelectedOptions()
        let adFormat = selectedOptions.values.compactMap { $0 as? AdFormat }.first ?? .banner
        let testParams = getTestParameters()
        toastSignalSubject.send(ToastSignal(message: Strings.loading, style: .loading, duration: nil))
        loadAdRepository.loadAd(
            placementId: placementId,
            adFormat: adFormat,
            testParams: testParams,
            adListener: self,
            customParams: nil
        )
    }
    
    // MARK: - AdListener
    func onError(msg: String) {
        print(Strings.adError + msg)
        toastSignalSubject.send(ToastSignal(message: msg, style: .error, duration: nil))
    }
    func onAdImpression(ad: MSPAd) {
        print(Strings.adImpression + "\(ad)")
    }
    func onAdClick(ad: MSPAd) {
        print(Strings.adClick + "\(ad)")
    }
    func onAdLoaded(placementId: String) {
        guard let ad = loadAdRepository.getAd(placementId: placementId) else {
            print(Strings.noAdFound + placementId)
            toastSignalSubject.send(ToastSignal(message: Strings.noAdFoundForPlacementId, style: .error, duration: nil))
            return
        }
        self.ad = ad
        print(Strings.adLoaded + placementId)
        toastSignalSubject.send(ToastSignal(message: Strings.adLoadedSuccessfully, style: .success, duration: 2.0))
        if let price = ad.adInfo[MSPConstants.AD_INFO_PRICE] as? Double {
            print(Strings.adPrice + "\(price)")
        }
        if let adNetworkName = ad.adInfo[MSPConstants.AD_INFO_NETWORK_NAME] as? String {
            print(Strings.adNetwork + adNetworkName)
        }
        if let adUnitId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_AD_UNIT_ID] {
            print(Strings.adUnitId + "\(adUnitId)")
        }
        if let creativeId = ad.adInfo[MSPConstants.AD_INFO_NETWORK_CREATIVE_ID] {
            print(Strings.creativeId + "\(creativeId)")
        }
        if let nativeAd = ad as? NativeAd {
            adPresentationSubject.send(.native(nativeAd: nativeAd))
        } else if let bannerAd = ad as? BannerAd {
            adPresentationSubject.send(.banner(bannerAd: bannerAd))
        } else if let interstitialAd = ad as? InterstitialAd {
            adPresentationSubject.send(.interstitial(interstitialAd: interstitialAd))
        }
    }
    func onAdDismissed(ad: InterstitialAd) {
        print(Strings.interstitialDismissed + "\(ad)")
    }
    func getRootViewController() -> UIViewController? {
        return debugAdLoadViewController
    }
    
    func setViewController(_ viewController: DebugAdLoadViewController) {
        self.debugAdLoadViewController = viewController
    }
} 
