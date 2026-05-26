@testable import CursorAPICore
import XCTest

final class ProtobufTests: XCTestCase {
    func testRunRequestContainsPromptAndModel() {
        let request = CursorSDKProto.runRequest(agentID: "agent-id", messageID: "message-id", modelID: "composer-2.5", prompt: "hello")
        let fields = Proto.decodeFields(request)
        XCTAssertEqual(fields.count, 1)
        guard case .bytes(let runEnvelope)? = fields.first?.value else {
            XCTFail("Expected envelope")
            return
        }
        let runFields = Proto.decodeFields(runEnvelope)
        XCTAssertEqual(Proto.stringField(runFields, 5), "agent-id")
        XCTAssertEqual(Proto.stringField(runFields, 13), "sdk")
    }

    func testConnectFrameRoundTrip() {
        let payload = Data("abc".utf8)
        let frame = ConnectProto.frame(payload)
        XCTAssertEqual(ConnectProto.frames(from: frame), [payload])
    }

    func testRequestContextDecode() {
        let context = CursorSDKProto.requestContextResult(id: 42, execID: "exec-1")
        let fields = Proto.decodeFields(context)
        guard case .bytes(let execMessage)? = fields.first(where: { $0.number == 2 })?.value else {
            XCTFail("Expected exec message")
            return
        }
        let serverLikeFrame = Proto.message([Proto.messageField(2, execMessage)])
        XCTAssertEqual(CursorSDKRequestContext.decode(serverLikeFrame), CursorSDKRequestContext(id: 42, execID: "exec-1"))
    }

    func testLocalHarnessUsesSDKRunIDPrefix() {
        let runID = LocalCursorSDKHarness.newRunID()
        XCTAssertTrue(runID.hasPrefix("run-"))
        XCTAssertFalse(runID.hasPrefix("msg-"))
    }

    func testDetectsSDKTurnEndedMarker() {
        let turnEnded = Proto.message([Proto.varintField(2, 1)])
        let interaction = Proto.message([Proto.messageField(14, turnEnded)])
        let frame = Proto.message([Proto.messageField(1, interaction)])

        XCTAssertTrue(CursorSDKStreamMarkers.hasTurnEnded(frame))
        XCTAssertFalse(CursorSDKStreamMarkers.hasTurnEnded(Proto.message([Proto.messageField(1, Proto.message([]))])))
    }
}
