import Darwin
import Foundation
import LoadStarDomain
import Network

let arguments = CommandLine.arguments
guard let scenarioPath = argument(after: "--scenario", in: arguments),
    let portText = argument(after: "--port", in: arguments),
    let port = UInt16(portText),
    let scenarioData = FileManager.default.contents(atPath: scenarioPath),
    let scenario = try? JSONDecoder().decode(LoadStarFixtureScenario.self, from: scenarioData)
else {
    FileHandle.standardError.write(Data("LoadStarFixtureServer requires --scenario <path> --port <port>\n".utf8))
    exit(2)
}

func argument(after name: String, in arguments: [String]) -> String? {
    guard let index = arguments.firstIndex(of: name), arguments.indices.contains(index + 1) else { return nil }
    return arguments[index + 1]
}

@Sendable func emit(_ event: LoadStarFixtureEvent) {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    guard let data = try? encoder.encode(event) else { return }
    FileHandle.standardOutput.write(Data("LOADSTAR_EVENT ".utf8))
    FileHandle.standardOutput.write(data)
    FileHandle.standardOutput.write(Data("\n".utf8))
}

func log(_ message: String, stderr: Bool = false) {
    let handle = stderr ? FileHandle.standardError : FileHandle.standardOutput
    handle.write(Data((message + "\n").utf8))
}

@Sendable func varInt(_ value: Int) -> [UInt8] {
    var value = value
    var bytes: [UInt8] = []
    repeat {
        var byte = UInt8(value & 0x7f)
        value >>= 7
        if value != 0 { byte |= 0x80 }
        bytes.append(byte)
    } while value != 0
    return bytes
}

@Sendable func readyResponse() -> Data {
    let json = Data(
        "{\"version\":{\"name\":\"LoadStar Fixture\"},\"players\":{\"online\":0,\"max\":20},\"description\":{\"text\":\"fixture\"}}"
            .utf8)
    var body = Data([0])
    body.append(contentsOf: varInt(json.count))
    body.append(json)
    return Data(varInt(body.count)) + body
}

let startedAt = Date()
let listener: NWListener
do {
    listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
} catch {
    log("fixture listener could not start", stderr: true)
    exit(1)
}
listener.newConnectionHandler = { connection in
    connection.start(queue: .main)
    connection.receive(minimumIncompleteLength: 1, maximumLength: 8_192) { _, _, _, _ in
        let elapsed = Int(Date().timeIntervalSince(startedAt) * 1_000)
        guard scenario.slp == .ready, elapsed >= scenario.readyAfterMillis else {
            if scenario.slp == .malformed {
                connection.send(
                    content: Data([0xff, 0xff]), completion: .contentProcessed { _ in connection.cancel() })
            } else {
                connection.cancel()
            }
            return
        }
        connection.send(content: readyResponse(), completion: .contentProcessed { _ in connection.cancel() })
    }
}
listener.stateUpdateHandler = { state in
    if case .failed = state {
        emit(LoadStarFixtureEvent(kind: "listenerFailed"))
        exit(1)
    }
}

signal(SIGTERM, SIG_IGN)
let signalSource = DispatchSource.makeSignalSource(signal: SIGTERM, queue: .main)
signalSource.setEventHandler {
    emit(LoadStarFixtureEvent(kind: "gracefulStopRequested"))
    guard !scenario.ignoreTermination else {
        log("fixture ignoring termination", stderr: true)
        return
    }
    let finish = {
        emit(LoadStarFixtureEvent(kind: "stopped"))
        exit(0)
    }
    if scenario.gracefulStopDelayMillis > 0 {
        DispatchQueue.main.asyncAfter(
            deadline: .now() + .milliseconds(scenario.gracefulStopDelayMillis), execute: finish)
    } else {
        finish()
    }
}
signalSource.resume()

if scenario.startupDelayMillis > 0 {
    Thread.sleep(forTimeInterval: Double(scenario.startupDelayMillis) / 1_000)
}
listener.start(queue: .main)
log("LoadStar fixture started on port \(port)")
emit(LoadStarFixtureEvent(kind: "started"))
if scenario.spawnChild {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/bin/sleep")
    child.arguments = ["60"]
    try? child.run()
    emit(LoadStarFixtureEvent(kind: "childSpawned"))
}
for line in scenario.stdout {
    if scenario.invalidUTF8 {
        FileHandle.standardOutput.write(Data([0xff, 0xfe, 0xfd, 0x0a]))
    }
    log(line)
}
for line in scenario.stderr {
    log(line, stderr: true)
}

if let crashAfterMillis = scenario.crashAfterMillis {
    DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(max(0, crashAfterMillis))) {
        emit(LoadStarFixtureEvent(kind: "crashed"))
        exit(1)
    }
}

dispatchMain()
