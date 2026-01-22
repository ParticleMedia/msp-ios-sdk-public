import Foundation

protocol SmoothProgressDelegate: AnyObject {
    func didUpdateProgress(_ progress: Double)
}

class SmoothProgress {
    private weak var delegate: SmoothProgressDelegate?
    private var timer: Timer?
    private var tick: Double = 0
    private var realProgress: Double = 0

    init(delegate: SmoothProgressDelegate) {
        self.delegate = delegate
    }

    deinit {
        self.timer?.invalidate()
        self.timer = nil
    }

    func startUpdatingProgress() {
        self.tick = 0
        self.realProgress = 0
        self.timer?.invalidate()
        self.timer = nil

        let timer = Timer(
            timeInterval: 0.1, repeats: true,
            block: { [weak self] _ in
                guard let self = self else { return }

                let tickProgress = 1.0 - 1.0 / (self.tick * 0.1 + 1)
                self.delegate?.didUpdateProgress(max(tickProgress, self.realProgress))
                self.tick = self.tick + 1
            })
        self.timer = timer
        RunLoop.current.add(timer, forMode: .common)
    }

    func stopUpdatingProgress() {
        self.tick = 0
        self.realProgress = 0
        self.timer?.invalidate()
        self.timer = nil
    }

    func receiveRealProgress(_ progress: Double) {
        self.realProgress = progress
    }
}
