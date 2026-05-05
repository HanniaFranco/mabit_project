import FoundationModels
import SwiftUI

struct FoundationModelDiagnosticsView: View {
    @State private var availabilityDescription = ""
    @State private var localeIdentifier = ""
    @State private var supportsCurrentLocale = false
    @State private var supportedLanguages: [String] = []
    @State private var probeResult = "Sin ejecutar"
    @State private var isRunningProbe = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                diagnosticCard(title: "Estado del modelo") {
                    DiagnosticRow(label: "Availability", value: availabilityDescription)
                    DiagnosticRow(label: "Locale actual", value: localeIdentifier)
                    DiagnosticRow(label: "Locale soportado", value: supportsCurrentLocale ? "Si" : "No")
                }

                diagnosticCard(title: "Idiomas soportados") {
                    Text(supportedLanguages.joined(separator: ", "))
                        .font(.custom("Gilroy-Regular", size: 14))
                        .foregroundStyle(.secondary)
                }

                diagnosticCard(title: "Probe manual") {
                    Text(probeResult)
                        .font(.custom("Gilroy-Regular", size: 14))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)

                    Button {
                        Task {
                            await runProbe()
                        }
                    } label: {
                        HStack {
                            if isRunningProbe {
                                ProgressView()
                                    .tint(.white)
                            }
                            Text(isRunningProbe ? "Probando..." : "Probar Foundation Model")
                                .font(.custom("Gilroy-Bold", size: 16))
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.mabeBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                    }
                    .disabled(isRunningProbe)
                }
            }
            .padding(20)
        }
        .background(Color(red: 230 / 255, green: 240 / 255, blue: 220 / 255).ignoresSafeArea())
        .navigationTitle("Diagnostico FM")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            loadDiagnostics()
        }
    }

    @ViewBuilder
    private func diagnosticCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.custom("Gilroy-Bold", size: 18))
                .foregroundStyle(Color.mabeBlue)

            content()
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private func loadDiagnostics() {
        let model = SystemLanguageModel.default
        availabilityDescription = String(describing: model.availability)
        localeIdentifier = Locale.current.identifier
        supportsCurrentLocale = model.supportsLocale()
        supportedLanguages = model.supportedLanguages
            .map(\.minimalIdentifier)
            .sorted()
    }

    private func runProbe() async {
        isRunningProbe = true
        defer { isRunningProbe = false }

        let session = LanguageModelSession()

        do {
            let response = try await session.respond(to: "Answer with the single word ok.")
            probeResult = "OK\n\n\(response.content)"
        } catch let error as LanguageModelSession.GenerationError {
            probeResult = """
            GenerationError
            description: \(error.errorDescription ?? "nil")
            failureReason: \(error.failureReason ?? "nil")
            debug: \(error)
            """
        } catch {
            probeResult = "Other error\n\(error)"
        }
    }
}

private struct DiagnosticRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Gilroy-Bold", size: 13))
                .foregroundStyle(.primary)

            Text(value)
                .font(.custom("Gilroy-Regular", size: 14))
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }
}

#Preview {
    NavigationStack {
        FoundationModelDiagnosticsView()
    }
}
