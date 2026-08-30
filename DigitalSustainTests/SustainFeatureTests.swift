@testable import DigitalSustain
import ComposableArchitecture
import SwiftUI
import XCTest

@MainActor
final class SustainFeatureTests: XCTestCase {
  func testPressThenReleaseSendsStandardPedalSequence() async {
    let events = MIDIEvents()
    let store = TestStore(initialState: readyState) {
      SustainFeature()
    } withDependencies: {
      $0.midiTransport = MIDITransport(
        prepare: { .ready(sessionName: "iPad") },
        sendSustain: { isDown in await events.append(isDown) }
      )
    }

    await store.send(.pedalPressed) {
      $0.isPressed = true
      $0.feedback = .pressed
      $0.pendingMIDICommands = [true]
      $0.isSendingMIDI = true
    }
    await store.receive(.midiDelivered(true)) {
      $0.pendingMIDICommands = []
      $0.isSendingMIDI = false
    }

    await store.send(.pedalReleased) {
      $0.isPressed = false
      $0.feedback = .released
      $0.pendingMIDICommands = [false]
      $0.isSendingMIDI = true
    }
    await store.receive(.midiDelivered(false)) {
      $0.pendingMIDICommands = []
      $0.isSendingMIDI = false
    }
    await store.finish()

    let values = await events.values
    XCTAssertEqual(values, [true, false])
  }

  func testInactiveSceneReleasesOnlyOnce() async {
    let events = MIDIEvents()
    let store = TestStore(initialState: SustainFeature.State(isPressed: true, transportStatus: .connected(sessionName: "iPad"))) {
      SustainFeature()
    } withDependencies: {
      $0.midiTransport = MIDITransport(
        prepare: { .connected(sessionName: "iPad") },
        sendSustain: { isDown in await events.append(isDown) }
      )
    }

    await store.send(.scenePhaseChanged(.inactive)) {
      $0.isPressed = false
      $0.feedback = .none
      $0.pendingMIDICommands = [false]
      $0.isSendingMIDI = true
    }
    await store.receive(.midiDelivered(false)) {
      $0.pendingMIDICommands = []
      $0.isSendingMIDI = false
    }
    await store.finish()
    await store.send(.pedalReleased)
    await store.finish()

    let values = await events.values
    XCTAssertEqual(values, [false])
  }

  func testUnavailablePedalDoesNotLatchDown() async {
    let store = TestStore(initialState: SustainFeature.State(transportStatus: .unavailable(message: "MIDI unavailable"))) {
      SustainFeature()
    }

    await store.send(.pedalPressed) {
      $0.feedback = .error
    }
  }

  func testSendFailureClearsPedalAndReleases() async {
    let events = MIDIEvents()
    let store = TestStore(initialState: readyState) {
      SustainFeature()
    } withDependencies: {
      $0.midiTransport = MIDITransport(
        prepare: { .ready(sessionName: "iPad") },
        sendSustain: { isDown in
          await events.append(isDown)
          if isDown { throw MIDITransportError.unavailable }
        }
      )
    }

    await store.send(.pedalPressed) {
      $0.isPressed = true
      $0.feedback = .pressed
      $0.pendingMIDICommands = [true]
      $0.isSendingMIDI = true
    }
    await store.receive(.midiFailed(true, .unavailable)) {
      $0.isPressed = false
      $0.transportStatus = .failed(message: "MIDI send failed")
      $0.feedback = .error
      $0.pendingMIDICommands = [false]
      $0.isSendingMIDI = true
    }
    await store.receive(.midiDelivered(false)) {
      $0.pendingMIDICommands = []
      $0.isSendingMIDI = false
    }
    await store.finish()

    let values = await events.values
    XCTAssertEqual(values, [true, false])
  }

  func testReleaseWaitsForAnInFlightPressBeforeSendingRelease() async {
    let events = MIDIEvents()
    let gate = SendGate()
    let store = TestStore(initialState: readyState) {
      SustainFeature()
    } withDependencies: {
      $0.midiTransport = MIDITransport(
        prepare: { .ready(sessionName: "iPad") },
        sendSustain: { isDown in
          await events.append(isDown)
          if isDown { await gate.waitForRelease() }
        }
      )
    }

    await store.send(.pedalPressed) {
      $0.isPressed = true
      $0.feedback = .pressed
      $0.pendingMIDICommands = [true]
      $0.isSendingMIDI = true
    }
    await gate.waitUntilPressIsInFlight()

    await store.send(.pedalReleased) {
      $0.isPressed = false
      $0.feedback = .released
      $0.pendingMIDICommands = [true, false]
    }

    await gate.open()
    await store.receive(.midiDelivered(true)) {
      $0.pendingMIDICommands = [false]
    }
    await store.receive(.midiDelivered(false)) {
      $0.pendingMIDICommands = []
      $0.isSendingMIDI = false
    }
    await store.finish()

    let values = await events.values
    XCTAssertEqual(values, [true, false])
  }

  private var readyState: SustainFeature.State {
    SustainFeature.State(transportStatus: .ready(sessionName: "iPad"))
  }
}

private actor MIDIEvents {
  private var recorded: [Bool] = []

  func append(_ value: Bool) {
    recorded.append(value)
  }

  var values: [Bool] {
    recorded
  }
}

private actor SendGate {
  private var pressHasStarted = false
  private var pressStartWaiters: [CheckedContinuation<Void, Never>] = []
  private var releaseContinuation: CheckedContinuation<Void, Never>?

  func waitForRelease() async {
    pressHasStarted = true
    pressStartWaiters.forEach { $0.resume() }
    pressStartWaiters = []
    await withCheckedContinuation { releaseContinuation = $0 }
  }

  func waitUntilPressIsInFlight() async {
    guard !pressHasStarted else { return }
    await withCheckedContinuation { pressStartWaiters.append($0) }
  }

  func open() {
    releaseContinuation?.resume()
    releaseContinuation = nil
  }
}
