import Foundation
import Tagged

// The `Tagged` ID convention for the app's domain models.
//
// Each model defines its `ID` as `Tagged<Tag, UUID>`, so an ID for one model can never be assigned
// where another model's ID is expected — the phantom `Tag` makes otherwise-identical `UUID`s
// type-distinct at compile time. Concrete model IDs (athlete, brief, week, …) arrive with the
// models in Epic 02; the representative type below proves the pattern compiles against
// `swift-tagged`.

/// Representative ID type demonstrating the `Tagged` convention (a real model `ID` follows the same
/// shape in Epic 02).
public typealias AthleteID = Tagged<AthleteIDTag, UUID>

/// Phantom tag for ``AthleteID``.
public enum AthleteIDTag {}
