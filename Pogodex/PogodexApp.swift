//
//  PogodexApp.swift
//  Pogodex
//
//  Created by Matthéo Ribeiro on 2/15/26.
//

import SwiftUI

@main
struct PogodexApp: App {
    @StateObject private var viewModel = PogodexViewModel()
    @AppStorage("app_theme") private var appTheme: Int = 0
    
    @Environment(\.locale) var locale
    
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    var body: some Scene {
        WindowGroup {
            TabView {
                Tab {
                    ContentView(viewModel: viewModel)
                } label: {
                    Label("Pokédex", systemImage: "circle.grid.3x3.fill")
                }
                
                Tab {
                    NavigationStack {
                        VStack(spacing: 16) {
                            Image(systemName: "questionmark.circle")
                                .font(.system(size: 40))
                                .foregroundStyle(.tertiary)
                            Text("À venir...")
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(UIColor.systemGroupedBackground))
                        .navigationTitle("??")
                    }
                } label: {
                    Label("??", systemImage: "questionmark")
                }
                
                Tab(role: .search) {
                    SearchView(viewModel: viewModel)
                }
            }
            .id(locale.identifier)
            .preferredColorScheme(colorScheme)
            .animation(.easeInOut, value: appTheme)
            .onAppear {
                updatePokemonLanguage(with: locale)
                
                if viewModel.pokemons.isEmpty {
                    Task { await viewModel.fetchPokemon() }
                }
            }
            .onChange(of: locale) { oldLocale, newLocale in
                updatePokemonLanguage(with: newLocale)
            }
        }
    }
}


