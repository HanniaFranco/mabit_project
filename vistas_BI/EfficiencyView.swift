//
//  EfficiencyView.swift
//  Mabits
//

import SwiftUI
import Charts
import Combine

// Modelo de datos para el volumen de consultas por tema
struct TopicVolume: Identifiable {
    let id = UUID()
    let topic: String
    let volume: Int
}

class EfficiencyViewModel: ObservableObject {
    @Published var automationRate: Double = 65.0
    @Published var avgResolutionTime: Double = 1.2

    @Published var totalMonthlyInteractions: Int = 10000
    let timeSavedPerInteraction: Double = 15.0
    let hourlyRate: Double = 85.0

    @Published var volumeData: [TopicVolume] = [
        TopicVolume(topic: "Recibo de Nómina", volume: 3200),
        TopicVolume(topic: "Vacaciones", volume: 2800),
        TopicVolume(topic: "Tienda Mabe", volume: 1500),
        TopicVolume(topic: "Caja de Ahorro", volume: 900)
    ]

    var hoursSavedMonthly: Double {
        let automatedInteractions = Double(totalMonthlyInteractions) * (automationRate / 100.0)
        return (automatedInteractions * timeSavedPerInteraction) / 60.0
    }

    var economicValueSaved: Double {
        return hoursSavedMonthly * hourlyRate
    }
}

struct EfficiencyView: View {
    @StateObject private var viewModel = EfficiencyViewModel()

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // KPIs Principales en fila horizontal
                HStack(spacing: 16) {
                    KPICardView(
                        title: "Automatización",
                        value: String(format: "%.1f%%", viewModel.automationRate),
                        subtitle: "Consultas sin intervención humana"
                    )

                    KPICardView(
                        title: "Horas Recuperadas",
                        value: String(format: "%.0f h", viewModel.hoursSavedMonthly),
                        subtitle: "Horas productivas al mes"
                    )

                    KPICardView(
                        title: "Ahorro Estimado",
                        value: String(format: "$%.0f", viewModel.economicValueSaved),
                        subtitle: "MXN Mensual (Proyección)"
                    )
                }

                // Card del gráfico con material nativo para jerarquía visual
                VStack(alignment: .leading, spacing: 16) {
                    Text("Volumen de Consultas por Tema")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Chart(viewModel.volumeData) { item in
                        BarMark(
                            x: .value("Tema", item.topic),
                            y: .value("Volumen", item.volume)
                        )
                        .foregroundStyle(.mablue.gradient)
                    }
                    .frame(maxWidth: .infinity, minHeight: 260)
                    // Provides a meaningful summary for VoiceOver users
                    .accessibilityLabel("Gráfica de volumen de consultas por tema")
                    .accessibilityElement(children: .combine)
                }
                .padding(24)
                .background(.regularMaterial)
                .cornerRadius(16)
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Eficiencia Operativa")
        .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    NavigationStack {
        EfficiencyView()
    }
}
