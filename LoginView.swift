//
//  LoginView.swift
//  mabit_project
//
//  Created by Alumno on 05/05/26.
//

import SwiftUI
import SwiftData

@Model
class User {
    var email: String
    var password: String
    
    init(email: String, password: String) {
        self.email = email
        self.password = password
    }
}

struct LoginView: View {
    
    @Environment(\.modelContext) private var context
    @Query private var users: [User]
    
    @State private var email = ""
    @State private var password = ""
    @State private var showPassword = false
    
    @State private var goToHome = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    @State private var goToRegister = false
    @State private var goToForgot = false
    
    @State private var showAlert = false
    @State private var message = ""
    
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        ZStack {
            
            Color(red: 230/255, green: 240/255, blue: 220/255)
                .ignoresSafeArea()
            
            VStack {
                
                // BOTÓN BACK
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "arrow.left")
                            .foregroundColor(Color.mabeBlue)
                            .padding()
                            .overlay(
                                Circle().stroke(Color.mabeBlue, lineWidth: 1)
                            )
                    }
                    Spacer()
                }
                .padding(.horizontal)
                
                Spacer(minLength: 0)
                
                // LOGO TEXTO
                HStack(spacing: 5) {
                    Text("mab")
                        .foregroundColor(.mabeBlue)
                        .font(.custom("Gilroy-Bold", size: 34))
                    
                    Text("it")
                        .foregroundColor(.black)
                        .font(.custom("Gilroy-Bold", size: 34))
                }
                
                Spacer(minLength: 0)
                
                // CARD
                VStack(spacing: 20) {
                    
                    Text("BIENVENIDO A mabit")
                        .foregroundColor(.gray)
                        .font(.custom("Gilroy-Medium", size: 16))
                        .padding(.top, 20)
                    
                    Spacer()
                        .frame(height: 10)
                    
                    TextField("Email address", text: $email)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(20)
                        .font(.custom("Gilroy-Regular", size: 16))
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                    
                    // Campo de contraseña con botón de ojo
                    HStack {
                        if showPassword {
                            TextField("Password", text: $password)
                                .font(.custom("Gilroy-Regular", size: 16))
                        } else {
                            SecureField("Password", text: $password)
                                .font(.custom("Gilroy-Regular", size: 16))
                        }
                        
                        Button(action: {
                            showPassword.toggle()
                        }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.mabeBlue)
                                .padding(.trailing, 8)
                        }
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(20)
                    
                    
                    Button(action: login) {
                        Text("Iniciar Sesión")
                            .foregroundColor(.white)
                            .font(.custom("Gilroy-Bold", size: 18))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.mabeBlue)
                            .cornerRadius(30)
                    }
                    .padding(.top, 30)
                    
                    Button("¿Has olvidado tu contraseña?") {
                        goToForgot = true
                    }
                    .foregroundColor(.black)
                    .font(.custom("Gilroy-Medium", size: 14))
                    
                    HStack(spacing: 4) {
                        Text("¿NO TIENES UNA CUENTA?")
                            .foregroundColor(.gray)
                            .font(.custom("Gilroy-Medium", size: 14))
                            .padding(.top, 50)
                        
                        Button("CREA UNA") {
                            goToRegister = true
                        }
                        .foregroundColor(.mabeBlue)
                        .font(.custom("Gilroy-Bold", size: 14))
                        .padding(.top, 50)
                    }
                }
                .padding(.vertical, 40)
                .padding(.horizontal, 30)
                .background(Color.white)
                .cornerRadius(40)
                .shadow(color: Color.black.opacity(0.05), radius: 10, x: 0, y: 4)
                .ignoresSafeArea(edges: .bottom)
                .padding(.bottom, -30)
            }
        }
        // ALERT DE ERROR
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        // ALERT DE LISTO
        .alert("Listo", isPresented: $showAlert) {
            Button("Continuar") {
                goToHome = true   // Se dispara la navegación
            }
        } message: {
            Text(message)
        }

        // FULL SCREEN COVERS
        .fullScreenCover(isPresented: $goToHome) {
            //HomeView()
        }
        .fullScreenCover(isPresented: $goToRegister) {
            //RegisterView()
        }
        .fullScreenCover(isPresented: $goToForgot) {
            //ForgotPasswordView()
        }
    }
    
    func login() {
        // VALIDACIONES LOCALES
        if email.isEmpty || password.isEmpty {
            errorMessage = "Por favor completa todos los campos"
            showError = true
            return
        }
        
        if !email.contains("@") {
            errorMessage = "Ingresa un correo válido"
            showError = true
            return
        }
        
        if password.count < 6 {
            errorMessage = "La contraseña debe tener al menos 6 caracteres"
            showError = true
            return
        }
        
        // VALIDAR CONTRA SWIFTDATA
        if let user = users.first(where: { $0.email == email }) {
            if user.password == password {
                message = "Sesión iniciada correctamente"
                showAlert = true
            } else {
                errorMessage = "La contraseña que ingresaste es incorrecta"
                showError = true
            }
        } else {
            errorMessage = "No existe ninguna cuenta registrada con este correo"
            showError = true
        }
    }

}

#Preview {
    LoginView()
}
