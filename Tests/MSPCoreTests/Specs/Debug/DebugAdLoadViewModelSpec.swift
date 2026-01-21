import Combine
import Nimble
import Quick
import UIKit
@testable import MSPCore
@testable import MSPiOSCore

class DebugAdLoadViewModelSpec: QuickSpec {
    override class func spec() {
        describe("DebugAdLoadViewModel") {
            var sectionsRepository: MockDebugSectionsRepository!
            var placementsRepository: MockPlacementsRepository!
            var loadAdRepository: MockLoadAdRepository!
            var cancellables: Set<AnyCancellable>!

            beforeEach {
                sectionsRepository = MockDebugSectionsRepository()
                placementsRepository = MockPlacementsRepository()
                loadAdRepository = MockLoadAdRepository()
                cancellables = []
            }

            context("initialization") {
                it("creates sections from repository data") {
                    let placements = [TestConstants.Placements.placement1]
                    let sections = TestDataFactory.createMinimalSections()
                    placementsRepository.placementsToReturn = placements
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    expect(placementsRepository.fetchCallCount).to(equal(1))
                    expect(sectionsRepository.fetchCallCount).to(equal(1))
                    expect(sectionsRepository.lastFetchedPlacements).to(equal(placements))
                    expect(sut.sections.count).to(equal(sections.count))
                    expect(sut.sections.first?.numberOfCells).to(equal(sections.first?.options.count))
                }

                it("sets default selection for sections without showCondition") {
                    let sections = TestDataFactory.createMinimalSections()
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    expect(sut.sections.first?.selectedIndex()).to(equal(0))
                }

                it("handles empty placements and sections") {
                    placementsRepository.placementsToReturn = []
                    sectionsRepository.sectionsToReturn = []

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    expect(sectionsRepository.lastFetchedPlacements).to(equal([]))
                    expect(sut.sections).to(beEmpty())
                }
            }

            context("visibility rules") {
                it("shows Nova sections when Nova + Interstitial are selected") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adNetwork,
                        optionId: AdNetwork.nova.rawValue
                    )
                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adFormat,
                        optionId: AdFormat.interstitial.id
                    )

                    let creativeTypeVisible = sectionVisible(in: sut, sectionId: DebugSectionData.SectionIds.creativeType)
                    let layoutVisible = sectionVisible(in: sut, sectionId: DebugSectionData.SectionIds.layout)

                    expect(creativeTypeVisible).to(beTrue())
                    expect(layoutVisible).to(beTrue())
                }

                it("hides Nova sections when conditions are not met") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    let nonNovaOptionId = firstOptionId(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adNetwork,
                        excluding: AdNetwork.nova.rawValue
                    )
                    if let nonNovaOptionId {
                        selectOption(
                            in: sut,
                            sectionId: DebugSectionData.SectionIds.adNetwork,
                            optionId: nonNovaOptionId
                        )
                    }
                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adFormat,
                        optionId: AdFormat.banner.id
                    )

                    let creativeTypeVisible = sectionVisible(in: sut, sectionId: DebugSectionData.SectionIds.creativeType)
                    let layoutVisible = sectionVisible(in: sut, sectionId: DebugSectionData.SectionIds.layout)

                    expect(creativeTypeVisible).to(beFalse())
                    expect(layoutVisible).to(beFalse())
                }
            }

            context("test parameter generation") {
                it("includes basic parameters for selected options") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adNetwork,
                        optionId: AdNetwork.google.rawValue
                    )

                    let params = decodeTestParams(from: sut.getTestParameters())
                    expect(params["test_ad"] as? Bool).to(beTrue())
                    expect(params["ad_network"] as? String).to(equal("msp_google"))
                }

                it("includes Nova-specific parameters when selected") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adNetwork,
                        optionId: AdNetwork.nova.rawValue
                    )
                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.adFormat,
                        optionId: AdFormat.interstitial.id
                    )
                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.creativeType,
                        optionId: NovaCreativeType.nativeImage.rawValue
                    )

                    let params = decodeTestParams(from: sut.getTestParameters())
                    expect(params["creative_type"] as? String).to(equal("image"))
                }
            }

            context("ad callbacks") {
                it("emits ad presentation signal on successful load") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.placement,
                        optionId: TestConstants.Placements.placement1
                    )

                    var receivedSignal: DebugAdPresentationSignal?
                    sut.adPresentationPublisher
                        .sink { signal in
                            receivedSignal = signal
                        }
                        .store(in: &cancellables)

                    loadAdRepository.mockAd = BannerAd(
                        adView: UIView(),
                        adNetworkAdapter: MockAdNetworkAdapter()
                    )
                    loadAdRepository.shouldSucceed = true

                    sut.loadAd()

                    expect(receivedSignal).toEventuallyNot(beNil())
                }

                it("emits toast signal on load error") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.placement,
                        optionId: TestConstants.Placements.placement1
                    )

                    var lastMessage: String?
                    sut.toastSignalPublisher
                        .sink { signal in
                            lastMessage = signal.message
                        }
                        .store(in: &cancellables)

                    loadAdRepository.shouldSucceed = false
                    loadAdRepository.errorMessage = TestConstants.Messages.errorMessage

                    sut.loadAd()

                    expect(lastMessage).toEventually(equal(TestConstants.Messages.errorMessage))
                }

                it("does not clear the ad reference on dismissal") {
                    let sections = TestDataFactory.createProductionLikeSections(placements: [TestConstants.Placements.placement1])
                    placementsRepository.placementsToReturn = [TestConstants.Placements.placement1]
                    sectionsRepository.sectionsToReturn = sections

                    let sut = DebugAdLoadViewModel(
                        debugSectionsRepository: sectionsRepository,
                        placementsRepository: placementsRepository,
                        loadAdRepository: loadAdRepository
                    )

                    let interstitialAd = InterstitialAd(adNetworkAdapter: MockAdNetworkAdapter())
                    loadAdRepository.mockAd = interstitialAd
                    loadAdRepository.shouldSucceed = true

                    selectOption(
                        in: sut,
                        sectionId: DebugSectionData.SectionIds.placement,
                        optionId: TestConstants.Placements.placement1
                    )

                    sut.loadAd()
                    expect(sut.ad).toNot(beNil())

                    sut.onAdDismissed(ad: interstitialAd)
                    expect(sut.ad).toNot(beNil())
                }
            }
        }
    }
}

private func sectionVisible(in viewModel: DebugAdLoadViewModel, sectionId: String) -> Bool? {
    return viewModel.sections.first(where: { $0.id == sectionId })?.visible
}

private func selectOption(in viewModel: DebugAdLoadViewModel, sectionId: String, optionId: String) {
    guard let sectionIndex = viewModel.sections.firstIndex(where: { $0.id == sectionId }) else { return }
    let section = viewModel.sections[sectionIndex]
    guard let optionIndex = section.cellViewModels.firstIndex(where: { $0.id == optionId }) else { return }
    viewModel.selectOption(section: sectionIndex, row: optionIndex)
}

private func firstOptionId(in viewModel: DebugAdLoadViewModel, sectionId: String, excluding excludedId: String) -> String? {
    guard let section = viewModel.sections.first(where: { $0.id == sectionId }) else { return nil }
    return section.cellViewModels.first(where: { $0.id != excludedId })?.id
}

private func decodeTestParams(from params: [String: String]) -> [String: Any] {
    guard let jsonString = params["test"],
          let data = jsonString.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data, options: []),
          let dict = object as? [String: Any] else {
        return [:]
    }
    return dict
}

private class MockAdNetworkAdapter: AdNetworkAdapter {
    func loadAdCreative(
        bidResponse: Any,
        auctionBidListener: AuctionBidListener,
        adListener: AdListener,
        context: Any,
        adRequest: AdRequest,
        bidderPlacementId: String,
        bidderFormat: AdFormat?,
        params: [String: String]?
    ) { }

    func initialize(
        initParams: InitializationParameters,
        adapterInitListener: AdapterInitListener,
        context: Any?
    ) { }

    func destroyAd() { }

    func prepareViewForInteraction(nativeAd: NativeAd, nativeAdView: Any) { }

    func setAdMetricReporter(adMetricReporter: AdMetricReporter) { }

    func getAdNetwork() -> AdNetwork { .unknown }

    func sendHideAdEvent(reason: String, adScreenShot: Data?, fullScreenShot: Data?) { }

    func sendReportAdEvent(reason: String, description: String?, adScreenShot: Data?, fullScreenShot: Data?) { }

    func getSDKVersion() -> String { "0.0.0" }
}
