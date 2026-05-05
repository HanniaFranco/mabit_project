//
//  NPSView.swift
//  Mabits
//

import SwiftUI

struct NPSView: View {
    @State private var rating: Double = 3
    @State private var showThankYouAlert = false

    // Scales emoji and number sizes proportionally with Dynamic Type
    @ScaledMetric(relativeTo: .largeTitle) private var emojiSize: CGFloat = 80
    @ScaledMetric(relativeTo: .largeTitle) private var numberSize: CGFloat = 56

    // Mapea cada valor del slider a un emoji expresivo
    private func emoji(for value: Int) -> String {
        switch value {
        case 0:  return "😡"
        case 1:  return "🙁"
        case 2:  return "😐"
        case 3:  return "🙂"
        case 4:  return "😀"
        default: return "🤩"
        }
    }

    // Descripción textual del emoji para VoiceOver
    private func emojiDescription(for value: Int) -> String {
        switch value {
        case 0:  return "Muy insatisfecho"
        case 1:  return "Insatisfecho"
        case 2:  return "Neutral"
        case 3:  return "Satisfecho"
        case 4:  return "Muy satisfecho"
        default: return "Excelente"
        }
    }

    var body: some View {
        // ScrollView prevents content overflow at large Dynamic Type sizes
        ScrollView {
            VStack(spacing: 48) {
                VStack(spacing: 8) {
                    Text("Califica tu experiencia")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Text("¿Qué tan satisfecho estás con la resolución de tu consulta?")
                        .font(.title3)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Tarjeta del slider con material nativo
                VStack(spacing: 32) {
                    VStack(spacing: 8) {
                        // ZStack + .id() forces SwiftUI to swap the view and fire the transition
                        ZStack {
                            Text(emoji(for: Int(rating)))
                                .font(.system(size: emojiSize))
                                .id(Int(rating))
                                .transition(.scale.combined(with: .opacity))
                        }
                        .animation(.spring(response: 0.3, dampingFraction: 0.6), value: Int(rating))
                        .accessibilityLabel(emojiDescription(for: Int(rating)))

                        Text("\(Int(rating))")
                            .font(.system(size: numberSize, weight: .bold, design: .rounded))
                            .foregroundColor(.mabeBlue)
                            .contentTransition(.numericText())
                            .animation(.spring(), value: rating)
                            .accessibilityHidden(true)
                    }
                    // Groups emoji + number so VoiceOver reads them as one element
                    .accessibilityElement(children: .combine)

                    Slider(value: $rating, in: 0...5, step: 1)
                        .tint(.mabeBlue)
                        .padding(.horizontal, 16)
                        .accessibilityLabel("Calificación de experiencia")
                        .accessibilityValue("\(Int(rating)) de 5, \(emojiDescription(for: Int(rating)))")

                    HStack {
                        Text("0 · Nada satisfecho")
                        Spacer()
                        Text("5 · Muy satisfecho")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    // Decorative labels — the slider's accessibilityValue provides this context
                    .accessibilityHidden(true)
                }
                .padding(32)
                .background(.regularMaterial)
                .cornerRadius(24)

                Button {
                    showThankYouAlert = true
                } label: {
                    Text("Enviar calificación")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.mabeBlue)
                        .foregroundColor(.white)
                        .cornerRadius(16)
                }
                .accessibilityHint("Envía tu calificación de \(Int(rating)) de 5")
            }
            .padding(24)
            // Centers content and fills the full TabView canvas
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .alert("Gracias por tu retroalimentacion", isPresented: $showThankYouAlert) {
            Button("Cerrar", role: .cancel) {}
        } message: {
            Text("Muchas gracias por usar la herramienta. Tu retroalimentacion es muy importante para nosotros y seguiremos trabajando para brindarte un mejor servicio.")
        }
    }
}

#Preview {
    NPSView()
}
