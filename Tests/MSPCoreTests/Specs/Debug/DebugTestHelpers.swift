import Combine

func captureValues<T>(
    from publisher: AnyPublisher<T, Never>, storeIn cancellables: inout Set<AnyCancellable>,
    handler: @escaping (T) -> Void
) {
    publisher
        .sink { value in
            handler(value)
        }
        .store(in: &cancellables)
}
