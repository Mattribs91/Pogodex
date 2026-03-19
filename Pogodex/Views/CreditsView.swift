import SwiftUI

struct CreditsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List {
                // MARK: - Disclaimer
                Section {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.yellow)
                            Text("Avertissement Légal")
                                .font(.headline)
                        }
                        .padding(.bottom, 4)
                        
                        Text("Pokémon et Pokémon GO sont des marques déposées de The Pokémon Company, Niantic, Inc., et Nintendo.")
                            .font(.subheadline)
                        
                        Text("Cette application est un outil non officiel créé par des fans et n'est ni affiliée, ni approuvée, ni sponsorisée par Niantic, The Pokémon Company ou Nintendo.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        
                        Text("Toutes les images, noms et informations de Pokémon sont utilisés dans le cadre du \"Fair Use\" à des fins informatives.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Data Sources
                Section(header: Text("Sources de Données")) {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "server.rack")
                                .foregroundStyle(.blue)
                            Text("Pokémon GO API")
                                .font(.headline)
                        }
                        Text("Données fournies par la communauté open-source Pokémon GO API.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link(destination: URL(string: "https://github.com/pokemon-go-api/pokemon-go-api")!) {
                            HStack {
                                Text("github.com/pokemon-go-api")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "photo.artframe")
                                .foregroundStyle(.purple)
                            Text("PokéAPI")
                                .font(.headline)
                        }
                        Text("Artworks et sprites haute résolution fournis par PokéAPI.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Link(destination: URL(string: "https://pokeapi.co")!) {
                            HStack {
                                Text("pokeapi.co")
                                Spacer()
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        .padding(.top, 4)
                    }
                    .padding(.vertical, 4)
                }
                
                // MARK: - Developer
                Section {
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red)
                        Text("Créé avec passion pour la communauté Pokémon GO.")
                            .font(.subheadline)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Crédits & Mentions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fermer") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    CreditsView()
}
