//
//  MainTabView.swift
//  mabit_project
//
//  Created by Hannia on 05/05/26.
//

import SwiftUI
import AVKit


struct HomeView: View {
    
    @Binding var goToChat: Bool

    var body: some View {
        ZStack(alignment: .bottom) {
            
            
            ScrollView {
                VStack(spacing: 30) {
                    AnimatedImageCard(imageName: "cultura",
                                      title: "Cultura Mabe",
                                      description: "Innovación, trabajo en equipo y crecimiento personal.")
                    
                    AnimatedImageCard(imageName: "beneficios",
                                      title: "Beneficios Generales",
                                      description: "Seguro médico, bienestar, descuentos en productos y más.")
                    
                    AnimatedImageCard(imageName: "oportunidades",
                                      title: "Oportunidades",
                                      description: "Explora vacantes y programas de desarrollo.")
                    
                    ProgramCard(title: "Universidad Mabe",
                                description: "Capacitación continua con cursos y certificaciones.")
                    
                    ProgramCard(title: "Compra de Productos",
                                description: "Electrodomésticos Mabe con descuentos exclusivos.")
                    
                    FakeVideoCard(imageName: "testimonio1",
                                  title: "María - Ingeniera de Producto",
                                  description: "Crecí profesionalmente y aporto a proyectos innovadores.")
                    
                    FakeVideoCard(imageName: "testimonio2",
                                  title: "Carlos - Área Comercial",
                                  description: "Encontré un equipo que me inspira cada día.")
                    
                    AnimatedImageCard(imageName: "porque",
                                      title: "¿Por qué trabajar en Mabe?",
                                      description: "Líderes en innovación, estabilidad laboral y crecimiento.")
                }
                .padding(.vertical, 10)
                .padding(.bottom, 110)
            }
            .navigationTitle("Inicio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                    } label: {
                        Image(systemName: "person.crop.circle")
                            .font(.title3)
                            .foregroundStyle(Color.mabeBlue)
                    }
                }
            }

            // BOTÓN
            NavigationLink {
                ChatView()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "message.fill")
                        .font(.headline)
                    Text("Hazme una pregunta!")
                        .font(.custom("Gilroy-Bold", size: 18))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.mabeBlue)
                .clipShape(Capsule())
                .shadow(color: Color.mabeBlue.opacity(0.28), radius: 14, x: 0, y: 10)
            }
            .padding(.bottom, 24)
        }

        .navigationDestination(isPresented: $goToChat) {
            ChatView()
        }
        .onDisappear {
            goToChat = false
        }
    }
}


struct AnimatedImageCard: View {
    var imageName: String
    var title: String
    var description: String
    
    @State private var animate = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(imageName)
                .resizable()
                .scaledToFill()
                .frame(height: 200)
                .clipped()
                .cornerRadius(20)
                .shadow(radius: 5)
                .scaleEffect(animate ? 1.02 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: animate)
                .onAppear { animate = true }
            
            Text(title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.mabeBlue)
            
            Text(description)
                .font(.body)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

struct ProgramCard: View {
    var title: String
    var description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.mabeBlue)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.white)
        .cornerRadius(15)
        .shadow(color: Color.black.opacity(0.05), radius: 6, x: 0, y: 3)
        .padding(.horizontal)
    }
}

struct FakeVideoCard: View {
    var imageName: String
    var title: String
    var description: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                Image(imageName)
                    .resizable()
                    .scaledToFill()
                    .frame(height: 200)
                    .clipped()
                    .cornerRadius(15)
                
                // Ícono de play encima
                Image(systemName: "play.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 60, height: 60)
                    .foregroundColor(.white)
                    .shadow(radius: 5)
            }
            
            Text(title)
                .font(.headline)
                .foregroundColor(.mabeBlue)
            Text(description)
                .font(.subheadline)
                .foregroundColor(.gray)
        }
        .padding()
    }
}

/*
 #Preview {
 NavigationStack {
 HomeView()
 }
 }
 
 */
