import Foundation
import UIKit

enum AnalyticsEvent: String, Sendable {
    case onboardingCompleted = "onboarding_completed"
    case friendRequestSent = "friend_request_sent"
    case friendRequestAccepted = "friend_request_accepted"
    case activityStarted = "activity_started"
    case activityCompleted = "activity_completed"
    case activityPlanned = "activity_planned"
    case inviteAccepted = "invite_accepted"
    case fyrupSent = "fyrup_sent"
    case joinLiveFriend = "join_live_friend"
}

protocol AnalyticsTracking: Sendable { func track(_ event: AnalyticsEvent) async }

actor DevelopmentAnalytics: AnalyticsTracking {
    func track(_ event: AnalyticsEvent) async {
        #if DEBUG
        print("[Analytics] \(event.rawValue)")
        #endif
    }
}

@MainActor enum Haptics {
    static func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) { UIImpactFeedbackGenerator(style: style).impactOccurred() }
    static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
}

