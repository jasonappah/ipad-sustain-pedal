import ComposableArchitecture
import SwiftUI

struct SustainFeature: Reducer {
  @ObservableState
  struct State: Equatable {
    var isPressed = false
    var transportStatus: MIDITransportStatus = .preparing
    var feedback: PedalFeedback = .none

    // MIDI effects may suspend. Keep their commands in reducer state so each
    // transition is emitted in order, even when a user releases immediately.
    var pendingMIDICommands: [Bool] = []
    var isSendingMIDI = false
  }

  enum PedalFeedback: Equatable {
    case none
    case pressed
    case released
    case error
  }

  enum Action: Equatable {
    case task
    case transportPrepared(MIDITransportStatus)
    case pedalPressed
    case pedalReleased
    case scenePhaseChanged(ScenePhase)
    case midiDelivered(Bool)
    case midiFailed(Bool, MIDITransportError)
  }

  @Dependency(\.midiTransport) var midiTransport

  private enum CancelID {
    case statusUpdates
  }

  func reduce(into state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .task:
      state.transportStatus = .preparing
      return .merge(
        .run { [midiTransport] send in
          await send(.transportPrepared(await midiTransport.prepare()))
        },
        .run { [midiTransport] send in
          for await status in await midiTransport.statusUpdates() {
            await send(.transportPrepared(status))
          }
        }
        .cancellable(id: CancelID.statusUpdates, cancelInFlight: true)
      )

    case let .transportPrepared(status):
      state.transportStatus = status
      return .none

    case .pedalPressed:
      guard !state.isPressed else { return .none }
      guard state.transportStatus.canSend else {
        state.feedback = .error
        return .none
      }

      state.isPressed = true
      state.feedback = .pressed
      return enqueueSustain(true, into: &state)

    case .pedalReleased:
      return release(&state)

    case let .scenePhaseChanged(phase):
      if phase == .active {
        return .run { [midiTransport] send in
          await send(.transportPrepared(await midiTransport.prepare()))
        }
      }
      return release(&state, feedback: .none)

    case let .midiDelivered(isDown):
      guard state.pendingMIDICommands.first == isDown else { return .none }
      state.pendingMIDICommands.removeFirst()
      return sendNextMIDICommand(into: &state)

    case let .midiFailed(isDown, error):
      guard state.pendingMIDICommands.first == isDown else { return .none }
      state.pendingMIDICommands.removeFirst()
      state.isPressed = false
      state.transportStatus = .failed(message: "MIDI send failed: \(error)")
      state.feedback = .error

      // A failed press can still have reached the receiver. Put one release
      // behind any already-queued release; a failed release is not retried.
      if isDown && !state.pendingMIDICommands.contains(false) {
        state.pendingMIDICommands.append(false)
      }
      return sendNextMIDICommand(into: &state)
    }
  }

  private func release(
    _ state: inout State,
    feedback: PedalFeedback = .released
  ) -> Effect<Action> {
    guard state.isPressed else { return .none }
    state.isPressed = false
    state.feedback = feedback
    return enqueueSustain(false, into: &state)
  }

  private func enqueueSustain(_ isDown: Bool, into state: inout State) -> Effect<Action> {
    state.pendingMIDICommands.append(isDown)
    guard !state.isSendingMIDI else { return .none }
    return sendNextMIDICommand(into: &state)
  }

  private func sendNextMIDICommand(into state: inout State) -> Effect<Action> {
    guard let isDown = state.pendingMIDICommands.first else {
      state.isSendingMIDI = false
      return .none
    }

    state.isSendingMIDI = true
    return .run { [midiTransport] send in
      do {
        try await midiTransport.sendSustain(isDown)
        await send(.midiDelivered(isDown))
      } catch let error as MIDITransportError {
        await send(.midiFailed(isDown, error))
      } catch {
        await send(.midiFailed(isDown, .unavailable))
      }
    }
  }
}
