import UIKit

enum DebugToastStyle {
    case loading
    case success
    case error
}

class DebugToast: UIView {
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = .white
        return indicator
    }()
    
    private lazy var stack: UIStackView = {
        let s: UIStackView
        if style == .loading {
            s = UIStackView(arrangedSubviews: [activityIndicator, messageLabel])
            s.spacing = 8
        } else {
            s = UIStackView(arrangedSubviews: [messageLabel])
            s.spacing = 0
        }
        s.axis = .horizontal
        s.alignment = .center
        s.translatesAutoresizingMaskIntoConstraints = false
        return s
    }()
    
    private let style: DebugToastStyle
    
    init(message: String, style: DebugToastStyle) {
        self.style = style
        super.init(frame: .zero)
        setView(message: message)
    }
    
    private func setView(message: String) {
        backgroundColor = {
            switch style {
            case .loading: return UIColor(white: 0, alpha: 0.6)
            case .success: return UIColor(red: 0.65, green: 0.85, blue: 0.65, alpha: 0.95) // subtle green
            case .error: return UIColor(red: 0.95, green: 0.65, blue: 0.65, alpha: 0.95) // subtle red
            }
        }()
        layer.cornerRadius = 12
        layer.masksToBounds = true
        messageLabel.text = message
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(16)
        }
        if style == .loading {
            activityIndicator.startAnimating()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func dismiss() {
        UIView.animate(withDuration: 0.2, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
}

class ToastManager {
    static let shared = ToastManager()
    private var currentToast: DebugToast?
    private var dismissWorkItem: DispatchWorkItem?
    private init() {}
    
    @discardableResult
    func show(message: String, style: DebugToastStyle, in view: UIView, duration: TimeInterval = 2.0) -> DebugToast {
        dismissCurrentToast()
        let toast = DebugToast(message: message, style: style)
        currentToast = toast
        toast.alpha = 0
        view.addSubview(toast)
        toast.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(-80)
            make.width.lessThanOrEqualTo(view.snp.width).multipliedBy(0.9)
        }
        UIView.animate(withDuration: 0.2) {
            toast.alpha = 1
        }
        if style != .loading {
            let workItem = DispatchWorkItem { [weak self, weak toast] in
                toast?.dismiss()
                if self?.currentToast === toast {
                    self?.currentToast = nil
                }
            }
            dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
        }
        return toast
    }
    
    func dismissCurrentToast() {
        dismissWorkItem?.cancel()
        currentToast?.dismiss()
        currentToast = nil
    }
    
    func dismiss() {
        dismissCurrentToast()
    }
} 