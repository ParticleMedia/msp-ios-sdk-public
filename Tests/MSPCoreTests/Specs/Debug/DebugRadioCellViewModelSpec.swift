import Combine
import Nimble
import Quick
@testable import MSPCore
@testable import MSPiOSCore

class DebugRadioCellViewModelSpec: QuickSpec {
    override class func spec() {
        describe("DebugRadioCellViewModel") {
            @TestState var sut: DebugRadioCellViewModel!
            @TestState var option: FakeDebugOption!
            @TestState var cancellables: Set<AnyCancellable>!

            beforeEach {
                option = FakeDebugOption(id: "option-id", displayTitle: "Option Title")
                sut = DebugRadioCellViewModel(debugOption: option)
                cancellables = []
            }

            it("[DRC001] should expose the option id and title") {
                expect(sut.id).to(equal(option.id))
                expect(sut.title).to(equal(option.displayTitle))
            }

            it("[DRC002] should update selection state and publish changes") {
                var received: [Bool] = []
                sut.isSelectedPublisher
                    .sink { value in
                        received.append(value)
                    }
                    .store(in: &cancellables)

                sut.setSelected(true)

                expect(sut.isSelected).to(beTrue())
                expect(received).toEventually(contain(true))
            }
        }
    }
}
