//
//  LanguageManager.swift
//  SplitBill
//

import Foundation
import Combine

final class LanguageManager: ObservableObject {

    static let shared = LanguageManager()

    @Published var currentLanguage: String {
        didSet {
            UserDefaults.standard.set(currentLanguage, forKey: "appLanguage")
        }
    }

    private init() {
        self.currentLanguage = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
    }

    var displayName: String {
        currentLanguage == "id" ? "Indonesia" : "English"
    }

    var flag: String {
        currentLanguage == "id" ? "🇮🇩" : "🇬🇧"
    }
}
