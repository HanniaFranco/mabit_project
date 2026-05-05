import Foundation

/// Chunk de texto extraido del PDF con metadata
struct TextChunk: Identifiable, Sendable {
    let id: String
    let text: String
    /// Pagina aproximada del PDF de donde proviene
    let page: Int
    /// Titulo de la seccion del PDF (ej: "SECCION 1 — JORNADA LABORAL")
    let sectionTitle: String
}

/// Resultado de una busqueda semantica sobre los chunks
struct SearchResult: Sendable {
    let chunk: TextChunk
    /// Score de similitud coseno (0 a 1, donde 1 es identico)
    let score: Float
    /// True si el score esta por debajo del umbral minimo de confianza (0.70)
    var belowThreshold: Bool {
        score < 0.70
    }
}

/// Respuesta completa del chat engine
struct ChatResponse: Sendable {
    let text: String
    let confidence: Float
    let source: String
    let shouldEscalate: Bool
    let intent: HRIntent?
    let authLevel: AuthLevel?
    let reason: String?
}
