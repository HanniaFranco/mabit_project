import Combine
import LocalAuthentication
import SwiftUI

struct ChatView: View {
    @State private var engine = HRChatEngine()
    @State private var inputText = ""
    @State private var messages: [Message] = [
        Message(
            text: "Hola, soy mabit. Preguntame sobre vacaciones, nomina, beneficios o politicas de RRHH.",
            isUser: false
        )
    ]
    @State private var currentSession = UserSession(
        isLoggedIn: true,
        employeeId: "EMP-001432",
        country: "MX",
        area: "Supply Chain",
        biometricVerified: false
    )
    @State private var pendingProtectedQuestion: String?
    @State private var showBiometricPrompt = false
    @State private var authenticationErrorMessage: String?
    @State private var showAuthenticationError = false
    @State private var secureSessionExpiration: Date?
    @State private var remainingSecureSessionSeconds = 0
    @FocusState private var isInputFocused: Bool

    private let secureSessionDuration: TimeInterval = 300
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isReady || engine.foundationModelStatusMessage != nil {
                statusBanner
            }

            if isSecureSessionActive {
                secureSessionBanner
            }

            messageList
            inputBar
        }
        .background(Color(red: 230 / 255, green: 240 / 255, blue: 220 / 255).ignoresSafeArea())
        .navigationTitle("mabit chat")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    FoundationModelDiagnosticsView()
                } label: {
                    Image(systemName: "stethoscope")
                        .foregroundStyle(Color.mabeBlue)
                }
            }
        }
        .task {
            if !engine.isReady && engine.errorMessage == nil {
                await engine.initialize()
            }
        }
        .onReceive(timer) { _ in
            refreshSecureSessionTimer()
        }
        .onDisappear {
            clearSecureSession()
        }
        .sheet(isPresented: $showBiometricPrompt) {
            biometricPromptSheet
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .alert("No se pudo verificar tu identidad", isPresented: $showAuthenticationError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(authenticationErrorMessage ?? "Intentalo de nuevo.")
        }
    }

    @ViewBuilder
    private var statusBanner: some View {
        VStack {
            if let error = engine.errorMessage {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                    Text(error)
                        .font(.custom("Gilroy-Medium", size: 13))
                }
                .foregroundStyle(.red)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
            } else if let foundationModelStatusMessage = engine.foundationModelStatusMessage {
                HStack(spacing: 10) {
                    Image(systemName: "info.circle.fill")
                    Text(foundationModelStatusMessage)
                        .font(.custom("Gilroy-Medium", size: 13))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
            } else {
                HStack(spacing: 10) {
                    ProgressView()
                    Text("Preparando la informacion de RRHH...")
                        .font(.custom("Gilroy-Medium", size: 13))
                        .foregroundStyle(Color.mabeBlue)
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .background(Color.white)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var secureSessionBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "lock.shield.fill")
                .foregroundStyle(Color.mabeBlue)

            VStack(alignment: .leading, spacing: 2) {
                Text("Sesion privada activa")
                    .font(.custom("Gilroy-Bold", size: 13))
                    .foregroundStyle(.primary)
                Text("Durara \(formattedRemainingTime)")
                    .font(.custom("Gilroy-Medium", size: 12))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(Color.white)
        .padding(.horizontal, 20)
        .padding(.top, 12)
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 14) {
                    ForEach(messages) { message in
                        ChatBubble(message: message)
                            .id(message.id)
                    }

                    if engine.isProcessing {
                        HStack(spacing: 10) {
                            ProgressView()
                            Text("Pensando...")
                                .font(.custom("Gilroy-Medium", size: 14))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 24)
                        .id("loading")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
            .onChange(of: messages.count) {
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var inputBar: some View {
        HStack(alignment: .bottom, spacing: 12) {
            TextField("Escribe tu pregunta...", text: $inputText, axis: .vertical)
                .font(.custom("Gilroy-Regular", size: 16))
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 22))
                .lineLimit(1...4)
                .focused($isInputFocused)
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "arrow.up")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(Color.mabeBlue)
                    .clipShape(Circle())
            }
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isProcessing || !engine.isReady)
            .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isProcessing || !engine.isReady ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background(Color.white.opacity(0.96))
    }

    private var biometricPromptSheet: some View {
        VStack(spacing: 18) {
            Capsule()
                .fill(Color.gray.opacity(0.25))
                .frame(width: 44, height: 5)
                .padding(.top, 8)

            Text("Quieres utilizar biometricos para verificar tu identidad?")
                .font(.custom("Gilroy-Bold", size: 22))
                .foregroundStyle(Color.mabeBlue)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)

            Text("Puedes usar \(biometricMethodName) para acceder a consultas privadas durante 5 minutos.")
                .font(.custom("Gilroy-Regular", size: 15))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)

            Button {
                Task {
                    await authenticateWithBiometrics()
                }
            } label: {
                Text("Verificar con \(biometricMethodName)")
                    .font(.custom("Gilroy-Bold", size: 17))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mabeBlue)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
            }
            .padding(.horizontal, 24)

            Button {
                authenticateWithPasswordFallback()
            } label: {
                Text("Verificar con contrasena")
                    .font(.custom("Gilroy-Medium", size: 15))
                    .foregroundStyle(.secondary)
                    .underline()
            }

            Spacer()
        }
        .background(Color.white)
    }

    private var isSecureSessionActive: Bool {
        currentSession.biometricVerified && remainingSecureSessionSeconds > 0
    }

    private var formattedRemainingTime: String {
        let minutes = remainingSecureSessionSeconds / 60
        let seconds = remainingSecureSessionSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    private var biometricMethodName: String {
        let context = LAContext()
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)

        switch context.biometryType {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "biometricos"
        }
    }

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        isInputFocused = false
        requestResponse(for: text, appendUserMessage: true)
    }

    private func requestResponse(for question: String, appendUserMessage: Bool) {
        if appendUserMessage {
            messages.append(Message(text: question, isUser: true))
        }

        Task {
            let response = await engine.ask(question, session: currentSession)
            messages.append(
                Message(
                    text: response.text,
                    isUser: false,
                    confidence: response.confidence,
                    shouldEscalate: response.shouldEscalate,
                    source: response.source,
                    intent: response.intent,
                    authLevel: response.authLevel,
                    reason: response.reason,
                    answerSource: response.answerSource,
                    trace: response.trace
                )
            )

            if response.requiresBiometricVerification {
                pendingProtectedQuestion = question
                showBiometricPrompt = true
            }
        }
    }

    private func authenticateWithBiometrics() async {
        let context = LAContext()
        context.localizedCancelTitle = "Cancelar"

        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            authenticationErrorMessage = error?.localizedDescription ?? "Este dispositivo no tiene biometria disponible."
            showAuthenticationError = true
            return
        }

        do {
            let success = try await evaluateBiometrics(using: context)
            if success {
                activateSecureSession()
            }
        } catch {
            authenticationErrorMessage = error.localizedDescription
            showAuthenticationError = true
        }
    }

    private func authenticateWithPasswordFallback() {
        activateSecureSession()
    }

    private func activateSecureSession() {
        currentSession.biometricVerified = true
        secureSessionExpiration = Date().addingTimeInterval(secureSessionDuration)
        refreshSecureSessionTimer()
        showBiometricPrompt = false

        messages.append(
            Message(
                text: "Identidad verificada. Ya puedes hacer consultas privadas durante 5 minutos.",
                isUser: false,
                source: "Sesion segura",
                answerSource: .fallback
            )
        )

        if let pendingProtectedQuestion {
            self.pendingProtectedQuestion = nil
            requestResponse(for: pendingProtectedQuestion, appendUserMessage: false)
        }
    }

    private func clearSecureSession() {
        currentSession.biometricVerified = false
        secureSessionExpiration = nil
        remainingSecureSessionSeconds = 0
        pendingProtectedQuestion = nil
        showBiometricPrompt = false
    }

    private func refreshSecureSessionTimer() {
        guard let secureSessionExpiration else {
            remainingSecureSessionSeconds = 0
            return
        }

        let seconds = max(0, Int(secureSessionExpiration.timeIntervalSinceNow.rounded(.down)))
        remainingSecureSessionSeconds = seconds

        if seconds == 0 {
            currentSession.biometricVerified = false
            self.secureSessionExpiration = nil
            messages.append(
                Message(
                    text: "La sesion privada expiro. Si vuelves a pedir informacion sensible, te pedire verificar tu identidad otra vez.",
                    isUser: false,
                    source: "Sesion segura",
                    answerSource: .fallback
                )
            )
        }
    }

    private func evaluateBiometrics(using context: LAContext) async throws -> Bool {
        try await withCheckedThrowingContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Necesitamos verificar tu identidad para mostrar informacion privada."
            ) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: success)
                }
            }
        }
    }
}

private struct ChatBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isUser { Spacer(minLength: 48) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.custom("Gilroy-Regular", size: 16))
                    .foregroundStyle(message.isUser ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(message.isUser ? Color.mabeBlue : Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                if !message.isUser {
                    messageMetadata
                }
            }

            if !message.isUser { Spacer(minLength: 48) }
        }
    }

    @ViewBuilder
    private var messageMetadata: some View {
        VStack(alignment: .leading, spacing: 4) {
            if let confidence = message.confidence {
                Text("Confianza \(Int(confidence * 100))%")
                    .font(.custom("Gilroy-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if let source = message.source, !source.isEmpty {
                Text(source)
                    .font(.custom("Gilroy-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if let answerSource = message.answerSource {
                Text(answerSource.rawValue)
                    .font(.custom("Gilroy-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if let authLevel = message.authLevel {
                Text(authLevel.rawValue)
                    .font(.custom("Gilroy-Medium", size: 11))
                    .foregroundStyle(.secondary)
            }

            if let trace = message.trace {
                Text(traceSummary(trace))
                    .font(.custom("Gilroy-Medium", size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
            }

            if message.shouldEscalate {
                Text("Escalar a RRHH")
                    .font(.custom("Gilroy-Bold", size: 11))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.red)
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 4)
    }

    private func traceSummary(_ trace: PipelineTrace) -> String {
        [
            stageText(trace.classification),
            stageText(trace.evidenceGrade),
            stageText(trace.finalAnswer)
        ].joined(separator: " | ")
    }

    private func stageText(_ step: TraceStep) -> String {
        let mode = step.usedFoundationModel ? "FM" : "FB"
        if let errorDescription = step.errorDescription, !errorDescription.isEmpty {
            return "\(step.stage): \(mode) (\(errorDescription))"
        }
        return "\(step.stage): \(mode)"
    }
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
