// DesignSystem gallery shell + Design-System section snapshots — light + dark. Proves the gallery
// shell composes and snapshots each Design-System page's matrix. Tall pages (Colors, Typography) are
// snapshotted as their device-fitting sections (not the scrolling page) so nothing clips below the
// fold; short pages (Spacing, Icons) are snapshotted whole via a `NavigationStack`. The token matrices
// live here exactly once (the old token-catalog fixture that duplicated them has been deleted).

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct GallerySnapshotTests {
    @Test func test_galleryShell() {
      assertCoachSnapshot(of: DesignSystemGalleryView())
    }

    @Test func test_colorsAccents() {
      assertCoachSnapshot(of: ColorsAccentsSection())
    }

    @Test func test_colorsNeutrals() {
      assertCoachSnapshot(of: ColorsNeutralsSection())
    }

    @Test func test_colorsSemanticNeutrals() {
      assertCoachSnapshot(of: ColorsSemanticNeutralsSection())
    }

    @Test func test_colorsSemanticAccents() {
      assertCoachSnapshot(of: ColorsSemanticAccentsSection())
    }

    @Test func test_typographyLarge() {
      assertCoachSnapshot(of: TypographyLargeSection())
    }

    @Test func test_typographyBody() {
      assertCoachSnapshot(of: TypographyBodySection())
    }

    @Test func test_spacingPage() {
      assertCoachSnapshot(of: NavigationStack { SpacingGalleryPage() })
    }

    @Test func test_motionTokenTable() {
      assertCoachSnapshot(of: MotionTokenTableSection())
    }

    @Test func test_iconsPage() {
      assertCoachSnapshot(of: NavigationStack { IconsGalleryPage() })
    }

    @Test func test_labels() {
      assertCoachSnapshot(of: LabelsSection())
    }
  }
#endif
