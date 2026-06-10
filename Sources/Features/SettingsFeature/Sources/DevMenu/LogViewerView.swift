#if DEBUG
  import ComposableArchitecture
  import SwiftUI

  /// Renders the recent log lines **newest-first** in a monospaced, selectable list, with a refresh
  /// action. Error / notice lines are tinted for scannability. Empty + loading states included. The
  /// raw formatted lines (`HH:mm:ss.SSS LEVEL [category] message …`) are shown verbatim — this is a
  /// developer tool. `#if DEBUG`, like the rest of the dev menu.
  public struct LogViewerView: View {
    @Bindable var store: StoreOf<LogViewerFeature>

    public init(store: StoreOf<LogViewerFeature>) {
      self.store = store
    }

    public var body: some View {
      List {
        if store.lines.isEmpty {
          Text(store.isLoading ? "Loading…" : "No logs captured yet.")
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
          ForEach(Array(store.lines.enumerated().reversed()), id: \.offset) { _, line in
            Text(line)
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(Self.tint(for: line))
              .textSelection(.enabled)
          }
        }
      }
      .navigationTitle("Logs")
      .toolbar {
        Button("Refresh", systemImage: "arrow.clockwise") {
          store.send(.refreshTapped)
        }
      }
      .onAppear { store.send(.onAppear) }
    }

    /// Tint by the level token in the rendered line (`… ERROR …` / `… NOTICE …`); everything else is
    /// the default colour. Substring match is good enough for a developer tool.
    private static func tint(for line: String) -> Color {
      if line.contains(" ERROR ") { return .red }
      if line.contains(" NOTICE ") { return .orange }
      return .primary
    }
  }
#endif
