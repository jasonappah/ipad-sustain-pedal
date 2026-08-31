import ComposableArchitecture
import SwiftUI
import UIKit

struct SustainPedalView: View {
  let store: StoreOf<SustainFeature>
  @Environment(\.scenePhase) private var scenePhase

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .top) {
        pedalSurface(isPressed: store.isPressed)
          .frame(width: proxy.size.width, height: proxy.size.height)

        status(store.transportStatus)
          .padding(.top, 20)
          .padding(.horizontal, 24)
          .allowsHitTesting(false)
      }
      .contentShape(Rectangle())
      .gesture(
        DragGesture(minimumDistance: 0)
          .onChanged { _ in store.send(.pedalPressed) }
          .onEnded { _ in store.send(.pedalReleased) }
      )
    }
    .ignoresSafeArea()
    .onAppear { store.send(.task) }
    .onChange(of: scenePhase) { _, phase in store.send(.scenePhaseChanged(phase)) }
    .onChange(of: store.feedback) { _, feedback in playFeedback(feedback) }
    .onDisappear { store.send(.pedalReleased) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Sustain Pedal")
    .accessibilityValue(store.isPressed ? "Down" : "Up")
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Press Sustain") { store.send(.pedalPressed) }
    .accessibilityAction(named: "Release Sustain") { store.send(.pedalReleased) }
  }

  private func pedalSurface(isPressed: Bool) -> some View {
    Rectangle()
      .fill(isPressed ? Color(red: 0.08, green: 0.55, blue: 0.31) : Color(red: 0.12, green: 0.14, blue: 0.18))
      .overlay {
        VStack(spacing: 14) {
          Image(systemName: isPressed ? "music.quarternote.3" : "music.quarternote")
            .font(.system(size: 78, weight: .bold))
          Text(isPressed ? "SUSTAIN ON" : "SUSTAIN")
            .font(.system(size: 42, weight: .black, design: .rounded))
          Text(isPressed ? "Release to lift" : "Press and hold")
            .font(.title3.weight(.semibold))
        }
        .foregroundStyle(.white)
        .scaleEffect(isPressed ? 0.96 : 1)
        .animation(.easeOut(duration: 0.14), value: isPressed)
      }
      .overlay {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
          .stroke(.white.opacity(isPressed ? 0.8 : 0.18), lineWidth: isPressed ? 10 : 4)
          .padding(18)
      }
  }

  private func status(_ transportStatus: MIDITransportStatus) -> some View {
    Text(transportStatus.label)
      .font(.footnote.weight(.bold))
      .foregroundStyle(.white.opacity(0.92))
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(.black.opacity(0.35), in: Capsule())
      .accessibilityLabel("MIDI status: \(transportStatus.label)")
  }

  private func playFeedback(_ feedback: SustainFeature.PedalFeedback) {
    switch feedback {
    case .none:
      break
    case .pressed:
      UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    case .released:
      UISelectionFeedbackGenerator().selectionChanged()
    case .error:
      UINotificationFeedbackGenerator().notificationOccurred(.error)
    }
  }
}
