//
//  CheckInView.swift
//  Mabits
//

import SwiftUI

// Cuatro opciones de estado de ánimo con su icono SF Symbol correspondiente
enum MoodOption: CaseIterable {
    case motivado, contento, desmotivado, frustrado

    var label: String {
        switch self {
        case .motivado:    return "Motivado"
        case .contento:    return "Contento"
        case .desmotivado: return "Desmotivado"
        case .frustrado:   return "Frustrado"
        }
    }

    var icon: String {
        switch self {
        case .motivado:    return "hands.sparkles"
        case .contento:    return "face.smiling.fill"
        case .desmotivado: return "cloud.rain.fill"
        case .frustrado:   return "exclamationmark.circle"
        }
    }
}

struct CheckInView: View {
    @State private var selectedMood: MoodOption? = nil

    // Dos columnas flexibles para la cuadrícula 2x2
    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        // ScrollView prevents content overflow at large Dynamic Type sizes
        ScrollView {
            VStack(spacing: 48) {
                VStack(spacing: 8) {
                    Text("¿Cómo te sientes hoy?")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("Selecciona tu estado antes de empezar")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .multilineTextAlignment(.center)

                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(MoodOption.allCases, id: \.label) { mood in
                        MoodCardView(mood: mood, isSelected: selectedMood == mood) {
                            withAnimation(.spring(response: 0.3)) {
                                selectedMood = mood
                            }
                        }
                    }
                }

                // Botón revelado con transición suave tras seleccionar una opción
                if selectedMood != nil {
                    Button {
                        print("Registrando entrada: \(selectedMood!.label)")
                    } label: {
                        Text("Registrar entrada")
                            .font(.title3)
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(.mablue)
                            .foregroundColor(.white)
                            .cornerRadius(16)
                    }
                    .accessibilityHint("Registra tu estado de ánimo y comienza la sesión")
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(24)
            // Centers content and fills the full TabView canvas
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

// Tarjeta individual de estado de ánimo con icono grande y etiqueta
struct MoodCardView: View {
    let mood: MoodOption
    let isSelected: Bool
    let action: () -> Void

    // Scales the icon size proportionally with Dynamic Type
    @ScaledMetric(relativeTo: .largeTitle) private var iconSize: CGFloat = 44

    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: mood.icon)
                    .font(.system(size: iconSize))
                    .symbolRenderingMode(.hierarchical)
                Text(mood.label)
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            // Ensures 44x44pt minimum tap target
            .frame(minHeight: 44)
            .background(isSelected ? Color.mablue : Color(UIColor.secondarySystemGroupedBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
        // VoiceOver reads icon + label as a single unit
        .accessibilityElement(children: .combine)
        .accessibilityLabel(mood.label)
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityHint("Selecciona \(mood.label) como tu estado de ánimo")
    }
}

#Preview {
    CheckInView()
}
