// DesignSystem gallery shell + Design-System section index snapshots (Phase 5.5 TASK-004) — light +
// dark. The per-component states are already snapshot-covered in 5.2–5.4; these prove the shell +
// the three index pages compose.

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

    @Test func test_colorsPage() {
      assertCoachSnapshot(of: NavigationStack { ColorsGalleryPage() })
    }

    @Test func test_typographyPage() {
      assertCoachSnapshot(of: NavigationStack { TypographyGalleryPage() })
    }

    @Test func test_spacingPage() {
      assertCoachSnapshot(of: NavigationStack { SpacingGalleryPage() })
    }

    @Test func test_iconsPage() {
      assertCoachSnapshot(of: NavigationStack { IconsGalleryPage() })
    }
  }
#endif
