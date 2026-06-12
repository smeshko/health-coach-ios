import DesignSystem
import SwiftUI

/// Design System → Colors. Mirrors the Colors reference: a two-tier token gallery. **Tier 1 —
/// Primitives** shows every accent/neutral as a light **and** dark swatch pair (each swatch pinned to
/// its scheme so both values are visible at once) beside its raw hex. **Tier 2 — Semantic** shows each
/// role token with the primitive it aliases. A single source list drives each group.
struct ColorsGalleryPage: View {
  private struct Primitive: Identifiable {
    var id: String { name }
    let name: String
    let light: String
    let dark: String
    let color: Color
  }

  private struct Semantic: Identifiable {
    var id: String { name }
    let name: String
    let alias: String
    let color: Color
  }

  private let swatchSize: CGFloat = 44

  private let accents: [Primitive] = [
    Primitive(name: "accent-1", light: "#2C7A6B", dark: "#41A18D", color: CoachColor.accent1),
    Primitive(name: "accent-1-soft", light: "#E2EEEA", dark: "#18302B", color: CoachColor.accent1Soft),
    Primitive(name: "accent-2", light: "#C68A24", dark: "#E1A33C", color: CoachColor.accent2),
    Primitive(name: "accent-2-soft", light: "#F4EAD4", dark: "#33291A", color: CoachColor.accent2Soft),
    Primitive(name: "accent-3", light: "#BC5639", dark: "#DA755A", color: CoachColor.accent3),
    Primitive(name: "accent-3-soft", light: "#F2E1DA", dark: "#36221D", color: CoachColor.accent3Soft),
    Primitive(name: "accent-4", light: "#DB7A3D", dark: "#E99157", color: CoachColor.accent4),
    Primitive(name: "accent-5", light: "#5E97B5", dark: "#71AAC8", color: CoachColor.accent5),
  ]

  private let neutrals: [Primitive] = [
    Primitive(name: "neutral-0", light: "#FFFFFF", dark: "#1C1B1F", color: CoachColor.neutral0),
    Primitive(name: "neutral-05", light: "#FAFAF7", dark: "#161518", color: CoachColor.neutral05),
    Primitive(name: "neutral-10", light: "#F2F1EC", dark: "#121214", color: CoachColor.neutral10),
    Primitive(name: "neutral-20", light: "#E7E5DE", dark: "#2C2B30", color: CoachColor.neutral20),
    Primitive(name: "neutral-40", light: "#A2A29C", dark: "#6C6B71", color: CoachColor.neutral40),
    Primitive(name: "neutral-60", light: "#6E6E73", dark: "#9D9CA3", color: CoachColor.neutral60),
    Primitive(name: "neutral-90", light: "#1A1A1C", dark: "#F3F2EE", color: CoachColor.neutral90),
    Primitive(name: "neutral-raised", light: "#FFFFFF", dark: "#3C3B42", color: CoachColor.neutralRaised),
    Primitive(name: "static-white", light: "#FFFFFF", dark: "#FFFFFF", color: CoachColor.staticWhite),
  ]

  private let semantics: [Semantic] = [
    Semantic(name: "fg", alias: "neutral-90", color: CoachColor.foreground),
    Semantic(name: "fg-muted", alias: "neutral-60", color: CoachColor.foregroundMuted),
    Semantic(name: "fg-subtle", alias: "neutral-40", color: CoachColor.foregroundSubtle),
    Semantic(name: "bg", alias: "neutral-10", color: CoachColor.background),
    Semantic(name: "surface", alias: "neutral-0", color: CoachColor.surface),
    Semantic(name: "surface-sunken", alias: "neutral-05", color: CoachColor.surfaceSunken),
    Semantic(name: "surface-raised", alias: "neutral-raised", color: CoachColor.surfaceRaised),
    Semantic(name: "border", alias: "neutral-20", color: CoachColor.border),
    Semantic(name: "accent", alias: "accent-1", color: CoachColor.accent),
    Semantic(name: "accent-soft", alias: "accent-1-soft", color: CoachColor.accentSoft),
    Semantic(name: "positive", alias: "accent-1", color: CoachColor.positive),
    Semantic(name: "warning", alias: "accent-2", color: CoachColor.warning),
    Semantic(name: "negative", alias: "accent-3", color: CoachColor.negative),
    Semantic(name: "info", alias: "accent-5", color: CoachColor.info),
    Semantic(name: "on-accent", alias: "static-white", color: CoachColor.onAccent),
  ]

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        Text(
          "Every color is a token with a light and dark value, resolved by the mode axis. "
            + "Primitives hold raw hex; semantics alias primitives by role; components use semantics."
        )
        .font(CoachFont.textMd)
        .foregroundStyle(CoachColor.foregroundMuted)

        section("Tier 1 — Primitives") {
          group("Accents", accents)
          group("Neutrals", neutrals)
        }

        section("Tier 2 — Semantic") {
          VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
            ForEach(semantics) { semanticRow($0) }
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Colors")
  }

  private func section(_ title: String, @ViewBuilder _ content: () -> some View) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
      Text(title).font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
      content()
    }
  }

  private func group(_ title: String, _ items: [Primitive]) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      Text(title).font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundSubtle)
      ForEach(items) { primitiveRow($0) }
    }
  }

  private func primitiveRow(_ item: Primitive) -> some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      HStack(spacing: CoachSpacing.spaceXs) {
        swatch(item.color, scheme: .light)
        swatch(item.color, scheme: .dark)
      }
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(item.name).font(CoachFont.textLg).foregroundStyle(CoachColor.foreground)
        Text("\(item.light) · \(item.dark)")
          .font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundMuted)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private func semanticRow(_ item: Semantic) -> some View {
    HStack(spacing: CoachSpacing.spaceSm) {
      swatch(item.color, scheme: nil)
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        Text(item.name).font(CoachFont.textLg).foregroundStyle(CoachColor.foreground)
        Text("→ \(item.alias)").font(CoachFont.textSm).foregroundStyle(CoachColor.foregroundMuted)
      }
      Spacer(minLength: 0)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  /// A swatch optionally pinned to `scheme` so a primitive's light/dark values can sit side by side.
  /// When `scheme` is `nil` the swatch resolves in the page's current mode (the semantic tier).
  @ViewBuilder
  private func swatch(_ color: Color, scheme: ColorScheme?) -> some View {
    let base = RoundedRectangle(cornerRadius: CoachRadius.sm)
      .fill(color)
      .frame(width: swatchSize, height: swatchSize)
      .overlay(RoundedRectangle(cornerRadius: CoachRadius.sm).stroke(CoachColor.border, lineWidth: 1))
    if let scheme {
      base.environment(\.colorScheme, scheme)
    } else {
      base
    }
  }
}
