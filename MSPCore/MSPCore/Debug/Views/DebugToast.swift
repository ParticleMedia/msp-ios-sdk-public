import UIKit

private enum UIConfig {
    static let fontSize: CGFloat = 15
    static let fontWeight: UIFont.Weight = .medium
    static let loadingSpacing: CGFloat = 8
    static let nonLoadingSpacing: CGFloat = 0
    static let cornerRadius: CGFloat = 12
    static let stackInset: CGFloat = 16
    static let toastBottomOffset: CGFloat = -80
    static let toastWidthMultiplier: CGFloat = 0.9
    static let animationDuration: TimeInterval = 0.2
    static let defaultDuration: TimeInterval = 2.0
    // Colors
    static let loadingBackground = UIColor(white: 0, alpha: 0.6)
    static let successBackground = UIColor(red: 0.65, green: 0.85, blue: 0.65, alpha: 0.95)
    static let errorBackground = UIColor(red: 0.95, green: 0.65, blue: 0.65, alpha: 0.95)
    static let textColor = UIColor.white
    static let indicatorColor = UIColor.white
}

enum DebugToastStyle {
    case loading
    case success
    case error
}

class DebugToast: UIView {
    private lazy var messageLabel: UILabel = {
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: UIConfig.fontSize, weight: UIConfig.fontWeight)
        label.numberOfLines = 0
        label.textAlignment = .center
        return label
    }()
    
    private lazy var activityIndicator: UIActivityIndicatorView = {
        let indicator = UIActivityIndicatorView(style: .medium)
        indicator.color = UIConfig.indicatorColor
        return indicator
    }()
    
    private lazy var stack: UIStackView = {
        let s: UIStackView
        if style == .loading {
            s = UIStackView(arrangedSubviews: [activityIndicator, messageLabel])
            s.spacing = UIConfig.loadingSpacing
        } else {
            s = UIStackView(arrangedSubviews: [messageLabel])
            s.spacing = UIConfig.nonLoadingSpacing
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
            case .loading: return UIConfig.loadingBackground
            case .success: return UIConfig.successBackground
            case .error: return UIConfig.errorBackground
            }
        }()
        layer.cornerRadius = UIConfig.cornerRadius
        layer.masksToBounds = true
        messageLabel.text = message
        addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(UIConfig.stackInset)
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
            make.bottom.equalTo(view.safeAreaLayoutGuide.snp.bottom).offset(UIConfig.toastBottomOffset)
            make.width.lessThanOrEqualTo(view.snp.width).multipliedBy(UIConfig.toastWidthMultiplier)
        }
        UIView.animate(withDuration: UIConfig.animationDuration) {
            toast.alpha = 1
        }
        let displayDuration = (duration == 2.0) ? UIConfig.defaultDuration : duration
        if style != .loading {
            let workItem = DispatchWorkItem { [weak self, weak toast] in
                toast?.dismiss()
                if self?.currentToast === toast {
                    self?.currentToast = nil
                }
            }
            dismissWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + displayDuration, execute: workItem)
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