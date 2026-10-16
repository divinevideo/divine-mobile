//
//  StreamingSignature.swift
//  LibProofMode
//
//  Divine-local addition (#10197). Upstream hashes and signs the media from a
//  `Data` holding all of it, and ObjectivePGP copies that buffer three more
//  times while signing. A long recording then outgrows the memory iOS allows
//  the app, and the app is killed. These types read the media once, a chunk
//  at a time, and produce the same hash and the same signature.
//

import CryptoKit
import Foundation
import ObjectivePGP

enum StreamingSignatureError: Error {
    case unreadableMedia
    case missingPassphrase
    case noSigningKey
    case unsupportedKey
    case signingFailed
}

/// The hashes a proof needs, read from the media in a single pass.
struct MediaDigest {
    private static let chunkSize = 1 << 20

    /// Lower-case hex SHA-256 of the media. It names the proof files.
    let sha256: String

    /// SHA-512 over the media, left open so the signature can append its own
    /// fields before finishing it.
    fileprivate let signatureHasher: SHA512

    init(reading stream: InputStream) throws {
        var fileHasher = SHA256()
        var signatureHasher = SHA512()
        var buffer = [UInt8](repeating: 0, count: Self.chunkSize)

        stream.open()
        defer { stream.close() }
        while true {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count < 0 {
                throw stream.streamError ?? StreamingSignatureError.unreadableMedia
            }
            if count == 0 {
                break
            }
            buffer.withUnsafeBytes { bytes in
                let chunk = UnsafeRawBufferPointer(rebasing: bytes.prefix(count))
                fileHasher.update(bufferPointer: chunk)
                signatureHasher.update(bufferPointer: chunk)
            }
        }

        self.sha256 = fileHasher.finalize().hexStr.lowercased()
        self.signatureHasher = signatureHasher
    }
}

/// An OpenPGP detached signature over media hashed by `MediaDigest`.
///
/// The packet is the one `ObjectivePGP.sign(_:detached:...)` writes: a v4
/// binary-document signature over SHA-512, with a creation-time subpacket
/// hashed and an issuer subpacket not. Only the hash differs in how it is
/// reached: it continues the digest instead of hashing a copy of the media.
/// ObjectivePGP has no call that signs a hash, so the RSA step uses its
/// `PGPRSA` class directly, as its own signing code does.
enum DetachedSignature {
    private static let sha512Algorithm: UInt8 = 10
    private static let sha512DigestInfo: [UInt8] = [
        0x30, 0x51, 0x30, 0x0D, 0x06, 0x09, 0x60, 0x86, 0x48, 0x01,
        0x65, 0x03, 0x04, 0x02, 0x03, 0x05, 0x00, 0x04, 0x40,
    ]
    private static let rsaAlgorithms: Set<UInt8> = [1, 2, 3]

    /// Returns the binary signature packet, ready for `Armor.armored`.
    static func sign(
        _ digest: MediaDigest,
        with key: Key,
        passphrase: String?,
        createdAt: Date = Date()
    ) throws -> Data {
        let signingKey = try decrypted(key, passphrase: passphrase)
        // `signingSecretKey` and the packet's `fingerprint` are declared
        // properties whose types Swift cannot see, so they are read by KVC.
        guard
            let packet = signingKey.value(forKey: "signingSecretKey") as? NSObject,
            let fingerprint = packet.value(forKey: "fingerprint") as? Fingerprint
        else {
            throw StreamingSignatureError.noSigningKey
        }
        let (algorithm, modulusLength) = try rsaParameters(ofKeyPacket: fingerprint.keyData)

        // Version 4, binary document, key and hash algorithms, then 6 octets
        // of hashed subpackets: the 5-octet creation time (type 2).
        var hashedPart = Data([4, 0x00, algorithm, sha512Algorithm])
        hashedPart.append(contentsOf: [0, 6, 5, 2])
        hashedPart.append(bigEndian: UInt32(createdAt.timeIntervalSince1970))

        // RFC 4880 5.2.4: media, hashed part, then a v4 trailer.
        var hasher = digest.signatureHasher
        hasher.update(data: hashedPart)
        var trailer = Data([4, 0xFF])
        trailer.append(bigEndian: UInt32(hashedPart.count))
        hasher.update(data: trailer)
        let hash = Data(hasher.finalize())

        let encoded = try emsaPKCS1v15(hash, length: modulusLength)
        guard let signature = privateEncrypt(encoded, with: packet) else {
            throw StreamingSignatureError.signingFailed
        }

        // 10 octets of unhashed subpackets: the 9-octet issuer key ID
        // (type 16), then the hash's first two octets and the signature.
        var body = hashedPart
        body.append(contentsOf: [0, 10, 9, 16])
        body.append(fingerprint.hashedData.suffix(8))
        body.append(hash.prefix(2))
        body.append(mpi(signature))

        // A new-format signature packet (tag 2).
        var packetData = Data([0xC2])
        packetData.append(newFormatLength(body.count))
        packetData.append(body)
        return packetData
    }

    private static func decrypted(_ key: Key, passphrase: String?) throws -> Key {
        guard key.isEncryptedWithPassword else {
            return key
        }
        guard let passphrase = passphrase, !passphrase.isEmpty else {
            throw StreamingSignatureError.missingPassphrase
        }
        return try key.decrypted(withPassphrase: passphrase)
    }

    /// Reads the algorithm and the modulus length from the public half of a
    /// v4 key packet, as ObjectivePGP hashes it for the fingerprint:
    /// 0x99, a two-octet length, then version, creation time, algorithm, n.
    private static func rsaParameters(ofKeyPacket packet: Data) throws -> (UInt8, Int) {
        let bytes = [UInt8](packet)
        guard bytes.count > 11, bytes[3] == 4, rsaAlgorithms.contains(bytes[8]) else {
            throw StreamingSignatureError.unsupportedKey
        }
        let modulusBits = Int(bytes[9]) << 8 | Int(bytes[10])
        return (bytes[8], (modulusBits + 7) / 8)
    }

    private static func emsaPKCS1v15(_ hash: Data, length: Int) throws -> Data {
        let digestInfoLength = sha512DigestInfo.count + hash.count
        guard length >= digestInfoLength + 11 else {
            throw StreamingSignatureError.unsupportedKey
        }
        var encoded = Data([0x00, 0x01])
        encoded.append(Data(repeating: 0xFF, count: length - digestInfoLength - 3))
        encoded.append(0x00)
        encoded.append(contentsOf: sha512DigestInfo)
        encoded.append(hash)
        return encoded
    }

    private static func privateEncrypt(_ encoded: Data, with packet: NSObject) -> Data? {
        let selector = NSSelectorFromString("privateEncrypt:withSecretKeyPacket:")
        guard let rsa = NSClassFromString("PGPRSA") as? NSObject.Type, rsa.responds(to: selector) else {
            return nil
        }
        return rsa.perform(selector, with: encoded, with: packet)?.takeUnretainedValue() as? Data
    }

    private static func mpi(_ value: Data) -> Data {
        let magnitude = value.drop { $0 == 0 }
        let bits = magnitude.first.map { (magnitude.count - 1) * 8 + (8 - $0.leadingZeroBitCount) } ?? 0
        var data = Data()
        data.append(bigEndian: UInt16(bits))
        data.append(magnitude)
        return data
    }

    private static func newFormatLength(_ length: Int) -> Data {
        switch length {
        case ..<192:
            return Data([UInt8(length)])
        case ..<8384:
            return Data([UInt8(((length - 192) >> 8) + 192), UInt8((length - 192) & 0xFF)])
        default:
            var data = Data([0xFF])
            data.append(bigEndian: UInt32(length))
            return data
        }
    }
}

private extension Data {
    mutating func append<T: FixedWidthInteger>(bigEndian value: T) {
        Swift.withUnsafeBytes(of: value.bigEndian) { append(contentsOf: $0) }
    }
}
