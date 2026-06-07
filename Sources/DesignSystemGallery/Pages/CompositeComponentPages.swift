import DesignSystem
import DomainModels
import SwiftUI

// Subpages for the Phase 5.3 / 5.4 composites — each rendering the component's documented states.

struct SessionCardPage: View {
  private let zone2 = ZoneRange(low: 143, high: 152)

  var body: some View {
    GalleryScaffold(title: "SessionCard") {
      stateLabel("Easy run (with strides add-on)")
      SessionCard(
        SessionBlock(
          card: .easyRun, intensity: .easy, zoneTarget: .z2,
          durationMinLow: 35, durationMinHigh: 45, hrCapBpm: 146, cadenceSpm: 170, flags: [.appendToEasy]
        ),
        zoneRange: zone2
      )
      stateLabel("Long run (effort-based)")
      SessionCard(
        SessionBlock(
          card: .longRun, intensity: .easy, zoneTarget: .z2,
          durationMinLow: 75, durationMinHigh: 90, hrCapBpm: 150, cadenceSpm: 168, flags: [.effortBased]
        ),
        zoneRange: zone2
      )
      stateLabel("Rest")
      SessionCard(SessionBlock(card: .rest, intensity: .recovery, durationMinLow: 0, durationMinHigh: 0))
      stateLabel("Weekly planned (hard day)")
      SessionCard(
        PlannedSession(
          card: .threshold, tier: .core, intensity: .quality, isHardDay: true,
          suggestedDay: .wed, zoneTarget: .z4, durationMinLow: 40, durationMinHigh: 50
        ),
        zoneRange: ZoneRange(low: 166, high: 175)
      )
    }
  }
}

struct ZoneChipPage: View {
  var body: some View {
    GalleryScaffold(title: "ZoneChip") {
      ZoneChip(zone: .z1, range: ZoneRange(low: 120, high: 142))
      ZoneChip(zone: .z2, range: ZoneRange(low: 143, high: 152))
      ZoneChip(zone: .z4, range: ZoneRange(low: 166, high: 175))
    }
  }
}

struct FlagBadgePage: View {
  var body: some View {
    GalleryScaffold(title: "FlagBadge") {
      HStack {
        FlagBadge(flag: .effortBased)
        FlagBadge(flag: .appendToEasy)
      }
      HStack {
        FlagBadge(flag: .needsGreenKnee)
        FlagBadge(flag: .unknown("brand_new_flag"))
      }
    }
  }
}

struct DayTypeTagPage: View {
  var body: some View {
    GalleryScaffold(title: "DayTypeTag") {
      HStack {
        DayTypeTag(dayType: .hard)
        DayTypeTag(dayType: .moderate)
        DayTypeTag(dayType: .rest)
      }
    }
  }
}

struct ReadinessGaugePage: View {
  var body: some View {
    GalleryScaffold(title: "ReadinessGauge") {
      ReadinessGauge(readiness: Readiness(score: 86, band: .green, penalties: []))
      ReadinessGauge(readiness: Readiness(score: 62, band: .amber, penalties: []))
      ReadinessGauge(readiness: Readiness(score: 34, band: .red, penalties: []))
    }
  }
}

struct NutritionPanelPage: View {
  private func macros(_ dayType: DayType, kcal: Int, protein: Int, carbs: Int) -> MacroFocus {
    MacroFocus(
      dayType: dayType, caloriesKcal: kcal, proteinG: protein, carbsG: carbs,
      fatGLow: 65, fatGHigh: 80, hydrationLLow: 2.5, hydrationLHigh: 3.2
    )
  }

  var body: some View {
    GalleryScaffold(title: "NutritionPanel") {
      NutritionPanel(focus: macros(.hard, kcal: 2800, protein: 165, carbs: 380))
      NutritionPanel(focus: macros(.moderate, kcal: 2400, protein: 160, carbs: 280))
      NutritionPanel(focus: macros(.rest, kcal: 2100, protein: 160, carbs: 180))
    }
  }
}

struct MacroRowPage: View {
  var body: some View {
    GalleryScaffold(title: "MacroRow") {
      stateLabel("Emphasized (protein)")
      MacroRow(label: "Protein", value: "165 g", emphasis: true)
      stateLabel("Standard")
      MacroRow(label: "Carbs", value: "380 g")
      MacroRow(label: "Fat", value: "65–80 g")
    }
  }
}

struct NarrativeRendererPage: View {
  private let sections: [NarrativeSection] = [
    NarrativeSection(type: .summary, heading: "Today", body: "A steady aerobic day. Keep it **easy**."),
    NarrativeSection(
      type: .session, heading: "How to run it",
      body: "Settle into zone 2:\n- Relaxed shoulders\n- Nose-breathing pace"
    ),
    NarrativeSection(type: .nutrition, heading: "Fuel", body: "Protein at every meal."),
    NarrativeSection(type: .caution, heading: "Gentle note", body: "Knee flag active — stop if it sharpens."),
    NarrativeSection(type: .plan, heading: "This week", body: "Two quality days. *Consistency over heroics.*"),
  ]

  var body: some View {
    GalleryScaffold(title: "NarrativeRenderer") {
      NarrativeRenderer(sections: sections)
    }
  }
}
