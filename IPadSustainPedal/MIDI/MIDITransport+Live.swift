@preconcurrency import CoreBluetooth
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
    },
    statusUpdates: {
      await MainActor.run {
        LiveMIDITransport.shared.statusUpdates()
      }
    }
  )

  static func sustainMessage(isDown: Bool) -> UInt32 {
    let status = UInt32(0xB0) << 16
    let controller = UInt32(64) << 8
    let value: UInt32 = isDown ? 127 : 0
    return (UInt32(0x2) << 28) | status | controller | value
  }

  static func bluetoothPacket(isDown: Bool, timestamp: UInt16) -> Data {
    let timestamp = timestamp & 0x1FFF
    return Data([
      0x80 | UInt8(timestamp >> 7),
      0x80 | UInt8(timestamp & 0x7F),
      0xB0,
      64,
      isDown ? 127 : 0,
    ])
  }
}

@MainActor
private final class LiveMIDITransport {
  static let shared = LiveMIDITransport()

  private let session = MIDINetworkSession.default()
  private let bluetooth = BluetoothMIDIPeripheral()
  private let client: MIDIClientRef
  private let outputPort: MIDIPortRef
  private let usbSource: MIDIEndpointRef
  private let clientInitializationError: MIDITransportError?
  private var statusContinuations: [UUID: AsyncStream<MIDITransportStatus>.Continuation] = [:]

  private init() {
    var newClient = MIDIClientRef()
    let clientResult = MIDIClientCreate("iPad Sustain Pedal" as CFString, nil, nil, &newClient)
    client = newClient

    guard clientResult == noErr else {
      outputPort = 0
      usbSource = 0
      clientInitializationError = .sendFailed(clientResult)
      return
    }

    var newOutputPort = MIDIPortRef()
    _ = MIDIOutputPortCreate(newClient, "iPad Sustain Pedal Output" as CFString, &newOutputPort)
    outputPort = newOutputPort

    var newUSBSource = MIDIEndpointRef()
    _ = MIDISourceCreateWithProtocol(
      newClient,
      "iPad Sustain Pedal USB" as CFString,
      ._1_0,
      &newUSBSource
    )
    usbSource = newUSBSource
    clientInitializationError = nil

    bluetooth.onStatusChange = { [weak self] in
      self?.publishStatus()
    }

    NotificationCenter.default.addObserver(
      forName: Notification.Name(MIDINetworkNotificationSessionDidChange),
      object: session,
      queue: .main
    ) { [weak self] _ in
      Task { @MainActor in
        self?.publishStatus()
      }
    }
  }

  func prepare() -> MIDITransportStatus {
    let configuration = MIDITransportConfiguration()
    bluetooth.setEnabled(configuration.bluetoothMIDIEnabled)
    session.isEnabled = configuration.networkMIDIEnabled
    if configuration.networkMIDIEnabled {
      session.connectionPolicy = .anyone
    }
    return currentStatus()
  }

  func sendSustain(isDown: Bool) throws {
    let configuration = MIDITransportConfiguration()
    var didSend = false
    var lastError: MIDITransportError?

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

    if configuration.usbMIDIEnabled, usbSource != 0 {
      let result = MIDIReceivedEventList(usbSource, &eventList)
      if result == noErr {
        didSend = true
      } else {
        lastError = .sendFailed(result)
      }
    }

    if configuration.bluetoothMIDIEnabled, bluetooth.canSend {
      do {
        try bluetooth.sendSustain(isDown: isDown)
        didSend = true
      } catch let error as MIDITransportError {
        lastError = error
      }
    }

    if configuration.networkMIDIEnabled, networkOutputIsAvailable, !session.connections().isEmpty {
      let result = MIDISendEventList(outputPort, session.destinationEndpoint(), &eventList)
      if result == noErr {
        didSend = true
      } else {
        lastError = .sendFailed(result)
      }
    }

    guard didSend else { throw lastError ?? .unavailable }
  }

  func statusUpdates() -> AsyncStream<MIDITransportStatus> {
    let identifier = UUID()
    return AsyncStream { continuation in
      statusContinuations[identifier] = continuation
      continuation.yield(currentStatus())
      continuation.onTermination = { [weak self] _ in
        Task { @MainActor in
          self?.statusContinuations.removeValue(forKey: identifier)
        }
      }
    }
  }

  private func currentStatus() -> MIDITransportStatus {
    let configuration = MIDITransportConfiguration()
    guard configuration.hasEnabledTransport else {
      return .unavailable(message: "No MIDI transport enabled — open Settings")
    }

    let enabled = configuration.enabledTransportNames.joined(separator: ", ")
    let details = [
      configuration.usbMIDIEnabled ? "USB MIDI \(usbSource == 0 ? "unavailable" : "enabled")" : nil,
      configuration.bluetoothMIDIEnabled ? bluetooth.statusLabel : nil,
      configuration.networkMIDIEnabled ? session.networkName : nil,
    ]
    .compactMap { $0 }
    .joined(separator: " • ")
    let name = "Enabled: \(enabled) • \(details)"

    let hasConnectedPeer =
      (configuration.networkMIDIEnabled && !session.connections().isEmpty)
      || (configuration.bluetoothMIDIEnabled && bluetooth.canSend)
    return hasConnectedPeer
      ? .connected(sessionName: name)
      : .ready(sessionName: name)
  }

  private var networkOutputIsAvailable: Bool {
    session.isEnabled && outputPort != 0 && session.destinationEndpoint() != 0
  }

  private func publishStatus() {
    let status = currentStatus()
    statusContinuations.values.forEach { $0.yield(status) }
  }
}
