//
//  SplashView.swift
//
//  Created by Hannia Naomi Arteaga Franco.
//

import SwiftUI

struct SplashView: View {
    let onFinished: () -> Void
    
    // Estas variables controlan animaciones
    @State private var showLogo = false
    @State private var showText = false
    
    var body: some View {
        
        // Fondo
        ZStack {
            Color.white
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                
                // LOGO
                Image("logo mabit")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 250)
                    
                    // Animaciones
                    .opacity(showLogo ? 1 : 0)
                    .scaleEffect(showLogo ? 1 : 0.8)
                
                .opacity(showText ? 1 : 0)

            }
        }
        
        // Cuando aparece la pantalla
        .onAppear {
            startAnimation()
        }
    }
    
    // Función que controla todo
    func startAnimation() {
        
        // 1. Logo aparece
        withAnimation(.easeOut(duration: 2.8)) {
            showLogo = true
        }
        
        // 2. Texto aparece después
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
            withAnimation(.easeIn(duration: 3.0)) {
                showText = true
            }
        }
        
        // 3. Ir a login
        DispatchQueue.main.asyncAfter(deadline: .now() + 5.5) {
            onFinished()
        }
    }
}

#Preview {
    SplashView { }
}
