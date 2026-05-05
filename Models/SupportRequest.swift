import Foundation
import Observation

enum SupportRequestStatus: String, CaseIterable, Identifiable {
    case pending = "Pendiente"
    case inReview = "En revision"
    case answered = "Respondida"

    var id: String { rawValue }

    var detailText: String {
        switch self {
        case .pending:
            return "Tu solicitud fue registrada y esta esperando ser tomada."
        case .inReview:
            return "Un colaborador de RRHH ya esta revisando tu caso."
        case .answered:
            return "La respuesta ya esta disponible para consulta."
        }
    }
}

struct SupportRequest: Identifiable {
    let id: UUID
    let title: String
    let question: String
    let createdAt: Date
    var status: SupportRequestStatus

    init(
        id: UUID = UUID(),
        title: String,
        question: String,
        createdAt: Date = .now,
        status: SupportRequestStatus
    ) {
        self.id = id
        self.title = title
        self.question = question
        self.createdAt = createdAt
        self.status = status
    }
}

@MainActor
@Observable
final class SupportInboxStore {
    static let shared = SupportInboxStore()

    var requests: [SupportRequest] = [
        SupportRequest(
            title: "Aclaracion de vacaciones",
            question: "Quiero confirmar por que mi saldo de vacaciones no coincide con mi ultima solicitud.",
            createdAt: Calendar.current.date(byAdding: .day, value: -2, to: .now) ?? .now,
            status: .inReview
        ),
        SupportRequest(
            title: "Comprobante de nomina",
            question: "Necesito apoyo para consultar un recibo de nomina anterior.",
            createdAt: Calendar.current.date(byAdding: .day, value: -7, to: .now) ?? .now,
            status: .answered
        )
    ]

    private init() {}

    func createRequest(from question: String) {
        let trimmedQuestion = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuestion.isEmpty else { return }

        requests.insert(
            SupportRequest(
                title: requestTitle(from: trimmedQuestion),
                question: trimmedQuestion,
                status: .pending
            ),
            at: 0
        )
    }

    func hasRequest(for question: String) -> Bool {
        let normalizedQuestion = normalized(question)
        return requests.contains { normalized($0.question) == normalizedQuestion }
    }

    private func requestTitle(from question: String) -> String {
        let cleaned = question.replacingOccurrences(of: "\n", with: " ")
        let title = String(cleaned.prefix(42))
        return title.isEmpty ? "Solicitud a RRHH" : title
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
