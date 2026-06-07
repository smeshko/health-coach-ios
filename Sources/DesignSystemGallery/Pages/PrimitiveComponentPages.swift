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
      Chip("Flagged", leading: .dot(CoachColor.warning), textColor: CoachColor.warning)
    }
  }
}

struct DayBadgePage: View {
  var body: some View {
    GalleryScaffold(title: "DayBadge") {
      stateLabel("Core / extra")
      HStack {
        DayBadge("Mon", tone: .accent, isCore: true)
        DayBadge("Tue", tone: .positive, isCore: true)
        DayBadge("Sat", isCore: false)
      }
    }
  }
}

struct MarkerPage: View {
  var body: some View {
    GalleryScaffold(title: "Marker") {
      stateLabel("Glow tints")
      HStack(spacing: CoachSpacing.space16) {
        Marker(glow: CoachColor.z2)
        Marker(glow: CoachColor.z4)
        Marker(glow: CoachColor.positive)
      }
    }
  }
}

struct ZoneBarPage: View {
  var body: some View {
    GalleryScaffold(title: "ZoneBar") {
      ForEach(1 ... 5, id: \.self) { target in
        stateLabel("Target Z\(target)")
        ZoneBar(target: target)
      }
    }
  }
}

struct ReadinessBarPage: View {
  var body: some View {
    GalleryScaffold(title: "ReadinessBar") {
      ForEach([10, 49, 50, 74, 75, 100], id: \.self) { score in
        stateLabel("Score \(score)")
        ReadinessBar(score: score)
      }
    }
  }
}

struct PrehabAddonPage: View {
  var body: some View {
    GalleryScaffold(title: "PrehabAddon") {
      PrehabAddon(title: "Foot prehab · 5 min", subtitle: "Quick add-on for flat feet")
    }
  }
}

struct StatusBarPage: View {
  var body: some View {
    GalleryScaffold(title: "StatusBar") {
      StatusBar()
      StatusBar(time: "12:30")
    }
  }
}

struct TabBarPage: View {
  @State private var selection: TabBar.Tab = .today

  var body: some View {
    GalleryScaffold(title: "TabBar") {
      stateLabel("Live (tap to switch)")
      TabBar(selection: $selection)
      stateLabel("Trends selected")
      TabBar(selection: .constant(.trends))
    }
  }
}

struct RestDayPage: View {
  var body: some View {
    RestDay()
      .navigationTitle("RestDay")
  }
}

struct MessageStatePage: View {
  var body: some View {
    GalleryScaffold(title: "MessageState") {
      MessageState(
        icon: "link", tone: .negative,
        title: "Reconnect to continue",
        body: "Your session expired. Reconnect to sync today's plan.",
        primary: .init(title: "Reconnect", icon: "arrow.clockwise", action: {}),
        secondaryTitle: "Not now"
      )
      .frame(height: 360)
      MessageState(
        icon: "checkmark.circle.fill", tone: .positive,
        title: "All synced",
        body: "Your latest data is in."
      )
      .frame(height: 280)
    }
  }
}
