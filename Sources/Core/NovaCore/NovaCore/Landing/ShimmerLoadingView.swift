import UIKit

// Stage A: Removed Shimmer dependency - replaced with simple static placeholder view
// This maintains the same visual structure without requiring Shimmer framework
class ShimmerLoadingView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)

         let containerView = UIView(frame: self.bounds)
         containerView.translatesAutoresizingMaskIntoConstraints = false

         let stackView = UIStackView()
         stackView.translatesAutoresizingMaskIntoConstraints = false
         stackView.axis = .vertical
         stackView.alignment = .leading
         stackView.spacing = 12

         containerView.addSubview(stackView)
         NSLayoutConstraint.activate([
             stackView.leftAnchor.constraint(equalTo: containerView.leftAnchor, constant: 20),
             stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 32),
             stackView.rightAnchor.constraint(equalTo: containerView.rightAnchor, constant: -20),
         ])

         let headerInsets: [CGFloat] = [0.0, 12.0, 120.0]
         for inset in headerInsets {
             let view = UIView()
             view.backgroundColor = UIColor(light: NovaColorPalettes.Gray.tint100, dark: NovaColorPalettes.Gray.tint800)
             view.translatesAutoresizingMaskIntoConstraints = false
             view.layer.cornerRadius = 4
             stackView.addArrangedSubview(view)
             NSLayoutConstraint.activate([
                 view.rightAnchor.constraint(equalTo: stackView.rightAnchor, constant: -inset),
                 view.heightAnchor.constraint(equalToConstant: 28),
             ])
         }

         stackView.setCustomSpacing(28, after: stackView.subviews.last!)

         let imageView = UIView()
         imageView.translatesAutoresizingMaskIntoConstraints = false
         imageView.backgroundColor = UIColor(light: NovaColorPalettes.Gray.tint100, dark: NovaColorPalettes.Gray.tint800)
         imageView.layer.cornerRadius = 4
         stackView.addArrangedSubview(imageView)
         NSLayoutConstraint.activate([
             imageView.rightAnchor.constraint(equalTo: stackView.rightAnchor),
             imageView.heightAnchor.constraint(equalToConstant: 175),
         ])

         stackView.setCustomSpacing(28, after: stackView.subviews.last!)

         let bodyInsets: [CGFloat] = [0.0, 37.0, 21.0, 58.0, 11.0, 17.0, 17.0, 0.0, 39.0, 39.0]
         for inset in bodyInsets {
             let view = UIView()
             view.translatesAutoresizingMaskIntoConstraints = false
             view.backgroundColor = UIColor(light: NovaColorPalettes.Gray.tint100, dark: NovaColorPalettes.Gray.tint800)
             view.layer.cornerRadius = 4
             stackView.addArrangedSubview(view)
             NSLayoutConstraint.activate([
                 view.rightAnchor.constraint(equalTo: stackView.rightAnchor, constant: -inset),
                 view.heightAnchor.constraint(equalToConstant: 20),
             ])
         }

         self.addSubview(containerView)
         NSLayoutConstraint.activate([
             containerView.leftAnchor.constraint(equalTo: self.leftAnchor),
             containerView.topAnchor.constraint(equalTo: self.topAnchor),
             containerView.rightAnchor.constraint(equalTo: self.rightAnchor),
             containerView.bottomAnchor.constraint(equalTo: self.bottomAnchor),
         ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

}
