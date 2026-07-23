#if DEBUG
  import ComposableArchitecture
  import DesignSystem
  import DevSettings
  import LogClient
  import SampleData
  import SwiftUI

  /// The DEBUG dev menu UI (ARCHITECTURE §7.1). **MOCK DATA**: a `useMockData` toggle that, when on,
  /// reveals one row per `DevEndpoint` — a navigation-link `Picker` listing **only that endpoint's**
  /// scenarios (`DevEndpoint.scenarios`). **LOGGING**: a toggle per `LogCategory` (always-on categories
  /// are shown on + disabled). **SESSION**: a destructive reset-token action. Labels are human-readable
  /// (`devMenuLabel`), not raw `rawValue`s. The whole file is `#if DEBUG`, so it is absent from RELEASE.
  public struct DevMenuView: View {
    @Bindable var store: StoreOf<DevMenuFeature>
    /// Gates the seed so it fires exactly once per presentation. Without it SwiftUI delivers a stale
    /// `.onAppear` while the sheet is torn down by the `.main → .onboarding` swap that "Reset token"
    /// triggers — that late `.presented(.onAppear)` reaches the root after it is already `.onboarding`,
    /// tripping TCA's "received a child action when child state was set to a different case" warning.
    @State private var didSeed = false

    public init(store: StoreOf<DevMenuFeature>) {
      self.store = store
    }

    public var body: some View {
      Form {
        Section {
          Toggle(
            "Use mock data",
            isOn: Binding(
              get: { store.useMockData },
              set: { store.send(.useMockDataToggled($0)) }
            )
          )
          // The scenario pickers only matter when mock data is on — the toggle shows/hides them.
          if store.useMockData {
            ForEach(DevEndpoint.allCases, id: \.self) { endpoint in
              Picker(
                endpoint.devMenuLabel,
                selection: Binding(
                  get: { store.scenarios[endpoint] ?? endpoint.defaultScenario },
                  set: { store.send(.scenarioSelected($0, endpoint)) }
                )
              ) {
                ForEach(endpoint.scenarios, id: \.self) { scenario in
                  Text(scenario.devMenuLabel).tag(scenario)
                }
              }
              // `.menu` collapses to one row (endpoint label + current fixture) that opens the
              // endpoint's own options on tap. (`.navigationLink` is iOS-only — it breaks the host build.)
              .pickerStyle(.menu)
            }
          }
        } header: {
          Text("Mock data")
        } footer: {
          Text("Off serves live data. On routes each endpoint to the selected fixture.")
        }
        .listRowBackground(Color.coachSurface)

        Section("Logging") {
          ForEach(LogCategory.allCases, id: \.self) { category in
            Toggle(
              category.devMenuLabel,
              isOn: Binding(
                get: { store.logEnabled[category] ?? category.isAlwaysOn },
                set: { store.send(.logCategoryToggled(category, $0)) }
              )
            )
            .disabled(category.isAlwaysOn)
          }
          Button("View logs") { store.send(.viewLogsTapped) }
        }
        .listRowBackground(Color.coachSurface)

        Section("Session") {
          Button("Reset token & restart onboarding", role: .destructive) {
            store.send(.resetTokenTapped)
          }
        }
        .listRowBackground(Color.coachSurface)

        Section {
          Button("Force full re-sync (clear sync anchor)") {
            store.send(.forceFullResyncTapped)
          }
        } header: {
          Text("Sync")
        } footer: {
          Text(
            "Deletes the sync watermark anchor. The next sync re-exports all HealthKit history "
              + "since the backfill floor (2026-05-23) in weekly chunks; the server dedups by uuid."
          )
        }
        .listRowBackground(Color.coachSurface)
      }
      .scrollContentBackground(.hidden)
      .background(Color.coachBackground)
      .tint(.coachAccent)
      .navigationTitle("Dev Menu")
      .navigationDestination(item: $store.scope(state: \.logViewer, action: \.logViewer)) { logStore in
        LogViewerView(store: logStore)
      }
      .onAppear {
        guard !didSeed else { return }
        didSeed = true
        store.send(.onAppear)
      }
    }
  }
#endif
