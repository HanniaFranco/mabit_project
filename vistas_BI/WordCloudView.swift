//
//  WordCloudView.swift
//  Mabits
//

import SwiftUI

struct WordTopic: Identifiable {
    let id = UUID()
    let word: String
    let frequency: Int
}

struct WordCloudLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        calculateLayout(in: CGRect(origin: .zero, size: proposal.replacingUnspecifiedDimensions()), subviews: subviews, place: false)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        calculateLayout(in: bounds, subviews: subviews, place: true)
    }

    // Calcula tamaños y posiciones en una sola función para evitar duplicar lógica.
    @discardableResult
    private func calculateLayout(in bounds: CGRect, subviews: Subviews, place: Bool) -> CGSize {
        var currentX = bounds.minX
        var currentY = bounds.minY
        var rowHeight: CGFloat = 0

        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if currentX + size.width > bounds.maxX {
                currentX = bounds.minX
                currentY += rowHeight + spacing
                rowHeight = 0
            }
            if place {
                view.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            }
            rowHeight = max(rowHeight, size.height)
            currentX += size.width + spacing
        }
        return CGSize(width: bounds.width, height: currentY + rowHeight - bounds.minY)
    }
}

struct WordCloudView: View {
    let keywords: [WordTopic]

    // Scales the base font size with Dynamic Type
    @ScaledMetric(relativeTo: .body) private var baseFontSize: CGFloat = 12

    var body: some View {
        WordCloudLayout(spacing: 12) {
            ForEach(keywords) { item in
                let scaledSize = CGFloat(item.frequency) * 0.4 + baseFontSize
                Text(item.word)
                    .font(.system(size: scaledSize, weight: .semibold))
                    // Scales opacity with frequency to create natural visual weight hierarchy
                    .foregroundColor(.mablue.opacity(Double(item.frequency) / 85.0 + 0.3))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    // Ensures each chip meets 44pt minimum tap/touch target
                    .frame(minWidth: 44, minHeight: 44)
                    .background(.regularMaterial)
                    .cornerRadius(8)
                    // Announces word and relative frequency for VoiceOver
                    .accessibilityLabel("\(item.word), frecuencia \(item.frequency)")
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}
