import SwiftUI
import Charts
import Combine

// Modelo de datos para las métricas de CSAT
struct CSATMetric: Identifiable {
    let id = UUID()
    let queryType: String
    let score: Double
}

// ViewModel para gestionar el estado de la vista de Satisfacción
class SatisfactionViewModel: ObservableObject {
    @Published var npsScore: Int = 42
    @Published var abandonmentRate: Double = 14.5
    @Published var csatData: [CSATMetric] = [
        CSATMetric(queryType: "Genérica", score: 4.7),
        CSATMetric(queryType: "Escalado RH", score: 4.2),
        CSATMetric(queryType: "Plataforma SAP", score: 3.1)
    ]
}

// Vista principal de la sección de Satisfacción
struct SatisfactionView: View {
    @StateObject private var viewModel = SatisfactionViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                HStack(spacing: 16) {
                    KPICardView(
                        title: "NPS General",
                        value: "\(viewModel.npsScore)",
                        subtitle: "Rango de -100 a 100"
                    )

                    KPICardView(
                        title: "Tasa de Abandono",
                        value: String(format: "%.1f%%", viewModel.abandonmentRate),
                        subtitle: "Conversaciones no finalizadas"
                    )
                }

                // Card con material nativo para crear profundidad visual sin bordes pesados
                VStack(alignment: .leading, spacing: 16) {
                    Text("CSAT por Tipo de Consulta")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Chart(viewModel.csatData) { metric in
                        BarMark(
                            x: .value("Puntuación", metric.score),
                            y: .value("Tipo", metric.queryType)
                        )
                        .foregroundStyle(.mablue.gradient)
                        .annotation(position: .trailing) {
                            Text(String(format: "%.1f", metric.score))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .chartXScale(domain: 0...5)
                    .frame(maxWidth: .infinity, minHeight: 220)
                    // Provides a meaningful summary for VoiceOver users
                    .accessibilityLabel("Gráfica de satisfacción por tipo de consulta")
                    .accessibilityElement(children: .combine)
                }
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Satisfacción")
        .navigationBarTitleDisplayMode(.large)
    }
}

// Componente reutilizable para mostrar indicadores clave de rendimiento
struct KPICardView: View {
    let title: String
    let value: String
    let subtitle: String

    // Scales the prominent KPI number with Dynamic Type
    @ScaledMetric(relativeTo: .largeTitle) private var valueSize: CGFloat = 40

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: valueSize, weight: .bold))
                .foregroundColor(.mablue)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial)
        .cornerRadius(16)
        // VoiceOver reads all three texts as a single cohesive unit
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    NavigationStack {
        SatisfactionView()
    }
}
