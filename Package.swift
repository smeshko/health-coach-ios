// swift-tools-version: 6.3
import PackageDescription

let package = Package(
  name: "CoachKit",
  // .iOS(.v26) is the product baseline. .macOS is REQUIRED so the package compiles for the macOS
  // host under `swift build` / `swift test` — TCA's products require macOS 13+, so an iOS-only
  // platforms line makes the host build fail to compile (validation round-2 #12, verified). The
  // .macOS line governs only host build/test; the shipped app target stays iOS-only (xcodeproj).
  platforms: [.iOS(.v26), .macOS(.v14)],
  // Products = EXACTLY the package modules the app + CoachWidgets extension targets link — one
  // `.library` per xcodeproj-linked module, nothing speculative (Phase 11.7 / DECISIONS D3; Phase 21.1
  // added the extension as a second product consumer). Same-package test targets reference targets
  // directly and need no products; anything re-needed later is a one-line `.library` addition.
  products: [
    .library(name: "AppFeature", targets: ["AppFeature"]),
    .library(name: "CoachCore", targets: ["CoachCore"]),
    .library(name: "TokenClient", targets: ["TokenClient"]),
    .library(name: "LogClient", targets: ["LogClient"]),
    .library(name: "LogClientLive", targets: ["LogClientLive"]),
    .library(name: "APIClientLive", targets: ["APIClientLive"]),
    .library(name: "Database", targets: ["Database"]),
    .library(name: "HealthKitClientLive", targets: ["HealthKitClientLive"]),
    .library(name: "NotificationClient", targets: ["NotificationClient"]),
    .library(name: "NotificationClientLive", targets: ["NotificationClientLive"]),
    .library(name: "DevSettings", targets: ["DevSettings"]),
    .library(name: "BriefRepositoryLive", targets: ["BriefRepositoryLive"]),
    .library(name: "WidgetSnapshotClient", targets: ["WidgetSnapshotClient"]),
    .library(name: "WidgetSnapshotClientLive", targets: ["WidgetSnapshotClientLive"]),
    .library(name: "WidgetsUI", targets: ["WidgetsUI"]),
    .library(name: "DomainModels", targets: ["DomainModels"]),
    .library(name: "LocalRepositories", targets: ["LocalRepositories"]),
    .library(name: "SyncRepositoryLive", targets: ["SyncRepositoryLive"]),
    .library(name: "ProfileRepositoryLive", targets: ["ProfileRepositoryLive"]),
  ],
  dependencies: [
    .package(url: "https://github.com/pointfreeco/swift-composable-architecture", from: "1.17.0"),
    // `Dependencies` is NOT a product of swift-composable-architecture (TCA exposes only the
    // `ComposableArchitecture` product), so CoachCore must depend on swift-dependencies DIRECTLY to
    // reach `@Dependency(\.calendar)` / `(\.date)`. `from: "1.4.0"` matches TCA's own lower bound, so
    // SPM unifies on the highest version satisfying both with no conflict (validation round-1 #1/#2,
    // round-2 #B, verified). Depending on ComposableArchitecture here would pull all of TCA into the
    // bottom-of-graph CoachCore target.
    .package(url: "https://github.com/pointfreeco/swift-dependencies", from: "1.4.0"),
    // GRDB — SQLite record protocols for the PersistenceModels cache layer (§18: GRDB pinned
    // directly; SharingGRDB wraps it in Epic 04, but only the GRDB record protocols are used here).
    .package(url: "https://github.com/groue/GRDB.swift", from: "7.0.0"),
    // swift-clocks — `TestClock` to advance the APIClient retry backoff instantly in tests. The
    // `\.continuousClock` dependency key itself is in swift-dependencies; only the test clock is here.
    .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.0.0"),
    // swift-sharing — `@Shared(.appStorage)` for `WeeklyFeature`'s persisted last-seen-ISO-week
    // watermark (Epic 9, DECISIONS #2). Promoted from transitive to a DIRECT dep so a literal
    // `import Sharing` resolves; TCA `@_exported`s it, so the build would compile without this entry —
    // it is for the explicit import, not a build requirement. Pinned to the transitively-resolved 2.8.0.
    .package(url: "https://github.com/pointfreeco/swift-sharing", from: "2.8.0"),
    // Test-only: SwiftUI image snapshots. Used only by CoachTestSupport + the snapshot test target.
    .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", from: "1.17.0"),
  ],
  targets: [
    .target(
      name: "AppFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        // The app spine subscribes to the session-event stream (401 routing) via the APIClient
        // INTERFACE — the one app-spine exception to the feature dependency rule (§13). Never *Live.
        "APIClient",
        // App-open session restore reads the stored bearer token via the TokenClient INTERFACE (same
        // §13/D12 app-spine carve-out) to fall back from the default `.main` to onboarding when absent.
        // Never *Live.
        "TokenClient",
        // The onboarding branch is its own feature module (ARCHITECTURE §4.5/§10); AppFeature composes
        // it and renders its root view.
        "OnboardingFeature",
        // The You-tab root feature (Phase 7.4): `MainTabs` composes it and renders `SettingsFeatureView`
        // — a feature→feature edge the tab root implies. Phase 10.2 expands the same target.
        "SettingsFeature",
        // The Today-tab root feature (Epic 8): `MainTabs` composes it and renders `TodayView` in place of
        // the 6.1 placeholder so each Today phase (8.1–8.4) is testable in the running app as it lands.
        "TodayFeature",
        // The Week-tab root feature (Epic 9): `MainTabs` composes it and renders `WeeklyView` in place of
        // the 6.1 placeholder. Same-package target dep (no product needed — mirrors TodayFeature).
        "WeeklyFeature",
        // The strength-test screen (Phase 10.4): the `SettingsPath.strengthTest` case + the You-tab
        // destination render `StrengthTestView`; the deep-link push constructs its `.State`.
        "StrengthTestFeature",
        // The badge deriver reads `strengthTestRepository.current` (`MainTabs` is the single deriver,
        // DECISIONS #2) — features may depend on repositories (ARCHITECTURE §3; TodayFeature already does).
        "LocalRepositories",
        // `isStrengthTestDue` (the ISO-week due rule, TASK-001) for the You-tab badge derivation.
        "CoachCore",
        // Shell views (onboarding + tab bar) use design tokens/primitives.
        "DesignSystem",
        // App-spine observability: emits `.app`/`.lifecycle` log lines (state swaps, session restore,
        // app-will-appear) via the LogClient INTERFACE — same §13 app-spine carve-out as APIClient/
        // TokenClient. Never *Live.
        "LogClient",
      ],
      path: "Sources/Features/AppFeature/Sources",
      swiftSettings: [
        // Explicit Swift 6 language mode = complete strict concurrency. Already the default from
        // `swift-tools-version: 6.3`; stated here to self-document and to satisfy the epic's
        // "strict-concurrency build settings" wording.
        .swiftLanguageMode(.v6),
      ]
    ),
    // The onboarding feature (ARCHITECTURE §4.5/§10): the Connect step (`ConnectComponent`) + the
    // HealthKit-priming step (Phase 7.3). An app-spine feature that may use the `APIClient`/`TokenClient`
    // INTERFACES directly (the §13/D12/§4.5 carve-out) alongside DesignSystem + DomainModels/CoachCore —
    // never a `*Live`, GRDB, HealthKit, or WireModels.
    .target(
      name: "OnboardingFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "APIClient",
        "TokenClient",
        // The HealthKit-priming step (Phase 7.3) drives auth + the degraded-detection delta probe via
        // the `HealthKitClient` INTERFACE only (the §13/D12/§4.5 onboarding carve-out) — never HealthKit
        // / `*Live`.
        "HealthKitClient",
        "DesignSystem",
        "DomainModels",
        "CoachCore",
      ],
      path: "Sources/Features/OnboardingFeature/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The You-tab root feature (ARCHITECTURE §4.5). **Minimal in Phase 7.4** — only a `tokenReset`
    // delegate seam + a `#if DEBUG` DEV section hosting the dev menu; Phase 10.2 expands this SAME target
    // (CONNECTION / APPLE HEALTH / PROFILE / REMINDERS, adding DesignSystem/DomainModels/CoachCore + repo
    // interfaces). The DEBUG dev menu writes the mock/live + scenario knobs through the `DevSettings`
    // INTERFACE and clears the bearer token through the `TokenClient` INTERFACE (the §13/D12 app-spine
    // carve-out) — never a `*Live`, GRDB, HealthKit, or WireModels. `SampleData` arrives transitively
    // via `DevSettings`.
    .target(
      name: "SettingsFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "DevSettings",
        "TokenClient",
        // The DEBUG dev menu surfaces the per-category log toggles. It uses the `LogClient` INTERFACE only
        // for the `LogCategory` vocabulary; the toggles are written through the `DevSettings` log seam
        // (keyed by rawValue), so this adds no client→client coupling beyond reading the enum.
        "LogClient",
        // The You-tab root + DEBUG dev menu are styled against the shared design tokens (the Settings
        // design reference): neutral background, accent tint, card surfaces, type + spacing scale.
        "DesignSystem",
        // The DEBUG dev menu surfaces the design-system gallery (component/token browser) as a sheet.
        // Used only behind `#if DEBUG`; absent from RELEASE behaviour.
        "DesignSystemGallery",
        // The log viewer parses log timestamps back into `Date`s via the shared `LogTimestamp` helper,
        // using the app's canonical Europe/Sofia frame — the same frame the live `LogClient` renders in.
        "CoachCore",
        // Phase 10.2 production sections: read-only profile constants + connection/HK/last-sync status.
        // Features depend on repository/data-source INTERFACES only (§3 + the §13/D12 + §4.5 app-spine
        // carve-out for HealthKitClient/TokenClient) + DomainModels — never *Live/WireModels/GRDB/HealthKit.
        "DomainModels",
        "ProfileRepository",
        "SyncRepository",
        "HealthKitClient",
        // Phase 10.3 reminders: the NotificationClient INTERFACE (D21 data source, no repo wraps it) +
        // Sharing for the persisted @Shared(.appStorage) reminders toggle. Never NotificationClientLive.
        "NotificationClient",
        .product(name: "Sharing", package: "swift-sharing"),
      ],
      path: "Sources/Features/SettingsFeature/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .target(
      name: "CoachCore",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Core/CoachCore/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Wire-contract DTOs (Codable mirror of openapi.yaml). Bottom-of-graph: depends only on
    // CoachCore (+ Foundation) + DomainModels (shared closed enums, Phase 11.3). Must NOT import
    // TCA / GRDB (ARCHITECTURE §4.1). No cycle: DomainModels depends only on CoachCore.
    .target(
      name: "WireModels",
      dependencies: [
        "CoachCore",
        "DomainModels",
      ],
      path: "Sources/Models/WireModels/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Shared test helper (light+dark / single reference device snapshot convention). Links XCTest via
    // SnapshotTesting, so it must be depended on ONLY by test targets — never by the app or a shipping
    // library, or the app build breaks. All UIKit-only code is wrapped in `#if canImport(UIKit)` so
    // this target compiles to an empty module on the macOS host (validation round-2 #A).
    .target(
      name: "CoachTestSupport",
      dependencies: [
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
        // Host-compiling helpers (outside the UIKit guard): the shared APIClient stub factory needs
        // the APIClient interface; the in-memory-DB convenience re-exports Database.makeInMemory.
        "APIClient",
        "Database",
      ],
      path: "Sources/Core/CoachTestSupport/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Logic tests — run on the macOS host via `swift test`. No snapshot/UIKit code.
    .testTarget(
      name: "CoachCoreTests",
      dependencies: [
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Core/CoachCore/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // App-tailored domain models + semantic enums consumed by reducers/views. Depends ONLY on
    // CoachCore — NO Codable, NO GRDB, NO WireModels (ARCHITECTURE §4.1 / §5). The only model
    // layer features import.
    .target(
      name: "DomainModels",
      dependencies: [
        "CoachCore",
      ],
      path: "Sources/Models/DomainModels/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Single source of sample truth — canned wire JSON + DTO/domain factories for previews/tests/
    // snapshots/mocks. Library (not a test target): imported by previews and *Live previewValues, so
    // it links NO XCTest and NO GRDB (§4.4). Depends on the model layers + WireDomainMapping (the
    // DTO→domain free functions live there; 2.2 DECISIONS #1).
    .target(
      name: "SampleData",
      dependencies: [
        "WireModels",
        "DomainModels",
        "WireDomainMapping",
      ],
      path: "Sources/Models/SampleData/Sources",
      resources: [
        .process("Resources"),
      ],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Bearer-token store: the read/write/clear interface + the Keychain-backed `liveValue` (links
    // Security, a host-safe system framework — its round-trip test runs on host, so the split bought no
    // isolation; merged into one module in Phase 11.7).
    .target(
      name: "TokenClient",
      dependencies: [
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/TokenClient/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // App-wide logging interface — `@Dependency(\.log)`: a Sendable closure-struct + `LogLevel` /
    // `LogCategory` (`.http` always-on) + a host-assertable `LogRecorder` + the `LogTimestamp`
    // format/parse contract. Depends on Dependencies + CoachCore (`Calendar.europeSofia`, for the
    // timestamp frame) — no app types, no DevSettings (the gate lives in LogClientLive).
    .target(
      name: "LogClient",
      dependencies: [
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/LogClient/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // LogClient.liveValue — the live `log` closure renders human-readable lines directly to console + a
    // rotating file (LogFileWriter), with category gating read from the persisted DevSettings toggles
    // (no third-party logging indirection, DECISIONS D1). Depends on the LogClient interface (incl. `LogTimestamp`)
    // + DevSettings (interface) + Dependencies. Imported only by the composition root + APIClientLive
    // (via the interface).
    .target(
      name: "LogClientLive",
      dependencies: [
        "LogClient",
        "DevSettings",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/LogClient/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The widget-snapshot mirror interface (Phase 21.1): the FULL Codable `WidgetSnapshot` schema
    // (daily + optional weekly/check-in sections — 21.2–21.5 add writers and UI, never schema
    // surgery), the Sofia staleness/timeline helpers (explicit `Calendar` — the extension process
    // never runs `prepareDependencies`), and the closure-struct client with a no-op `testValue`.
    // Consumed by BriefRepositoryLive (the writer hook), WidgetsUI, and the CoachWidgets extension.
    .target(
      name: "WidgetSnapshotClient",
      dependencies: [
        "CoachCore",
        "DomainModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/WidgetSnapshot/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // WidgetSnapshotClient.liveValue — the atomic App-Group JSON store (`widget-snapshot.json`) with
    // section-preserving merge writes serialized through a single actor (no lost updates between the
    // sibling section writers later phases add), plus the WidgetKit timeline reload after each write
    // (`#if canImport(WidgetKit)`-guarded for the macOS host). Failures log via the LogClient
    // INTERFACE and drop — the brief path never fails on the mirror. Linked by the app target AND
    // the CoachWidgets extension (whose providers resolve it via dynamic `liveValue` lookup).
    .target(
      name: "WidgetSnapshotClientLive",
      dependencies: [
        "WidgetSnapshotClient",
        "DomainModels",
        "CoachCore",
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/WidgetSnapshot/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // WidgetSnapshotStore write/read/merge tests over a temp directory — host, no simulator; never
    // the real App Group container. Sibling subfolder to WidgetSnapshotClientTests under `Tests/`.
    .testTarget(
      name: "WidgetSnapshotClientLiveTests",
      dependencies: [
        "WidgetSnapshotClient",
        "WidgetSnapshotClientLive",
        "DomainModels",
        "SampleData",
        "CoachCore",
      ],
      path: "Sources/Clients/WidgetSnapshot/Tests/WidgetSnapshotClientLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // WidgetSnapshot schema/round-trip + Sofia staleness-helper tests — host, no simulator. Two test
    // targets nest under `Tests/` (this + WidgetSnapshotClientLiveTests) — the LogClient layout.
    .testTarget(
      name: "WidgetSnapshotClientTests",
      dependencies: [
        "WidgetSnapshotClient",
        "DomainModels",
        "SampleData",
        "CoachCore",
      ],
      path: "Sources/Clients/WidgetSnapshot/Tests/WidgetSnapshotClientTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The network client interface — concrete typed closures for the six routes + a session-event
    // stream, plus `APIError`/`SessionEvent`. No URLSession here (that's APIClientLive). Repos/
    // features depend only on this (§4.2/§6.1).
    .target(
      name: "APIClient",
      dependencies: [
        "CoachCore",
        "WireModels",
        // The canned `/profile` testValue builds `DomainModels` profile types (Phase 11.3 fold).
        "DomainModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/APIClient/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // URLSession-backed APIClient.liveValue — the Endpoint routes, request builder, and the single
    // generic send<R> transport (auth, retry, envelope decode, 401 stream). Depends on the APIClient
    // interface + TokenClient + WireModels (§4.2). The `\.continuousClock` retry key comes from
    // Dependencies.
    .target(
      name: "APIClientLive",
      dependencies: [
        "APIClient",
        "TokenClient",
        "WireModels",
        "CoachCore",
        // The transport logs every request/response/error under `.http` via the LogClient INTERFACE
        // (no LogClientLive — the composition root installs the live value).
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/APIClient/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // HealthKit data-source interface — plain payload structs + auth status + delta reads. NO
    // HealthKit import (that's HealthKitClientLive); reuses `WireModels.RecordType` as a type tag.
    .target(
      name: "HealthKitClient",
      dependencies: [
        "CoachCore",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/HealthKitClient/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The live HealthKit reader. All HealthKit code is `#if canImport(HealthKit)`-guarded so the
    // package compiles on the macOS host (HealthKit is iOS-only → the `#else` `liveValue` is empty);
    // the iOS path is exercised on simulator/device.
    .target(
      name: "HealthKitClientLive",
      dependencies: [
        "HealthKitClient",
        // The stopped-queries instrumentation logs one `.app` line via the LogClient INTERFACE
        // (no LogClientLive — the composition root installs the live value).
        "LogClient",
        "WireModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/HealthKitClient/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The local-notifications data source INTERFACE (D21 / §6): pure `Sendable` value types
    // (`NotificationRequest`/`NotificationTrigger`/`NotificationDateComponents`/
    // `NotificationAuthorizationStatus`) + the closure struct + a recording test value. Imports NO
    // `UserNotifications` (§15) — that framework lives only in NotificationClientLive. Consumers
    // (10.2 Settings, 10.3 wiring) depend on this interface only.
    .target(
      name: "NotificationClient",
      dependencies: [
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/NotificationClient/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // NotificationClient.liveValue over UNUserNotificationCenter. The ONLY target importing
    // `UserNotifications` (§15); all framework code is `#if canImport(UserNotifications)`-guarded so the
    // macOS host build collapses to the `#else` stub. Imported only by the composition root.
    .target(
      name: "NotificationClientLive",
      dependencies: [
        "NotificationClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/NotificationClient/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The persistence data-source: the generic read/write/observe interface over a GRDB transaction
    // block (Decision #2 puts `GRDB.Database` on the closure signatures, so it imports GRDB) PLUS the
    // live DB — a single DatabaseQueue, the DatabaseMigrator, and the implementations. The interface
    // already imported GRDB, so the split bought no isolation; merged into one module in Phase 11.7.
    .target(
      name: "Database",
      dependencies: [
        "CoachCore",
        "PersistenceModels",
        // The resilient-open recovery decision (quarantine vs preserve, Phase 18.4) logs on the
        // always-on `.http` category via the LogClient INTERFACE (no LogClientLive — the
        // composition root installs the live value; 18.2 precedent).
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Clients/Database/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DEBUG mock/live routing control: a persisted `useMockData` flag + per-endpoint `SampleScenario`
    // selection, PLUS the UserDefaults-backed `liveValue` + the launch-arg/env override seed. DEBUG-only
    // behaviour; in RELEASE `useMockData()` is hard-`false`, the override body is empty, and the writers
    // are no-ops (`#if DEBUG` guards). A tiny pure-Foundation store — the split bought no isolation;
    // merged into one module in Phase 11.7. Depends only on swift-dependencies + SampleData.
    .target(
      name: "DevSettings",
      dependencies: [
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/DevSettings/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepository interface — the daily/weekly get-or-generate seam features see. Depends only on
    // DomainModels + CoachCore (ISOWeek) + SampleData (for `.mock`) + Dependencies — NO APIClient /
    // Database / GRDB / *Live (the §3 repo-interface dependency rule). Owns `BriefError`.
    .target(
      name: "BriefRepository",
      dependencies: [
        "DomainModels",
        "CoachCore",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/BriefRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepository.live — the network+GRDB daily/weekly cache policy. Depends on the data-source
    // INTERFACES (APIClient owns APIError; Database owns the GRDB transaction block) + all model
    // layers + WireDomainMapping + GRDB. Never a *Live or a feature (§3/§4.3 repo-live rule).
    .target(
      name: "BriefRepositoryLive",
      dependencies: [
        "BriefRepository",
        "APIClient",
        "Database",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "WireDomainMapping",
        "CoachCore",
        // `routed(dev:)` mock/live toggle: DevSettings (devRoute) + SampleData (the mock fixtures).
        "DevSettings",
        "SampleData",
        // Decode-degradation notices (Phase 19.2): a corrupt cached row logs on `.http` and
        // degrades to a miss (the Database/SyncRepositoryLive interface-dependency precedent).
        "LogClient",
        // The widget-snapshot mirror (Phase 21.1): the daily cache write fires `updateDailyBrief`
        // through the client INTERFACE (the LogClient-in-repo-live precedent) — never *Live.
        "WidgetSnapshotClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/BriefRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The two local-only GRDB repositories — `CheckInRepository` (upsert-by-Sofia-day of the daily
    // check-in) and `StrengthTestRepository` (upsert + at-or-before-latest read of the weekly strength
    // numbers). Structurally identical local `save`/`current` shapes with no routing and no network, so
    // they merged into ONE module in Phase 11.7 (DECISIONS D2); the public type names and `@Dependency`
    // keys are preserved verbatim. Interface-less local module → features that consume these now link
    // the GRDB-backed live code (the "features depend only on the interface" rule no longer holds here;
    // ARCHITECTURE §4.3 records the exception). GRDB persistence via the Database interface.
    .target(
      name: "LocalRepositories",
      dependencies: [
        "CoachCore",
        "Database",
        "DomainModels",
        "PersistenceModels",
        // The Phase 21.2 selection→widget-snapshot mirror hook (interface only, no App Group I/O).
        "WidgetSnapshotClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/LocalRepositories/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository interface — the no-args sync() orchestrator seam. Interface deps: DomainModels +
    // Dependencies only (SyncResult/SyncError are domain types). No HealthKit/APIClient/Database here.
    .target(
      name: "SyncRepository",
      dependencies: [
        "DomainModels",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/SyncRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository.live — reads HK deltas since the watermark, attaches inputs, POSTs /sync, advances
    // the watermark only on success. Depends on the data-source + repo INTERFACES + model layers. The
    // HK→wire mapping lives here (3.3 boundary decision).
    .target(
      name: "SyncRepositoryLive",
      dependencies: [
        "SyncRepository",
        "HealthKitClient",
        "APIClient",
        "Database",
        // The two local-only repos (CheckIn/StrengthTest) now live in `LocalRepositories` (Phase 11.7).
        "LocalRepositories",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "SampleData",
        "CoachCore",
        // `routed(dev:)` mock/live toggle (devRoute).
        "DevSettings",
        // Truncation visibility (Phase 19.1): a delta read hitting `limitPerType` logs a warning on
        // the always-on `.http` category so the condition is diagnosable on device.
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/SyncRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository interface — cache-first profile fetch + zone-range accessor.
    // Interface deps: DomainModels + SampleData (for .mock/testValue) + Dependencies only.
    .target(
      name: "ProfileRepository",
      dependencies: [
        "DomainModels",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Repositories/ProfileRepository/Interface",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository.live — fetch GET /profile, map via WireDomainMapping, cache via Database.
    // Depends on the data-source INTERFACES + model layers + WireDomainMapping.
    .target(
      name: "ProfileRepositoryLive",
      dependencies: [
        "ProfileRepository",
        "APIClient",
        "Database",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "WireDomainMapping",
        // `routed(dev:)` mock/live toggle: DevSettings (devRoute) + SampleData (the mock fixtures).
        "DevSettings",
        "SampleData",
        // Decode degradation (Phase 19.2): an undecodable cached profile logs a notice on the
        // always-on `.http` category before deleting the row and refetching.
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/ProfileRepository/Live",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ALL widget implementation (views, providers, `Widget` conformances) — the CoachWidgets
    // extension target holds ONLY the `@main` bundle listing widgets from here, so 21.2–21.5 ship by
    // adding Swift files to this module + one line to the bundle (zero Package/Makefile/pbxproj
    // edits; DECISIONS D4). Providers read via the WidgetSnapshotClient INTERFACE — the extension
    // process links `*Live`, so the dynamic `liveValue` lookup resolves the real store. DesignSystem
    // lands now so 21.2's styled widgets need no Package.swift edit; the transitive closure stays
    // pure value code — no Database/GRDB/APIClient. WidgetKit-touching files are
    // `#if canImport(WidgetKit)`-guarded for the macOS host.
    .target(
      name: "WidgetsUI",
      dependencies: [
        "WidgetSnapshotClient",
        "DomainModels",
        "DesignSystem",
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Features/WidgetsUI/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Widget view snapshots (skeleton populated/stale, light + dark) — iOS 26 simulator only, via
    // `xcodebuild test` (`make test-snapshots` lists this target). `#if canImport(UIKit)`-guarded so
    // it compiles to an empty module on the host.
    .testTarget(
      name: "WidgetsUISnapshotTests",
      dependencies: [
        "WidgetsUI",
        "WidgetSnapshotClient",
        "DomainModels",
        "SampleData",
        "CoachTestSupport",
        "DesignSystem",
        "CoachCore",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/WidgetsUI/Tests/WidgetsUISnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The design system — color/typography/spacing tokens + the enum→label boundary (§9, §4.4, D19).
    // Pure SwiftUI value code; depends ONLY on DomainModels + CoachCore (never repositories /
    // WireModels / APIClient / GRDB).
    .target(
      name: "DesignSystem",
      dependencies: [
        "DomainModels",
        "CoachCore",
        // The `HealthDataCategory` → label mapping (Phase 7.3 / DECISIONS #1) — a recorded §4.4 widening:
        // DesignSystem imports the `HealthKitClient` INTERFACE (a pure value enum, never `*Live`/HealthKit)
        // so the priming/degraded category labels live at the single enum→label boundary (principle #2 / D19).
        "HealthKitClient",
      ],
      path: "Sources/DesignSystem/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // A navigable design-system gallery (Colors/Typography/Icons + a subpage per component) — a
    // permanent DEBUG dev-menu tool reachable from Settings. Depends on DesignSystem + DomainModels
    // only (component states are built from inline DomainModels literals); never repositories / wire
    // / GRDB / TCA.
    .target(
      name: "DesignSystemGallery",
      dependencies: [
        "DesignSystem",
        "DomainModels",
      ],
      path: "Sources/Features/DesignSystemGallery/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // GRDB record types for the six cached entities + their lossless domain↔record mapping. Depends
    // on CoachCore + GRDB + DomainModels only — NO WireModels, NO SharingGRDB API (§4.1).
    .target(
      name: "PersistenceModels",
      dependencies: [
        "CoachCore",
        "DomainModels",
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Models/PersistenceModels/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Pure DTO→domain mapping functions (the read path). After Phase 11.3 shared the closed enums and
    // folded the Profile/CheckIn/StrengthTest twins, only the REAL shape changes remain here — the
    // brief `{data,narrative}` envelope flattening, intake mapping, date conversions, and the
    // free-string open-enum maps. Sits at/above the repository-live tier (ARCHITECTURE §3: a repo
    // *Live may depend on all model layers), below features. Depends on BOTH model layers;
    // DomainModels itself never imports WireModels (DECISIONS Decision 1).
    .target(
      name: "WireDomainMapping",
      dependencies: [
        "WireModels",
        "DomainModels",
      ],
      path: "Sources/Models/WireDomainMapping/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Wire decode/round-trip tests — pure Foundation, run on the macOS host via `swift test`
    // (no simulator needed).
    .testTarget(
      name: "WireModelsTests",
      dependencies: [
        "WireModels",
        // Request/coder tests build the shared `DomainModels` types directly (Phase 11.3 fold);
        // SwiftPM doesn't re-export the transitive import, so list it directly.
        "DomainModels",
        "CoachCore",
        // Phase 11.6 (TASK-003): the decode tests now load the canonical wire-JSON from SampleData's
        // bundle resources (one fixture source) instead of inline JSON blobs.
        "SampleData",
      ],
      path: "Sources/Models/WireModels/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // APIClient interface + transport tests (transport bits land in TASK-003/004).
    .testTarget(
      name: "APIClientLiveTests",
      dependencies: [
        "APIClient",
        "APIClientLive",
        "TokenClient",
        "WireModels",
        // RequestBuildingTests builds the shared `DomainModels.CheckIn` directly (Phase 11.3 fold);
        // SwiftPM doesn't re-export the transitive import, so list it directly.
        "DomainModels",
        // The transport-logging test builds a recorder `LogClient`; SwiftPM doesn't re-export the
        // transitive import, so the test target lists it directly.
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "Clocks", package: "swift-clocks"),
      ],
      path: "Sources/Clients/APIClient/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // TokenClient tests — in-memory round-trip + guarded live Keychain round-trip.
    .testTarget(
      name: "TokenClientTests",
      dependencies: [
        "TokenClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/TokenClient/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // LogClient interface tests — recorder capture + level-helper routing + always-on rule. Host, no
    // simulator. LogClient has TWO test targets (this + LogClientLiveTests, TASK-002), so each sits in
    // its own subfolder under `Tests/` — the repository-style nested layout (e.g. BriefRepository),
    // not the flat single-`Tests/` layout the single-test-target clients use.
    .testTarget(
      name: "LogClientTests",
      dependencies: [
        "LogClient",
        // The `LogTimestamp` round-trip tests build dates in the Europe/Sofia frame.
        "CoachCore",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/LogClient/Tests/LogClientTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // LogClientLive tests — file write (via the writer's `flush` seam) + rotation cap + DevSettings
    // category gating. Host, no simulator. Sibling subfolder to LogClientTests under `Tests/`.
    .testTarget(
      name: "LogClientLiveTests",
      dependencies: [
        "LogClient",
        "LogClientLive",
        "DevSettings",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/LogClient/Tests/LogClientLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // HealthKitClient interface + test-value tests — host (no HealthKit, no simulator).
    .testTarget(
      name: "HealthKitClientTests",
      dependencies: [
        "HealthKitClient",
        "HealthKitClientLive",
        "WireModels",
        // `TestClock` drives the BoundedReadCoordinator timeout deterministically (a DIRECT dep —
        // a transitively-resolved package is not importable).
        .product(name: "Clocks", package: "swift-clocks"),
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/HealthKitClient/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // NotificationClient interface + recording-test-value tests — host (no UserNotifications, no
    // simulator). Runs against the framework-free recording test value.
    .testTarget(
      name: "NotificationClientTests",
      dependencies: [
        "NotificationClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/NotificationClient/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Database migrate / read / write / observe tests — host, on an in-memory queue.
    .testTarget(
      name: "DatabaseTests",
      dependencies: [
        "Database",
        "PersistenceModels",
        "DomainModels",
        // Test-only: a real profile fixture for the v3 cache-clear migration test (11.2).
        "SampleData",
        "CoachCore",
        // Test-only: `LogRecorder`/`.recording(into:)` + `withDependencies` capture the
        // resilient-open recovery records (Phase 18.4).
        "LogClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Clients/Database/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // PersistenceModels record + domain round-trip tests — host. GRDB for the record protocols;
    // `SampleData`/`DomainModels` (added in TASK-004) source domain inputs for the round-trip.
    .testTarget(
      name: "PersistenceModelsTests",
      dependencies: [
        "PersistenceModels",
        "DomainModels",
        "SampleData",
        "CoachCore",
        // Test-only: the production migrator (`DatabaseClient.makeInMemory`) so record round-trips run
        // against the real schema, not an ad-hoc in-test one (11.2 TASK-002).
        "Database",
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Models/PersistenceModels/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SampleData decode-every-scenario tests — host. Links XCTest; `SampleData` itself does not.
    .testTarget(
      name: "SampleDataTests",
      dependencies: [
        "SampleData",
        "WireModels",
        "DomainModels",
      ],
      path: "Sources/Models/SampleData/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // Mapping tests — pure functions, host (no simulator).
    .testTarget(
      name: "WireDomainMappingTests",
      dependencies: [
        "WireDomainMapping",
        "WireModels",
        "DomainModels",
      ],
      path: "Sources/Models/WireDomainMapping/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DomainModels pure value/enum tests — host (no simulator).
    .testTarget(
      name: "DomainModelsTests",
      dependencies: [
        "DomainModels",
      ],
      path: "Sources/Models/DomainModels/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DevSettings persistence/override/routing tests — pure Foundation, run on the macOS host via
    // `swift test` (no simulator needed).
    .testTarget(
      name: "DevSettingsTests",
      dependencies: [
        "DevSettings",
        "SampleData",
        .product(name: "Dependencies", package: "swift-dependencies"),
      ],
      path: "Sources/Clients/DevSettings/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // BriefRepositoryLive cache-policy + APIError-mapping tests — host, with a migrated in-memory
    // Database (Database.makeInMemory) and a stubbed APIClient.
    .testTarget(
      name: "BriefRepositoryLiveTests",
      dependencies: [
        "BriefRepositoryLive",
        "BriefRepository",
        "APIClient",
        "Database",
        "PersistenceModels",
        "WireModels",
        "DomainModels",
        "SampleData",
        "CoachCore",
        "CoachTestSupport",
        // The `routed(dev:)` mock-toggle test builds a fake DevSettings.
        "DevSettings",
        // The decode-degradation tests assert notices via `LogRecorder` / `.recording(into:)`.
        "LogClient",
        // The Phase 21.1 mirror tests override `\.widgetSnapshot` with a recording client.
        "WidgetSnapshotClient",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/BriefRepository/Tests/BriefRepositoryLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // LocalRepositories tests — the CheckIn (upsert/latest-wins) + StrengthTest (upsert +
    // at-or-before-latest read) GRDB suites, host, on a migrated in-memory Database (Phase 11.7 merged
    // the two repo test targets into one alongside the source merge).
    .testTarget(
      name: "LocalRepositoriesTests",
      dependencies: [
        "LocalRepositories",
        "Database",
        "PersistenceModels",
        "DomainModels",
        "CoachCore",
        "WidgetSnapshotClient",
        "CoachTestSupport",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/LocalRepositories/Tests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // SyncRepository.live orchestration + HK→wire mapping + APIError mapping tests — host, all client
    // deps stubbed + a migrated in-memory Database.
    .testTarget(
      name: "SyncRepositoryLiveTests",
      dependencies: [
        "SyncRepositoryLive",
        "SyncRepository",
        "HealthKitClient",
        "APIClient",
        "Database",
        "LocalRepositories",
        // `LogRecorder` pins the Phase 19.1 truncation warning on the always-on `.http` category.
        "LogClient",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "SampleData",
        "CoachCore",
        "CoachTestSupport",
        .product(name: "Dependencies", package: "swift-dependencies"),
        // `TestClock` drives the CR-3 HK-read timeout deterministically (never-advanced in the normal
        // tests so the timeout never fires; an `ImmediateClock` in the timeout test fires it at once).
        .product(name: "Clocks", package: "swift-clocks"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/SyncRepository/Tests/SyncRepositoryLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ProfileRepository.live cache tests — host, stubbed APIClient + in-memory DB.
    .testTarget(
      name: "ProfileRepositoryLiveTests",
      dependencies: [
        "ProfileRepositoryLive",
        "ProfileRepository",
        "APIClient",
        "Database",
        // `LogRecorder` pins the Phase 19.2 decode-degradation notice on the always-on `.http` category.
        "LogClient",
        "WireModels",
        "DomainModels",
        "PersistenceModels",
        "SampleData",
        "CoachTestSupport",
        .product(name: "Dependencies", package: "swift-dependencies"),
        .product(name: "GRDB", package: "GRDB.swift"),
      ],
      path: "Sources/Repositories/ProfileRepository/Tests/ProfileRepositoryLiveTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DesignSystem enum→label boundary tests — pure logic, host (no UIKit/snapshot).
    .testTarget(
      name: "DesignSystemTests",
      dependencies: [
        "DesignSystem",
        "DomainModels",
      ],
      path: "Sources/DesignSystem/Tests/DesignSystemTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AppFeatureTests",
      dependencies: [
        "AppFeature",
        // The switch/401 tests construct `OnboardingFeature.State` (the onboarding branch payload).
        "OnboardingFeature",
        // The token-reset route test constructs `SettingsFeature.Action.delegate(.tokenReset)` to drive
        // the You-tab → MainTabs → AppFeature bubble.
        "SettingsFeature",
        // The MainTabs/deep-link tests construct `SettingsPath.State.strengthTest(.init())` and match
        // `.strengthTest(.delegate(.saved))`, so the test target must import the feature (Phase 10.4).
        "StrengthTestFeature",
        // The 401-routing tests inject a controlled `SessionEvent` stream via the APIClient interface.
        "APIClient",
        // The logging tests inject `LogClient.recording(into:)` and assert `.app`/`.lifecycle` entries.
        "LogClient",
        // The 401-mid-orchestration containment test drives a suspended TodayFeature sync→brief chain
        // through the AppFeature reducer, so it overrides the repo + clock dependencies (Phase 11.6).
        "LocalRepositories",
        "SyncRepository",
        "BriefRepository",
        "ProfileRepository",
        "DomainModels",
        "SampleData",
        "CoachCore",
        .product(name: "Clocks", package: "swift-clocks"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      path: "Sources/Features/AppFeature/Tests/AppFeatureTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ConnectComponent exhaustive TestStore (host) — write→probe→clear ordering, success/failure
    // branches, binding-reset, paste, and the `canSubmit` gate (PLAN.md D18). No snapshot/UIKit code.
    .testTarget(
      name: "OnboardingFeatureTests",
      dependencies: [
        "OnboardingFeature",
        "APIClient",
        "TokenClient",
        // The HealthKit-priming TestStore stubs `HealthKitClient` + constructs `HealthDataCategory`/
        // `HealthSampleSet` fixtures; the label tests reach the `DesignSystem` category labels.
        "HealthKitClient",
        "DesignSystem",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      path: "Sources/Features/OnboardingFeature/Tests/OnboardingFeatureTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DevMenuFeature + SettingsFeature exhaustive TestStore (host) — the DEBUG dev-menu write-through
    // contract (toggle/scenario ⇒ DevSettings writers), the reset-token clear + delegate, and the DEV
    // section presentation. The test files are `#if DEBUG`-guarded (they reference DEBUG-only types).
    .testTarget(
      name: "SettingsFeatureTests",
      dependencies: [
        "SettingsFeature",
        // The dev-menu tests reference DevEndpoint / SampleScenario / DevSettings / LogCategory by symbol
        // and override TokenClient.clear directly; depend on those interfaces explicitly (the transitive
        // visibility through SettingsFeature is the fallback).
        "DevSettings",
        "SampleData",
        "TokenClient",
        "LogClient",
        // Phase 10.2: the SettingsFeature load TestStore stubs these interfaces + builds DomainModels.
        "ProfileRepository",
        "SyncRepository",
        "HealthKitClient",
        "DomainModels",
        // Phase 10.3: ReminderScheduler/reminders TestStore drive the NotificationClient recorder.
        "NotificationClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      path: "Sources/Features/SettingsFeature/Tests/SettingsFeatureTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // View snapshot tests — run only on an iOS 26 simulator via `xcodebuild test`. The whole body is
    // `#if canImport(UIKit)`-guarded so it compiles to an empty module on the host (so `swift test`
    // stays green); SwiftUI image snapshots use the iOS-only ViewImageConfig/.device API.
    // DesignSystem view snapshots (the token/label catalog) — iOS 26 simulator only, via
    // `xcodebuild test`. `#if canImport(UIKit)`-guarded so it compiles to an empty module on the host.
    .testTarget(
      name: "DesignSystemSnapshotTests",
      dependencies: [
        "DesignSystem",
        "DesignSystemGallery",
        "DomainModels",
        "CoachTestSupport",
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/DesignSystem/Tests/DesignSystemSnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    .testTarget(
      name: "AppFeatureSnapshotTests",
      dependencies: [
        "AppFeature",
        // The shell snapshots construct `OnboardingFeature.State` for the onboarding branch.
        "OnboardingFeature",
        // The main-tab-bar snapshot seeds the Today tab root to a deterministic `.syncing` state (so the
        // app-open orchestration's async churn can't make the capture flaky) — needs `TodayFeature.State`.
        "TodayFeature",
        // The same snapshot parks the chain's first await — the check-in gate's `current()` read — so
        // Today holds on `.syncing`.
        "LocalRepositories",
        // Pins `\.calendar`/`\.date` to Europe/Sofia for the Today header's date subtitle.
        "CoachCore",
        "CoachTestSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/AppFeature/Tests/AppFeatureSnapshotTests",
      // Reference images are read from disk by swift-snapshot-testing (not bundled), so exclude them
      // from the target to avoid SwiftPM's "unhandled files" warning.
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // DevMenuView snapshot (the DEBUG dev menu) — iOS 26 simulator only, via `xcodebuild test`. Guarded
    // on `#if canImport(UIKit)` (empty module on the host) AND `#if DEBUG` (compiles out of RELEASE).
    .testTarget(
      name: "SettingsFeatureSnapshotTests",
      dependencies: [
        "SettingsFeature",
        "DevSettings",
        "SampleData",
        "LogClient",
        "CoachTestSupport",
        // Phase 10.2 SettingsView snapshots seed DomainModels constants + HealthDataCategory missing sets,
        // and pin the SyncRepository.lastSync reappear-refresh read.
        "DomainModels",
        "HealthKitClient",
        "SyncRepository",
        // Phase 10.3 reminders snapshots seed the auth status + the @Shared(.appStorage) toggle.
        "NotificationClient",
        .product(name: "Sharing", package: "swift-sharing"),
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/SettingsFeature/Tests/SettingsFeatureSnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // ConnectView snapshots (connect + error states, light + dark) — iOS 26 simulator only, via
    // `xcodebuild test`. `#if canImport(UIKit)`-guarded so it compiles to an empty module on the host.
    .testTarget(
      name: "OnboardingFeatureSnapshotTests",
      dependencies: [
        "OnboardingFeature",
        "CoachTestSupport",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/OnboardingFeature/Tests/OnboardingFeatureSnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The Today tab's hero "daily brief" feature (ARCHITECTURE §4.5, PRD §6/§8.1): the universal
    // `BriefViewState` lifecycle + the morning orchestration (check-in → sync → daily brief). A pure
    // feature — depends ONLY on the repo INTERFACES (`BriefRepository`/`SyncRepository`/
    // `CheckInRepository`) + `DesignSystem` + `DomainModels` + `CoachCore` (the §3 feature dependency
    // rule) — never a `*Live`, data-source client, GRDB, HealthKit, or WireModels.
    .target(
      name: "TodayFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "BriefRepository",
        "SyncRepository",
        // The local CheckIn repo now lives in `LocalRepositories` (Phase 11.7) — an interface-less local
        // module, so this feature links the GRDB-backed live code (the §4.3-recorded exception to the
        // "features depend only on the interface" rule).
        "LocalRepositories",
        // `ProfileRepository` INTERFACE — the orchestration reads `zones()` so the swapped session resolves
        // its bpm range (DECISIONS #4). Interface only (feature dependency rule), never *Live.
        "ProfileRepository",
        "DesignSystem",
        "DomainModels",
        "CoachCore",
        // `.lifecycle` observability: emits a log line when the morning orchestration is triggered, via
        // the LogClient INTERFACE (the feature dependency rule allows interface clients). Never *Live.
        "LogClient",
      ],
      path: "Sources/Features/TodayFeature/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // TodayFeature exhaustive TestStore (host) — the orchestration (sync-before-brief, sync-fail blocks
    // the brief, cache-hit, brief-error, non-typed-throw, skip-check-in), the check-in clamp/upsert, and
    // the debounced Refresh + cancellation. Logic only — no snapshot/UIKit symbols (§4.6 split).
    // `Clocks` (a DIRECT dep — a transitively-resolved package is not importable) supplies `TestClock`/
    // `ImmediateClock` for the debounce; production injects the built-in `\.continuousClock`.
    .testTarget(
      name: "TodayFeatureTests",
      dependencies: [
        "TodayFeature",
        "BriefRepository",
        "SyncRepository",
        "LocalRepositories",
        "DomainModels",
        // `SampleData` vends the `DailyBrief` fixtures the orchestration tests return from the stubbed
        // `BriefRepository` (the `cached` flag is flipped per test to exercise the Freshness branch).
        "SampleData",
        "CoachCore",
        // The logging test injects `LogClient.recording(into:)` and asserts the `.lifecycle` `onAppOpen`
        // entry.
        "LogClient",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Clocks", package: "swift-clocks"),
      ],
      path: "Sources/Features/TodayFeature/Tests/TodayFeatureTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // TodayView snapshots (the loading / generating / sync-failed states, light + dark) — iOS 26
    // simulator only, via `xcodebuild test`. `#if canImport(UIKit)`-guarded so it compiles to an empty
    // module on the host. `exclude: ["__Snapshots__"]` keeps the committed references out of the target
    // (otherwise SwiftPM warns "unhandled files").
    .testTarget(
      name: "TodayFeatureSnapshotTests",
      dependencies: [
        "TodayFeature",
        "DomainModels",
        "SampleData",
        "CoachTestSupport",
        // The readiness / forced-REST snapshots frame the cards on `.coachBackground` with the spacing
        // scale — the same page chrome the real screen uses. A test-only edge (DesignSystem is a shipping
        // library; this never reaches the app graph).
        "DesignSystem",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/TodayFeature/Tests/TodayFeatureSnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The "This Week" feature (Epic 9) — the menu-with-budgets weekly plan screen (the 2026-06-10 design).
    // Mirrors TodayFeature's universal-lifecycle-enum shape (`WeeklyViewState`). Depends ONLY on the repo
    // INTERFACES (`BriefRepository`/`ProfileRepository`) + `DesignSystem` + `DomainModels` + `CoachCore`
    // (the §3 feature dependency rule) + `Sharing` (the persisted last-seen-week watermark, DECISIONS #2)
    // — never a `*Live`, data-source client, GRDB, HealthKit, or WireModels.
    .target(
      name: "WeeklyFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        // `Sharing` (a DIRECT dep so a literal `import Sharing` resolves) backs the persisted
        // `@Shared(.appStorage)` last-seen-ISO-week watermark. TCA `@_exported`s it, so the build would
        // compile without this — the direct dep is for the explicit import (DECISIONS #2).
        .product(name: "Sharing", package: "swift-sharing"),
        // `BriefRepository` INTERFACE — `weeklyBrief(isoWeek:refresh:)` (get-or-cache, D9/4.2) + the typed
        // `BriefError`. Interface only (feature dependency rule), never *Live.
        "BriefRepository",
        // `ProfileRepository` INTERFACE — `zones()`, resolved once by the fetch effect so 9.2's pure rows
        // can render "Zone N · bpm" lines (DECISIONS #4, cross-plan with 9.2). Interface only, never *Live.
        "ProfileRepository",
        "DesignSystem",
        "DomainModels",
        "CoachCore",
      ],
      path: "Sources/Features/WeeklyFeature/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // WeeklyFeature exhaustive TestStore (host) — new-ISO-week detection, the get-or-cache fetch effect,
    // debounced refresh + cancellation, the rhythm derivation, and the UI toggles. Logic only — no
    // snapshot/UIKit symbols (§4.6 split). `Clocks` (a DIRECT dep — a transitively-resolved package is not
    // importable) supplies `TestClock` for the debounce; production injects the built-in `\.continuousClock`.
    .testTarget(
      name: "WeeklyFeatureTests",
      dependencies: [
        "WeeklyFeature",
        "BriefRepository",
        "ProfileRepository",
        "DomainModels",
        // `SampleData` vends the `WeeklyPlan` fixtures the fetch tests return from the stubbed repo.
        "SampleData",
        "CoachCore",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "Clocks", package: "swift-clocks"),
      ],
      path: "Sources/Features/WeeklyFeature/Tests/WeeklyFeatureTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // WeeklyView snapshots (the shell — normal / deload / collapsed states, light + dark) — iOS 26
    // simulator only, via `xcodebuild test`. `#if canImport(UIKit)`-guarded so it compiles to an empty
    // module on the host. `exclude: ["__Snapshots__"]` keeps the committed references out of the target.
    .testTarget(
      name: "WeeklyFeatureSnapshotTests",
      dependencies: [
        "WeeklyFeature",
        "DomainModels",
        "SampleData",
        "CoachTestSupport",
        "DesignSystem",
        // `Calendar.europeSofia` (the fixed-instant snapshot pin) lives in CoachCore.
        "CoachCore",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/WeeklyFeature/Tests/WeeklyFeatureSnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // The strength-test input feature (Epic 10.4) — the two-numeric-stepper "log today's max" screen the
    // weekly reminder deep-links into. Mirrors TodayFeature's target shape. Depends on `LocalRepositories`
    // (the `StrengthTestRepository` it saves through — an interface-less local module, the §4.3 exception)
    // + `DesignSystem`/`DomainModels`/`CoachCore` (the §3 feature dependency rule) — never a data-source
    // client, GRDB, HealthKit, WireModels, or `UserNotifications` (the tap glue lives in the app target).
    .target(
      name: "StrengthTestFeature",
      dependencies: [
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        "LocalRepositories",
        "DesignSystem",
        "DomainModels",
        // `isStrengthTestDue` + `Calendar.europeSofia` (the ISO-week due rule, TASK-001).
        "CoachCore",
      ],
      path: "Sources/Features/StrengthTestFeature/Sources",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // StrengthTestFeature exhaustive TestStore (host) — seed-from-`current`, the 0...300 clamp, save →
    // `save` recorded + `Delegate.saved`, and the `isDue` derivation. Logic only — no snapshot/UIKit
    // symbols (§4.6 split). Overrides `\.strengthTestRepository`/`\.date`/`\.calendar`.
    .testTarget(
      name: "StrengthTestFeatureTests",
      dependencies: [
        "StrengthTestFeature",
        "LocalRepositories",
        "DomainModels",
        "CoachCore",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
      ],
      path: "Sources/Features/StrengthTestFeature/Tests/StrengthTestFeatureTests",
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
    // StrengthTestView snapshots (the due + not-due states, light + dark) — iOS 26 simulator only, via
    // `xcodebuild test`. `#if canImport(UIKit)`-guarded so it compiles to an empty module on the host.
    // `exclude: ["__Snapshots__"]` keeps the committed references out of the target.
    .testTarget(
      name: "StrengthTestFeatureSnapshotTests",
      dependencies: [
        "StrengthTestFeature",
        "CoachTestSupport",
        "DesignSystem",
        "CoachCore",
        // `DomainModels.StrengthTest` is referenced directly to seed the pinned `current` stub —
        // `StrengthTestFeature` doesn't re-export it, so it must be a direct dep to `import` it.
        "DomainModels",
        .product(name: "ComposableArchitecture", package: "swift-composable-architecture"),
        .product(name: "SnapshotTesting", package: "swift-snapshot-testing"),
      ],
      path: "Sources/Features/StrengthTestFeature/Tests/StrengthTestFeatureSnapshotTests",
      exclude: ["__Snapshots__"],
      swiftSettings: [
        .swiftLanguageMode(.v6),
      ]
    ),
  ]
)
