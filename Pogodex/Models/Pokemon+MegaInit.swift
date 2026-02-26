import Foundation

extension Pokemon {
    /// Initialiseur pour créer un "faux" Pokémon à partir d'une Méga-Évolution.
    /// Cela permet d'afficher une page de détails complète pour la Méga.
    init(from mega: MegaEvolution, basePokemon: Pokemon) {
        self.init(
            id: mega.id,
            dexNr: basePokemon.dexNr, // Affiche le numéro du Pokemon de base (ex: #006 pour Charizard)
            generation: basePokemon.generation,
            names: mega.names ?? basePokemon.names, // Fallback sur les noms de base si nécessaire
            assets: Assets(image: mega.assets?.image, shinyImage: mega.assets?.shinyImage),
            assetForms: basePokemon.assetForms,
            primaryType: mega.primaryType,
            secondaryType: mega.secondaryType,
            stats: mega.stats,
            pokemonClass: "MEGA", // Classe personnalisée pour l'affichage
            evolutions: nil, // On ne montre pas la chaîne d'évolution pour éviter la confusion/boucles
            regionForms: nil,
            megaEvolutions: nil,
            hasMegaEvolution: false,
            hasGigantamaxEvolution: false
        )
    }
}
