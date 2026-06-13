import DesignSystem
import SwiftUI

/// Design System → Colors. Mirrors the Colors reference: a two-tier token gallery. **Tier 1 —
/// Primitives** shows every accent/neutral as a light **and** dark swatch pair (each swatch pinned to
/// its scheme so both values are visible at once) beside its raw hex. **Tier 2 — Semantic** shows each
/// role token with the primitive it aliases.
///
/// The full two-tier list is much taller than the device frame, so it is split into four device-fitting
/// sections (`ColorsAccentsSection` + `ColorsNeutralsSection` + `ColorsSemanticNeutralsSection` +
/// `ColorsSemanticAccentsSection`) which the page stacks and the snapshot tests render directly (so
/// nothing clips below the fold).
struct ColorsGalleryPage: View {
  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: CoachSpacing.spaceLg) {
        Text(
          "Every color is a token with a light and dark value, resolved by the mode axis. "
            + "Primitives hold raw hex; semantics alias primitives by role; components use semantics."
        )
        .font(CoachFont.textMd)
        .foregroundStyle(CoachColor.foregroundMuted)

        ColorsAccentsSection()
        ColorsNeutralsSection()
        ColorsSemanticNeutralsSection()
        ColorsSemanticAccentsSection()
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(CoachSpacing.spaceMd)
    }
    .background(CoachColor.background)
    .navigationTitle("Colors")
  }
}

/// Shared row data for the color tiers.
private struct ColorPrimitive: Identifiable {
  var id: String { name }
  let name: String
  let light: String
  let dark: String
  let color: Color
}

private struct ColorSemantic: Identifiable {
  var id: String { name }
  let name: String
  let alias: String
  let color: Color
}

private let swatchSize: CGFloat = 44

private let accents: [ColorPrimitive] = [
  ColorPrimitive(name: "accent-1", light: "#2C7A6B", dark: "#41A18D", color: CoachColor.accent1),
  ColorPrimitive(name: "accent-1-soft", light: "#E2EEEA", dark: "#18302B", color: CoachColor.accent1Soft),
  ColorPrimitive(name: "accent-2", light: "#C68A24", dark: "#E1A33C", color: CoachColor.accent2),
  ColorPrimitive(name: "accent-2-soft", light: "#F4EAD4", dark: "#33291A", color: CoachColor.accent2Soft),
  ColorPrimitive(name: "accent-3", light: "#BC5639", dark: "#DA755A", color: CoachColor.accent3),
  ColorPrimitive(name: "accent-3-soft", light: "#F2E1DA", dark: "#36221D", color: CoachColor.accent3Soft),
  ColorPrimitive(name: "accent-4", light: "#DB7A3D", dark: "#E99157", color: CoachColor.accent4),
  ColorPrimitive(name: "accent-5", light: "#5E97B5", dark: "#71AAC8", color: CoachColor.accent5),
]

private let neutrals: [ColorPrimitive] = [
  ColorPrimitive(name: "neutral-0", light: "#FFFFFF", dark: "#1C1B1F", color: CoachColor.neutral0),
  ColorPrimitive(name: "neutral-05", light: "#FAFAF7", dark: "#161518", color: CoachColor.neutral05),
  ColorPrimitive(name: "neutral-10", light: "#F2F1EC", dark: "#121214", color: CoachColor.neutral10),
  ColorPrimitive(name: "neutral-20", light: "#E7E5DE", dark: "#2C2B30", color: CoachColor.neutral20),
  ColorPrimitive(name: "neutral-40", light: "#A2A29C", dark: "#6C6B71", color: CoachColor.neutral40),
  ColorPrimitive(name: "neutral-60", light: "#6E6E73", dark: "#9D9CA3", color: CoachColor.neutral60),
  ColorPrimitive(name: "neutral-90", light: "#1A1A1C", dark: "#F3F2EE", color: CoachColor.neutral90),
  ColorPrimitive(name: "neutral-raised", light: "#FFFFFF", dark: "#3C3B42", color: CoachColor.neutralRaised),
  ColorPrimitive(name: "static-white", light: "#FFFFFF", dark: "#FFFFFF", color: CoachColor.staticWhite),
]

/// The neutral-role semantic tokens (foreground / background / surface / border).
private let semanticNeutrals: [ColorSemantic] = [
  ColorSemantic(name: "fg", alias: "neutral-90", color: CoachColor.foreground),
  ColorSemantic(name: "fg-muted", alias: "neutral-60", color: CoachColor.foregroundMuted),
  ColorSemantic(name: "fg-subtle", alias: "neutral-40", color: CoachColor.foregroundSubtle),
  ColorSemantic(name: "bg", alias: "neutral-10", color: CoachColor.background),
  ColorSemantic(name: "surface", alias: "neutral-0", color: CoachColor.surface),
  ColorSemantic(name: "surface-sunken", alias: "neutral-05", color: CoachColor.surfaceSunken),
  ColorSemantic(name: "surface-raised", alias: "neutral-raised", color: CoachColor.surfaceRaised),
  ColorSemantic(name: "border", alias: "neutral-20", color: CoachColor.border),
]

/// The accent-role semantic tokens (accent / status / on-accent).
private let semanticAccents: [ColorSemantic] = [
  ColorSemantic(name: "accent", alias: "accent-1", color: CoachColor.accent),
  ColorSemantic(name: "accent-soft", alias: "accent-1-soft", color: CoachColor.accentSoft),
  ColorSemantic(name: "positive", alias: "accent-1", color: CoachColor.positive),
  ColorSemantic(name: "warning", alias: "accent-2", color: CoachColor.warning),
  ColorSemantic(name: "negative", alias: "accent-3", color: CoachColor.negative),
  ColorSemantic(name: "info", alias: "accent-5", color: CoachColor.info),
  ColorSemantic(name: "on-accent", alias: "static-white", color: CoachColor.onAccent),
]

/// Tier 1 — the accent primitives as light/dark swatch pairs. A device-fitting section.
struct ColorsAccentsSection: View {
  var body: some View {
    primitiveGroupSection("Tier 1 — Primitives · Accents", accents)
  }
}

/// Tier 1 — the neutral primitives as light/dark swatch pairs. A device-fitting section.
struct ColorsNeutralsSection: View {
  var body: some View {
    primitiveGroupSection("Tier 1 — Primitives · Neutrals", neutrals)
  }
}

/// One device-fitting section rendering a labelled group of primitive swatch rows.
private func primitiveGroupSection(_ title: String, _ items: [ColorPrimitive]) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
    Text(title).font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
    ForEach(items) { primitiveRow($0) }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .padding(CoachSpacing.spaceMd)
  .background(CoachColor.background)
}

private func primitiveRow(_ item: ColorPrimitive) -> some View {
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

/// Tier 2 — the neutral-role semantic tokens with the primitive each aliases. A device-fitting section.
struct ColorsSemanticNeutralsSection: View {
  var body: some View {
    semanticGroupSection("Tier 2 — Semantic · Neutrals", semanticNeutrals)
  }
}

/// Tier 2 — the accent-role semantic tokens with the primitive each aliases. A device-fitting section.
struct ColorsSemanticAccentsSection: View {
  var body: some View {
    semanticGroupSection("Tier 2 — Semantic · Accents", semanticAccents)
  }
}

/// One device-fitting section rendering a labelled group of semantic role rows.
private func semanticGroupSection(_ title: String, _ items: [ColorSemantic]) -> some View {
  VStack(alignment: .leading, spacing: CoachSpacing.spaceMd) {
    Text(title).font(CoachFont.text2xs).tracking(1).foregroundStyle(CoachColor.foregroundSubtle)
    VStack(alignment: .leading, spacing: CoachSpacing.spaceSm) {
      ForEach(items) { semanticRow($0) }
    }
  }
  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  .padding(CoachSpacing.spaceMd)
  .background(CoachColor.background)
}

private func semanticRow(_ item: ColorSemantic) -> some View {
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
