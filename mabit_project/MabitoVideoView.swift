//
//  MabitoVideoView.swift
//  mabit_project
//

import SwiftUI
import AVKit

struct MabitoVideoView: View {
    
    @State private var player: AVPlayer = AVPlayer()
    @State private var animate = false
    
    var body: some View {
        ZStack {
            
            // Círculo blanco de fondo
            Circle()
                .fill(Color.white)
                .frame(width: 90, height: 90)
                .shadow(radius: 6)
            
            // Video
            VideoPlayer(player: player)
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .onAppear {
                    setupVideo()
                }
        }
        // Animación
        .offset(y: animate ? -75 : -65)
        .animation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true), value: animate)
        .onAppear {
            animate = true
        }
    }
    
    private func setupVideo() {
        guard let url = Bundle.main.url(forResource: "mabito", withExtension: "mp4") else {
            print("No se encontró el video")
            return
        }
        
        player = AVPlayer(url: url)
        player.isMuted = true
        player.play()
        
  
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: .zero)
            player.play()
        }
    }
}
