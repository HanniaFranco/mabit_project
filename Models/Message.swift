import Foundation

enum MessageDisplayStyle {
    case standard
    case systemDivider
    case humanSupport
}

/// Representa un mensaje en el chat (del usuario o del bot)
struct Message: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    let displayStyle: MessageDisplayStyle
    let confidence: Float?
    let shouldEscalate: Bool
    let source: String?
    let intent: HRIntent?
    let authLevel: AuthLevel?
    let reason: String?

    init(
        text: String,
        isUser: Bool,
        displayStyle: MessageDisplayStyle = .standard,
        confidence: Float? = nil,
        shouldEscalate: Bool = false,
        source: String? = nil,
        intent: HRIntent? = nil,
        authLevel: AuthLevel? = nil,
        reason: String? = nil
    ) {
        self.text = text
        self.isUser = isUser
        self.displayStyle = displayStyle
        self.confidence = confidence
        self.shouldEscalate = shouldEscalate
        self.source = source
        self.intent = intent
        self.authLevel = authLevel
        self.reason = reason
    }
}
