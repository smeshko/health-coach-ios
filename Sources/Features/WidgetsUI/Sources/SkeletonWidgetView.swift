import DesignSystem
import Foundation
import SwiftUI

/// The Phase 21.1 pipeline-proof view: the snapshot's Sofia date + readiness score, or a placeholder
/// line when there is no current snapshot. Placeholder visuals only — replaced by the real widgets in
/// 21.2+. Plain SwiftUI (not WidgetKit-guarded) so the snapshot target renders it; `widgetURL` is
/// applied by the WidgetKit-side wrapper in `SkeletonWidget.swift`.
public struct SkeletonWidgetView: View {
  /// Fixed-frame Sofia date label (`en_US_POSIX`) so the rendered text is deterministic in snapshots.
  private static let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = .europeSofia
    formatter.calendar = .europeSofia
    formatter.dateFormat = "EEE d MMM"
    return formatter
  }()

  let date: Date?
  let readinessScore: Int?
  let isStale: Bool

  public init(date: Date?, readinessScore: Int?, isStale: Bool) {
    self.date = date
    self.readinessScore = readinessScore
    self.isStale = isStale
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
      Text("READINESS")
        .font(.coachText2xs)
        .tracking(1)
        .foregroundStyle(.coachForegroundSubtle)
      if let date, let readinessScore, !isStale {
        Text("\(readinessScore)")
          .font(.coachText3xl)
          .foregroundStyle(.coachForeground)
        Text(Self.dateFormatter.string(from: date))
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      } else {
        Text("—")
          .font(.coachText3xl)
          .foregroundStyle(.coachForegroundSubtle)
        Text("No brief yet")
          .font(.coachTextSm)
          .foregroundStyle(.coachForegroundMuted)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .padding(CoachSpacing.spaceMd)
  }
}
