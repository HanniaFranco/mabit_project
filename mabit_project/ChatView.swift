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
        isLoggedIn: false,
        employeeId: nil,
        country: nil,
        area: nil,
        biometricVerified: false
    )
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            if !engine.isReady {
                statusBanner
            }

            messageList
            inputBar
        }
        .background(Color(red: 230 / 255, green: 240 / 255, blue: 220 / 255).ignoresSafeArea())
        .navigationTitle("mabit chat")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if !engine.isReady && engine.errorMessage == nil {
                await engine.initialize()
            }
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

    private func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        messages.append(Message(text: text, isUser: true))
        inputText = ""
        isInputFocused = false

        Task {
            let response = await engine.ask(text, session: currentSession)
            messages.append(
                Message(
                    text: response.text,
                    isUser: false,
                    confidence: response.confidence,
                    shouldEscalate: response.shouldEscalate,
                    source: response.source,
                    intent: response.intent,
                    authLevel: response.authLevel,
                    reason: response.reason
                )
            )
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
