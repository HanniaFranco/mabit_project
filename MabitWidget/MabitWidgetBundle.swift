//
//  MabitWidgetBundle.swift
//  MabitWidget
//
//  Created by Alumno on 05/05/26.
//

import WidgetKit
import SwiftUI

@main
struct MabitWidgetBundle: WidgetBundle {
    var body: some Widget {
        MabitWidget()
        MabitWidgetControl()
        MabitWidgetLiveActivity()
    }
}
