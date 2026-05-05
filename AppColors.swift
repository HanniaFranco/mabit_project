//
//  AppColors.swift
//  mabit_project
//
//  Created by Alumno on 05/05/26.
//

import Foundation
import SwiftUI

extension Color {
    static let mabeBlue = Color(red: 36/255, green: 152/255, blue: 187/255)
    static let mablue = mabeBlue
}

extension ShapeStyle where Self == Color {
    static var mabeBlue: Color { Color.mabeBlue }
    static var mablue: Color { Color.mablue }
}
