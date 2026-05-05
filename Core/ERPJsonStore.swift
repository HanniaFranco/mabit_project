import Foundation

struct ERPJsonStore {
    private let employees: [EmployeeRecord]

    init() {
        if
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
                    country: "Mexico",
                    area: "Operations",
                    seniorityYears: 2,
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
