import SwiftUI

/// A soft-tinted badge framing a single icon — the decorative icon container behind a stat, a section
/// header, or an empty state. The frame is the tone's soft fill, the icon its strong foreground (never a
/// soft-on-soft pair, the COMPONENTS.md rule shared with `Pill`/`Banner`). Pick a `shape` (continuous
/// rounded square or circle) and a `size`; swap the `tone` per meaning (accent / warning / negative /
/// positive).
public struct IconBadge: View {
  /// The badge outline — a continuous rounded square or a circle.
  public enum Shape: Sendable {
    case square
    case circle
  }

  /// The badge footprint. Each size pairs a frame side with an icon point size; `square` also carries a
  /// corner radius (token-backed) chosen to hold a constant ~36% squircle across sizes.
  public enum Size: Sendable {
    case sm
    case md
    case lg

    var side: CGFloat {
      switch self {
      case .sm: 32
      case .md: 44
      case .lg: 64
      }
    }

    var icon: CGFloat {
      switch self {
      case .sm: 12
      case .md: 20
      case .lg: 32
      }
    }

    var radius: CGFloat {
      CoachRadius.sm
    }
  }

  let icon: String
  let shape: Shape
  let size: Size
  let tone: Tone

    public init(
        _ icon: String,
        shape: Shape = .square,
        size: Size = .md,
        tone: Tone = .accent
    ) {
    self.icon = icon
    self.shape = shape
    self.size = size
    self.tone = tone
  }

  public var body: some View {
    Image(systemName: icon)
      .font(.system(size: size.icon))
      .foregroundStyle(tone.foreground)
      .frame(width: size.side, height: size.side)
      .background {
        switch shape {
        case .square:
          RoundedRectangle(cornerRadius: size.radius, style: .continuous).fill(tone.fill)
        case .circle:
          Circle().fill(tone.fill)
        }
      }
  }
}
