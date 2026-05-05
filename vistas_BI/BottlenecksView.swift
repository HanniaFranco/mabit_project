//
//  BottlenecksView.swift
//  Mabits
//

import SwiftUI
import Combine

struct BottleneckTopic: Identifiable {
    let id = UUID()
    let topic: String
    let abandonmentRate: Double
    let escalationRate: Double
    let recommendation: String

    var isCritical: Bool {
        abandonmentRate > 20.0 || escalationRate > 40.0
    }
}

class BottlenecksViewModel: ObservableObject {
    @Published var topics: [BottleneckTopic] = [
        BottleneckTopic(topic: "Avisos Infonavit", abandonmentRate: 25.4, escalationRate: 15.0, recommendation: "Simplificar lenguaje técnico"),
        BottleneckTopic(topic: "Bloqueo SAP", abandonmentRate: 5.0, escalationRate: 85.0, recommendation: "Crear flujo de auto-desbloqueo (Ext 1111)"),
        BottleneckTopic(topic: "Prima Vacacional", abandonmentRate: 18.2, escalationRate: 35.0, recommendation: "Mejorar base de conocimiento"),
        BottleneckTopic(topic: "Permisos Paternidad", abandonmentRate: 4.1, escalationRate: 12.0, recommendation: "Flujo estable")
    ]

    @Published var unresolvedKeywords: [WordTopic] = [
        WordTopic(word: "SAP", frequency: 85), WordTopic(word: "Contraseña", frequency: 70),
        WordTopic(word: "Infonavit", frequency: 60), WordTopic(word: "Prima", frequency: 45),
        WordTopic(word: "Error", frequency: 40), WordTopic(word: "Desbloqueo", frequency: 35),
        WordTopic(word: "Sistema", frequency: 30), WordTopic(word: "Vacaciones", frequency: 25),
        WordTopic(word: "Baja", frequency: 20), WordTopic(word: "Acceso", frequency: 15)
    ]
}

struct BottlenecksView: View {
    @StateObject private var viewModel = BottlenecksViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                SectionContainer(title: "Términos con Mayor Fricción") {
                    WordCloudView(keywords: viewModel.unresolvedKeywords)
                }

                SectionContainer(title: "Temas de Alta Fricción") {
                    Table(viewModel.topics) {
                        TableColumn("Tema", value: \.topic)
                        TableColumn("Tasa de Abandono") { topic in
                            Text(String(format: "%.1f%%", topic.abandonmentRate))
                                .foregroundColor(topic.abandonmentRate > 20.0 ? .red : .primary)
                        }
                        TableColumn("Tasa de Escalamiento") { topic in
                            Text(String(format: "%.1f%%", topic.escalationRate))
                                .foregroundColor(topic.escalationRate > 40.0 ? .red : .primary)
                        }
                        TableColumn("Recomendación", value: \.recommendation)
                    }
                    .frame(minHeight: 280)
                    .cornerRadius(12)
                    // Summarizes table purpose for VoiceOver
                    .accessibilityLabel("Tabla de temas con alta fricción mostrando tasas de abandono y escalamiento")
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .navigationTitle("Áreas de Oportunidad")
        .navigationBarTitleDisplayMode(.large)
    }
}

// Contenedor reutilizable para secciones con título destacado y espaciado consistente
struct SectionContainer<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title3)
                .fontWeight(.semibold)

            content
        }
    }
}

#Preview {
    NavigationStack {
        BottlenecksView()
    }
}
