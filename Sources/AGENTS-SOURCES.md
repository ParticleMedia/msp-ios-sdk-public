# AI Agent Context: Swift Sources

> **Version**: 1.0
> **Last Updated**: 2026-01-20
> **Scope**: Sources/ directory (Swift code development)
> **Applies To**: All AI Agents working in Sources/

## Architecture: MVVM-Repository Pattern

We follow the **MVVM-Repository pattern** for all Swift feature development:

```
View → ViewModel → Repository → DataSource/Service
```

### Layer Responsibilities

#### View Layer
- **Responsibility**: UI rendering only, no business logic
- **Technology**: UIKit or SwiftUI
- **Rules**:
  - Observe ViewModel state changes
  - Send user actions to ViewModel
  - Never access Repository or DataSource directly
  - No network calls, no business logic

#### ViewModel Layer
- **Responsibility**: Presentation logic, state management, input/output transformation
- **Technology**: Pure Swift classes (no UIKit dependencies)
- **Rules**:
  - Expose observable properties for View binding
  - Transform business models to view models
  - Coordinate Repository operations
  - Handle user input validation
  - **Unit Test Friendly**: No UIKit means fully testable

**Example**:
```swift
class AdBiddingViewModel {
    private let repository: AdBiddingRepositoryProtocol

    @Published var bidStatus: BidStatus = .idle
    @Published var errorMessage: String?

    func requestAd() {
        repository.fetchBid { [weak self] result in
            switch result {
            case .success(let bid):
                self?.bidStatus = .success(bid)
            case .failure(let error):
                self?.errorMessage = error.localizedDescription
            }
        }
    }
}
```

#### Repository Layer
- **Responsibility**: Data access abstraction, coordinates multiple data sources
- **Technology**: Protocol-based design
- **Rules**:
  - Define protocol for dependency injection
  - Coordinate network, cache, and database sources
  - Transform DataSource models to domain models
  - No UI dependencies, no UIKit imports
  - **Easy to Mock**: Protocol-based for testing

**Example**:
```swift
protocol AdBiddingRepositoryProtocol {
    func fetchBid(completion: @escaping (Result<Bid, Error>) -> Void)
}

class AdBiddingRepository: AdBiddingRepositoryProtocol {
    private let networkService: NetworkServiceProtocol
    private let cacheService: CacheServiceProtocol

    func fetchBid(completion: @escaping (Result<Bid, Error>) -> Void) {
        // Check cache first
        if let cachedBid = cacheService.getBid() {
            completion(.success(cachedBid))
            return
        }

        // Fetch from network
        networkService.requestBid { result in
            if case .success(let bid) = result {
                self.cacheService.saveBid(bid)
            }
            completion(result)
        }
    }
}
```

#### DataSource/Service Layer
- **Responsibility**: Concrete implementations (network, cache, database)
- **Technology**: URLSession, CoreData, UserDefaults, etc.
- **Rules**:
  - Implement specific data source protocols
  - Handle low-level details (HTTP, serialization, SQL)
  - Return raw data or errors
  - No business logic

### Testing Strategy

#### ViewModel Tests
- **What to test**: Business logic, state transitions, input validation
- **How to test**: Mock repositories, verify output transformations
- **Example**:
```swift
class AdBiddingViewModelTests: QuickSpec {
    override class func spec() {
        describe("AdBiddingViewModel") {
            var sut: AdBiddingViewModel!
            var mockRepository: MockAdBiddingRepository!

            beforeEach {
                mockRepository = MockAdBiddingRepository()
                sut = AdBiddingViewModel(repository: mockRepository)
            }

            it("should update bidStatus to success when fetch succeeds") {
                // Given
                let expectedBid = Bid(id: "123", price: 1.5)
                mockRepository.result = .success(expectedBid)

                // When
                sut.requestAd()

                // Then
                expect(sut.bidStatus).toEventually(equal(.success(expectedBid)))
            }
        }
    }
}
```

#### Repository Tests
- **What to test**: Data source coordination, caching logic, error handling
- **How to test**: Mock data sources, verify calls and transformations
- **Example**:
```swift
class AdBiddingRepositoryTests: QuickSpec {
    override class func spec() {
        describe("AdBiddingRepository") {
            var sut: AdBiddingRepository!
            var mockNetwork: MockNetworkService!
            var mockCache: MockCacheService!

            beforeEach {
                mockNetwork = MockNetworkService()
                mockCache = MockCacheService()
                sut = AdBiddingRepository(
                    networkService: mockNetwork,
                    cacheService: mockCache
                )
            }

            it("should return cached bid if available") {
                // Given
                let cachedBid = Bid(id: "cached", price: 2.0)
                mockCache.storedBid = cachedBid

                // When
                var result: Bid?
                sut.fetchBid { res in
                    result = try? res.get()
                }

                // Then
                expect(result).toEventually(equal(cachedBid))
                expect(mockNetwork.requestCount).to(equal(0))
            }
        }
    }
}
```

#### Integration Tests
- **What to test**: End-to-end flows with real components
- **How to test**: Real View + ViewModel + Repository, mock only external services
- **Example**: User taps "Load Ad" → ViewModel requests → Repository fetches → View updates

### API Design Principles

1. **Protocol-First Design**
   - Define protocol before implementation
   - Use protocols for dependency injection
   - Enable easy mocking in tests

2. **Clear Naming Conventions**
   - ViewModels: `*ViewModel` (e.g., `AdBiddingViewModel`)
   - Repositories: `*Repository` + `*RepositoryProtocol`
   - Services: `*Service` + `*ServiceProtocol`
   - Models: Plain nouns (e.g., `Bid`, `Ad`, `User`)

3. **Dependency Injection**
   - Inject dependencies via initializer
   - Never use singletons in ViewModels or Repositories
   - Use property injection only for optional dependencies

4. **Error Handling**
   - Use `Result<T, Error>` for async operations
   - Define domain-specific error types
   - See `Sources/constitution.md` Article IV.5 for details

5. **Logging**
   - Use `Logger` API (iOS 14+)
   - See `Sources/constitution.md` Article IV.4 for details

### Performance Guidelines

1. **Memory Management**
   - Use `[weak self]` in closures to avoid retain cycles
   - Release resources in `deinit`
   - Avoid capturing ViewControllers in long-lived closures

2. **Background Processing**
   - Perform network operations on background queues
   - Update UI only on main queue
   - Use `@MainActor` for SwiftUI ViewModels

3. **Caching**
   - Cache expensive computations in ViewModels
   - Use Repository layer for data caching
   - Respect memory warnings

## When to Use This Pattern

- ✅ Feature development in Sources/
- ✅ New UI screens with business logic
- ✅ Data-driven components
- ❌ Simple utility classes (use plain Swift classes)
- ❌ Scripts (see `Scripts/AGENTS-SCRIPTS.md`)

## References

- `Sources/constitution.md` - Swift practices and standards
- `AGENTS.md` - Project-wide context
- `Tests/` - Test examples and templates
