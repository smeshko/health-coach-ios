#if DEBUG
  import ComposableArchitecture
  import DesignSystem
  import LogClient
  import SwiftUI

  /// Renders the recent log lines **newest-first** as styled rows (level badge · category · Sofia-local
  /// timestamp · monospaced message), over a filter bar — free-text search, a minimum-severity picker
  /// and per-category chips — plus toolbar **Clear** and **Refresh** actions. Error/notice rows are
  /// tinted for scannability. Empty + loading states included. `#if DEBUG`, like the rest of the dev menu.
  public struct LogViewerView: View {
    @Bindable var store: StoreOf<LogViewerFeature>
    /// Gates the initial load to once per presentation (mirrors `DevMenuView` — keeps a stale teardown
    /// `.onAppear` from re-firing; the toolbar's Refresh is the explicit reload).
    @State private var didLoad = false

    public init(store: StoreOf<LogViewerFeature>) {
      self.store = store
    }

    public var body: some View {
      VStack(spacing: 0) {
        LogFilterBar(store: store)
        Divider().overlay(Color.coachBorder)
        List {
          if store.filteredEntries.isEmpty {
            Text(store.isLoading ? "Loading…" : "No logs match the current filters.")
              .font(.coachTextMd)
              .foregroundStyle(.coachForegroundSubtle)
              .listRowBackground(Color.coachSurface)
          } else {
            // `filteredEntries` is oldest→newest; show newest first.
            ForEach(store.filteredEntries.reversed()) { entry in
              LogRow(entry: entry)
                .listRowBackground(Color.coachSurface)
                .listRowSeparatorTint(.coachBorder)
            }
          }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
      }
      .background(Color.coachBackground)
      .navigationTitle("Logs")
      .toolbar {
        // `.primaryAction` is the cross-platform trailing slot (the host build compiles every target —
        // `.topBarTrailing` is iOS-only and would break macOS).
        ToolbarItemGroup(placement: .primaryAction) {
          Button(role: .destructive) {
            store.send(.clearTapped)
          } label: {
            Label("Clear", systemImage: "trash")
          }
          .tint(.coachNegative)
          Button("Refresh", systemImage: "arrow.clockwise") {
            store.send(.refreshTapped)
          }
        }
      }
      .tint(.coachAccent)
      .onAppear {
        guard !didLoad else { return }
        didLoad = true
        store.send(.onAppear)
      }
    }

    /// The tint for a level's badge + (error/notice) message — design status tokens so color is a cue,
    /// never the only one (the badge always carries the level word too).
    static func tint(for level: LogLevel?) -> Color {
      switch level {
      case .error: .coachNegative
      case .notice: .coachWarning
      case .info: .coachAccent
      case .debug, nil: .coachForegroundMuted
      }
    }
  }

  /// The search + level + category filter bar above the log list.
  private struct LogFilterBar: View {
    let store: StoreOf<LogViewerFeature>

    var body: some View {
      VStack(spacing: CoachSpacing.spaceSm) {
        HStack(spacing: CoachSpacing.spaceXs) {
          Image(systemName: "magnifyingglass").foregroundStyle(.coachForegroundSubtle)
          TextField(
            "Search logs",
            text: Binding(get: { store.query }, set: { store.send(.queryChanged($0)) })
          )
          .font(.coachTextMd)
          // `.textInputAutocapitalization` is iOS-only; the host build compiles this target for macOS.
          #if os(iOS)
            .textInputAutocapitalization(.never)
          #endif
          .autocorrectionDisabled()
          if !store.query.isEmpty {
            Button {
              store.send(.queryChanged(""))
            } label: {
              Image(systemName: "xmark.circle.fill").foregroundStyle(.coachForegroundSubtle)
            }
            .buttonStyle(.plain)
          }
        }
        .padding(.horizontal, CoachSpacing.spaceSm)
        .padding(.vertical, CoachSpacing.spaceXs)
        .background(RoundedRectangle(cornerRadius: CoachRadius.sm).fill(.coachSurfaceSunken))

        HStack(spacing: CoachSpacing.spaceLg) {
          // A native `Picker` inside the `Menu` (rather than hand-rolled `Button`+checkmark rows) lets
          // SwiftUI manage the selection/checkmark itself, so the menu content isn't rebuilt on every
          // tap — which is what spammed the `updateVisibleMenuWithBlock` console warnings. The custom
          // icon+text label is preserved via the trailing `label:`.
          Menu {
            Picker(
              "Minimum level",
              selection: Binding(get: { store.minLevel }, set: { store.send(.minLevelChanged($0)) })
            ) {
              ForEach(LogLevel.ordered, id: \.self) { level in
                Text(level.devMenuLabel).tag(level)
              }
            }
          } label: {
            HStack(spacing: CoachSpacing.space2xs) {
              Image(systemName: "line.3.horizontal.decrease.circle")
              Text(store.minLevel.devMenuLabel)
            }
            .font(.coachTextXs)
            .foregroundStyle(.coachAccent)
          }

          Menu {
            Picker(
              "Date range",
              selection: Binding(get: { store.dateRange }, set: { store.send(.dateRangeChanged($0)) })
            ) {
              ForEach(DateRange.allCases, id: \.self) { range in
                Text(range.devMenuLabel).tag(range)
              }
            }
          } label: {
            HStack(spacing: CoachSpacing.space2xs) {
              Image(systemName: "calendar")
              Text(store.dateRange.devMenuLabel)
            }
            .font(.coachTextXs)
            .foregroundStyle(.coachAccent)
          }

          Spacer(minLength: 0)
        }

        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: CoachSpacing.spaceXs) {
            ForEach(LogCategory.allCases, id: \.self) { category in
              let isOn = store.enabledCategories.contains(category)
              Button {
                store.send(.categoryToggled(category))
              } label: {
                Text(category.devMenuLabel)
                  .font(.coachTextXs)
                  .foregroundStyle(isOn ? .coachAccent : .coachForegroundMuted)
                  .padding(.vertical, CoachSpacing.space2xs)
                  .padding(.horizontal, CoachSpacing.spaceSm)
                  .background(Capsule().fill(isOn ? Color.coachAccentSoft : .clear))
                  .overlay(Capsule().stroke(isOn ? .clear : .coachBorder, lineWidth: 1))
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
      .padding(CoachSpacing.spaceMd)
      .background(Color.coachSurface)
    }
  }

  /// One styled log row: a level badge + category + timestamp header over the monospaced message.
  private struct LogRow: View {
    let entry: LogEntry

    var body: some View {
      VStack(alignment: .leading, spacing: CoachSpacing.space2xs) {
        HStack(spacing: CoachSpacing.spaceXs) {
          if let level = entry.level {
            Text(level.devMenuLabel.uppercased())
              .font(.coachText2xs)
              .foregroundStyle(LogViewerView.tint(for: level))
          }
          if let category = entry.category {
            Text(category.devMenuLabel)
              .font(.coachTextXs)
              .foregroundStyle(.coachForegroundSubtle)
              .lineLimit(1)
          }
          Spacer(minLength: CoachSpacing.spaceXs)
          if !entry.timestamp.isEmpty {
            // Full `yyyy-MM-dd HH:mm:ss.SSS` (Sofia). `fixedSize` so the date is never truncated away —
            // the category truncates first if the row is tight.
            Text(entry.timestamp)
              .font(.system(.caption2, design: .monospaced))
              .foregroundStyle(.coachForegroundSubtle)
              .lineLimit(1)
              .fixedSize(horizontal: true, vertical: false)
          }
        }
        Text(entry.message.isEmpty ? entry.raw : entry.message)
          .font(.system(.caption2, design: .monospaced))
          .foregroundStyle(entry.level == .error ? .coachNegative : .coachForeground)
          .textSelection(.enabled)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
      .padding(.vertical, CoachSpacing.space2xs)
    }
  }
#endif
