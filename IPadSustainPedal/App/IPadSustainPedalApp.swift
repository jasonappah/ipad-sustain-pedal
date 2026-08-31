import SwiftUI
import ComposableArchitecture

@main
struct IPadSustainPedalApp: App {
  private let store = Store(initialState: SustainFeature.State()) {
    SustainFeature()
  }

  var body: some Scene {
    WindowGroup {
      SustainPedalView(store: store)
    }
  }
}
