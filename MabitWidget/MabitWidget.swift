//
//  MabitWidget.swift
//  MabitWidget
//
//  Created by Alumno on 05/05/26.
//

import WidgetKit
import SwiftUI

struct Provider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: ConfigurationAppIntent())
    }

    func snapshot(for configuration: ConfigurationAppIntent, in context: Context) async -> SimpleEntry {
        SimpleEntry(date: Date(), configuration: configuration)
    }
    
    func timeline(for configuration: ConfigurationAppIntent, in context: Context) async -> Timeline<SimpleEntry> {
        var entries: [SimpleEntry] = []

        // Generate a timeline consisting of five entries an hour apart, starting from the current date.
        let currentDate = Date()
        for hourOffset in 0 ..< 5 {
            let entryDate = Calendar.current.date(byAdding: .hour, value: hourOffset, to: currentDate)!
            let entry = SimpleEntry(date: entryDate, configuration: configuration)
            entries.append(entry)
        }

        return Timeline(entries: entries, policy: .atEnd)
    }

//    func relevances() async -> WidgetRelevances<ConfigurationAppIntent> {
//        // Generate a list containing the contexts this widget is relevant in.
//    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let configuration: ConfigurationAppIntent
}

struct MabitWidgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.mabeBlue, Color.mabeBlue.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .scaledToFill()


            VStack(alignment: .leading, spacing: 10) {
                
                HStack {
                    Text("mabit")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "sparkles")
                        .foregroundColor(.white.opacity(0.8))
                }

                Text("¿Tienes dudas?")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)

                Text("Pregunta sobre beneficios, cultura o oportunidades")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.85))

                Spacer()

                HStack {
                    Image(systemName: "message.fill")
                    Text("Abrir chat")
                }
                .font(.caption)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.2))
                .clipShape(Capsule())
                .foregroundColor(.white)
            }
            .padding()
    
        }
    }
}
struct MabitWidget: Widget {
    let kind: String = "MabitWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: ConfigurationAppIntent.self, provider: Provider()) { entry in
            MabitWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "mabit://chat"))

        }
    }
}

extension ConfigurationAppIntent {
    fileprivate static var smiley: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "😀"
        return intent
    }
    
    fileprivate static var starEyes: ConfigurationAppIntent {
        let intent = ConfigurationAppIntent()
        intent.favoriteEmoji = "🤩"
        return intent
    }
}

#Preview(as: .systemSmall) {
    MabitWidget()
} timeline: {
    SimpleEntry(date: .now, configuration: .smiley)
    SimpleEntry(date: .now, configuration: .starEyes)
}
