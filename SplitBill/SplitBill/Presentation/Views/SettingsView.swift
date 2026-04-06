//
//  SettingsView.swift
//  SplitBill
//

import SwiftUI

struct SettingsView: View {

    @AppStorage("userName") private var userName = ""
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = true
    @Environment(\.dismiss) private var dismiss

    @State private var showResetConfirm = false
    @FocusState private var nameFocused: Bool

    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {

                        // MARK: - Avatar
                        VStack(spacing: 12) {
                            Circle()
                                .fill(Color.appPrimary.opacity(0.12))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 38, weight: .medium))
                                        .foregroundColor(Color.appPrimary)
                                )

                            Text(userName.isEmpty ? "Your Name" : userName)
                                .font(AppTheme.Fonts.inter(18, weight: .semibold))
                                .foregroundColor(Color.textPrimary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)

                        // MARK: - Profile Section
                        sectionHeader("PROFILE")

                        VStack(spacing: 0) {
                            HStack {
                                Text("Name")
                                    .font(AppTheme.Fonts.inter(16, weight: .regular))
                                    .foregroundColor(Color.textPrimary)
                                Spacer()
                                TextField("Enter your name", text: $userName)
                                    .font(AppTheme.Fonts.inter(16, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                                    .multilineTextAlignment(.trailing)
                                    .focused($nameFocused)
                                    .submitLabel(.done)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 15)
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // MARK: - App Section
                        sectionHeader("APP")

                        VStack(spacing: 0) {
                            settingsRow(icon: "info.circle", iconColor: Color.appPrimary, title: "Version") {
                                Text(appVersion)
                                    .font(AppTheme.Fonts.inter(15, weight: .regular))
                                    .foregroundColor(Color.textSecondary)
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(icon: "star.fill", iconColor: Color(hex: "F59E0B"), title: "Rate SplitBill") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.textSecondary.opacity(0.4))
                            }

                            Divider().padding(.leading, 52)

                            settingsRow(icon: "envelope.fill", iconColor: Color.appSecondary, title: "Send Feedback") {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(Color.textSecondary.opacity(0.4))
                            }
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // MARK: - Reset Section
                        sectionHeader("RESET")

                        VStack(spacing: 0) {
                            Button(action: { showResetConfirm = true }) {
                                settingsRow(icon: "arrow.counterclockwise", iconColor: Color.orange, title: "Replay Onboarding") {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(Color.textSecondary.opacity(0.4))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .background(Color.appSurface)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 2)
                        .padding(.horizontal, 16)

                        // MARK: - Footer
                        Text("Made with ♥ by Alvin")
                            .font(AppTheme.Fonts.inter(13, weight: .regular))
                            .foregroundColor(Color.textSecondary.opacity(0.5))
                            .padding(.top, 36)
                            .padding(.bottom, 24)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(AppTheme.Fonts.inter(16, weight: .semibold))
                        .foregroundColor(Color.appPrimary)
                }
            }
            .confirmationDialog(
                "This will restart the onboarding flow.",
                isPresented: $showResetConfirm,
                titleVisibility: .visible
            ) {
                Button("Replay Onboarding", role: .destructive) {
                    hasSeenOnboarding = false
                }
                Button("Cancel", role: .cancel) {}
            }
            .onTapGesture { nameFocused = false }
        }
    }

    // MARK: - Helpers

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(AppTheme.Fonts.inter(12, weight: .semibold))
                .foregroundColor(Color.textSecondary)
                .tracking(0.8)
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func settingsRow<Trailing: View>(
        icon: String,
        iconColor: Color,
        title: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(iconColor.opacity(0.12))
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(iconColor)
                )

            Text(title)
                .font(AppTheme.Fonts.inter(16, weight: .regular))
                .foregroundColor(Color.textPrimary)

            Spacer()

            trailing()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }
}

#Preview {
    SettingsView()
}
