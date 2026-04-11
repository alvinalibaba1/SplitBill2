//
//  LanguagePickerSheet.swift
//  SplitBill
//

import SwiftUI

struct LanguagePickerSheet: View {

    @AppStorage("appLanguage") private var currentLanguage: String = "en"
    @Environment(\.dismiss) private var dismiss

    private let languages: [(code: String, name: String, flag: String)] = [
        ("en", "English",   "🇬🇧"),
        ("id", "Indonesia", "🇮🇩")
    ]

    var body: some View {
        VStack(spacing: 0) {

            // Header
            HStack {
                Text("profile.language".localized)
                    .roundedFont(17, weight: .semibold)
                    .foregroundColor(Color.textPrimary)
                Spacer()
                Button("common.done".localized) { dismiss() }
                    .roundedFont(15, weight: .semibold)
                    .foregroundColor(Color.appPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // Language rows
            VStack(spacing: 0) {
                ForEach(Array(languages.enumerated()), id: \.element.code) { index, lang in
                    Button {
                        UIImpactFeedbackGenerator(style: .light).impactOccurred()
                        currentLanguage = lang.code
                        dismiss()
                    } label: {
                        HStack(spacing: 14) {
                            Text(lang.flag)
                                .font(.system(size: 26))
                                .frame(width: 40, height: 40)

                            Text(lang.name)
                                .roundedFont(16, weight: .medium)
                                .foregroundColor(Color.textPrimary)

                            Spacer()

                            if currentLanguage == lang.code {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(AppTheme.Fonts.inter(18))
                                    .foregroundColor(Color.appPrimary)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 18)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if index < languages.count - 1 {
                        Divider().padding(.leading, 74)
                    }
                }
            }
            .background(Color.appSurface)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}
