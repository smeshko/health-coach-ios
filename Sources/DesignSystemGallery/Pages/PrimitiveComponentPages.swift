import DesignSystem
import SwiftUI

// Subpages for the Phase 5.2 primitives — each rendering all of that component's documented states.

struct ButtonsPage: View {
  var body: some View {
    GalleryScaffold(title: "Buttons") {
      stateLabel("Primary")
      PrimaryButton("Continue", icon: "checkmark") {}
      stateLabel("Primary (no icon)")
      PrimaryButton("Save") {}
      stateLabel("Secondary")
      SecondaryButton("Not now") {}
    }
  }
}

struct SegTabsPage: View {
  @State private var selection: SegTabs.Tab = .exercise

  var body: some View {
    GalleryScaffold(title: "SegTabs") {
      stateLabel("Live (tap to toggle)")
      SegTabs(selection: $selection)
      stateLabel("Exercise selected")
      SegTabs(selection: .constant(.exercise))
      stateLabel("Nutrition selected")
      SegTabs(selection: .constant(.nutrition))
    }
  }
}

struct PillPage: View {
  var body: some View {
    GalleryScaffold(title: "Pill") {
      stateLabel("Tones")
      HStack {
        Pill("Easy", tone: .accent)
        Pill("Threshold", tone: .warning)
        Pill("Primed", tone: .positive)
        Pill("Strained", tone: .negative)
      }
      stateLabel("Leading + uppercase")
      HStack {
        Pill("Primed", tone: .positive, leading: .icon("checkmark.circle.fill"))
        Pill("Ready", tone: .accent, leading: .dot)
        Pill("Recover", tone: .negative, uppercase: true)
      }
    }
  }
}

struct ChipPage: View {
  var body: some View {
    GalleryScaffold(title: "Chip") {
      stateLabel("Neutral")
      HStack {
        Chip("5 km", leading: .icon("ruler"))
        Chip("RPE 6")
      }
      stateLabel("Flag variant")
      Chip("Flagged", leading: .dot(.coachWarning), textColor: .coachWarning)
    }
  }
}

struct DayBadgePage: View {
  var body: some View {
    GalleryScaffold(title: "DayBadge") {
      stateLabel("Core day")
      HStack {
        DayBadge("Tue", tone: .negative, isCore: true)
        DayBadge("Mon", tone: .accent, isCore: true)
      }
      stateLabel("Optional day")
      HStack {
        DayBadge("Fri", tone: .warning, isCore: false)
        DayBadge("Sun", tone: .accent, isCore: false)
      }
    }
  }
}

struct IconBadgePage: View {
  var body: some View {
    GalleryScaffold(title: "IconBadge") {
      stateLabel("Shapes (· lg)")
      HStack(spacing: CoachSpacing.spaceMd) {
        IconBadge(Icon.drop.systemName, shape: .square, size: .lg)
        IconBadge(Icon.drop.systemName, shape: .circle, size: .lg)
      }
      stateLabel("Sizes (square)")
      HStack(alignment: .center, spacing: CoachSpacing.spaceMd) {
        IconBadge(Icon.drop.systemName, size: .sm)
        IconBadge(Icon.drop.systemName, size: .md)
        IconBadge(Icon.drop.systemName, size: .lg)
      }
      stateLabel("Tones")
      HStack(spacing: CoachSpacing.spaceMd) {
        IconBadge("drop", tone: .accent)
        IconBadge("exclamationmark.triangle.fill", tone: .warning)
        IconBadge("xmark", tone: .negative)
        IconBadge("checkmark", tone: .positive)
      }
    }
  }
}

struct BannerPage: View {
  var body: some View {
    GalleryScaffold(title: "Banner") {
      stateLabel("Accent")
      Banner(
        icon: "info.circle", tone: .accent,
        title: "It's been a week since your last test",
        message: "Log today's numbers to keep the trend honest."
      )
      stateLabel("Warning")
      Banner(
        icon: "exclamationmark.triangle.fill", tone: .warning,
        title: "Heads up — gut sensitivity flagged",
        message: "Favor low-residue meals around today's run."
      )
      stateLabel("Negative")
      Banner(
        icon: "xmark.octagon.fill", tone: .negative,
        title: "Session blocked",
        message: "We couldn't sync today's plan. Reconnect to continue."
      )
      stateLabel("Positive")
      Banner(
        icon: "checkmark.circle.fill", tone: .positive,
        title: "You're all set",
        message: "Today's readiness is in and looking strong."
      )
    }
  }
}

struct BarColumnsPage: View {
  var body: some View {
    GalleryScaffold(title: "BarColumns") {
      stateLabel("Flat series · last highlighted")
      galleryCard { BarColumns(bars: flat) }
      stateLabel("Ascending ramp · last highlighted")
      galleryCard { BarColumns(bars: ramp) }
      stateLabel("Per-bar color")
      galleryCard { BarColumns(bars: multitone) }
    }
  }

  /// Eight equal columns with the last in the strong accent — the flat-trend shape (#chart-1).
  private var flat: [BarColumns.Bar] {
    (0 ..< 8).map { BarColumns.Bar(value: 1, color: $0 == 7 ? .coachAccent : .coachAccentSoft) }
  }

  /// An ascending ramp ending on the highlighted peak — the climb shape (#charts-2).
  private var ramp: [BarColumns.Bar] {
    let heights: [CGFloat] = [0.45, 0.5, 0.62, 0.65, 0.78, 0.82, 0.92, 1]
    return heights.enumerated().map { index, height in
      BarColumns.Bar(value: height, color: index == heights.count - 1 ? .coachAccent : .coachAccentSoft)
    }
  }

  /// Per-bar colors — the primitive takes any fill, so future charts can be more colorful.
  private var multitone: [BarColumns.Bar] {
    [
      BarColumns.Bar(value: 0.5, color: .coachBorder),
      BarColumns.Bar(value: 0.85, color: .coachWarning),
      BarColumns.Bar(value: 0.7, color: .coachAccent),
      BarColumns.Bar(value: 0.65, color: .coachAccent),
      BarColumns.Bar(value: 0.55, color: .coachBorder),
      BarColumns.Bar(value: 0.95, color: .coachWarning),
      BarColumns.Bar(value: 0.5, color: .coachBorder),
    ]
  }
}

struct SegmentedBarPage: View {
  var body: some View {
    GalleryScaffold(title: "SegmentedBar") {
      stateLabel("Zones (Z1–Z5 + marker)")
      ForEach(1 ... 5, id: \.self) { target in
        SegmentedBar.zones(target: target)
      }
      stateLabel("Readiness (3 bands + marker)")
      ForEach([10, 60, 88], id: \.self) { score in
        SegmentedBar.readiness(score: score)
      }
      stateLabel("Effort range")
      // The RPE/effort meter (#7): a markerless range bar framed by caller-composed captions.
      VStack(spacing: CoachSpacing.spaceXs) {
        HStack {
          Text("RPE 6–7 target").font(.coachTextSm).foregroundStyle(.coachWarning)
          Spacer()
          Text("Effort · 1–10").font(.coachTextSm).foregroundStyle(.coachForegroundMuted)
        }
        SegmentedBar.range(6 ... 7, total: 10, tone: .warning)
        HStack {
          Text("1 · easy").font(.coachTextXs).foregroundStyle(.coachForegroundSubtle)
          Spacer()
          Text("max · 10").font(.coachTextXs).foregroundStyle(.coachForegroundSubtle)
        }
      }
      stateLabel("Weekly streak")
      VStack(spacing: CoachSpacing.spaceMd) {
        streakRow("Protein target", "6 of 7 days",
                  days: [true, true, true, false, true, true, true], tone: .accent)
        streakRow("Calorie deficit", "5 of 7 days",
                  days: [true, true, false, true, true, true, false], tone: .warning)
      }
    }
  }

  /// One labelled weekly-streak row (#8): a title + count caption over a markerless steps bar.
  private func streakRow(_ title: String, _ caption: String, days: [Bool], tone: Tone) -> some View {
    VStack(alignment: .leading, spacing: CoachSpacing.spaceXs) {
      HStack {
        Text(title).font(.coachTextMd).foregroundStyle(.coachForeground)
        Spacer()
        Text(caption).font(.coachTextSm).foregroundStyle(.coachForegroundMuted)
      }
      SegmentedBar.steps(days, tone: tone)
    }
  }
}
