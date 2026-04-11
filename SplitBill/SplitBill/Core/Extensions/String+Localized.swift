//
//  String+Localized.swift
//  SplitBill
//

import Foundation

extension String {
    /// Returns the localized string for the current app language.
    var localized: String {
        let lang = UserDefaults.standard.string(forKey: "appLanguage") ?? "en"
        guard let path = Bundle.main.path(forResource: lang, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return Bundle.main.localizedString(forKey: self, value: self, table: nil)
        }
        return bundle.localizedString(forKey: self, value: self, table: nil)
    }
}
