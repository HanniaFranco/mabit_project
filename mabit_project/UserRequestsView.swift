import SwiftUI

struct UserRequestsView: View {
    @State private var inbox = SupportInboxStore.shared

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 236 / 255, green: 244 / 255, blue: 235 / 255),
                    Color(red: 245 / 255, green: 239 / 255, blue: 230 / 255)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    headerCard

                    ForEach(inbox.requests) { request in
                        requestCard(for: request)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
            }
        }
        .navigationTitle("Mi usuario")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Solicitudes a RRHH")
                .font(.custom("Gilroy-Bold", size: 26))
                .foregroundStyle(Color.mabeBlue)

            Text("Consulta aqui las dudas que dejaste a RRHH y el estado de seguimiento de cada una.")
                .font(.custom("Gilroy-Regular", size: 15))
                .foregroundStyle(Color.black.opacity(0.65))

            HStack(spacing: 12) {
                statusChip(title: "\(inbox.requests.count) registradas", color: Color.mabeBlue)
                statusChip(title: "\(pendingCount) activas", color: Color(red: 182 / 255, green: 123 / 255, blue: 36 / 255))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.9))
        .clipShape(RoundedRectangle(cornerRadius: 26))
        .shadow(color: Color.black.opacity(0.06), radius: 16, x: 0, y: 10)
    }

    private func requestCard(for request: SupportRequest) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(request.title)
                        .font(.custom("Gilroy-Bold", size: 18))
                        .foregroundStyle(Color.mabeBlue)

                    Text(request.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.custom("Gilroy-Medium", size: 12))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(request.status.rawValue)
                    .font(.custom("Gilroy-Bold", size: 12))
                    .foregroundStyle(statusForegroundColor(for: request.status))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(statusBackgroundColor(for: request.status))
                    .clipShape(Capsule())
            }

            Text(request.question)
                .font(.custom("Gilroy-Regular", size: 15))
                .foregroundStyle(Color.black.opacity(0.78))

            Text(request.status.detailText)
                .font(.custom("Gilroy-Medium", size: 13))
                .foregroundStyle(Color.black.opacity(0.55))
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .shadow(color: Color.black.opacity(0.05), radius: 14, x: 0, y: 8)
    }

    private func statusChip(title: String, color: Color) -> some View {
        Text(title)
            .font(.custom("Gilroy-Bold", size: 12))
            .foregroundStyle(color)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }

    private func statusBackgroundColor(for status: SupportRequestStatus) -> Color {
        switch status {
        case .pending:
            return Color(red: 255 / 255, green: 244 / 255, blue: 222 / 255)
        case .inReview:
            return Color(red: 233 / 255, green: 245 / 255, blue: 255 / 255)
        case .answered:
            return Color(red: 226 / 255, green: 245 / 255, blue: 231 / 255)
        }
    }

    private func statusForegroundColor(for status: SupportRequestStatus) -> Color {
        switch status {
        case .pending:
            return Color(red: 157 / 255, green: 98 / 255, blue: 19 / 255)
        case .inReview:
            return Color.mabeBlue
        case .answered:
            return Color(red: 40 / 255, green: 129 / 255, blue: 78 / 255)
        }
    }

    private var pendingCount: Int {
        inbox.requests.filter { $0.status != .answered }.count
    }
}

#Preview {
    NavigationStack {
        UserRequestsView()
    }
}
