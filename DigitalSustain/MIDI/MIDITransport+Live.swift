@preconcurrency import CoreMIDI

extension MIDITransport {
  static let live = Self(
    prepare: {
      await MainActor.run {
        LiveMIDITransport.shared.prepare()
      }
    },
    sendSustain: { isDown in
      try await MainActor.run {
        try LiveMIDITransport.shared.sendSustain(isDown: isDown)
      }
    }
  )

  static func sustainMessage(isDown: Bool) -> UInt32 {
    let status = UInt32(0xB0) << 16
    let controller = UInt32(64) << 8
    let value: UInt32 = isDown ? 127 : 0
    return (UInt32(0x2) << 28) | status | controller | value
  }
}

@MainActor
private final class LiveMIDITransport {
  static let shared = LiveMIDITransport()

  private let session = MIDINetworkSession.default()
  private let client: MIDIClientRef
  private let outputPort: MIDIPortRef
  private let initializationError: MIDITransportError?

  private init() {
    var newClient = MIDIClientRef()
    let clientResult = MIDIClientCreate("Digital Sustain" as CFString, nil, nil, &newClient)
    client = newClient

    guard clientResult == noErr else {
      outputPort = 0
      initializationError = .sendFailed(clientResult)
      return
    }

    var newOutputPort = MIDIPortRef()
    let portResult = MIDIOutputPortCreate(newClient, "Digital Sustain Output" as CFString, &newOutputPort)
    outputPort = newOutputPort
    initializationError = portResult == noErr ? nil : .sendFailed(portResult)
  }

  func prepare() -> MIDITransportStatus {
    session.isEnabled = true
    session.connectionPolicy = .anyone

    let sessionName = session.networkName
    guard initializationError == nil, outputPort != 0, session.destinationEndpoint() != 0 else {
      return .unavailable(message: "MIDI output is unavailable")
    }

    return session.connections().isEmpty
      ? .ready(sessionName: sessionName)
      : .connected(sessionName: sessionName)
  }

  func sendSustain(isDown: Bool) throws {
    guard initializationError == nil, session.isEnabled, outputPort != 0, session.destinationEndpoint() != 0 else {
      throw MIDITransportError.unavailable
    }

    var eventList = MIDIEventList()
    let packet = MIDIEventListInit(&eventList, ._1_0)
    var message = MIDITransport.sustainMessage(isDown: isDown)
    _ = withUnsafePointer(to: &message) { messagePointer in
      MIDIEventListAdd(
        &eventList,
        MemoryLayout<MIDIEventList>.size,
        packet,
        0,
        1,
        messagePointer
      )
    }

    let result = MIDISendEventList(outputPort, session.destinationEndpoint(), &eventList)
    guard result == noErr else {
      throw MIDITransportError.sendFailed(result)
    }
  }
}
