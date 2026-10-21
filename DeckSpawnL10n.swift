import Foundation

/// Localizes messages created outside SwiftUI's `Text`, such as battle and
/// network status messages. Uses the same preference as SettingsView/MyApp.
nonisolated enum DeckSpawnL10n {
    private static let preferenceKey = "deckspawn.language"

    static var languageCode: String {
        let selected = UserDefaults.standard.string(forKey: preferenceKey) ?? "system"
        if selected == "pt-BR" || selected == "en" { return selected }
        return Bundle.main.preferredLocalizations.first ?? "pt-BR"
    }

    private static var localizedBundle: Bundle {
        let language = languageCode
        let candidates = language.hasPrefix("pt")
            ? ["pt-BR", "pt"] : ["en", "en-US"]

        for code in candidates {
            if let path = Bundle.main.path(forResource: code, ofType: "lproj"),
               let bundle = Bundle(path: path) {
                return bundle
            }
        }
        return Bundle.main
    }

    private static var formattingLocale: Locale {
        Locale(identifier: languageCode)
    }

    static func text(_ key: String) -> String {
        // Portuguese text is the catalog's source key: preserve it if the
        // language-specific bundle is not available on this build.
        if languageCode.hasPrefix("pt"),
           Bundle.main.path(forResource: "pt-BR", ofType: "lproj") == nil,
           Bundle.main.path(forResource: "pt", ofType: "lproj") == nil {
            return key
        }
        return localizedBundle.localizedString(forKey: key, value: key, table: "Localizable")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: text(key), locale: formattingLocale, arguments: arguments)
    }
}
