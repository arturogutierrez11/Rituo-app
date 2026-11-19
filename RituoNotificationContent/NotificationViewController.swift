import UIKit
import UserNotifications
import UserNotificationsUI

/// A delivery-time snapshot, never a live claim about the current blocking state.
final class NotificationViewController: UIViewController, UNNotificationContentExtension {
    private let stack = UIStackView()
    private let icon = UIImageView()
    private let heading = UILabel()
    private let name = UILabel()
    private let message = UILabel()
    private let detail = UILabel()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.06, green: 0.09, blue: 0.18, alpha: 1)
        stack.axis = .vertical
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: view.topAnchor, constant: 24),
            stack.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -24)
        ])
        icon.tintColor = UIColor(red: 0.63, green: 0.82, blue: 1, alpha: 1)
        icon.contentMode = .left
        icon.heightAnchor.constraint(equalToConstant: 36).isActive = true
        icon.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 30, weight: .medium)
        icon.isAccessibilityElement = false
        for (label, style) in [(heading, UIFont.TextStyle.title2), (name, .headline), (message, .body), (detail, .footnote)] {
            label.font = .preferredFont(forTextStyle: style)
            label.adjustsFontForContentSizeCategory = true
            label.numberOfLines = 0
            label.textColor = .white
        }
        detail.textColor = UIColor(white: 0.8, alpha: 1)
        [icon, heading, name, message, detail].forEach { stack.addArrangedSubview($0) }
    }

    func didReceive(_ notification: UNNotification) {
        loadViewIfNeeded()
        let content = notification.request.content
        heading.text = content.title
        name.text = content.subtitle
        name.isHidden = content.subtitle.isEmpty
        message.text = content.body
        message.isHidden = content.body.isEmpty
        detail.text = content.userInfo["rituo.detail"] as? String
        detail.isHidden = detail.text?.isEmpty != false
        let symbol: String
        switch content.userInfo["rituo.event"] as? String {
        case "break-start": symbol = "cup.and.saucer.fill"
        case "break-end": symbol = "arrow.clockwise.circle.fill"
        case "end", "stop": symbol = "checkmark.circle.fill"
        default: symbol = "moon.stars.fill"
        }
        icon.image = UIImage(systemName: symbol)
        updateHeight()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateHeight()
    }

    private func updateHeight() {
        guard view.bounds.width > 48 else { return }
        let size = stack.systemLayoutSizeFitting(
            CGSize(width: view.bounds.width - 48, height: 0),
            withHorizontalFittingPriority: .required, verticalFittingPriority: .fittingSizeLevel)
        let height = ceil(size.height + 48)
        if abs(preferredContentSize.height - height) > 1 {
            preferredContentSize = CGSize(width: view.bounds.width, height: height)
        }
    }
}
