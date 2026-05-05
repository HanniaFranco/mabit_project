import Foundation

struct ERPJsonStore {
    private let employees: [EmployeeRecord]

    init() {
        if
            let url = Bundle.main.url(forResource: "api_response", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(SAPERPResponse.self, from: data),
            !decoded.data.users.isEmpty
        {
            self.employees = decoded.data.users.map { user in
                EmployeeRecord(
                    employeeId: user.auth.employeeID,
                    name: user.personal.fullName,
                    email: user.personal.email,
                    country: user.position.location.country,
                    area: user.position.area,
                    department: user.position.department,
                    jobTitle: user.position.jobTitle,
                    seniorityYears: user.hr.seniorityYears,
                    hireDate: user.hr.hireDate,
                    employmentStatus: user.hr.status,
                    vacationDaysAvailable: max(0, 12 + user.hr.seniorityYears - 5),
                    payrollStatus: user.hr.status,
                    nextPaymentDate: user.auth.tokenExpiresAt
                )
            }
        } else if
            let url = Bundle.main.url(forResource: "erp_data", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode([EmployeeRecord].self, from: data),
            !decoded.isEmpty
        {
            self.employees = decoded
        } else {
            self.employees = [
                EmployeeRecord(
                    employeeId: "MX-10293",
                    name: "Ana López",
                    email: nil,
                    country: "Mexico",
                    area: "Operations",
                    department: nil,
                    jobTitle: nil,
                    seniorityYears: 2,
                    hireDate: nil,
                    employmentStatus: "Activo",
                    vacationDaysAvailable: 8,
                    payrollStatus: "Pagado",
                    nextPaymentDate: "2026-05-15"
                )
            ]
        }
    }

    func findEmployee(id: String) -> EmployeeRecord? {
        employees.first { $0.employeeId.caseInsensitiveCompare(id) == .orderedSame }
    }
}

private struct SAPERPResponse: Decodable {
    let data: SAPERPData
}

private struct SAPERPData: Decodable {
    let users: [SAPERPUser]
}

private struct SAPERPUser: Decodable {
    let auth: SAPERPAuth
    let personal: SAPERPPersonal
    let position: SAPERPPosition
    let hr: SAPERPHR
}

private struct SAPERPAuth: Decodable {
    let employeeID: String
    let tokenExpiresAt: String

    enum CodingKeys: String, CodingKey {
        case employeeID = "employee_id"
        case tokenExpiresAt = "token_expires_at"
    }
}

private struct SAPERPPersonal: Decodable {
    let fullName: String
    let email: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case email
    }
}

private struct SAPERPPosition: Decodable {
    let jobTitle: String
    let department: String
    let area: String
    let location: SAPERPLocation

    enum CodingKeys: String, CodingKey {
        case jobTitle = "job_title"
        case department
        case area
        case location
    }
}

private struct SAPERPLocation: Decodable {
    let country: String
}

private struct SAPERPHR: Decodable {
    let hireDate: String
    let status: String
    let seniorityYears: Int

    enum CodingKeys: String, CodingKey {
        case hireDate = "hire_date"
        case status
        case seniorityYears = "seniority_years"
    }
}
