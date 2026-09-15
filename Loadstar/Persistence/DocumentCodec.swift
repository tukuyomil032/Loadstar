import Foundation
import LoadStarDomain

public struct DocumentHeader: Equatable, Sendable {
    public let documentType: DocumentType
    public let revision: Int

    public init(documentType: DocumentType, revision: Int) {
        self.documentType = documentType
        self.revision = revision
    }
}

public enum DocumentCodecError: Error, Equatable, Sendable {
    case rootIsNotObject
    case missingDocumentType
    case invalidDocumentType
    case missingSchemaVersion
    case invalidSchemaVersion
    case unexpectedDocumentType(expected: DocumentType, actual: DocumentType)
    case payloadIsNotObject
}

public struct DocumentCodec: Sendable {
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        self.encoder = encoder
        self.decoder = decoder
    }

    public func encode<Payload: Codable & Sendable>(_ document: LoadStarDocument<Payload>) throws -> Data {
        let payloadValue: JSONValue = try encodeValue(document.payload)
        guard case .object(let payloadFields) = payloadValue else {
            throw DocumentCodecError.payloadIsNotObject
        }

        var fields = payloadFields
        fields["documentType"] = JSONValue.string(document.documentType.rawValue)
        fields["schemaVersion"] = JSONValue.integer(Int64(document.schemaVersion.revision))

        mergeUnknownFields(document.unknownFields, into: &fields)

        return try encodeData(JSONValue.object(fields))
    }

    public func decode<Payload: Codable & Sendable>(
        _ type: Payload.Type,
        from data: Data,
        expectedDocumentType: DocumentType
    ) throws -> LoadStarDocument<Payload> {
        let raw = try decodeJSONValue(data)
        let header = try decodeHeader(from: raw)
        guard header.documentType == expectedDocumentType else {
            throw DocumentCodecError.unexpectedDocumentType(expected: expectedDocumentType, actual: header.documentType)
        }

        guard case .object(let allFields) = raw else {
            throw DocumentCodecError.rootIsNotObject
        }

        var payloadFields = allFields
        payloadFields.removeValue(forKey: "documentType")
        payloadFields.removeValue(forKey: "schemaVersion")

        let payload = try decoder.decode(Payload.self, from: encodeData(JSONValue.object(payloadFields)))
        let normalizedPayload: JSONValue = try encodeValue(payload)
        guard case .object(let knownFields) = normalizedPayload else {
            throw DocumentCodecError.payloadIsNotObject
        }

        let unknownFields = extractUnknownFields(from: payloadFields, known: knownFields)
        return try LoadStarDocument(
            documentType: expectedDocumentType,
            revision: header.revision,
            payload: payload,
            unknownFields: unknownFields
        )
    }

    public func decodeHeader(from data: Data) throws -> DocumentHeader {
        try decodeHeader(from: decodeJSONValue(data))
    }

    public func decodeRaw(_ data: Data) throws -> JSONValue {
        try decodeJSONValue(data)
    }

    public func encodeRaw(_ value: JSONValue) throws -> Data {
        try encodeData(value)
    }

    private func decodeHeader(from raw: JSONValue) throws -> DocumentHeader {
        guard case .object(let fields) = raw else {
            throw DocumentCodecError.rootIsNotObject
        }

        guard case .string(let documentTypeValue) = fields["documentType"],
            let documentType = DocumentType(rawValue: documentTypeValue)
        else {
            if fields["documentType"] == nil {
                throw DocumentCodecError.missingDocumentType
            }
            throw DocumentCodecError.invalidDocumentType
        }

        guard case .integer(let revision) = fields["schemaVersion"], revision > 0, revision <= Int64(Int.max) else {
            if fields["schemaVersion"] == nil {
                throw DocumentCodecError.missingSchemaVersion
            }
            throw DocumentCodecError.invalidSchemaVersion
        }

        return DocumentHeader(documentType: documentType, revision: Int(revision))
    }

    private func encodeData<Value: Encodable>(_ value: Value) throws -> Data {
        try encoder.encode(value)
    }

    private func encodeValue<Value: Encodable>(_ value: Value) throws -> JSONValue {
        try decoder.decode(JSONValue.self, from: encoder.encode(value))
    }

    private func decodeJSONValue(_ data: Data) throws -> JSONValue {
        try decoder.decode(JSONValue.self, from: data)
    }

    private func mergeUnknownFields(_ unknownFields: UnknownFields, into fields: inout [String: JSONValue]) {
        for (key, value) in unknownFields {
            guard let knownValue = fields[key] else {
                fields[key] = value
                continue
            }
            fields[key] = mergeUnknownValue(value, into: knownValue)
        }
    }

    private func mergeUnknownValue(_ unknown: JSONValue, into known: JSONValue) -> JSONValue {
        switch (known, unknown) {
        case (.object(let knownFields), .object(let unknownFields)):
            var merged = knownFields
            mergeUnknownFields(unknownFields, into: &merged)
            return .object(merged)
        case (.array(let knownValues), .array(let unknownValues)) where knownValues.count == unknownValues.count:
            return .array(zip(knownValues, unknownValues).map { mergeUnknownValue($1, into: $0) })
        default:
            return known
        }
    }

    private func extractUnknownFields(from raw: [String: JSONValue], known: [String: JSONValue]) -> UnknownFields {
        var unknownFields: UnknownFields = [:]
        for (key, rawValue) in raw {
            guard let knownValue = known[key] else {
                unknownFields[key] = rawValue
                continue
            }
            if let nestedUnknown = extractUnknownValue(from: rawValue, known: knownValue) {
                unknownFields[key] = nestedUnknown
            }
        }
        return unknownFields
    }

    private func extractUnknownValue(from raw: JSONValue, known: JSONValue) -> JSONValue? {
        switch (raw, known) {
        case (.object(let rawFields), .object(let knownFields)):
            let nestedUnknown = extractUnknownFields(from: rawFields, known: knownFields)
            return nestedUnknown.isEmpty ? nil : .object(nestedUnknown)
        case (.array(let rawValues), .array(let knownValues)) where rawValues.count == knownValues.count:
            var foundUnknown = false
            let nestedValues = zip(rawValues, knownValues).map { rawValue, knownValue in
                guard let nestedUnknown = extractUnknownValue(from: rawValue, known: knownValue) else {
                    return JSONValue.object([:])
                }
                foundUnknown = true
                return nestedUnknown
            }
            return foundUnknown ? .array(nestedValues) : nil
        default:
            return nil
        }
    }
}
