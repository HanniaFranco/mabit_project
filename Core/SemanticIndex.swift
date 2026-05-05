import Foundation
import NaturalLanguage

/// Indice semantico que permite buscar chunks por similitud usando embeddings
/// Usa actor para garantizar que el trabajo pesado de embeddings corra en background
/// y evitar problemas de concurrencia con Swift 6
actor SemanticIndex {

    /// Chunks con vector de embedding (pueden participar en busqueda semantica)
    private let vectorEntries: [(chunk: TextChunk, vector: [Double])]
    /// TODOS los chunks, incluyendo los que no pudieron generar vector
    /// Participan en keyword matching como fallback
    private let allChunks: [TextChunk]
    /// Embedding de NL usado para generar vectores de queries
    private let embedding: NLEmbedding
    /// True si estamos usando word embedding (promedio) en vez de sentence embedding
    private let usesWordEmbedding: Bool

    /// Stopwords comunes en espanol que se ignoran al promediar vectores y keyword matching
    private static let spanishStopwords: Set<String> = [
        "de", "la", "el", "en", "y", "a", "que", "se", "los", "las", "por", "con",
        "un", "una", "del", "al", "es", "lo", "su", "para", "no", "son", "como",
        "más", "pero", "sus", "le", "ya", "o", "fue", "este", "ha", "si", "porque",
        "esta", "son", "entre", "cuando", "muy", "sin", "sobre", "ser", "también",
        "me", "hasta", "hay", "donde", "han", "quien", "están", "estado", "desde",
        "todo", "nos", "durante", "estados", "todos", "uno", "les", "ni", "contra",
        "otros", "fueron", "ese", "eso", "ante", "ellos", "e", "esto", "mí", "antes",
        "qué", "cuántas", "cuántos", "cuál", "cómo", "dónde", "tengo", "puedo", "tiene"
    ]

    /// Peso del keyword boost en el score hibrido
    private static let keywordWeight: Float = 0.35

    init(chunks: [TextChunk]) async {
        self.allChunks = chunks

        if let emb = NLEmbedding.sentenceEmbedding(for: .spanish) {
            print("[SemanticIndex] Usando sentence embedding - Español")
            self.embedding = emb
            self.usesWordEmbedding = false
        } else if let emb = NLEmbedding.sentenceEmbedding(for: .english) {
            print("[SemanticIndex] Usando sentence embedding - Inglés (fallback)")
            self.embedding = emb
            self.usesWordEmbedding = false
        } else if let emb = NLEmbedding.wordEmbedding(for: .spanish) {
            print("[SemanticIndex] Usando word embedding - Español (fallback)")
            self.embedding = emb
            self.usesWordEmbedding = true
        } else if let emb = NLEmbedding.wordEmbedding(for: .english) {
            print("[SemanticIndex] Usando word embedding - Inglés (fallback final)")
            self.embedding = emb
            self.usesWordEmbedding = true
        } else {
            print("[SemanticIndex] ERROR: No hay embedding disponible, usando solo keywords")
            // Guardar un embedding dummy - no se usara porque vectorEntries estara vacio
            self.embedding = NLEmbedding.wordEmbedding(for: .english)!
            self.usesWordEmbedding = true
            self.vectorEntries = []
            return
        }

        var indexed: [(chunk: TextChunk, vector: [Double])] = []
        for chunk in chunks {
            if let vector = Self.computeChunkVector(for: chunk.text, embedding: embedding, useWordAverage: usesWordEmbedding) {
                indexed.append((chunk: chunk, vector: vector))
                print("[SemanticIndex] Chunk '\(chunk.sectionTitle)' -> vector OK (\(chunk.text.split(separator: " ").count) palabras)")
            } else {
                print("[SemanticIndex] Chunk '\(chunk.sectionTitle)' -> SIN VECTOR (solo keywords)")
            }
        }
        self.vectorEntries = indexed
        print("[SemanticIndex] Indexados \(indexed.count)/\(chunks.count) con vector, \(chunks.count) con keywords")
    }

    /// Busca los chunks mas similares usando score hibrido (embedding + keywords).
    /// Si el query vector no se puede generar, usa keyword matching puro.
    /// Chunks sin vector tambien participan via keywords.
    func search(query: String, topK: Int = 3) -> [SearchResult] {
        let queryKeywords = Self.extractKeywords(from: query)
        let queryVector = Self.computeQueryVector(for: query, embedding: embedding, useWordAverage: usesWordEmbedding)

        if queryVector == nil {
            print("[SemanticIndex] Sin vector para query, usando keyword matching puro")
        }

        // Crear un lookup rapido de vectores por chunk ID
        var vectorLookup: [String: [Double]] = [:]
        for entry in vectorEntries {
            vectorLookup[entry.chunk.id] = entry.vector
        }

        var results: [SearchResult] = []

        // Evaluar TODOS los chunks (con y sin vector)
        for chunk in allChunks {
            let keywordScore = Self.keywordOverlap(queryKeywords: queryKeywords, chunkText: chunk.text)

            var finalScore: Float
            if let qVec = queryVector, let chunkVec = vectorLookup[chunk.id] {
                // Tiene ambos vectores: score hibrido
                let similarity = Self.cosineSimilarity(qVec, chunkVec)
                let embeddingScore = Float((similarity + 1.0) / 2.0)
                finalScore = embeddingScore * (1 - Self.keywordWeight) + keywordScore * Self.keywordWeight
            } else {
                // Sin vector: score basado solo en keywords
                finalScore = keywordScore
            }

            results.append(SearchResult(chunk: chunk, score: finalScore))
        }

        results.sort { $0.score > $1.score }

        // Debug: mostrar ranking completo
        print("[SemanticIndex] Query: '\(query)' | keywords: \(queryKeywords) | hasVector: \(queryVector != nil)")
        for (i, r) in results.enumerated() {
            let hasVec = vectorLookup[r.chunk.id] != nil
            print("[SemanticIndex]   #\(i+1) score=\(String(format: "%.4f", r.score)) \(hasVec ? "V+K" : "K  ") -> '\(r.chunk.sectionTitle)'")
        }

        return Array(results.prefix(topK))
    }

    // MARK: - Keywords

    /// Extrae palabras clave de un texto (sin stopwords, en minusculas)
    private static func extractKeywords(from text: String) -> Set<String> {
        let words = text.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty && $0.count > 2 && !spanishStopwords.contains($0) }
        return Set(words)
    }

    /// Calcula que porcentaje de las keywords de la query aparecen en el chunk
    private static func keywordOverlap(queryKeywords: Set<String>, chunkText: String) -> Float {
        guard !queryKeywords.isEmpty else { return 0 }
        let chunkLower = chunkText.lowercased()
        var matches = 0
        for keyword in queryKeywords {
            if chunkLower.contains(keyword) {
                matches += 1
            }
        }
        return Float(matches) / Float(queryKeywords.count)
    }

    // MARK: - Vectorizacion de chunks

    /// Calcula el vector de un CHUNK largo dividiendo en oraciones y promediando
    private static func computeChunkVector(for text: String, embedding: NLEmbedding, useWordAverage: Bool) -> [Double]? {
        if useWordAverage {
            return computeWordAverageVector(for: text, embedding: embedding)
        }

        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        var sentences: [String] = []
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let sentence = String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
            if sentence.split(separator: " ").count >= 3 {
                sentences.append(sentence)
            }
            return true
        }

        guard !sentences.isEmpty else {
            return embedding.vector(for: text)
        }

        var sumVector: [Double]?
        var count = 0

        for sentence in sentences {
            guard let vec = embedding.vector(for: sentence) else { continue }
            if sumVector == nil {
                sumVector = vec
            } else {
                for i in 0..<vec.count { sumVector![i] += vec[i] }
            }
            count += 1
        }

        guard var result = sumVector, count > 0 else {
            return embedding.vector(for: text)
        }
        for i in 0..<result.count { result[i] /= Double(count) }
        return result
    }

    // MARK: - Vectorizacion de queries

    private static func computeQueryVector(for text: String, embedding: NLEmbedding, useWordAverage: Bool) -> [Double]? {
        if useWordAverage {
            return computeWordAverageVector(for: text, embedding: embedding)
        }
        return embedding.vector(for: text)
    }

    // MARK: - Word average fallback

    private static func computeWordAverageVector(for text: String, embedding: NLEmbedding) -> [Double]? {
        let words = text.lowercased()
            .split(separator: " ")
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }
            .filter { !$0.isEmpty && !spanishStopwords.contains($0) }
            .prefix(50)

        var sumVector: [Double]?
        var count = 0

        for word in words {
            guard let vec = embedding.vector(for: word) else { continue }
            if sumVector == nil {
                sumVector = vec
            } else {
                for i in 0..<vec.count { sumVector![i] += vec[i] }
            }
            count += 1
        }

        guard var result = sumVector, count > 0 else { return nil }
        for i in 0..<result.count { result[i] /= Double(count) }
        return result
    }

    // MARK: - Similitud coseno

    private static func cosineSimilarity(_ a: [Double], _ b: [Double]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }

        var dotProduct = 0.0
        var normA = 0.0
        var normB = 0.0

        for i in 0..<a.count {
            dotProduct += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }

        let denominator = sqrt(normA) * sqrt(normB)
        guard denominator > 0 else { return 0 }
        return dotProduct / denominator
    }
}
