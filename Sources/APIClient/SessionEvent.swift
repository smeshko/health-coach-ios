/// A session-level event published by the transport. `AppFeature` (Epic 06) subscribes to the
/// `AsyncStream<SessionEvent>` and routes `.unauthorized` to the Connect flow (§13/D13).
public enum SessionEvent: Sendable, Equatable {
  /// A 401 was received on an authenticated route — the stored token is no longer valid.
  case unauthorized
}
