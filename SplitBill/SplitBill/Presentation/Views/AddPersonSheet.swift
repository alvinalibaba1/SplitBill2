//
//  AddPersonSheet.swift
//  SplitBill
//
//  Created by Alvin Reyvaldo on 26/11/25.
//

import SwiftUI

struct AddPersonSheet: View {

    let onAdd: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var addedNames: [String] = []
    @FocusState private var isFocused: Bool

    // ✅ Light haptic fires on each successful add — tactile confirmation
    private let haptic = UIImpactFeedbackGenerator(style: .light)

    var body: some View {
        VStack(spacing: 0) {

            // MARK: Header
            HStack {
                Text("Add People")
                    .font(AppTheme.Fonts.inter(17, weight: .semibold))
                    .foregroundColor(Color.textPrimary)
                Spacer()
                // ✅ "Done" closes the sheet — user controls when they're finished
                Button("Done") { dismiss() }
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(Color.appPrimary)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 16)

            // MARK: Input Card
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: "person.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isFocused ? Color.appPrimary : Color.textSecondary.opacity(0.5))
                        .animation(.easeInOut(duration: 0.2), value: isFocused)

                    // ✅ Removed "NAME" label — redundant in context
                    // ✅ Friendlier placeholder with example
                    // ✅ .submitLabel(.done) — keyboard return key triggers add
                    TextField("Who's splitting? e.g. John", text: $name)
                        .font(AppTheme.Fonts.inter(16, weight: .regular))
                        .foregroundColor(Color.textPrimary)
                        .focused($isFocused)
                        .submitLabel(.done)
                        .autocorrectionDisabled(true)
                        .onSubmit { attemptAdd() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color.appBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isFocused ? Color.appPrimary.opacity(0.6) : Color.clear, lineWidth: 1.5)
            )
            .animation(.easeInOut(duration: 0.2), value: isFocused)
            .padding(.horizontal, 20)

            // MARK: Add Button
            Button(action: attemptAdd) {
                Text("Add")
                    .font(AppTheme.Fonts.inter(16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(isValid ? Color.appPrimary : Color.textSecondary.opacity(0.25))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(!isValid)
            .padding(.horizontal, 20)
            .padding(.top, 12)

            // MARK: Added Names
            // ✅ Shows names added this session as chips — visual confirmation without closing
            if !addedNames.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Added")
                        .font(AppTheme.Fonts.inter(12, weight: .semibold))
                        .foregroundColor(Color.textSecondary)
                        .tracking(0.6)

                    FlowLayout(spacing: 8) {
                        ForEach(addedNames, id: \.self) { personName in
                            HStack(spacing: 5) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Color.appPrimary)
                                Text(personName)
                                    .font(AppTheme.Fonts.inter(13, weight: .medium))
                                    .foregroundColor(Color.textPrimary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.appPrimary.opacity(0.08))
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()
        }
        .background(Color.appBackground.ignoresSafeArea())
        .onAppear { isFocused = true }
        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: addedNames.count)
    }

    // MARK: - Helpers

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func attemptAdd() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        onAdd(trimmed)
        addedNames.append(trimmed)
        name = ""

        // ✅ Haptic confirms the add — user knows it worked without looking at the list
        haptic.impactOccurred()

        // ✅ Keep sheet open + refocus — ready for next name immediately (Add Another flow)
        isFocused = true
    }
}

// MARK: - FlowLayout
// ✅ Custom layout so name chips wrap naturally instead of truncating in a single row
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        let height = rows.map { $0.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0 }
                         .reduce(0) { $0 + $1 + spacing } - spacing
        return CGSize(width: proposal.width ?? 0, height: max(height, 0))
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            let rowHeight = row.map { $0.sizeThatFits(.unspecified).height }.max() ?? 0
            for subview in row {
                let size = subview.sizeThatFits(.unspecified)
                subview.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += rowHeight + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [[LayoutSubview]] {
        var rows: [[LayoutSubview]] = [[]]
        var x: CGFloat = 0
        let maxWidth = proposal.width ?? 0

        for subview in subviews {
            let width = subview.sizeThatFits(.unspecified).width
            if x + width > maxWidth, !rows[rows.count - 1].isEmpty {
                rows.append([])
                x = 0
            }
            rows[rows.count - 1].append(subview)
            x += width + spacing
        }
        return rows
    }
}

#Preview {
    AddPersonSheet(onAdd: { _ in })
        .presentationDetents([.height(320)])
}
