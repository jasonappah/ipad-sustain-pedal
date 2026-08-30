import SwiftUI
import ComposableArchitecture

@main
struct DigitalSustainApp: App {
  private let store = Store(initialState: SustainFeature.State()) {
    SustainFeature()
  }

  var body: some Scene {
    WindowGroup {
      SustainPedalView(store: store)
    }
  }
}
