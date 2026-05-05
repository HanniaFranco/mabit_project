import Foundation

/// Niveles de proteccion de datos para consultas de RRHH
enum AuthLevel: String, Codable, Sendable {
    case general
    case employeeContext
    case biometricRequired
    case blocked
}
