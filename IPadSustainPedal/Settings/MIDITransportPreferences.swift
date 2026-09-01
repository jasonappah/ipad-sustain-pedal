import Foundation

struct MIDITransportConfiguration: Equatable, Sendable {
  var networkMIDIEnabled: Bool
  var bluetoothMIDIEnabled: Bool
  var usbMIDIEnabled: Bool

  init(
    networkMIDIEnabled: Bool,
    bluetoothMIDIEnabled: Bool,
    usbMIDIEnabled: Bool
  ) {
    self.networkMIDIEnabled = networkMIDIEnabled
    self.bluetoothMIDIEnabled = bluetoothMIDIEnabled
    self.usbMIDIEnabled = usbMIDIEnabled
  }

  init(defaults: UserDefaults = .standard) {
    networkMIDIEnabled = defaults.enabledValue(forKey: MIDITransportPreferences.networkMIDIKey)
    bluetoothMIDIEnabled = defaults.enabledValue(forKey: MIDITransportPreferences.bluetoothMIDIKey)
    usbMIDIEnabled = defaults.enabledValue(forKey: MIDITransportPreferences.usbMIDIKey)
  }

  var hasEnabledTransport: Bool {
    networkMIDIEnabled || bluetoothMIDIEnabled || usbMIDIEnabled
  }

  var enabledTransportNames: [String] {
    [
      networkMIDIEnabled ? "Network MIDI" : nil,
      bluetoothMIDIEnabled ? "Bluetooth MIDI" : nil,
      usbMIDIEnabled ? "USB MIDI" : nil,
    ]
    .compactMap { $0 }
  }
}

enum MIDITransportPreferences {
  static let networkMIDIKey = "networkMIDIEnabled"
  static let bluetoothMIDIKey = "bluetoothMIDIEnabled"
  static let usbMIDIKey = "usbMIDIEnabled"
  static let hasSeenSettingsHintKey = "hasSeenTransportSettingsHint"
  static let showTouchDiagnosticsKey = "showTouchDiagnostics"
}

private extension UserDefaults {
  func enabledValue(forKey key: String) -> Bool {
    object(forKey: key) as? Bool ?? true
  }
}
