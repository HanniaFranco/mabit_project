import Foundation
import PDFKit
import NaturalLanguage

/// Errores posibles durante la indexacion del PDF
enum PDFIndexerError: LocalizedError {
    case pdfNotFound(String)
    case noTextExtracted

    var errorDescription: String? {
        switch self {
        case .pdfNotFound(let name):
            return "No se encontro el PDF '\(name)' en el bundle de la app."
        case .noTextExtracted:
            return "No se pudo extraer texto del PDF."
        }
    }
}

/// Extrae texto de un PDF y lo divide en chunks por seccion para indexacion
struct PDFIndexer {

    /// Limite de palabras para considerar una seccion "muy larga" y subdividirla
    private static let maxSectionWords = 300

    /// Patron regex para detectar encabezados de seccion tipo "SECCION N — TITULO"
    private static let sectionPattern = #"(?=SECCIÓN\s+\d+)"#

    /// Indexa un PDF del bundle, extrayendo texto y dividiendolo por secciones
    /// - Parameter pdfNamed: Nombre del archivo PDF (sin extension)
    /// - Returns: Array de TextChunk listos para ser indexados semanticamente
    static func index(pdfNamed: String) async throws -> [TextChunk] {
        guard let url = Bundle.main.url(forResource: pdfNamed, withExtension: "pdf") else {
            throw PDFIndexerError.pdfNotFound(pdfNamed)
        }

        guard let document = PDFDocument(url: url) else {
            throw PDFIndexerError.pdfNotFound(pdfNamed)
        }

        // Extraer texto completo del PDF concatenando todas las paginas
        var fullText = ""
        var pageBreaks: [(offset: Int, page: Int)] = []

        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let text = page.string {
                let startOffset = fullText.count
                fullText += text + "\n"
                pageBreaks.append((offset: startOffset, page: i + 1))
            }
        }

        guard !fullText.isEmpty else {
            throw PDFIndexerError.noTextExtracted
        }

        // Dividir por secciones respetando la estructura del documento
        let chunks = splitBySections(fullText: fullText, pageBreaks: pageBreaks)
        return chunks
    }

    /// Divide el texto en chunks basandose en el patron "SECCION N" como separador
    /// Si una seccion excede maxSectionWords, la subdivide por parrafos
    private static func splitBySections(fullText: String, pageBreaks: [(offset: Int, page: Int)]) -> [TextChunk] {
        // Separar el texto usando el patron de seccion como delimitador
        let sections: [String]
        if let regex = try? NSRegularExpression(pattern: sectionPattern, options: []) {
            let nsText = fullText as NSString
            let matches = regex.matches(in: fullText, range: NSRange(location: 0, length: nsText.length))

            if matches.isEmpty {
                // Si no hay patron de seccion, tratar todo el texto como una seccion
                sections = [fullText]
            } else {
                var parts: [String] = []
                for i in 0..<matches.count {
                    let start = matches[i].range.location
                    let end = (i + 1 < matches.count) ? matches[i + 1].range.location : nsText.length
                    parts.append(nsText.substring(with: NSRange(location: start, length: end - start)))
                }
                // Si hay texto antes de la primera seccion, agregarlo tambien
                if let firstMatch = matches.first, firstMatch.range.location > 0 {
                    let preamble = nsText.substring(with: NSRange(location: 0, length: firstMatch.range.location))
                    let cleaned = cleanText(preamble)
                    if !cleaned.isEmpty {
                        parts.insert(preamble, at: 0)
                    }
                }
                sections = parts
            }
        } else {
            sections = [fullText]
        }

        var chunks: [TextChunk] = []

        for section in sections {
            let cleaned = cleanText(section)
            guard !cleaned.isEmpty else { continue }

            let title = extractSectionTitle(from: cleaned)
            let page = estimatePage(for: section, in: fullText, pageBreaks: pageBreaks)
            let wordCount = cleaned.split(separator: " ").count

            if wordCount > maxSectionWords {
                // Seccion muy larga: subdividir por parrafos (doble salto de linea)
                let paragraphs = cleaned.components(separatedBy: "\n\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                for (i, paragraph) in paragraphs.enumerated() {
                    let cleanedParagraph = cleanText(paragraph)
                    guard !cleanedParagraph.isEmpty else { continue }
                    chunks.append(TextChunk(
                        id: UUID().uuidString,
                        text: cleanedParagraph,
                        page: page,
                        sectionTitle: paragraphs.count > 1 ? "\(title) (parte \(i + 1))" : title
                    ))
                }
            } else {
                chunks.append(TextChunk(
                    id: UUID().uuidString,
                    text: cleaned,
                    page: page,
                    sectionTitle: title
                ))
            }
        }

        return chunks
    }

    /// Extrae el titulo de la seccion de la primera linea del texto
    /// Busca el patron "SECCION N — TITULO" o usa las primeras palabras
    private static func extractSectionTitle(from text: String) -> String {
        let firstLine = text.components(separatedBy: .newlines).first ?? text
        // Buscar patron "SECCION N — TITULO" o "SECCION N - TITULO"
        if let regex = try? NSRegularExpression(pattern: #"^(SECCIÓN\s+\d+\s*[—\-–]\s*.+?)$"#, options: .anchorsMatchLines),
           let match = regex.firstMatch(in: firstLine, range: NSRange(location: 0, length: (firstLine as NSString).length)) {
            return (firstLine as NSString).substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespaces)
        }
        // Fallback: primeras 8 palabras de la primera linea
        let words = firstLine.split(separator: " ").prefix(8)
        return words.joined(separator: " ")
    }

    /// Estima en que pagina del PDF cae un fragmento de texto
    private static func estimatePage(for section: String, in fullText: String, pageBreaks: [(offset: Int, page: Int)]) -> Int {
        guard let range = fullText.range(of: section.prefix(50)) else {
            return pageBreaks.first?.page ?? 1
        }
        let offset = fullText.distance(from: fullText.startIndex, to: range.lowerBound)
        // Encontrar la pagina cuyo offset es menor o igual al offset del texto
        var page = 1
        for pb in pageBreaks {
            if pb.offset <= offset { page = pb.page }
            else { break }
        }
        return page
    }

    /// Limpia el texto: preserva puntuacion y saltos de linea,
    /// elimina espacios y lineas vacias redundantes
    private static func cleanText(_ text: String) -> String {
        let lines = text.components(separatedBy: .newlines)
        var cleaned: [String] = []
        var lastWasEmpty = false

        for line in lines {
            // Colapsar espacios multiples dentro de la linea
            let trimmed = line.replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression).trimmingCharacters(in: .whitespaces)
            
            let isSeparator = trimmed.allSatisfy { "─—_-–=".contains($0) }
            if isSeparator { continue }
            
            if trimmed.isEmpty {
                if !lastWasEmpty && !cleaned.isEmpty {
                    cleaned.append("")
                    lastWasEmpty = true
                }
            } else {
                cleaned.append(trimmed)
                lastWasEmpty = false
            }
        }

        // Eliminar lineas vacias al final
        while cleaned.last?.isEmpty == true { cleaned.removeLast() }

        return cleaned.joined(separator: "\n")
    }
}
