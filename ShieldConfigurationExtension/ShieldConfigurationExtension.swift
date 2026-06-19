//
//  ShieldConfigurationExtension.swift
//  ShieldConfigurationExtension
//
//  Created by Arturo Gutierrez on 24/04/2026.
//

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {
    override func configuration(shielding application: Application) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        makeConfiguration()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        makeConfiguration()
    }

    private func makeConfiguration() -> ShieldConfiguration {
        ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.09, green: 0.12, blue: 0.24, alpha: 0.94),
            icon: shieldArtwork,
            title: nil,
            subtitle: nil,
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "seguir en foco",
                color: UIColor(red: 0.07, green: 0.09, blue: 0.17, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.83, green: 0.89, blue: 1.0, alpha: 1),
            secondaryButtonLabel: ShieldConfiguration.Label(
                text: "volver despues",
                color: UIColor(red: 0.88, green: 0.90, blue: 0.96, alpha: 1)
            )
        )
    }

    private var shieldArtwork: UIImage? {
        guard let path = Bundle.main.path(forResource: "ShieldFocusMode", ofType: "png") else {
            return UIImage(systemName: "hourglass.circle.fill")
        }

        return UIImage(contentsOfFile: path) ?? UIImage(systemName: "hourglass.circle.fill")
    }
}
