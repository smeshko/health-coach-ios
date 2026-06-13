// Atom/control primitive gallery pages — each primitive's own gallery subpage, snapshotted in
// light + dark on the reference device. These pages are the single source for each primitive's state
// matrix (the old atoms-catalog grid duplicated them and has been deleted). Each page is short
// and fits the device frame, so the whole page is snapshotted via a `NavigationStack`.

#if canImport(UIKit)
  import CoachTestSupport
  import SnapshotTesting
  import SwiftUI
  import Testing

  @testable import DesignSystemGallery

  @MainActor
  struct AtomsSnapshotTests {
    @Test func test_buttonsPage() {
      assertCoachSnapshot(of: NavigationStack { ButtonsPage() })
    }

    @Test func test_segTabsPage() {
      assertCoachSnapshot(of: NavigationStack { SegTabsPage() })
    }

    @Test func test_pillPage() {
      assertCoachSnapshot(of: NavigationStack { PillPage() })
    }

    @Test func test_chipPage() {
      assertCoachSnapshot(of: NavigationStack { ChipPage() })
    }

    @Test func test_dayBadgePage() {
      assertCoachSnapshot(of: NavigationStack { DayBadgePage() })
    }

    @Test func test_iconBadgePage() {
      assertCoachSnapshot(of: NavigationStack { IconBadgePage() })
    }

    @Test func test_bannerPage() {
      assertCoachSnapshot(of: NavigationStack { BannerPage() })
    }

    @Test func test_insetCalloutPage() {
      assertCoachSnapshot(of: NavigationStack { InsetCalloutPage() })
    }
  }
#endif
