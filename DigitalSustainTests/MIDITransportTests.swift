@testable import DigitalSustain
import XCTest

final class MIDITransportTests: XCTestCase {
  func testSustainOnUsesChannelOneController64Value127() {
    XCTAssertEqual(MIDITransport.sustainMessage(isDown: true), 0x20B0407F)
  }

  func testSustainOffUsesChannelOneController64Value0() {
    XCTAssertEqual(MIDITransport.sustainMessage(isDown: false), 0x20B04000)
  }
}
