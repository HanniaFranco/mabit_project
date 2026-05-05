//
//  ContentView.swift
//  mabit_project
//
//  Created by Alumno on 05/05/26.
//


import SwiftUI
import SwiftData

extension Color {
    static let mabeBlue = Color(red: 36/255, green: 152/255, blue: 187/255)
}

struct ContentView: View {
    @State private var route: AppRoute = .splash

    var body: some View {
        NavigationStack {
            Group {
                switch route {
                case .splash:
                    SplashView {
                        route = .welcome
                    }
                case .welcome:
                    WelcomeView {
                        route = .login
                    }
                case .login:
                    LoginView {
                        route = .home
                    }
                case .home:
                    HomeView()
                }
            }
        }
    }
}

#Preview {
    ContentView()
}

private enum AppRoute {
    case splash
    case welcome
    case login
    case home
}

/*
struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
                ToolbarItem {
                    Button(action: addItem) {
                        Label("Add Item", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

*/
