import ComposableArchitecture
import OSLog
import SwiftUI
import UIKit

struct SustainPedalView: View {
  let store: StoreOf<SustainFeature>
  @Environment(\.scenePhase) private var scenePhase
  @AppStorage(MIDITransportPreferences.hasSeenSettingsHintKey) private var hasSeenSettingsHint = false
  @AppStorage(MIDITransportPreferences.showTouchDiagnosticsKey) private var showsTouchDiagnostics = false
  @State private var isShowingSettingsHint = false
  @State private var touchDiagnostics = TouchDiagnostics()

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .top) {
        pedalSurface(isPressed: store.isPressed)
          .frame(width: proxy.size.width, height: proxy.size.height)
          .contentShape(Rectangle())
          .overlay {
            TouchPedalSurface(
              onTouchStateChanged: { isTouching in
                store.send(isTouching ? .pedalPressed : .pedalReleased)
              },
              onDiagnosticsChanged: { touchDiagnostics = $0 }
            )
            .accessibilityHidden(true)
          }

        VStack(spacing: 8) {
          status(store.transportStatus)
          if showsTouchDiagnostics {
            touchDiagnosticsView
          }
        }
          .padding(.top, 20)
          .padding(.horizontal, 24)
      }
    }
    .ignoresSafeArea()
    .onAppear {
      store.send(.task)
      if !hasSeenSettingsHint {
        hasSeenSettingsHint = true
        isShowingSettingsHint = true
      }
    }
    .onChange(of: scenePhase) { _, phase in store.send(.scenePhaseChanged(phase)) }
    .onChange(of: store.feedback) { _, feedback in playFeedback(feedback) }
    .onDisappear { store.send(.pedalReleased) }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel("Sustain Pedal")
    .accessibilityValue(pedalAccessibilityValue)
    .accessibilityAddTraits(.isButton)
    .accessibilityAction(named: "Press Sustain") { store.send(.pedalPressed) }
    .accessibilityAction(named: "Release Sustain") { store.send(.pedalReleased) }
    .alert("Choose your MIDI transports", isPresented: $isShowingSettingsHint) {
      Button("Open Settings") { openSettings() }
      Button("Not Now", role: .cancel) {}
    } message: {
      Text("Enable or disable Network MIDI, Bluetooth MIDI, and USB MIDI in the Settings app whenever you want.")
    }
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

  @ViewBuilder
  private func status(_ transportStatus: MIDITransportStatus) -> some View {
    if transportStatus.opensTransportSettings {
      Button(action: openSettings) {
        statusLabel(transportStatus.label, showsSettingsHint: true)
      }
      .buttonStyle(.plain)
      .accessibilityLabel("MIDI status: (transportStatus.label). Open Settings")
      .accessibilityHint("Opens this app's Settings page to enable a MIDI transport")
    } else {
      statusLabel(transportStatus.label, showsSettingsHint: false)
        .allowsHitTesting(false)
    }
  }

  private func statusLabel(_ text: String, showsSettingsHint: Bool) -> some View {
    HStack(spacing: 6) {
      Text(text)
      if showsSettingsHint {
        Image(systemName: "gearshape")
      }
    }
      .font(.footnote.weight(.bold))
      .foregroundStyle(.white.opacity(0.92))
      .padding(.horizontal, 14)
      .padding(.vertical, 8)
      .background(.black.opacity(0.35), in: Capsule())
  }

  private var touchDiagnosticsView: some View {
    Text("\(touchDiagnostics.activeContactCount) contacts \u{2022} \(touchDiagnostics.lastEvent)")
      .font(.caption.monospaced())
      .foregroundStyle(.white.opacity(0.92))
      .padding(.horizontal, 12)
      .padding(.vertical, 7)
      .background(.black.opacity(0.55), in: Capsule())
      .allowsHitTesting(false)
      .accessibilityLabel("Touch diagnostics: \(touchDiagnostics.activeContactCount) active contacts. \(touchDiagnostics.lastEvent)")
  }

  private var pedalAccessibilityValue: String {
    var value = store.isPressed ? "Down" : "Up"
    if showsTouchDiagnostics {
      value += ". \(touchDiagnostics.activeContactCount) active contacts. \(touchDiagnostics.lastEvent)"
    }
    return value
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

  private func openSettings() {
    guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(settingsURL)
  }
}

struct TouchContactTracker {
  private var activeContactIDs: Set<ObjectIdentifier> = []

  var activeContactCount: Int {
    activeContactIDs.count
  }

  mutating func begin<S: Sequence>(_ contacts: S) -> Bool where S.Element: AnyObject {
    let wasTouching = !activeContactIDs.isEmpty
    contacts.forEach { activeContactIDs.insert(ObjectIdentifier($0)) }
    return !wasTouching && !activeContactIDs.isEmpty
  }

  mutating func end<S: Sequence>(_ contacts: S) -> Bool where S.Element: AnyObject {
    let wasTouching = !activeContactIDs.isEmpty
    contacts.forEach { activeContactIDs.remove(ObjectIdentifier($0)) }
    return wasTouching && activeContactIDs.isEmpty
  }

  mutating func cancel<S: Sequence>(_ contacts: S) -> Bool where S.Element: AnyObject {
    end(contacts)
  }

  mutating func reset() -> Bool {
    guard !activeContactIDs.isEmpty else { return false }
    activeContactIDs.removeAll()
    return true
  }
}

struct TouchDiagnostics {
  var activeContactCount = 0
  var lastEvent = "Waiting for touch"
}

private struct TouchPedalSurface: UIViewRepresentable {
  let onTouchStateChanged: (Bool) -> Void
  let onDiagnosticsChanged: (TouchDiagnostics) -> Void

  func makeUIView(context: Context) -> TouchPedalControl {
    TouchPedalControl(
      onTouchStateChanged: onTouchStateChanged,
      onDiagnosticsChanged: onDiagnosticsChanged
    )
  }

  func updateUIView(_ view: TouchPedalControl, context: Context) {
    view.onTouchStateChanged = onTouchStateChanged
    view.onDiagnosticsChanged = onDiagnosticsChanged
  }
}

private final class TouchPedalControl: UIView {
  var onTouchStateChanged: (Bool) -> Void
  var onDiagnosticsChanged: (TouchDiagnostics) -> Void

  private var contactTracker = TouchContactTracker()
  private let logger = Logger(
    subsystem: Bundle.main.bundleIdentifier ?? "me.jasonaa.ipad-sustain-pedal",
    category: "TouchPedal"
  )

  init(
    onTouchStateChanged: @escaping (Bool) -> Void,
    onDiagnosticsChanged: @escaping (TouchDiagnostics) -> Void
  ) {
    self.onTouchStateChanged = onTouchStateChanged
    self.onDiagnosticsChanged = onDiagnosticsChanged
    super.init(frame: .zero)
    backgroundColor = .clear
    isOpaque = false
    isMultipleTouchEnabled = true
    isAccessibilityElement = false
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    let becameTouched = contactTracker.begin(touches)
    report("began", touches: touches)
    if becameTouched {
      onTouchStateChanged(true)
    }
  }

  override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
    let becameUntouched = contactTracker.end(touches)
    report("ended", touches: touches)
    if becameUntouched {
      onTouchStateChanged(false)
    }
  }

  override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
    let becameUntouched = contactTracker.cancel(touches)
    report("cancelled", touches: touches)
    if becameUntouched {
      onTouchStateChanged(false)
    }
  }

  override func didMoveToWindow() {
    super.didMoveToWindow()
    guard window == nil, contactTracker.reset() else { return }
    report("surface removed", touches: [])
    onTouchStateChanged(false)
  }

  private func report(_ event: String, touches: Set<UITouch>) {
    let touch = touches.first
    let contactDescription: String
    if let touch {
      let location = touch.location(in: self)
      contactDescription = "\(String(describing: touch.type)) @ \(Int(location.x)),\(Int(location.y))"
    } else {
      contactDescription = "no contact details"
    }

    let diagnostics = TouchDiagnostics(
      activeContactCount: contactTracker.activeContactCount,
      lastEvent: "\(event): \(touches.count) \(contactDescription)"
    )
    logger.info("\(diagnostics.lastEvent, privacy: .public); active contacts: \(diagnostics.activeContactCount)")
    onDiagnosticsChanged(diagnostics)
  }
}
