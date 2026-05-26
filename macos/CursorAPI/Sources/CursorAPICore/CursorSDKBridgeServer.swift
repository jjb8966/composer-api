import Foundation
import Network

struct CursorSDKBridgeEndpoint: Sendable {
    var url: URL
    var token: String
}

actor CursorSDKBridgeServer {
    static let shared = CursorSDKBridgeServer()

    private var process: Process?
    private var endpoint: CursorSDKBridgeEndpoint?
    private let token = UUID().uuidString.replacingOccurrences(of: "-", with: "")

    func endpoint(settings: CursorAPISettings) async throws -> CursorSDKBridgeEndpoint {
        if let endpoint, await isHealthy(endpoint.url) {
            return endpoint
        }
        stop()
        let script = try bridgeScriptURL()
        let port = try await start(script: script, settings: settings)
        let endpoint = CursorSDKBridgeEndpoint(url: URL(string: "http://127.0.0.1:\(port)/sdk")!, token: token)
        self.endpoint = endpoint
        return endpoint
    }

    private func start(script: URL, settings: CursorAPISettings) async throws -> UInt16 {
        var lastError: (any Error)?
        for port in 8792...8892 {
            guard let candidate = UInt16(exactly: port), await !tcpPortIsOpen(candidate) else {
                continue
            }
            do {
                try launch(script: script, port: candidate, settings: settings)
                let health = URL(string: "http://127.0.0.1:\(candidate)/health")!
                for _ in 0..<40 {
                    if await isHealthy(health) {
                        return candidate
                    }
                    try await Task.sleep(nanoseconds: 50_000_000)
                }
                stop()
                lastError = CursorAPIError.transport("Cursor SDK bridge did not become ready.")
            } catch {
                stop()
                lastError = error
            }
        }
        throw lastError ?? CursorAPIError.transport("Could not start Cursor SDK bridge.")
    }

    private func launch(script: URL, port: UInt16, settings: CursorAPISettings) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["node", script.path]
        var environment = ProcessInfo.processInfo.environment
        environment["CURSOR_SDK_BRIDGE_HOST"] = "127.0.0.1"
        environment["CURSOR_SDK_BRIDGE_PORT"] = String(port)
        environment["CURSOR_SDK_BRIDGE_TOKEN"] = token
        environment["CURSOR_BACKEND_BASE_URL"] = settings.backendBaseURL
        environment["CURSOR_LOCAL_AGENT_ENDPOINT"] = settings.localAgentEndpoint
        environment["CURSOR_SDK_CLIENT_VERSION"] = settings.clientVersion.isEmpty ? "sdk-1.0.13" : settings.clientVersion
        environment["CURSOR_SDK_BRIDGE_REQUEST_TIMEOUT_MS"] = "120000"
        process.environment = environment
        process.currentDirectoryURL = script.deletingLastPathComponent()
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        self.process = process
    }

    private func stop() {
        process?.terminate()
        process = nil
        endpoint = nil
    }

    private func isHealthy(_ url: URL) async -> Bool {
        var request = URLRequest(url: url)
        request.timeoutInterval = 1
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            return data.contains(Data(#""ok": true"#.utf8)) || data.contains(Data(#""ok":true"#.utf8))
        } catch {
            return false
        }
    }

    private func tcpPortIsOpen(_ port: UInt16) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: "127.0.0.1", port: NWEndpoint.Port(rawValue: port)!, using: .tcp)
            let queue = DispatchQueue(label: "CursorAPI.SDKBridgePortCheck.\(port)")
            let state = PortCheckState()
            let finish: @Sendable (Bool) -> Void = { value in
                guard state.finish() else { return }
                connection.cancel()
                continuation.resume(returning: value)
            }
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    finish(true)
                case .failed, .cancelled:
                    finish(false)
                default:
                    break
                }
            }
            connection.start(queue: queue)
            queue.asyncAfter(deadline: .now() + 0.25) {
                finish(false)
            }
        }
    }

    private func bridgeScriptURL() throws -> URL {
        let candidates = [
            Bundle.main.url(forResource: "cursor-sdk-opencode-bridge", withExtension: "mjs"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appending(path: "scripts/cursor-sdk-opencode-bridge.mjs"),
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath).deletingLastPathComponent().appending(path: "scripts/cursor-sdk-opencode-bridge.mjs")
        ].compactMap(\.self)
        for candidate in candidates where FileManager.default.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw CursorAPIError.invalidConfiguration("Cursor SDK bridge script is missing. Repackage \(CursorAPIBrand.displayName) or run from the repository checkout.")
    }
}

private final class PortCheckState: @unchecked Sendable {
    private let lock = NSLock()
    private var finished = false

    func finish() -> Bool {
        lock.withLock {
            guard !finished else { return false }
            finished = true
            return true
        }
    }
}
