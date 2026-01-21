import Combine
import Nimble
import Quick
@testable import MSPCore
@testable import MSPiOSCore

class DebugRadioCellViewModelSpec: QuickSpec {
    override class func spec() {
        describe("DebugRadioCellViewModel") {
            var sut: DebugRadioCellViewModel!
            var option: MockDebugOption!
            var cancellables: Set<AnyCancellable>!

            beforeEach {
                option = MockDebugOption(id: "option-id", displayTitle: "Option Title")
                sut = DebugRadioCellViewModel(debugOption: option)
                cancellables = []
            }

            it("exposes the option id and title") {
                expect(sut.id).to(equal(option.id))
                expect(sut.title).to(equal(option.displayTitle))
            }

            it("updates selection state and publishes changes") {
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
