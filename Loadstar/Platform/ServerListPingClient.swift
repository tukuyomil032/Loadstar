import Foundation
import LoadStarDomain
import Network

public enum ServerListPingError: Error, Equatable, Sendable {
    case invalidHost
    case invalidPort
    case connectionFailed(String)
    case timeout
    case malformedResponse
}

public protocol ServerListPingClient: Sendable {
    func ping(host: String, port: Int, timeout: Duration) async throws -> ServerPing
}

public enum MinecraftSLPPacketCodec: Sendable {
    public static func handshake(host: String, port: Int, protocolVersion: Int = 765) -> Data {
        var body = Data()
        body.append(contentsOf: varInt(0))
        body.append(contentsOf: varInt(protocolVersion))
        appendString(host, to: &body)
        body.append(UInt8((port >> 8) & 0xff))
        body.append(UInt8(port & 0xff))
        body.append(contentsOf: varInt(1))
        return frame(body)
    }

    public static var statusRequest: Data {
        frame(Data([0]))
    }

    public static func decodeStatusResponse(_ data: Data) throws -> ServerPing {
        var offset = 0
        let packetLength = try readVarInt(data, offset: &offset)
        guard packetLength >= 1, data.count - offset >= packetLength else {
            throw ServerListPingError.malformedResponse
        }
        let packetEnd = offset + packetLength
        let packetID = try readVarInt(data, offset: &offset)
        guard packetID == 0 else { throw ServerListPingError.malformedResponse }
        let jsonLength = try readVarInt(data, offset: &offset)
        guard jsonLength >= 0, offset + jsonLength <= packetEnd else { throw ServerListPingError.malformedResponse }
        let jsonData = data.subdata(in: offset..<(offset + jsonLength))
        let response = try JSONDecoder().decode(StatusResponse.self, from: jsonData)
        let description: String?
        switch response.description {
        case .string(let value): description = value
        case .object(let value): description = value["text"] as? String
        case .none: description = nil
        }
        return ServerPing(
            versionName: response.version?.name,
            playersOnline: response.players?.online,
            playersMax: response.players?.max,
            description: description
        )
    }

    private struct StatusResponse: Decodable {
        struct Version: Decodable { let name: String? }
        struct Players: Decodable {
            let online: Int?
            let max: Int?
        }
        let version: Version?
        let players: Players?
        let description: Description?

        enum Description: Decodable {
            case string(String)
            case object([String: Any])

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let value = try? container.decode(String.self) {
                    self = .string(value)
                } else if let value = try? container.decode([String: AnyCodable].self) {
                    self = .object(value.mapValues(\.value))
                } else {
                    throw ServerListPingError.malformedResponse
                }
            }
        }

        private struct AnyCodable: Decodable {
            let value: Any

            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                if let string = try? container.decode(String.self) { value = string } else { value = "" }
            }
        }
    }

    private static func frame(_ body: Data) -> Data {
        var result = Data(varInt(body.count))
        result.append(body)
        return result
    }

    private static func appendString(_ string: String, to data: inout Data) {
        let encoded = Data(string.utf8)
        data.append(contentsOf: varInt(encoded.count))
        data.append(encoded)
    }

    private static func varInt(_ value: Int) -> [UInt8] {
        var value = value
        var result: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            result.append(byte)
        } while value != 0
        return result
    }

    private static func readVarInt(_ data: Data, offset: inout Int) throws -> Int {
        var value = 0
        var shift = 0
        while offset < data.count, shift <= 28 {
            let byte = data[offset]
            offset += 1
            value |= Int(byte & 0x7f) << shift
            if byte & 0x80 == 0 { return value }
            shift += 7
        }
        throw ServerListPingError.malformedResponse
    }
}

public struct NetworkServerListPingClient: ServerListPingClient {
    public init() {}

    public func ping(host: String, port: Int, timeout: Duration = .seconds(3)) async throws -> ServerPing {
        guard !host.isEmpty else { throw ServerListPingError.invalidHost }
        guard (1...65_535).contains(port) else { throw ServerListPingError.invalidPort }

        return try await withThrowingTaskGroup(of: ServerPing.self) { group in
            group.addTask { try await Self.performPing(host: host, port: port) }
            group.addTask {
                try await Task.sleep(for: timeout)
                throw ServerListPingError.timeout
            }
            defer { group.cancelAll() }
            guard let result = try await group.next() else { throw ServerListPingError.timeout }
            return result
        }
    }

    private static func performPing(host: String, port: Int) async throws -> ServerPing {
        try await withCheckedThrowingContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: UInt16(port))!,
                using: .tcp
            )
            let queue = DispatchQueue(label: "com.tukuyomi032.loadstar.slp")
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(
                        content: MinecraftSLPPacketCodec.handshake(host: host, port: port),
                        completion: .contentProcessed { error in
                            if let error {
                                connection.cancel()
                                continuation.resume(
                                    throwing: ServerListPingError.connectionFailed(error.localizedDescription))
                                return
                            }
                            connection.send(
                                content: MinecraftSLPPacketCodec.statusRequest,
                                completion: .contentProcessed { error in
                                    if let error {
                                        connection.cancel()
                                        continuation.resume(
                                            throwing: ServerListPingError.connectionFailed(error.localizedDescription))
                                        return
                                    }
                                    connection.receive(minimumIncompleteLength: 1, maximumLength: 1_048_576) {
                                        data, _, _, error in
                                        connection.cancel()
                                        if let error {
                                            continuation.resume(
                                                throwing: ServerListPingError.connectionFailed(
                                                    error.localizedDescription))
                                        } else if let data {
                                            do {
                                                continuation.resume(
                                                    returning: try MinecraftSLPPacketCodec.decodeStatusResponse(data))
                                            } catch { continuation.resume(throwing: error) }
                                        } else {
                                            continuation.resume(throwing: ServerListPingError.malformedResponse)
                                        }
                                    }
                                })
                        })
                case .failed(let error):
                    connection.cancel()
                    continuation.resume(throwing: ServerListPingError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    break
                default:
                    break
                }
            }
            connection.start(queue: queue)
        }
    }
}
