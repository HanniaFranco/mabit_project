import SwiftUI

struct ChatView: View {
    private static let initialGreeting = "Hola, soy mabit. Preguntame sobre vacaciones, nomina, beneficios o politicas de RRHH."

    @State private var engine = HRChatEngine()
    @State private var supportInbox = SupportInboxStore.shared
    @State private var inputText = ""
    @State private var messages: [Message] = [
        Message(
            text: Self.initialGreeting,
            isUser: false
        )
    ]
    @State private var currentSession = UserSession(
        isLoggedIn: false,
        employeeId: nil,
        country: nil,
        area: nil,
        biometricVerified: false
    )
    @State private var pendingProtectedQuestion: String?
    @State private var showBiometricPrompt = false
    @State private var authenticationErrorMessage: String?
    @State private var showAuthenticationError = false
    @State private var secureSessionExpiration: Date?
    @State private var remainingSecureSessionSeconds = 0
    @State private var isHumanSupportMode = false
    @State private var isChatLocked = false
    @State private var isHumanSupportUnavailable = false
    @State private var isAwaitingContinuationResponse = false
    @State private var showConversationEndOptions = false
    @State private var navigateToNPS = false
    @State private var pendingSupportQuestion: String?
    @State private var supportRequestDraft = ""
    @State private var showSupportRequestEditor = false
    @State private var humanSupportFollowUpTask: Task<Void, Never>?
    @FocusState private var isInputFocused: Bool
    @FocusState private var isSupportEditorFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isReady {
                statusBanner
            }

            if isSecureSessionActive {
                secureSessionBanner
            }

            if isHumanSupportMode {
                humanSupportBanner
            }

            messageList
            inputBar
        }
        .background(chatBackgroundColor.ignoresSafeArea())
        .navigationTitle("mabit chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !engine.isReady && engine.errorMessage == nil {
                await engine.initialize()
            }
        }
        .onReceive(timer) { _ in
            refreshSecureSessionTimer()
        }
        .onDisappear {
            humanSupportFollowUpTask?.cancel()
            clearSecureSession()
        }
        .sheet(isPresented: $showBiometricPrompt) {
            biometricPromptSheet
                .presentationDetents([.height(300)])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showSupportRequestEditor) {
            supportRequestEditorSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .navigationDestination(isPresented: $navigateToNPS) {
            NPSView()
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

    private var humanSupportBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "person.2.fill")
                .foregroundStyle(Color(red: 126 / 255, green: 84 / 255, blue: 33 / 255))

            VStack(alignment: .leading, spacing: 2) {
                Text("Seguimiento con RRHH")
                    .font(.custom("Gilroy-Bold", size: 13))
                    .foregroundStyle(.primary)
                Text("Este chat queda pausado mientras se da seguimiento a tu solicitud.")
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

                    if isHumanSupportUnavailable {
                        conversationSupportRequestCard
                    }

                    if showConversationEndOptions {
                        conversationEndOptionsCard
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
        VStack(spacing: 12) {
            HStack(alignment: .bottom, spacing: 12) {
                TextField(chatPlaceholder, text: $inputText, axis: .vertical)
                    .font(.custom("Gilroy-Regular", size: 16))
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .disabled(isChatLocked)
                    .onSubmit { sendMessage() }

                Button {
                    sendMessage()
                } label: {
                    Image(systemName: isChatLocked ? "lock.fill" : "arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(inputAccentColor)
                        .clipShape(Circle())
                }
                .disabled(isSendButtonDisabled)
                .opacity(isSendButtonDisabled ? 0.5 : 1)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 20)
        .background(inputBarBackgroundColor)
    }

    private var conversationSupportRequestCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Seguimiento disponible de forma asincrona")
                .font(.custom("Gilroy-Bold", size: 16))
                .foregroundStyle(Color(red: 96 / 255, green: 62 / 255, blue: 22 / 255))

            Text("Si lo deseas, puedes registrar tu consulta para que el equipo de RRHH la revise posteriormente y puedas consultar su estatus en User.")
                .font(.custom("Gilroy-Regular", size: 14))
                .foregroundStyle(Color.black.opacity(0.65))

            Button {
                presentSupportRequestEditor()
            } label: {
                Text(hasRegisteredPendingQuestion ? "Solicitud registrada" : "Registrar pregunta")
                    .font(.custom("Gilroy-Bold", size: 15))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(hasRegisteredPendingQuestion ? Color.gray : Color(red: 126 / 255, green: 84 / 255, blue: 33 / 255))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .disabled(hasRegisteredPendingQuestion)
        }
        .padding(16)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.top, 4)
    }

    private var conversationEndOptionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Confirmacion de cierre")
                .font(.custom("Gilroy-Bold", size: 16))
                .foregroundStyle(Color.mabeBlue)

            HStack(spacing: 10) {
                Button {
                    stayInConversation()
                } label: {
                    Text("No, quedarme")
                        .font(.custom("Gilroy-Bold", size: 15))
                        .foregroundStyle(Color.mabeBlue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.white)
                        .overlay(
                            RoundedRectangle(cornerRadius: 18)
                                .stroke(Color.mabeBlue.opacity(0.3), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }

                Button {
                    navigateToNPS = true
                } label: {
                    Text("Si, terminar")
                        .font(.custom("Gilroy-Bold", size: 15))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.mabeBlue)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.94))
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .padding(.top, 4)
    }

    private var supportRequestEditorSheet: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Puedes editar el texto antes de registrar la solicitud para que el equipo de RRHH reciba una descripcion clara de tu consulta.")
                    .font(.custom("Gilroy-Regular", size: 15))
                    .foregroundStyle(Color.black.opacity(0.68))

                VStack(alignment: .leading, spacing: 10) {
                    Text("Detalle de la solicitud")
                        .font(.custom("Gilroy-Bold", size: 15))
                        .foregroundStyle(Color.mabeBlue)

                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color(red: 247 / 255, green: 249 / 255, blue: 244 / 255))
                }
                .overlay(alignment: .topLeading) {
                    TextEditor(text: $supportRequestDraft)
                        .font(.custom("Gilroy-Regular", size: 16))
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .focused($isSupportEditorFocused)
                }
                .frame(minHeight: 280)

                Text("La solicitud quedara asociada a tu perfil para su seguimiento.")
                    .font(.custom("Gilroy-Medium", size: 13))
                    .foregroundStyle(Color.black.opacity(0.55))

                Button {
                    confirmSupportRequest()
                } label: {
                    Text("Confirmar y registrar")
                        .font(.custom("Gilroy-Bold", size: 16))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(red: 126 / 255, green: 84 / 255, blue: 33 / 255))
                        .clipShape(RoundedRectangle(cornerRadius: 20))
                }
                .disabled(supportRequestDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .opacity(supportRequestDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.45 : 1)

                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .background(Color(red: 252 / 255, green: 248 / 255, blue: 243 / 255))
            .navigationTitle("Registrar solicitud")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        showSupportRequestEditor = false
                    }
                    .font(.custom("Gilroy-Medium", size: 15))
                    .foregroundStyle(Color.mabeBlue)
                }
            }
            .onAppear {
                isSupportEditorFocused = true
            }
        }
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

    private var chatBackgroundColor: Color {
        if isHumanSupportMode {
            return Color(red: 243 / 255, green: 234 / 255, blue: 224 / 255)
        }
        return Color(red: 230 / 255, green: 240 / 255, blue: 220 / 255)
    }

    private var inputAccentColor: Color {
        isHumanSupportMode ? Color(red: 126 / 255, green: 84 / 255, blue: 33 / 255) : Color.mabeBlue
    }

    private var inputBarBackgroundColor: Color {
        isHumanSupportMode ? Color(red: 252 / 255, green: 248 / 255, blue: 243 / 255) : Color.white.opacity(0.96)
    }

    private var isSendButtonDisabled: Bool {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || engine.isProcessing || !engine.isReady || isChatLocked
    }

    private var chatPlaceholder: String {
        isChatLocked ? "Este chat quedo pausado por seguimiento con RRHH" : "Escribe tu pregunta..."
    }

    private var hasRegisteredPendingQuestion: Bool {
        guard let pendingSupportQuestion else { return false }
        return supportInbox.hasRequest(for: pendingSupportQuestion)
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
        guard !isChatLocked else { return }

        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        inputText = ""
        isInputFocused = false

        if handleConversationFlowDecision(for: text) {
            return
        }

        requestResponse(for: text, appendUserMessage: true)
    }

    private func requestResponse(for question: String, appendUserMessage: Bool) {
        if appendUserMessage {
            messages.append(Message(text: question, isUser: true))
        }

        Task {
            let response = await engine.ask(question, session: currentSession)
            let responseText = response.shouldEscalate
                ? "Por seguridad, no puedo confirmar estos datos sin una validacion adicional."
                : response.text
            let responseMessage = Message(
                text: responseText,
                isUser: false,
                confidence: response.confidence,
                shouldEscalate: false,
                source: response.shouldEscalate ? nil : response.source,
                intent: response.intent,
                authLevel: response.authLevel,
                reason: response.reason,
                answerSource: response.shouldEscalate ? nil : response.answerSource,
                trace: response.shouldEscalate ? nil : response.trace
            )
            messages.append(responseMessage)

            if response.shouldEscalate {
                isAwaitingContinuationResponse = false
                showConversationEndOptions = false
                pendingSupportQuestion = question
                startHumanSupportFlow()
            }

            if response.requiresBiometricVerification {
                isAwaitingContinuationResponse = false
                pendingProtectedQuestion = question
                showBiometricPrompt = true
            } else if !response.shouldEscalate {
                appendContinuationPrompt()
            }
        }
    }

    private func startHumanSupportFlow() {
        guard !isChatLocked else { return }

        humanSupportFollowUpTask?.cancel()

        messages.append(
            Message(
                text: "Estamos transfiriendo tu consulta al equipo de RRHH.",
                isUser: false,
                source: "Seguimiento"
            )
        )

        humanSupportFollowUpTask = Task {
            try? await Task.sleep(for: .seconds(4.2))
            guard !Task.isCancelled else { return }

            isHumanSupportMode = true
            isChatLocked = true
            isHumanSupportUnavailable = true
            isInputFocused = false
            inputText = ""

            messages.append(
                Message(
                    text: "RRHH",
                    isUser: false,
                    displayStyle: .systemDivider
                )
            )

            messages.append(
                Message(
                    text: "Por el momento, no hay personal de RRHH disponible para atender tu consulta en tiempo real.",
                    isUser: false,
                    displayStyle: .humanSupport,
                    source: "Canal humano"
                )
            )
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

    private func registerSupportRequest() {
        guard let pendingSupportQuestion, !hasRegisteredPendingQuestion else { return }

        supportInbox.createRequest(from: pendingSupportQuestion)
        messages.append(
            Message(
                text: "Tu consulta fue registrada correctamente. Podras revisar su estatus desde User.",
                isUser: false,
                displayStyle: .humanSupport,
                source: "Canal humano"
            )
        )
    }

    private func presentSupportRequestEditor() {
        guard let pendingSupportQuestion, !hasRegisteredPendingQuestion else { return }
        supportRequestDraft = pendingSupportQuestion
        showSupportRequestEditor = true
    }

    private func confirmSupportRequest() {
        let trimmedDraft = supportRequestDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedDraft.isEmpty else { return }

        pendingSupportQuestion = trimmedDraft
        showSupportRequestEditor = false
        registerSupportRequest()
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

    private func appendContinuationPrompt() {
        isAwaitingContinuationResponse = true
        showConversationEndOptions = false

        messages.append(
            Message(
                text: continuationPrompt,
                isUser: false,
                source: "Seguimiento"
            )
        )
    }

    private func handleConversationFlowDecision(for text: String) -> Bool {
        guard isAwaitingContinuationResponse else {
            showConversationEndOptions = false
            return false
        }

        if isNegativeContinuationResponse(text) {
            messages.append(Message(text: text, isUser: true))
            isAwaitingContinuationResponse = false
            messages.append(
                Message(
                    text: "Parece que no tienes mas dudas por el momento. Deseas terminar esta conversacion?",
                    isUser: false,
                    source: "Seguimiento"
                )
            )
            showConversationEndOptions = true
            return true
        }

        isAwaitingContinuationResponse = false
        showConversationEndOptions = false
        return false
    }

    private func stayInConversation() {
        showConversationEndOptions = false
        messages.append(
            Message(
                text: Self.initialGreeting,
                isUser: false,
                source: "mabit"
            )
        )
    }

    private var continuationPrompt: String {
        let prompts = [
            "Te puedo ayudar con algo mas?",
            "Tienes alguna otra duda?",
            "Si lo deseas, puedo apoyarte con otra consulta."
        ]
        return prompts[messages.filter { !$0.isUser }.count % prompts.count]
    }

    private func isNegativeContinuationResponse(_ text: String) -> Bool {
        let normalized = text
            .folding(options: .diacriticInsensitive, locale: .current)
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let exactMatches = [
            "no",
            "nop",
            "nope",
            "nel",
            "ninguna",
            "ninguno",
            "nada mas",
            "nada más",
            "ya no",
            "estoy bien",
            "todo bien",
            "eso es todo"
        ]

        return exactMatches.contains(normalized)
    }
}

private struct ChatBubble: View {
    let message: Message

    var body: some View {
        if message.displayStyle == .systemDivider {
            systemDivider
        } else {
            bubbleRow
        }
    }

    private var bubbleRow: some View {
        HStack {
            if message.isUser { Spacer(minLength: 48) }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: 6) {
                if message.displayStyle == .humanSupport {
                    Text("RRHH humano")
                        .font(.custom("Gilroy-Bold", size: 11))
                        .foregroundStyle(Color(red: 126 / 255, green: 84 / 255, blue: 33 / 255))
                        .padding(.horizontal, 4)
                }

                Text(message.text)
                    .font(.custom("Gilroy-Regular", size: 16))
                    .foregroundStyle(foregroundColor)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(bubbleBackgroundColor)
                    .clipShape(RoundedRectangle(cornerRadius: 22))

                if !message.isUser {
                    messageMetadata
                }
            }

            if !message.isUser { Spacer(minLength: 48) }
        }
    }

    private var systemDivider: some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Color.gray.opacity(0.35))
                .frame(height: 1)

            Text(message.text)
                .font(.custom("Gilroy-Medium", size: 12))
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(Color.gray.opacity(0.35))
                .frame(height: 1)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 8)
    }

    private var bubbleBackgroundColor: Color {
        if message.isUser {
            return Color.mabeBlue
        }
        if message.displayStyle == .humanSupport {
            return Color(red: 248 / 255, green: 241 / 255, blue: 232 / 255)
        }
        return Color.white
    }

    private var foregroundColor: Color {
        if message.isUser {
            return .white
        }
        if message.displayStyle == .humanSupport {
            return Color(red: 96 / 255, green: 62 / 255, blue: 22 / 255)
        }
        return .primary
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
                    .foregroundStyle(message.displayStyle == .humanSupport ? Color(red: 126 / 255, green: 84 / 255, blue: 33 / 255) : .secondary)
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
}

#Preview {
    NavigationStack {
        ChatView()
    }
}
