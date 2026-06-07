import DomainModels
import SwiftUI

/// A quiet badge for a session `Flag` (PRD §12.2) — low-emphasis, never alarming. Renders
/// `Flag.unknown(String)` gracefully via the Phase 5.1 `DisplayLabel` boundary (a humanized label,
/// never the raw machine key). Composes the neutral `Chip` primitive.
public struct FlagBadge: View {
  public let flag: Flag

  public init(flag: Flag) {
    self.flag = flag
  }

  public var body: some View {
    Chip(flag.label)
  }
}
