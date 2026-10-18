import Foundation

/// Every place on the internet All Set can contact, when it does, and what it
/// sends: the one list the Data & Privacy page shows. `NetworkUseTests` fails
/// if any address in the source isn't covered here or in `linkHosts`.
public enum NetworkUse: String, CaseIterable, Identifiable, Sendable {
    case weather, geocoding, airQuality, photoSearch, featuredPhotos, photoFiles, github, statusChecks, anthropic, openAI,
         libraryServer

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .weather: "Weather forecast (Open-Meteo)"
        case .geocoding: "City search (Open-Meteo)"
        case .airQuality: "Air quality (Open-Meteo)"
        case .photoSearch: "Photo search (Openverse)"
        case .featuredPhotos: "Featured photos (Picsum, Unsplash photos)"
        case .photoFiles: "Photo files"
        case .github: "GitHub"
        case .statusChecks: "Status checks"
        case .anthropic: "Anthropic"
        case .openAI: "OpenAI"
        case .libraryServer: "Your wallpaper library server"
        }
    }

    /// When the app makes the request.
    public var when: String {
        switch self {
        case .weather: "While a Weather widget is on your desktop, about every 30 minutes."
        case .geocoding: "When you type a city into a Weather or Air Quality widget."
        case .airQuality: "While an Air Quality widget is on your desktop."
        case .photoSearch: "When you search for photos in the picture picker."
        case .featuredPhotos: "When you open the picture picker's featured photos, or a widget shows one."
        case .photoFiles: "When a photo you picked from search is shown for the first time; then it's kept on this Mac."
        case .github: "While a GitHub widget is on your desktop."
        case .statusChecks: "While a Status widget is on your desktop, for the addresses in it."
        case .anthropic: "Only when you send a screenshot to Claude in AI Screenshot, with your own API key."
        case .openAI: "Only when you send a screenshot to OpenAI in AI Screenshot, with your own API key."
        case .libraryServer: "At launch, to check your access key; then for the wallpaper list a few times a day, and each wallpaper you pick."
        }
    }

    /// What the request carries.
    public var sends: String {
        switch self {
        case .weather, .airQuality: "The latitude and longitude of the city you chose."
        case .geocoding: "The city name you typed."
        case .photoSearch: "The words you searched for."
        case .featuredPhotos: "Which page of the photo list, or which photo."
        case .photoFiles: "A request for the photo, to the site it lives on (such as Flickr or WordPress)."
        case .github: "The GitHub user name or repository you entered. Your public contribution calendar is read from github.com."
        case .statusChecks: "A plain request to each address, to see if it answers."
        case .anthropic, .openAI: "The screenshot, your question and your API key. Nothing is sent until you press Send."
        case .libraryServer: "Your access key when it's checked, then the token the server gave for it with every request for the wallpaper list and files."
        }
    }

    /// The hosts this use contacts. Empty for those whose host is the
    /// person's own choice (status checks, their library server, photo sites).
    public var hosts: [String] {
        switch self {
        case .weather: ["api.open-meteo.com"]
        case .geocoding: ["geocoding-api.open-meteo.com"]
        case .airQuality: ["air-quality-api.open-meteo.com"]
        case .photoSearch: ["api.openverse.org"]
        case .featuredPhotos: ["picsum.photos"]
        case .github: ["api.github.com", "github.com"]
        // The Status widget's starting examples; any address can be added.
        case .statusChecks: ["www.githubstatus.com", "www.apple.com", "www.google.com", "1.1.1.1"]
        case .anthropic: ["api.anthropic.com"]
        case .openAI: ["api.openai.com"]
        case .photoFiles, .libraryServer: []
        }
    }

    /// Never contacted by the app itself: pages it opens in your browser when
    /// you click (credits, where to get an API key, shortcut tiles), and
    /// placeholder addresses shown in empty fields.
    public static let linkHosts: Set<String> = [
        "openverse.org", "console.anthropic.com", "platform.openai.com", "www.pinterest.com", "www.youtube.com",
        "example.com", "localhost", "creativecommons.org", "unsplash.com",
    ]

    public static var contactedHosts: Set<String> { Set(allCases.flatMap(\.hosts)) }

    /// Things the app never does, said plainly next to the list.
    public static let never = [
        "No analytics, tracking or advertising.",
        "No account, and nothing about you is sent to All Set's developer.",
        "Crash and performance reports stay on this Mac unless you export them yourself.",
    ]
}
