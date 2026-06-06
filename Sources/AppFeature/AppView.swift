import ComposableArchitecture
import SwiftUI

public struct AppView: View {
  let store: StoreOf<AppFeature>

  public init(store: StoreOf<AppFeature>) {
    self.store = store
  }

  public var body: some View {
    VStack(spacing: 12) {
      Image(systemName: "figure.run")
        .font(.largeTitle)
      Text("Coach")
        .font(.headline)
    }
    .onAppear { store.send(.onAppear) }
  }
}
