@preconcurrency import CoreBluetooth
import Foundation

@MainActor
final class BluetoothMIDIPeripheral: NSObject, @preconcurrency CBPeripheralManagerDelegate {
  private enum BluetoothMIDIProfile {
    // Standardized by the Bluetooth LE MIDI specification, not app-specific IDs.
    static let service = CBUUID(string: "03B80E5A-EDE8-4B33-A751-6CE34EC4C700")
    static let dataIOCharacteristic = CBUUID(string: "7772E5DB-3868-4112-A1A9-F2669D106BF3")
  }

  var onStatusChange: (() -> Void)?

  private var manager: CBPeripheralManager!
  private var characteristic: CBMutableCharacteristic?
  private var subscribedCentrals: Set<UUID> = []
  private var hasPublishedService = false
  private(set) var statusLabel = "Bluetooth MIDI preparing"

  var canSend: Bool { !subscribedCentrals.isEmpty }

  override init() {
    super.init()
    manager = CBPeripheralManager(delegate: self, queue: .main)
  }

  func sendSustain(isDown: Bool) throws {
    guard canSend, let characteristic else { throw MIDITransportError.unavailable }

    let milliseconds = UInt16((ProcessInfo.processInfo.systemUptime * 1_000).truncatingRemainder(dividingBy: 8_192))
    let packet = MIDITransport.bluetoothPacket(isDown: isDown, timestamp: milliseconds)
    guard manager.updateValue(packet, for: characteristic, onSubscribedCentrals: nil) else {
      throw MIDITransportError.sendFailed(-1)
    }
  }

  func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
    switch peripheral.state {
    case .poweredOn:
      publishServiceIfNeeded()
    case .poweredOff:
      updateStatus("Bluetooth is off")
    case .unauthorized:
      updateStatus("Bluetooth permission is unavailable")
    case .unsupported:
      updateStatus("Bluetooth MIDI is unsupported")
    case .resetting, .unknown:
      updateStatus("Bluetooth MIDI preparing")
    @unknown default:
      updateStatus("Bluetooth MIDI is unavailable")
    }
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
    guard error == nil else {
      updateStatus("Bluetooth MIDI is unavailable")
      return
    }
    peripheral.startAdvertising([
      CBAdvertisementDataLocalNameKey: "Digital Sustain",
      CBAdvertisementDataServiceUUIDsKey: [BluetoothMIDIProfile.service],
    ])
  }

  func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
    updateStatus(error == nil ? "Bluetooth MIDI advertising" : "Bluetooth MIDI is unavailable")
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didSubscribeTo characteristic: CBCharacteristic) {
    subscribedCentrals.insert(central.identifier)
    updateStatus("Bluetooth MIDI connected")
  }

  func peripheralManager(_ peripheral: CBPeripheralManager, central: CBCentral, didUnsubscribeFrom characteristic: CBCharacteristic) {
    subscribedCentrals.remove(central.identifier)
    updateStatus("Bluetooth MIDI advertising")
  }

  func peripheralManagerIsReady(toUpdateSubscribers peripheral: CBPeripheralManager) {}

  private func publishServiceIfNeeded() {
    guard !hasPublishedService else {
      manager.startAdvertising([
        CBAdvertisementDataLocalNameKey: "Digital Sustain",
        CBAdvertisementDataServiceUUIDsKey: [BluetoothMIDIProfile.service],
      ])
      return
    }

    let characteristic = CBMutableCharacteristic(
      type: BluetoothMIDIProfile.dataIOCharacteristic,
      properties: [.read, .writeWithoutResponse, .notify],
      value: nil,
      permissions: .readable
    )
    let service = CBMutableService(type: BluetoothMIDIProfile.service, primary: true)
    service.characteristics = [characteristic]
    self.characteristic = characteristic
    hasPublishedService = true
    manager.add(service)
  }

  private func updateStatus(_ status: String) {
    guard statusLabel != status else { return }
    statusLabel = status
    onStatusChange?()
  }
}
