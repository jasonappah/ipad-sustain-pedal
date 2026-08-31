@testable import IPadSustainPedal
import Foundation
import XCTest

final class MIDITransportTests: XCTestCase {
  func testSustainOnUsesChannelOneController64Value127() {
    XCTAssertEqual(MIDITransport.sustainMessage(isDown: true), 0x20B0407F)
  }

  func testSustainOffUsesChannelOneController64Value0() {
    XCTAssertEqual(MIDITransport.sustainMessage(isDown: false), 0x20B04000)
  }

  func testBluetoothPacketUsesCC64WithBLETimestamp() {
    XCTAssertEqual(MIDITransport.bluetoothPacket(isDown: true, timestamp: 0x123), Data([0x82, 0xA3, 0xB0, 64, 127]))
    XCTAssertEqual(MIDITransport.bluetoothPacket(isDown: false, timestamp: 0x123), Data([0x82, 0xA3, 0xB0, 64, 0]))
  }

  func testTransportPreferencesRespectEachToggle() {
    let suiteName = "MIDITransportPreferencesTests"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    defaults.set(false, forKey: MIDITransportPreferences.networkMIDIKey)
    defaults.set(true, forKey: MIDITransportPreferences.bluetoothMIDIKey)
    defaults.set(false, forKey: MIDITransportPreferences.usbMIDIKey)

    XCTAssertEqual(
      MIDITransportConfiguration(defaults: defaults),
      MIDITransportConfiguration(networkMIDIEnabled: false, bluetoothMIDIEnabled: true, usbMIDIEnabled: false)
    )
  }
}
