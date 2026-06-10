#if DEBUG
  import ComposableArchitecture
  import DevSettings
  import SampleData
  import SwiftUI

  /// The DEBUG dev menu UI (ARCHITECTURE §7.1): a `Toggle` for `useMockData`, one scenario `Picker` per
  /// `DevEndpoint`, and a destructive "reset token" action. Renders raw `rawValue` labels on purpose —
  /// this is a developer tool, so the DesignSystem "never show a raw machine key" boundary does not apply
  /// (PLAN Decisions / DECISIONS #2). The whole file is `#if DEBUG`, so it is absent from RELEASE.
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
        }

        ForEach(DevEndpoint.allCases, id: \.self) { endpoint in
          Section(endpoint.rawValue) {
            Picker(
              "Scenario",
              selection: Binding(
                get: { store.scenarios[endpoint] ?? endpoint.defaultScenario },
                set: { store.send(.scenarioSelected($0, endpoint)) }
              )
            ) {
              ForEach(SampleScenario.allCases, id: \.self) { scenario in
                Text(scenario.rawValue).tag(scenario)
              }
            }
          }
        }

        Section("SESSION") {
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
