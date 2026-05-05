//
//  WelcomeView.swift
//  
//
//  Created by Hannia Naomi Arteaga Franco
//

import SwiftUI

struct WelcomeView: View {
    
    @State private var showContent = false
    @State private var goToHome = false
    
    var body: some View {
        ZStack {
            
            // Fondo verde
            Color.white
                .ignoresSafeArea()
            
            VStack {
                
                Spacer()
                
                // TEXTOS
                VStack(spacing: 0) {
                    Text("Bienvenido")
                        .font(.custom("Poppins-Bold", size: 38))
                        .foregroundColor(.mabeBlue)
                        .padding(.top, 60)
                    
                    Text("a mabit")
                        .font(.custom("Gilroy-Regular", size: 34))
                        .foregroundColor(.mabeBlue)
                    
                    Text("Una experiencia inteligente que te escucha y te acompaña")
                        .font(.custom("Poppins-Regular", size: 20))
                        .foregroundColor(.black.opacity(0.8))
                        .padding(.top, 15)
                        .padding(.horizontal, 50)
                        .multilineTextAlignment(.center)
    
                }
                .opacity(showContent ? 1 : 0)
                .offset(y: showContent ? 0 : -20)
                
                //Spacer()
                
                // IMAGEN
                
                /*
                Image("welcomeImage")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 414, height: 554)
                    .opacity(showContent ? 1 : 0)
                    .scaleEffect(showContent ? 1 : 0.9)
                    .padding(.top, 100)
                
                 */
                
                GeometryReader { geometry in
                    Image("welcomeimage")
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.height * 1.3) // ocupa 70% del alto
                        .clipped()
                        .opacity(showContent ? 1 : 0)
                        .scaleEffect(showContent ? 1 : 0.9)
                        .padding(.top, 20)
                }
                 
                
                // BOTÓN
                Button(action: {
                    goToHome = true
                }) {
                    Text("Siguiente")
                        .font(.custom("Gilroy-Medium", size: 18))
                        .foregroundColor(.mabeBlue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.9))
                        .cornerRadius(30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 30)
                                .stroke(Color.mabeBlue, lineWidth: 1.5)
                        )
                }
                .padding(.horizontal, 30)
                .padding(.bottom, 60)
                .opacity(showContent ? 1 : 0)
                
            }
        }
        .onAppear {
            startAnimation()
        }
        .fullScreenCover(isPresented: $goToHome) {
            HomeView()
        }
    }
    
    func startAnimation() {
        withAnimation(.easeOut(duration: 1.2)) {
            showContent = true
        }
    }
}

#Preview {
    WelcomeView()
}
