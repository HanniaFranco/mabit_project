//
//  MabitWidgetLiveActivity.swift
//  MabitWidget
//
//  Created by Alumno on 05/05/26.
//

import ActivityKit
import WidgetKit
import SwiftUI

struct MabitWidgetAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        // Dynamic stateful properties about your activity go here!
        var emoji: String
    }

    // Fixed non-changing properties about your activity go here!
    var name: String
}

struct MabitWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: MabitWidgetAttributes.self) { context in
            // Lock screen/banner UI goes here
            VStack {
                Text("Hello \(context.state.emoji)")
            }
            .activityBackgroundTint(Color.cyan)
            .activitySystemActionForegroundColor(Color.black)

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI goes here.  Compose the expanded UI through
                // various regions, like leading/trailing/center/bottom
                DynamicIslandExpandedRegion(.leading) {
                    Text("Leading")
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("Trailing")
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text("Bottom \(context.state.emoji)")
                    // more content
                }
            } compactLeading: {
                Text("L")
            } compactTrailing: {
                Text("T \(context.state.emoji)")
            } minimal: {
                Text(context.state.emoji)
            }
            .widgetURL(URL(string: "http://www.apple.com"))
            .keylineTint(Color.red)
        }
    }
}

extension MabitWidgetAttributes {
    fileprivate static var preview: MabitWidgetAttributes {
        MabitWidgetAttributes(name: "World")
    }
}

extension MabitWidgetAttributes.ContentState {
    fileprivate static var smiley: MabitWidgetAttributes.ContentState {
        MabitWidgetAttributes.ContentState(emoji: "😀")
     }
     
     fileprivate static var starEyes: MabitWidgetAttributes.ContentState {
         MabitWidgetAttributes.ContentState(emoji: "🤩")
     }
}

#Preview("Notification", as: .content, using: MabitWidgetAttributes.preview) {
   MabitWidgetLiveActivity()
} contentStates: {
    MabitWidgetAttributes.ContentState.smiley
    MabitWidgetAttributes.ContentState.starEyes
}
