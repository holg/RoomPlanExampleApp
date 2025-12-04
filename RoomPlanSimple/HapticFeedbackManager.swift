/*
See LICENSE folder for this sample's licensing information.

Abstract:
Centralized haptic feedback manager (Issue #14 - extracted component).
*/

import UIKit

// MARK: - Haptic Feedback Manager

@MainActor
final class HapticFeedbackManager {
    static let shared = HapticFeedbackManager()

    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let notificationFeedback = UINotificationFeedbackGenerator()

    private init() {
        prepareGenerators()
    }

    func prepareGenerators() {
        lightImpact.prepare()
        mediumImpact.prepare()
        notificationFeedback.prepare()
    }

    func objectDetected() {
        lightImpact.impactOccurred()
    }

    func scanComplete() {
        notificationFeedback.notificationOccurred(.success)
    }

    func scanError() {
        notificationFeedback.notificationOccurred(.error)
    }

    func trackingStateChanged() {
        mediumImpact.impactOccurred()
    }
}
