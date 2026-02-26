import Foundation

/// Dictionnaire associant l'ID d'un Pokémon à sa région d'exclusivité dans le monde réel.
let regionalLocations: [Int: String] = [
    83: "Asie (Japon, Corée du Sud, Taïwan, Hong Kong)", // Canarticho
    115: "Australie et Nouvelle-Zélande", // Kangourex
    122: "Europe", // M. Mime
    128: "Amérique du Nord", // Tauros
    214: "Amérique du Sud, Amérique Centrale, et parties de l'Amérique du Nord", // Scarhino
    222: "Océanie, Asie de l'Est, et parties de l'Amérique du Nord et du Sud", // Corayon
    313: "Amérique du Nord, Amérique du Sud, et Afrique", // Mucuscule
    314: "Europe, Asie, et Océanie", // Lumivole
    324: "Hémisphère Ouest", // Chartor
    335: "Europe, Asie, et Océanie", // Mangriff
    336: "Amérique du Nord, Amérique du Sud, et Afrique", // Séviper
    337: "Amérique du Nord, Amérique du Sud, et Afrique", // Séléroc
    338: "Europe, Asie, et Océanie", // Solaroc
    357: "Amérique du Sud, Amérique Centrale, et parties de l'Amérique du Nord", // Tropius
    369: "Nouvelle-Zélande et îles environnantes", // Relicanth
    417: "Hémisphère Nord", // Pachirisu
    422: "Hémisphère Ouest", // Sancoki (Mer Occidentale)
    423: "Hémisphère Est", // Sancoki (Mer Orientale)
    439: "Europe", // Mime Jr.
    441: "Hémisphère Nord", // Pijako
    455: "Hémisphère Sud", // Vortente
    480: "Europe, Asie, et Océanie", // Créhelf
    481: "Amérique du Nord, Amérique du Sud, et Groenland", // Créfollet
    482: "Asie-Pacifique", // Créfadet
    511: "Hémisphère Ouest", // Feuillajou
    513: "Europe, Asie, et Océanie", // Flamajou
    515: "Asie-Pacifique", // Flotajou
    538: "Hémisphère Ouest", // Judokrak
    539: "Hémisphère Est", // Karaclée
    545: "Hémisphère Ouest", // Venipatte
    550: "Hémisphère Ouest", // Bargantua (Motif Rouge)
    556: "Hémisphère Sud", // Maracachi
    561: "Hémisphère Nord", // Cryptéro
    626: "Amérique du Nord", // Frison
    631: "Hémisphère Ouest", // Aflamanoir
    632: "Hémisphère Est", // Fermite
    669: "Europe, Asie, et Océanie", // Flabébé (Fleur Rouge)
    670: "Hémisphère Ouest", // Flabébé (Fleur Bleue)
    671: "Hémisphère Est", // Flabébé (Fleur Jaune)
    701: "Hémisphère Nord", // Brutalibré
    707: "Europe", // Trousselin
    741: "Hémisphère Ouest", // Plumeline (Style Pom-Pom)
    742: "Hémisphère Est", // Plumeline (Style Hula)
    764: "Hémisphère Ouest", // Guérilande
    797: "Hémisphère Nord", // Bamboiselle
    798: "Hémisphère Sud" // Katagami
]

/// Dictionnaire associant l'ID d'un Pokémon ET sa forme à sa région d'exclusivité.
/// Clé : "ID_FORME" (ex: "741_POM_POM")
let regionalFormLocations: [String: String] = [
    // Tauros (128)
    "128_PALDEA_BLAZE": "Amériques et Afrique", // Race Combative (Feu)
    "128_PALDEA_AQUA": "Europe, Asie, et Océanie", // Race Aquatique (Eau)
    
    // Sancoki (422) & Tritosor (423)
    "422_WEST_SEA": "Hémisphère Ouest",
    "422_EAST_SEA": "Hémisphère Est",
    "423_WEST_SEA": "Hémisphère Ouest",
    "423_EAST_SEA": "Hémisphère Est",
    
    // Bargantua (550)
    "550_RED_STRIPED": "Hémisphère Est",
    "550_BLUE_STRIPED": "Hémisphère Ouest",
    
    // Flabébé (669), Floette (670), Florges (671)
    "669_RED": "Europe, Asie, Océanie",
    "669_BLUE": "Hémisphère Ouest",
    "669_YELLOW": "Hémisphère Est",
    "670_RED": "Europe, Asie, Océanie",
    "670_BLUE": "Hémisphère Ouest",
    "670_YELLOW": "Hémisphère Est",
    "671_RED": "Europe, Asie, Océanie",
    "671_BLUE": "Hémisphère Ouest",
    "671_YELLOW": "Hémisphère Est",
    
    // Couafarel (676)
    "676_DEBUTANTE": "Amériques",
    "676_DIAMOND": "Europe, Moyen-Orient, Afrique",
    "676_STAR": "Asie-Pacifique",
    "676_LA_REINE": "France",
    "676_KABUKI": "Japon",
    "676_PHARAOH": "Égypte",
    
    // Plumeline (741)
    "741_BAILE": "Europe, Moyen-Orient, Afrique",
    "741_POMPOM": "Amériques",
    "741_PAU": "Îles d'Afrique, Asie, Pacifique",
    "741_SENSU": "Asie-Pacifique"
]
