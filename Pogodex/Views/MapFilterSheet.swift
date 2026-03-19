import SwiftUI

struct MapFilterSheet: View {
    @Binding var showRaids: Bool
    @Binding var showGyms: Bool
    @Binding var showWilds: Bool
    @Binding var teamFilter: Set<Int>
    @Binding var minIV: Double
    @Binding var searchText: String
    var onApply: () -> Void

    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Arènes & Raids") {
                    Toggle("Afficher les Arènes", isOn: $showGyms)
                    Toggle("Afficher les Raids", isOn: $showRaids)
                    
                    VStack(alignment: .leading) {
                        Text("Équipes")
                            .font(.subheadline)
                        HStack(spacing: 20) {
                            teamToggle(1, "M", .blue)
                            teamToggle(2, "V", .red)
                            teamToggle(3, "I", .yellow)
                            teamToggle(0, "N", .gray)
                        }
                        .padding(.vertical, 4)
                    }
                }

                Section("Pokémon Sauvages") {
                    Toggle("Afficher les Pokémon", isOn: $showWilds)
                    
                    if showWilds {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("IV Minimum: \(Int(minIV))%")
                            Slider(value: $minIV, in: 0...100, step: 5)
                            Text("Attention : Un IV bas chargera plus de données.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                        
                        TextField("Rechercher un Pokémon...", text: $searchText)
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }
            .navigationTitle("Filtres")
#if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
#endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fermer") {
                        dismiss()
                        onApply()
                    }
                }
            }
        }
    }

    private func teamToggle(_ id: Int, _ name: String, _ color: Color) -> some View {
        let isOn = teamFilter.contains(id)
        return Button(action: {
            if isOn { teamFilter.remove(id) } else { teamFilter.insert(id) }
        }) {
            Text(name)
                .font(.system(size: 16, weight: .bold))
                .frame(width: 36, height: 36)
                .background(isOn ? color.opacity(0.3) : Color.gray.opacity(0.1))
                .foregroundStyle(isOn ? color : .gray)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
