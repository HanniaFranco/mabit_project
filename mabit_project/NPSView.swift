import SwiftUI

struct NPSView: View {
    @State private var rating: Double = 3
    @State private var showThankYouAlert = false

    private func emoji(for value: Int) -> String {
        switch value {
        case 0: return "😡"
        case 1: return "🙁"
        case 2: return "😐"
        case 3: return "🙂"
        case 4: return "😀"
        default: return "🤩"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 36) {
                VStack(spacing: 8) {
                    Text("Califica tu experiencia")
                        .font(.custom("Gilroy-Bold", size: 30))
                        .foregroundStyle(Color.mabeBlue)

                    Text("¿Que tan satisfecho estas con la resolucion de tu consulta?")
                        .font(.custom("Gilroy-Regular", size: 18))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                VStack(spacing: 24) {
                    Text(emoji(for: Int(rating)))
                        .font(.system(size: 76))

                    Text("\(Int(rating))")
                        .font(.custom("Gilroy-Bold", size: 54))
                        .foregroundStyle(Color.mabeBlue)

                    Slider(value: $rating, in: 0...5, step: 1)
                        .tint(Color.mabeBlue)

                    HStack {
                        Text("0 · Nada satisfecho")
                        Spacer()
                        Text("5 · Muy satisfecho")
                    }
                    .font(.custom("Gilroy-Medium", size: 12))
                    .foregroundStyle(.secondary)
                }
                .padding(28)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 26))
                .shadow(color: Color.black.opacity(0.05), radius: 16, x: 0, y: 10)

                Button {
                    showThankYouAlert = true
                } label: {
                    Text("Enviar calificacion")
                        .font(.custom("Gilroy-Bold", size: 18))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.mabeBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(24)
        }
        .background(Color(red: 236 / 255, green: 244 / 255, blue: 235 / 255).ignoresSafeArea())
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
