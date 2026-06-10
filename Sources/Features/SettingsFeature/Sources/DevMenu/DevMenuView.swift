#if DEBUG
  import ComposableArchitecture
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
        }

        Section("Session") {
          Button("Reset token & restart onboarding", role: .destructive) {
            store.send(.resetTokenTapped)
          }
        }
      }
      .navigationTitle("Dev Menu")
      .onAppear { store.send(.onAppear) }
    }
  }
#endif
