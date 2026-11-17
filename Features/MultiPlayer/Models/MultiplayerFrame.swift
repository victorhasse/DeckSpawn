import Foundation

/// TCP is a byte stream, not a message transport. Every packet (including
/// the room handshake) uses a four-byte big-endian length and JSON payload.
nonisolated enum MultiplayerFrame {
    static let maximumPayloadLength = 65_536

    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let payload = try JSONEncoder().encode(value)
        guard !payload.isEmpty, payload.count <= maximumPayloadLength else {
            throw FrameError.invalidLength
        }
        let count = UInt32(payload.count)
        var result = Data([
            UInt8((count >> 24) & 0xff),
            UInt8((count >> 16) & 0xff),
            UInt8((count >> 8) & 0xff),
            UInt8(count & 0xff)
        ])
        result.append(payload)
        return result
    }

    static func payloadLength(from header: Data) -> Int? {
        guard header.count == 4 else { return nil }
        let count = header.reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
        guard count > 0, count <= UInt32(maximumPayloadLength) else { return nil }
        return Int(count)
    }

    enum FrameError: Error {
        case invalidLength
    }
}
