import SwiftUI
import Combine

/// Vue des réglages de l'application.
struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: PogodexViewModel
    @State private var showResetAlert = false
    @AppStorage("app_language") private var storedLanguage: String?
    @AppStorage("trainer_nickname") private var trainerNickname: String = ""
    @AppStorage("app_theme") private var appTheme: Int = 0
    @AppStorage("app_store_mode") private var isAppStoreMode: Bool = false
    @AppStorage("pogomap_auth_username") private var pogoMapUsername: String = ""
    @AppStorage("pogomap_auth_password") private var pogoMapPassword: String = ""
    @State private var selectedLanguage = CurrentPokemonLanguageKey
    @State private var resetConfirmationText = ""
    @State private var showCredits = false
    @State private var pogoMapCookieStatus: String?

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
    
    private var colorScheme: ColorScheme? {
        switch appTheme {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 44))
                            .foregroundStyle(.blue)
                        
                        HStack(spacing: 4) {
                            ZStack(alignment: .leading) {
                                if trainerNickname.isEmpty {
                                    Text("Dresseur")
                                        .font(.system(size: 18, weight: .bold, design: .rounded))
                                        .foregroundStyle(.primary.opacity(0.7))
                                }
                                TextField("", text: $trainerNickname)
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.primary)
                            }
                            .fixedSize() // Empêche le TextField de prendre toute la largeur, mais garde la taille du placeholder
                            
                            Image(systemName: "pencil")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                        }
                        
                        Spacer()
                        
                        // Indicateur iCloud minimaliste
                        if viewModel.isCloudSyncActive {
                            if viewModel.isSyncing {
                                HStack(spacing: 4) {
                                    Text("Synchro...")
                                        .font(.system(size: 11, weight: .medium, design: .rounded))
                                        .foregroundStyle(.secondary)
                                    Image(systemName: "arrow.triangle.2.circlepath.icloud")
                                        .font(.system(size: 16))
                                        .foregroundStyle(.blue)
                                        .symbolEffect(.bounce, options: .repeating)
                                }
                                .padding(.trailing, 8)
                            } else {
                                Image(systemName: "checkmark.icloud")
                                    .font(.system(size: 16))
                                    .foregroundStyle(.green)
                                    .padding(.trailing, 8)
                            }
                        } else {
                            Image(systemName: "xmark.icloud")
                                .font(.system(size: 16))
                                .foregroundStyle(.red)
                                .padding(.trailing, 8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                
                Section("Général") {
                    Picker(selection: $selectedLanguage) {
                        Text("English").tag("English")
                        Text("Français").tag("French")
                        Text("Deutsch").tag("German")
                        Text("Español").tag("Spanish")
                        Text("Italiano").tag("Italian")
                        Text("日本語").tag("Japanese")
                        Text("한국어").tag("Korean")
                    } label: {
                        Label("Langue des Pokémon", systemImage: "globe")
                    }
                    .onChange(of: selectedLanguage) { _, newValue in
                        storedLanguage = newValue
                        CurrentPokemonLanguageKey = newValue
                        viewModel.objectWillChange.send()
                    }
                    
                    Picker(selection: $appTheme) {
                        Text("Système").tag(0)
                        Text("Clair").tag(1)
                        Text("Sombre").tag(2)
                    } label: {
                        Label("Apparence", systemImage: "paintbrush")
                    }
                    
                    Toggle(isOn: $isAppStoreMode) {
                        Label("Pixéliser les Pokémon (App Store)", systemImage: "squareshape.split.3x3")
                    }
                    
                    #if DEBUG
                    Label("Notifications", systemImage: "bell.badge")
                    #endif
                }
                
                Section("Données") {
                    #if DEBUG
                    Label("Exporter mes données", systemImage: "square.and.arrow.up")
                    #endif

                    Button(role: .destructive) {
                        showResetAlert = true
                    } label: {
                        Label("Réinitialiser la progression", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(.red)
                    }
                }

                Section("PogoMap") {
                    TextField("Identifiant", text: $pogoMapUsername)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    SecureField("Mot de passe", text: $pogoMapPassword)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)

                    Button {
                        Task {
                            pogoMapCookieStatus = "Connexion en cours..."
                            let success = await PogoMapFetcher.refreshSessionCookieWithCredentialsPublic()
                            pogoMapCookieStatus = success
                                ? "Cookie PogoMap mis à jour avec succès !"
                                : "Échec de connexion (vérifiez vos identifiants)."
                        }
                    } label: {
                        Label("Se connecter à PogoMap", systemImage: "network")
                    }
                    .disabled(pogoMapUsername.isEmpty || pogoMapPassword.isEmpty)

                    if let pogoMapCookieStatus {
                        Text(pogoMapCookieStatus)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("À propos") {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    
                    Button {
                        showCredits = true
                    } label: {
                        Label("Crédits & Mentions légales", systemImage: "doc.text")
                            .foregroundStyle(.primary)
                    }
                }
            }
            .navigationTitle("Réglages")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("OK") {
                        dismiss()
                    }
                    .buttonStyle(.glassProminent)
                }
            }
            .sheet(isPresented: $showCredits) {
                CreditsView()
            }
            .alert("Réinitialiser les données ?", isPresented: $showResetAlert) {
                TextField("Tapez 'Pogodex'", text: $resetConfirmationText)
                    .textInputAutocapitalization(.never)
                    .disableAutocorrection(true)
                
                Button("Annuler", role: .cancel) { 
                    resetConfirmationText = ""
                }
                
                Button("Réinitialiser", role: .destructive) {
                    if resetConfirmationText.lowercased() == "pogodex" {
                        viewModel.resetAllData()
                        dismiss()
                    }
                    resetConfirmationText = ""
                }
                .disabled(resetConfirmationText.lowercased() != "pogodex")
            } message: {
                Text("Êtes-vous sûr de vouloir effacer toutes vos captures ? Cette action est irréversible. Tapez 'Pogodex' pour confirmer.")
            }
        }
        .task {
            selectedLanguage = storedLanguage ?? CurrentPokemonLanguageKey
        }
        .preferredColorScheme(colorScheme)
        .animation(.easeInOut, value: appTheme)
    }
}
