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
            backgroundBlurStyle: .regular,
            backgroundColor: UIColor(
                // Compensates the gray tint added by the system material and
                // preserves a visibly stronger navy-blue finish.
                red: 15.0 / 255.0,
                green: 23.0 / 255.0,
                blue: 65.0 / 255.0,
                alpha: 1
            ),
            icon: shieldArtwork,
            title: ShieldConfiguration.Label(
                text: "Estás en un ritual",
                color: UIColor(red: 0.95, green: 0.96, blue: 1.0, alpha: 1)
            ),
            subtitle: ShieldConfiguration.Label(
                text: "Si querés desactivarlo, andá a la app de rituo y apoyá tu tarjeta.",
                color: UIColor(red: 0.61, green: 0.70, blue: 0.78, alpha: 1)
            ),
            primaryButtonLabel: ShieldConfiguration.Label(
                text: "Salir",
                color: UIColor(red: 0.07, green: 0.09, blue: 0.17, alpha: 1)
            ),
            primaryButtonBackgroundColor: UIColor(red: 0.83, green: 0.89, blue: 1.0, alpha: 1),
            secondaryButtonLabel: nil
        )
    }

    private var shieldArtwork: UIImage? {
        guard let path = Bundle.main.path(forResource: "ShieldFocusMode", ofType: "png") else {
            return UIImage(systemName: "hourglass.circle.fill")
        }

        return UIImage(contentsOfFile: path) ?? UIImage(systemName: "hourglass.circle.fill")
    }
}
