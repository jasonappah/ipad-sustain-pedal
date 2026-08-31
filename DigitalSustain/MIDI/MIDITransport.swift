import ComposableArchitecture

enum MIDITransportStatus: Equatable, Sendable {
  case preparing
  case ready(sessionName: String)
  case connected(sessionName: String)
  case unavailable(message: String)
  case failed(message: String)

  var canSend: Bool {
    switch self {
    case .ready, .connected:
      true
    case .preparing, .unavailable, .failed:
      false
    }
  }

  var label: String {
    switch self {
    case .preparing:
      "Preparing MIDI…"
    case let .ready(sessionName):
      "Ready — \(sessionName)"
    case let .connected(sessionName):
      "Connected — \(sessionName)"
    case let .unavailable(message), let .failed(message):
      message
    }
  }
}

enum MIDITransportError: Error, Equatable, Sendable {
  case unavailable
  case sendFailed(Int32)
}

struct MIDITransport: Sendable {
  var prepare: @Sendable () async -> MIDITransportStatus
  var sendSustain: @Sendable (Bool) async throws -> Void
  var statusUpdates: @Sendable () async -> AsyncStream<MIDITransportStatus> = {
    AsyncStream { $0.finish() }
  }
}

extension MIDITransport: DependencyKey {
  static let liveValue = MIDITransport.live
}

extension DependencyValues {
  var midiTransport: MIDITransport {
    get { self[MIDITransport.self] }
    set { self[MIDITransport.self] = newValue }
  }
}
