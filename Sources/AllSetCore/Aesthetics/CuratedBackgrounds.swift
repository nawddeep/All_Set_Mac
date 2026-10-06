import Foundation

/// A themed set of photos for widget and wallpaper backgrounds.
public struct BackgroundCollection: Identifiable, Sendable {
    public let title: String
    public let symbol: String
    public let photos: [WebPhoto]

    public var id: String { title }
}

/// Hand-picked photos that make good backgrounds: Unsplash photos served by
/// Picsum, then CC0 photos from Openverse for the football and music themes;
/// calm enough for text on top, and chosen from the whole library by eye.
public enum CuratedBackgrounds {
    public static let collections: [BackgroundCollection] = [
        BackgroundCollection(title: "Night & Stars", symbol: "moon.stars.fill", photos: [
            WebPhoto(id: "120", author: "Guillaume", width: 4928, height: 3264),
            WebPhoto(id: "537", author: "Juskteez Vu", width: 2291, height: 3450),
            WebPhoto(id: "654", author: "Josh Felise", width: 2509, height: 1673),
            WebPhoto(id: "681", author: "Axel  Antas-Bergkvist", width: 5000, height: 2951),
            WebPhoto(id: "683", author: "ahmadreza sajadi", width: 5000, height: 2577),
            WebPhoto(id: "724", author: "Nelly Volkovich", width: 5000, height: 3333),
            WebPhoto(id: "825", author: "Michael Hull", width: 5000, height: 3333),
            WebPhoto(id: "869", author: "Caleb Ralston", width: 2000, height: 1333),
            WebPhoto(id: "901", author: "Marcelo Quinan", width: 4016, height: 4016),
            WebPhoto(id: "903", author: "Greg Rakozy", width: 5000, height: 3333),
            WebPhoto(id: "974", author: "Greg Rakozy", width: 5000, height: 2589),
            WebPhoto(id: "981", author: "Anna Anikina", width: 4200, height: 5000),
            WebPhoto(id: "1022", author: "Vashishtha Jogi", width: 5000, height: 2813),
            WebPhoto(id: "967", author: "NASA", width: 4928, height: 3280),
            WebPhoto(id: "831", author: "Luke Pamer", width: 5000, height: 3333),
        ]),
        BackgroundCollection(title: "Golden Hour", symbol: "sun.horizon.fill", photos: [
            WebPhoto(id: "27", author: "Yoni Kaplan-Nadel", width: 3264, height: 1836),
            WebPhoto(id: "110", author: "Kenneth Thewissen", width: 5000, height: 3333),
            WebPhoto(id: "129", author: "Charlie Foster", width: 4910, height: 3252),
            WebPhoto(id: "132", author: "Peter Besser", width: 1600, height: 1066),
            WebPhoto(id: "176", author: "Good Free Photos", width: 2500, height: 1662),
            WebPhoto(id: "213", author: "Kelly Sikkema", width: 4928, height: 3264),
            WebPhoto(id: "362", author: "Ry Van", width: 4438, height: 2954),
            WebPhoto(id: "385", author: "Griffin Keller", width: 5000, height: 3333),
            WebPhoto(id: "499", author: "Gabriel Santiago", width: 5000, height: 3333),
            WebPhoto(id: "505", author: "lee Scott", width: 2000, height: 1333),
            WebPhoto(id: "705", author: "Breno Machado", width: 5000, height: 3333),
            WebPhoto(id: "715", author: "Leah Tardivel", width: 4272, height: 2848),
            WebPhoto(id: "765", author: "Grant McIver", width: 4586, height: 3439),
            WebPhoto(id: "769", author: "Blake Richard Verdoorn", width: 5000, height: 3333),
            WebPhoto(id: "788", author: "Michael Baird", width: 3648, height: 2736),
            WebPhoto(id: "794", author: "Lauren Coleman", width: 5000, height: 3333),
            WebPhoto(id: "865", author: "Federico Bottos", width: 2000, height: 1333),
            WebPhoto(id: "866", author: "Samuel Zeller", width: 4704, height: 3136),
            WebPhoto(id: "867", author: "Stefanus Martanto Setyo Husodo", width: 4288, height: 2848),
            WebPhoto(id: "896", author: "Jenna Beekhuis", width: 5000, height: 3333),
            WebPhoto(id: "900", author: "Todd DeSantis", width: 2173, height: 1449),
            WebPhoto(id: "902", author: "Nitish Meena", width: 3300, height: 2200),
            WebPhoto(id: "962", author: "Austin Schmid", width: 3200, height: 1800),
            WebPhoto(id: "987", author: "Sebastien Gabriel", width: 5000, height: 3333),
            WebPhoto(id: "994", author: "Jonathan Bean", width: 5000, height: 3337),
        ]),
        BackgroundCollection(title: "Mountains", symbol: "mountain.2.fill", photos: [
            WebPhoto(id: "29", author: "Go Wild", width: 4000, height: 2670),
            WebPhoto(id: "128", author: "Matteo Minelli", width: 3823, height: 2549),
            WebPhoto(id: "231", author: "Aleksandra Boguslawska", width: 4088, height: 2715),
            WebPhoto(id: "235", author: "Paul E. Harrer", width: 5000, height: 3333),
            WebPhoto(id: "256", author: "Sylwia Bartyzel", width: 2000, height: 697),
            WebPhoto(id: "327", author: "Ryan Schroeder", width: 4442, height: 2961),
            WebPhoto(id: "406", author: "Roland Batke-Mutschler", width: 4134, height: 2738),
            WebPhoto(id: "426", author: "Ales Krivec", width: 4272, height: 2848),
            WebPhoto(id: "434", author: "Ales Krivec", width: 4928, height: 3264),
            WebPhoto(id: "450", author: "Tanvi Malik", width: 4288, height: 2848),
            WebPhoto(id: "482", author: "Danny Froese", width: 5000, height: 3333),
            WebPhoto(id: "484", author: "David Marcu", width: 4288, height: 2848),
            WebPhoto(id: "519", author: "Alexandr Schwarz", width: 4761, height: 3174),
            WebPhoto(id: "558", author: "Ales Krivec", width: 4928, height: 3264),
            WebPhoto(id: "575", author: "Alberto Restifo", width: 2509, height: 1673),
            WebPhoto(id: "664", author: "Jonathan Bean", width: 2513, height: 1669),
            WebPhoto(id: "676", author: "Drew Patrick Miller", width: 5000, height: 3324),
            WebPhoto(id: "684", author: "Lee Roylland", width: 3872, height: 2178),
            WebPhoto(id: "830", author: "Luca Zanon", width: 5000, height: 3333),
            WebPhoto(id: "873", author: "Daniel Roe", width: 2640, height: 3960),
            WebPhoto(id: "906", author: "Andras Toth", width: 3840, height: 2880),
            WebPhoto(id: "916", author: "Larry Chen", width: 5000, height: 2480),
            WebPhoto(id: "930", author: "Dominik Lange", width: 3264, height: 4912),
            WebPhoto(id: "931", author: "Paul Earle", width: 3000, height: 1987),
            WebPhoto(id: "961", author: "Sven Scheuermeier", width: 2560, height: 1707),
            WebPhoto(id: "984", author: "Sylvain Guiheneuc", width: 4000, height: 2248),
        ]),
        BackgroundCollection(title: "Ocean", symbol: "water.waves", photos: [
            WebPhoto(id: "16", author: "Paul Jarvis", width: 2500, height: 1667),
            WebPhoto(id: "124", author: "Anton Sulsky", width: 3504, height: 2336),
            WebPhoto(id: "323", author: "Paweł Wojciechowski", width: 3831, height: 2554),
            WebPhoto(id: "384", author: "Griffin Keller", width: 5000, height: 3333),
            WebPhoto(id: "501", author: "davide ragusa", width: 3891, height: 2585),
            WebPhoto(id: "640", author: "Sarah Bürvenich", width: 2509, height: 1673),
            WebPhoto(id: "716", author: "Matthew Kosloski", width: 2592, height: 1728),
            WebPhoto(id: "846", author: "Jeremy Bishop", width: 4000, height: 3000),
            WebPhoto(id: "848", author: "Stefanus Martanto Setyo Husodo", width: 4912, height: 3264),
            WebPhoto(id: "853", author: "Stephen Radford", width: 3000, height: 1993),
            WebPhoto(id: "881", author: "贝莉儿 NG", width: 3000, height: 2000),
            WebPhoto(id: "909", author: "Austin Schmid", width: 3200, height: 1800),
            WebPhoto(id: "912", author: "Clem Onojeghuo", width: 5000, height: 3333),
            WebPhoto(id: "913", author: "Mikkel Schmidt", width: 4522, height: 3015),
            WebPhoto(id: "941", author: "Ivan Slade", width: 2600, height: 1734),
            WebPhoto(id: "950", author: "Nitish Kadam", width: 5000, height: 3333),
            WebPhoto(id: "970", author: "Darrell Cassell", width: 3264, height: 2448),
            WebPhoto(id: "973", author: "Cameron Kirby", width: 5000, height: 3334),
            WebPhoto(id: "1041", author: "Tim Marshall", width: 5000, height: 2813),
            WebPhoto(id: "1053", author: "Anna Popović", width: 3596, height: 2393),
            WebPhoto(id: "1069", author: "Marat Gilyadzinov", width: 3500, height: 2333),
            WebPhoto(id: "581", author: "Lance Anderson", width: 2509, height: 1672),
        ]),
        BackgroundCollection(title: "Mist & Forest", symbol: "tree.fill", photos: [
            WebPhoto(id: "11", author: "Paul Jarvis", width: 2500, height: 1667),
            WebPhoto(id: "83", author: "Julie Geiger", width: 2560, height: 1920),
            WebPhoto(id: "95", author: "Kundan Ramisetti", width: 2048, height: 2048),
            WebPhoto(id: "187", author: "Andre Koch", width: 4000, height: 2667),
            WebPhoto(id: "227", author: "Andrea Boldizsar", width: 1024, height: 683),
            WebPhoto(id: "229", author: "Orlova Maria", width: 2300, height: 1533),
            WebPhoto(id: "353", author: "Forrest Cavale", width: 5000, height: 2806),
            WebPhoto(id: "412", author: "Samuel Rohl", width: 5000, height: 3337),
            WebPhoto(id: "465", author: "Paula Vermeulen", width: 4928, height: 3264),
            WebPhoto(id: "472", author: "Dustin Scarpitti", width: 5000, height: 3333),
            WebPhoto(id: "599", author: "Dustin Scarpitti", width: 2509, height: 1673),
            WebPhoto(id: "634", author: "Jay Mantri", width: 2200, height: 1467),
            WebPhoto(id: "809", author: "Namphuong Van", width: 5000, height: 3333),
            WebPhoto(id: "876", author: "Carmine De Fazio", width: 5000, height: 3338),
            WebPhoto(id: "923", author: "Sebastian Unrau", width: 4616, height: 2699),
            WebPhoto(id: "932", author: "Vadim Sherbakov", width: 5000, height: 3333),
            WebPhoto(id: "1044", author: "Steve Carter", width: 4032, height: 2268),
            WebPhoto(id: "1064", author: "Olivier Miche", width: 4236, height: 2819),
        ]),
        BackgroundCollection(title: "City Lights", symbol: "building.2.fill", photos: [
            WebPhoto(id: "84", author: "Johnny Lam", width: 1280, height: 848),
            WebPhoto(id: "122", author: "Vadim Sherbakov", width: 4147, height: 2756),
            WebPhoto(id: "195", author: "Matthew Skinner", width: 768, height: 1024),
            WebPhoto(id: "220", author: "Robin Röcker", width: 3872, height: 2416),
            WebPhoto(id: "223", author: "Maria Carrasco", width: 4912, height: 3264),
            WebPhoto(id: "249", author: "Anders Jildén", width: 3000, height: 2000),
            WebPhoto(id: "259", author: "Namphuong Van", width: 3264, height: 2448),
            WebPhoto(id: "351", author: "Rafael Fabricio", width: 3994, height: 2443),
            WebPhoto(id: "352", author: "Caleb George", width: 3264, height: 2176),
            WebPhoto(id: "391", author: "Sarah Holmes", width: 2980, height: 2151),
            WebPhoto(id: "579", author: "Israel Sundseth", width: 2164, height: 1440),
            WebPhoto(id: "857", author: "Dmitry Sytnik", width: 5000, height: 3088),
            WebPhoto(id: "1067", author: "Kevin Young", width: 5000, height: 3333),
        ]),
        BackgroundCollection(title: "Soft & Dreamy", symbol: "sparkles", photos: [
            WebPhoto(id: "38", author: "Allyson Souza", width: 1280, height: 960),
            WebPhoto(id: "54", author: "Nicholas Swanson", width: 3264, height: 2176),
            WebPhoto(id: "56", author: "Sebastian Muller", width: 2880, height: 1920),
            WebPhoto(id: "82", author: "Rula Sibai", width: 1500, height: 997),
            WebPhoto(id: "106", author: "Arvee Marie", width: 2592, height: 1728),
            WebPhoto(id: "152", author: "Steven Spassov", width: 3888, height: 2592),
            WebPhoto(id: "189", author: "Buzo Jesús", width: 2048, height: 1536),
            WebPhoto(id: "306", author: "Schicka", width: 1024, height: 768),
            WebPhoto(id: "313", author: "Sonja Langford", width: 3888, height: 2592),
            WebPhoto(id: "360", author: "Cas Cornelissen", width: 1925, height: 1280),
            WebPhoto(id: "586", author: "Marco Bonomo", width: 2508, height: 1673),
            WebPhoto(id: "733", author: "Dominik Schröder", width: 5000, height: 3334),
            WebPhoto(id: "755", author: "Padurariu Alexandru", width: 5000, height: 3800),
            WebPhoto(id: "976", author: "Ales Krivec", width: 5000, height: 2901),
        ]),
        BackgroundCollection(title: "Portraits & Pets", symbol: "person.and.background.dotted", photos: [
            WebPhoto(id: "65", author: "Alexander Shustov", width: 4912, height: 3264),
            WebPhoto(id: "64", author: "Alexander Shustov", width: 4326, height: 2884),
            WebPhoto(id: "646", author: "Morgan Sessions", width: 2509, height: 1673),
            WebPhoto(id: "778", author: "Julia Caesar", width: 3000, height: 2000),
            WebPhoto(id: "399", author: "Sunset Girl", width: 2048, height: 1365),
            WebPhoto(id: "1011", author: "Roberto Nickson", width: 5000, height: 3333),
            WebPhoto(id: "669", author: "Luke Pamer", width: 4869, height: 3456),
            WebPhoto(id: "823", author: "Benjamin Combs", width: 5000, height: 3333),
            WebPhoto(id: "237", author: "André Spieker", width: 3500, height: 2095),
            WebPhoto(id: "659", author: "Alexander Dimitrov", width: 2731, height: 1536),
            WebPhoto(id: "582", author: "Levi Saunders", width: 2509, height: 1673),
            WebPhoto(id: "593", author: "Paula Borowska", width: 1774, height: 2365),
            WebPhoto(id: "1074", author: "Samuel Scrimshaw", width: 5000, height: 3333),
            WebPhoto(id: "1025", author: "Matthew Wiebe", width: 4951, height: 3301),
            WebPhoto(id: "433", author: "Thomas Lefebvre", width: 4752, height: 3168),
            WebPhoto(id: "718", author: "Josh Felise", width: 2274, height: 1440),
            WebPhoto(id: "219", author: "Martyn Seddon", width: 5000, height: 3333),
            WebPhoto(id: "169", author: "Noel Lopez", width: 2500, height: 1662),
        ]),
        BackgroundCollection(title: "Desert", symbol: "sun.dust.fill", photos: [
            WebPhoto(id: "46", author: "Jeffrey Kam", width: 3264, height: 2448),
            WebPhoto(id: "184", author: "Tim de Groot", width: 4288, height: 2848),
            WebPhoto(id: "196", author: "Dyaa Eldin Moustafa", width: 2048, height: 1536),
            WebPhoto(id: "247", author: "Georgia Dixon", width: 3264, height: 2168),
            WebPhoto(id: "261", author: "Fabio Rose", width: 2200, height: 1650),
            WebPhoto(id: "525", author: "Luca Zanon", width: 5000, height: 3333),
            WebPhoto(id: "551", author: "Forrest Cavale", width: 5000, height: 3337),
            WebPhoto(id: "564", author: "Sebastian Boguszewicz", width: 2000, height: 1333),
            WebPhoto(id: "829", author: "Drew Hays", width: 3333, height: 5000),
        ]),
    ] + licensed

    public static var all: [WebPhoto] { collections.flatMap(\.photos) }

    /// A good photo for a new widget, different for each kind of widget.
    public static func suggestion(_ index: Int) -> WebPhoto {
        // From the Picsum set, so new widgets start as they always have.
        let photos = all.filter { $0.provider == nil }
        return photos[abs(index) % photos.count]
    }

    /// A warm mix of places and people for a new Polaroids widget.
    public static var polaroidStarters: [WebPhoto] {
        ["110", "65", "54", "129", "1011", "56"].compactMap(photo(id:))
    }

    /// The photos of one collection, by title; empty if there's none by that name.
    public static func collection(_ title: String) -> [WebPhoto] {
        collections.first { $0.title == title }?.photos ?? []
    }

    public static func photo(id: String) -> WebPhoto? {
        all.first { $0.id == id }
    }
}
