import Foundation

struct UserSession: Codable, Sendable {
    var isLoggedIn: Bool
    var employeeId: String?
    var country: String?
    var area: String?
    var biometricVerified: Bool
}

struct AIClassification: Codable, Sendable {
    let intent: HRIntent
    let authLevel: AuthLevel
    let needsPDF: Bool
    let needsERP: Bool
    let isAnswerableWithoutLogin: Bool
    let reason: String
}

struct EvidenceGrade: Codable, Sendable {
    let hasEnoughEvidence: Bool
    let reason: String
    let missingInfo: [String]
    let confidence: Float
}

struct EmployeeRecord: Codable, Sendable {
    let employeeId: String
    let name: String
    let email: String?
    let country: String
    let area: String
    let department: String?
    let jobTitle: String?
    let seniorityYears: Int
    let hireDate: String?
    let employmentStatus: String?
    let vacationDaysAvailable: Int
    let payrollStatus: String
    let nextPaymentDate: String
}

struct PipelineTrace: Codable, Sendable {
    let classification: TraceStep
    let evidenceGrade: TraceStep
    let finalAnswer: TraceStep
}

struct TraceStep: Codable, Sendable {
    let stage: String
    let usedFoundationModel: Bool
    let usedFallback: Bool
    let summary: String
    let rawOutput: String?
    let errorDescription: String?
}
