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
    let country: String
    let area: String
    let seniorityYears: Int
    let vacationDaysAvailable: Int
    let payrollStatus: String
    let nextPaymentDate: String
}
