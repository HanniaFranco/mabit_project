import Foundation
import Observation
import FoundationModels

/// Motor principal del chatbot de RRHH.
/// Usa un pipeline controlado para clasificar, validar acceso,
/// recuperar evidencia y responder sin inventar datos.
@MainActor
@Observable
final class HRChatEngine {
    var isReady = false
    var isProcessing = false
    var errorMessage: String?

    private var semanticIndex: SemanticIndex?
    private let erpStore = ERPJsonStore()
    private let confidenceThreshold: Float = 0.55

    func initialize() async {
        do {
            let chunks = try await PDFIndexer.index(pdfNamed: "politicas_generales")
            let index = await Task.detached {
                await SemanticIndex(chunks: chunks)
            }.value

            self.semanticIndex = index
            self.isReady = true

            let model = SystemLanguageModel.default
            switch model.availability {
            case .available:
                print("[HRChatEngine] Foundation Models: DISPONIBLE")
            case .unavailable(let reason):
                print("[HRChatEngine] Foundation Models: NO DISPONIBLE - \(reason)")
            @unknown default:
                print("[HRChatEngine] Foundation Models: estado desconocido")
            }
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func ask(_ question: String, session: UserSession) async -> ChatResponse {
        guard let index = semanticIndex else {
            return ChatResponse(
                text: "El sistema aún no está listo. Espera a que se complete la indexación.",
                confidence: 0,
                source: "N/A",
                shouldEscalate: true,
                intent: nil,
                authLevel: nil,
                reason: "semanticIndexUnavailable"
            )
        }

        isProcessing = true
        defer { isProcessing = false }

        let classification = await aiClassify(question)
        let hasAccess = validateAccess(classification: classification, session: session)

        guard hasAccess else {
            return deniedAccessResponse(for: classification)
        }

        let pdfEvidence = await retrieveEvidence(
            question: question,
            intent: classification.intent,
            index: index
        )

        let erpRecord: EmployeeRecord?
        if classification.needsERP, let employeeId = session.employeeId {
            erpRecord = erpStore.findEmployee(id: employeeId)
        } else {
            erpRecord = nil
        }

        let grade = await aiGradeEvidence(
            question: question,
            classification: classification,
            pdfEvidence: pdfEvidence,
            erpRecord: erpRecord
        )

        guard grade.hasEnoughEvidence else {
            return insufficientEvidenceResponse(
                grade: grade,
                source: pdfEvidence.first?.chunk.sectionTitle,
                intent: classification.intent,
                authLevel: classification.authLevel
            )
        }

        let answer = await aiGenerateFinalAnswer(
            question: question,
            classification: classification,
            pdfEvidence: pdfEvidence,
            erpRecord: erpRecord,
            grade: grade
        )

        let source = pdfEvidence.map(\.chunk.sectionTitle).uniqueJoined(limit: 2) ?? "ERP"
        return ChatResponse(
            text: answer,
            confidence: grade.confidence,
            source: source,
            shouldEscalate: false,
            intent: classification.intent,
            authLevel: classification.authLevel,
            reason: classification.reason
        )
    }

    private func validateAccess(classification: AIClassification, session: UserSession) -> Bool {
        switch classification.authLevel {
        case .general:
            return true
        case .employeeContext:
            return session.isLoggedIn && session.employeeId != nil
        case .biometricRequired:
            return session.isLoggedIn && session.employeeId != nil && session.biometricVerified
        case .blocked:
            return false
        }
    }

    private func deniedAccessResponse(for classification: AIClassification) -> ChatResponse {
        let text: String
        switch classification.authLevel {
        case .general:
            text = "Puedo ayudarte con eso si vuelves a intentarlo."
        case .employeeContext:
            text = "Para responder eso necesito que inicies sesión con tu número de empleado, porque la respuesta depende de tu perfil."
        case .biometricRequired:
            text = "Para consultar esa información necesito verificar tu identidad con Face ID o Touch ID, porque contiene datos personales de empleado."
        case .blocked:
            text = "No puedo ayudar con esa consulta porque podría exponer información personal o sensible de otro colaborador."
        }

        return ChatResponse(
            text: text,
            confidence: 0,
            source: "Control de acceso",
            shouldEscalate: classification.authLevel == .blocked,
            intent: classification.intent,
            authLevel: classification.authLevel,
            reason: classification.reason
        )
    }

    private func aiClassify(_ question: String) async -> AIClassification {
        guard isFoundationModelAvailable else {
            return fallbackClassify(question)
        }

        let prompt = """
        Clasifica la pregunta de RRHH en JSON estricto.

        Intents permitidos:
        vacationPolicy, vacationBalance, benefitsPolicy, payrollPolicy, payrollPersonal,
        schedulePolicy, trainingPolicy, conductPolicy, hrContact, unknown.

        Niveles permitidos:
        general, employeeContext, biometricRequired, blocked.

        Reglas:
        - Si pregunta por política general de vacaciones, beneficios/prestaciones, nómina, horario, capacitación, conducta o contacto: general.
        - Si pregunta por saldo personal, vacaciones disponibles, recibos, depósito propio, nómina propia, pagos personales o datos individuales: biometricRequired.
        - Si requiere país, área o número de empleado para personalizar: employeeContext.
        - Si pide datos de otra persona: blocked.
        - Si no está relacionado con RRHH o no hay información suficiente para clasificar: unknown con authLevel general.
        - No expliques fuera del JSON.

        Formato exacto:
        {
          "intent": "vacationPolicy",
          "authLevel": "general",
          "needsPDF": true,
          "needsERP": false,
          "isAnswerableWithoutLogin": true,
          "reason": "..."
        }

        Pregunta:
        \(question)
        """

        if let classification: AIClassification = await decodeJSONResponse(prompt: prompt) {
            return classification
        }

        return fallbackClassify(question)
    }

    private func fallbackClassify(_ question: String) -> AIClassification {
        let normalized = normalizedText(question)

        if asksForAnotherPerson(normalized) {
            return AIClassification(
                intent: .unknown,
                authLevel: .blocked,
                needsPDF: false,
                needsERP: false,
                isAnswerableWithoutLogin: false,
                reason: "La consulta pide datos de otra persona."
            )
        }

        if containsAny(normalized, ["cuantas vacaciones tengo", "cuántas vacaciones tengo", "vacaciones disponibles", "saldo de vacaciones"]) {
            return AIClassification(
                intent: .vacationBalance,
                authLevel: .biometricRequired,
                needsPDF: true,
                needsERP: true,
                isAnswerableWithoutLogin: false,
                reason: "Consulta personal sobre saldo de vacaciones."
            )
        }

        if containsAny(normalized, ["vacaciones"]) {
            return AIClassification(
                intent: .vacationPolicy,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta general sobre política de vacaciones."
            )
        }

        if containsAny(normalized, ["beneficios", "prestaciones", "seguro", "vales", "aguinaldo"]) {
            return AIClassification(
                intent: .benefitsPolicy,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta general sobre beneficios."
            )
        }

        if containsAny(normalized, ["nomina", "nómina", "pago", "pagan", "deposito", "depósito"]) {
            if containsAny(normalized, [" mi ", " me ", "me depositaron", "recibo", "propio"]) || normalized.hasPrefix("mi ") {
                return AIClassification(
                    intent: .payrollPersonal,
                    authLevel: .biometricRequired,
                    needsPDF: true,
                    needsERP: true,
                    isAnswerableWithoutLogin: false,
                    reason: "Consulta personal de nómina."
                )
            }

            return AIClassification(
                intent: .payrollPolicy,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta general sobre política de nómina."
            )
        }

        if containsAny(normalized, ["horario", "jornada", "entrada", "salida"]) {
            return AIClassification(
                intent: .schedulePolicy,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta general sobre jornada u horario."
            )
        }

        if containsAny(normalized, ["capacitacion", "capacitación", "academy", "curso"]) {
            return AIClassification(
                intent: .trainingPolicy,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta general sobre capacitación."
            )
        }

        if containsAny(normalized, ["conducta", "etica", "ética", "conflicto"]) {
            return AIClassification(
                intent: .conductPolicy,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta general sobre conducta."
            )
        }

        if containsAny(normalized, ["contacto", "rrhh", "recursos humanos"]) {
            return AIClassification(
                intent: .hrContact,
                authLevel: .general,
                needsPDF: true,
                needsERP: false,
                isAnswerableWithoutLogin: true,
                reason: "Consulta de contacto con RRHH."
            )
        }

        return AIClassification(
            intent: .unknown,
            authLevel: .general,
            needsPDF: true,
            needsERP: false,
            isAnswerableWithoutLogin: true,
            reason: "No hay una clasificación confiable para la consulta."
        )
    }

    private func retrieveEvidence(
        question: String,
        intent: HRIntent,
        index: SemanticIndex
    ) async -> [SearchResult] {
        let results = await index.search(query: question, topK: 5)
        guard let preferredKeyword = preferredSectionKeyword(for: intent) else {
            return results
        }

        let preferred = results.filter {
            $0.chunk.sectionTitle.localizedCaseInsensitiveContains(preferredKeyword)
        }
        return preferred.isEmpty ? results : preferred
    }

    private func preferredSectionKeyword(for intent: HRIntent) -> String? {
        switch intent {
        case .vacationPolicy, .vacationBalance:
            return "VACACIONES"
        case .benefitsPolicy:
            return "PRESTACIONES"
        case .payrollPolicy, .payrollPersonal:
            return "NÓMINA"
        case .schedulePolicy:
            return "JORNADA"
        case .trainingPolicy:
            return "CAPACITACIÓN"
        case .conductPolicy:
            return "CONDUCTA"
        case .hrContact:
            return "CONTACTO"
        case .unknown:
            return nil
        }
    }

    private func aiGradeEvidence(
        question: String,
        classification: AIClassification,
        pdfEvidence: [SearchResult],
        erpRecord: EmployeeRecord?
    ) async -> EvidenceGrade {
        guard isFoundationModelAvailable else {
            return fallbackEvidenceGrade(
                classification: classification,
                pdfEvidence: pdfEvidence,
                erpRecord: erpRecord
            )
        }

        let prompt = """
        Evalúa si la evidencia permite responder la pregunta de RRHH.

        Responde solo JSON.

        Criterios:
        - hasEnoughEvidence debe ser false si falta un dato personal necesario.
        - hasEnoughEvidence debe ser false si la evidencia solo habla de un tema relacionado pero no responde la pregunta exacta.
        - Para preguntas personales, si needsERP es true y no hay datos ERP autorizados, hasEnoughEvidence debe ser false.
        - No uses conocimiento externo.
        - Sé estricto: si dudas, marca hasEnoughEvidence false.

        Formato exacto:
        {
          "hasEnoughEvidence": true,
          "reason": "...",
          "missingInfo": [],
          "confidence": 0.85
        }

        Pregunta:
        \(question)

        Clasificación:
        \(jsonString(for: classification) ?? "N/A")

        Evidencia PDF:
        \(jsonString(for: pdfEvidence.map { EvidenceSnippet(result: $0) }) ?? "[]")

        Datos ERP autorizados:
        \(jsonString(for: erpRecord) ?? "N/A")
        """

        if let grade: EvidenceGrade = await decodeJSONResponse(prompt: prompt) {
            return grade
        }

        return fallbackEvidenceGrade(
            classification: classification,
            pdfEvidence: pdfEvidence,
            erpRecord: erpRecord
        )
    }

    private func fallbackEvidenceGrade(
        classification: AIClassification,
        pdfEvidence: [SearchResult],
        erpRecord: EmployeeRecord?
    ) -> EvidenceGrade {
        if classification.needsERP, erpRecord == nil {
            return EvidenceGrade(
                hasEnoughEvidence: false,
                reason: "Faltan datos ERP autorizados para responder una consulta personal.",
                missingInfo: ["employeeId", "biometricVerification"],
                confidence: 0.85
            )
        }

        if classification.intent == .unknown {
            return EvidenceGrade(
                hasEnoughEvidence: false,
                reason: "La intención no es suficientemente clara para responder con seguridad.",
                missingInfo: [],
                confidence: 0.3
            )
        }

        guard let best = pdfEvidence.first else {
            return EvidenceGrade(
                hasEnoughEvidence: !classification.needsPDF,
                reason: "No se encontró evidencia PDF relevante.",
                missingInfo: classification.needsPDF ? ["policyEvidence"] : [],
                confidence: 0
            )
        }

        if classification.needsPDF && best.score < confidenceThreshold {
            return EvidenceGrade(
                hasEnoughEvidence: false,
                reason: "La evidencia recuperada es demasiado débil.",
                missingInfo: ["policyEvidence"],
                confidence: best.score
            )
        }

        return EvidenceGrade(
            hasEnoughEvidence: true,
            reason: "La evidencia PDF y ERP es suficiente para responder.",
            missingInfo: [],
            confidence: best.score
        )
    }

    private func aiGenerateFinalAnswer(
        question: String,
        classification: AIClassification,
        pdfEvidence: [SearchResult],
        erpRecord: EmployeeRecord?,
        grade: EvidenceGrade
    ) async -> String {
        guard isFoundationModelAvailable else {
            return fallbackFinalAnswer(
                classification: classification,
                erpRecord: erpRecord
            )
        }

        let prompt = """
        Redacta una respuesta breve, amable y segura para un colaborador.

        Reglas obligatorias:
        - Usa únicamente la evidencia proporcionada.
        - No inventes políticas, fechas, montos, beneficios ni datos personales.
        - No copies el texto literalmente.
        - Máximo 3 oraciones.
        - Si hay datos personales, usa solo los datos ERP autorizados.
        - No menciones que eres un modelo de AI.
        - No menciones JSON ni proceso interno.
        - Si la evidencia no permite responder, di que no hay información suficiente.

        Pregunta:
        \(question)

        Clasificación:
        \(jsonString(for: classification) ?? "N/A")

        Evidencia validada PDF:
        \(jsonString(for: pdfEvidence.map { EvidenceSnippet(result: $0) }) ?? "[]")

        Datos ERP autorizados:
        \(jsonString(for: erpRecord) ?? "N/A")

        Grado de evidencia:
        \(jsonString(for: grade) ?? "N/A")
        """

        guard let answer = await generateText(prompt: prompt), !answer.isEmpty else {
            return fallbackFinalAnswer(classification: classification, erpRecord: erpRecord)
        }

        return answer
    }

    private func fallbackFinalAnswer(
        classification: AIClassification,
        erpRecord: EmployeeRecord?
    ) -> String {
        switch classification.intent {
        case .vacationPolicy:
            return "Los días de vacaciones dependen de la antigüedad: 12 días el primer año, 14 el segundo, 16 durante el tercero y cuarto, 18 del quinto al noveno, y 20 a partir del décimo. La solicitud debe hacerse con al menos 15 días de anticipación por MABE Connect o con el formato HR-VAC-01."
        case .vacationBalance:
            guard let erpRecord else { return insufficientFallbackText }
            return "Tienes \(erpRecord.vacationDaysAvailable) días de vacaciones disponibles. Para solicitarlas, debes hacerlo con al menos 15 días de anticipación por MABE Connect o con el formato HR-VAC-01."
        case .benefitsPolicy:
            return "Las prestaciones generales incluyen seguro de gastos médicos mayores, fondo de ahorro, vales de despensa, aguinaldo, prima vacacional y seguro de vida. Algunos detalles pueden depender del país, área o condiciones internas aplicables."
        case .payrollPolicy:
            return "La nómina se paga de forma quincenal, los días 15 y último de cada mes. Si la fecha cae en fin de semana o día festivo, el pago se adelanta al día hábil anterior."
        case .payrollPersonal:
            guard let erpRecord else { return insufficientFallbackText }
            return "Tu estado de nómina aparece como \(erpRecord.payrollStatus). La próxima fecha de pago registrada es \(erpRecord.nextPaymentDate)."
        case .schedulePolicy:
            return "La jornada estándar es de 8 horas diarias y 40 semanales, normalmente de lunes a viernes. El horario específico puede variar según la planta o el área."
        case .trainingPolicy:
            return "MABE Academy está disponible 24/7 como plataforma en línea. Incluye cursos técnicos, liderazgo, idiomas y certificaciones."
        case .conductPolicy:
            return "Se espera actuar con integridad, respeto y profesionalismo en todo momento. Los reportes pueden canalizarse por la línea ética."
        case .hrContact:
            return "Puedes contactar a tu Business Partner de RRHH o escribir a rrhh@mabe.com. El tiempo esperado de respuesta es de 48 horas hábiles."
        case .unknown:
            return insufficientFallbackText
        }
    }

    private func insufficientEvidenceResponse(
        grade: EvidenceGrade,
        source: String?,
        intent: HRIntent,
        authLevel: AuthLevel
    ) -> ChatResponse {
        let text: String
        if !grade.missingInfo.isEmpty {
            text = "Para responder eso necesito información adicional: \(grade.missingInfo.joined(separator: ", ")). Por seguridad, no puedo asumir esos datos."
        } else {
            text = "Revisé la información disponible, pero no encontré evidencia suficiente para responder esto con seguridad. Para evitar darte una respuesta incorrecta, te recomiendo contactar a RRHH."
        }

        return ChatResponse(
            text: text,
            confidence: grade.confidence,
            source: source ?? "N/A",
            shouldEscalate: true,
            intent: intent,
            authLevel: authLevel,
            reason: grade.reason
        )
    }

    private var insufficientFallbackText: String {
        "Revisé la información disponible, pero no encontré evidencia suficiente para responder esto con seguridad. Para evitar darte una respuesta incorrecta, te recomiendo contactar a RRHH."
    }

    private var isFoundationModelAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    private func generateText(prompt: String) async -> String? {
        do {
            let session = LanguageModelSession()
            let response = try await session.respond(to: prompt)
            return sanitizeModelOutput(response.content)
        } catch {
            print("[HRChatEngine] Foundation Models error: \(error)")
            return nil
        }
    }

    private func decodeJSONResponse<T: Decodable>(prompt: String) async -> T? {
        guard let output = await generateText(prompt: prompt) else {
            return nil
        }

        let cleaned = sanitizeJSONText(output)
        guard let data = cleaned.data(using: .utf8) else {
            return nil
        }

        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            print("[HRChatEngine] JSON decode error: \(error)")
            return nil
        }
    }

    private func sanitizeModelOutput(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func sanitizeJSONText(_ text: String) -> String {
        var cleaned = sanitizeModelOutput(text)
        if cleaned.hasPrefix("```json") {
            cleaned = String(cleaned.dropFirst(7))
        } else if cleaned.hasPrefix("```") {
            cleaned = String(cleaned.dropFirst(3))
        }
        if cleaned.hasSuffix("```") {
            cleaned = String(cleaned.dropLast(3))
        }
        return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func jsonString<T: Encodable>(for value: T?) -> String? {
        guard let value else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private func normalizedText(_ text: String) -> String {
        " \(text.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()) "
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current).lowercased()) }
    }

    private func asksForAnotherPerson(_ text: String) -> Bool {
        let patterns = [
            "de otra persona",
            "de otro empleado",
            "de otro colaborador",
            "de mi companero",
            "de mi compañero",
            "de juan",
            "de ana"
        ]
        return containsAny(text, patterns)
    }
}

private struct EvidenceSnippet: Codable, Sendable {
    let sectionTitle: String
    let page: Int
    let score: Float
    let text: String

    init(result: SearchResult) {
        self.sectionTitle = result.chunk.sectionTitle
        self.page = result.chunk.page
        self.score = result.score
        self.text = result.chunk.text
    }

    init(_ result: SearchResult) {
        self.init(result: result)
    }
}

private extension Array where Element == String {
    func uniqueJoined(limit: Int) -> String? {
        let unique = reduce(into: [String]()) { partialResult, item in
            if !partialResult.contains(item) {
                partialResult.append(item)
            }
        }
        let trimmed = Array(unique.prefix(limit))
        guard !trimmed.isEmpty else { return nil }
        return trimmed.joined(separator: " · ")
    }
}
