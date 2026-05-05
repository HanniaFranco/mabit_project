import Foundation

enum HRIntent: String, Codable, Sendable {
    case vacationPolicy
    case vacationBalance
    case benefitsPolicy
    case payrollPolicy
    case payrollPersonal
    case schedulePolicy
    case trainingPolicy
    case conductPolicy
    case hrContact
    case unknown
}
