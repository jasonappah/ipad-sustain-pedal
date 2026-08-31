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
    let clientResult = MIDIClientCreate("Digital Sustain" as CFString, nil, nil, &newClient)
    client = newClient

    guard clientResult == noErr else {
      outputPort = 0
      usbSource = 0
      clientInitializationError = .sendFailed(clientResult)
      return
    }

    var newOutputPort = MIDIPortRef()
    _ = MIDIOutputPortCreate(newClient, "Digital Sustain Output" as CFString, &newOutputPort)
    outputPort = newOutputPort

    var newUSBSource = MIDIEndpointRef()
    _ = MIDISourceCreateWithProtocol(
      newClient,
      "Digital Sustain USB" as CFString,
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
    session.isEnabled = true
    session.connectionPolicy = .anyone

    guard clientInitializationError == nil, usbSource != 0 || networkOutputIsAvailable else {
      return .unavailable(message: "MIDI output is unavailable")
    }
    return currentStatus()
  }

  func sendSustain(isDown: Bool) throws {
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

    if usbSource != 0 {
      let result = MIDIReceivedEventList(usbSource, &eventList)
#if DEBUG
      print("Digital Sustain USB send result: \(result)")
#endif
      if result == noErr {
        didSend = true
      } else {
        lastError = .sendFailed(result)
      }
    }

    if bluetooth.canSend {
      do {
        try bluetooth.sendSustain(isDown: isDown)
#if DEBUG
        print("Digital Sustain Bluetooth send result: success")
#endif
        didSend = true
      } catch let error as MIDITransportError {
#if DEBUG
        print("Digital Sustain Bluetooth send error: \(error)")
#endif
        lastError = error
      }
    }

    if networkOutputIsAvailable, !session.connections().isEmpty {
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
    guard clientInitializationError == nil, usbSource != 0 || networkOutputIsAvailable else {
      return .unavailable(message: "MIDI output is unavailable")
    }

    let name = "\(session.networkName) • USB MIDI ready • \(bluetooth.statusLabel)"
    return session.connections().isEmpty && !bluetooth.canSend
      ? .ready(sessionName: name)
      : .connected(sessionName: name)
  }

  private var networkOutputIsAvailable: Bool {
    session.isEnabled && outputPort != 0 && session.destinationEndpoint() != 0
  }

  private func publishStatus() {
    let status = currentStatus()
    statusContinuations.values.forEach { $0.yield(status) }
  }
}
