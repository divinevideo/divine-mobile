//
//  Proofmode.swift
//  LibProofMode
//
//  Created by N-Pex on 2020-07-22.
//

import Foundation
import CryptoKit
import ObjectivePGP
import Photos

// CryptoKit.Digest utils
extension Digest {
    var bytes: [UInt8] { Array(makeIterator()) }
    var data: Data { Data(bytes) }
    
    var hexStr: String {
        bytes.map { String(format: "%02X", $0) }.joined()
    }
}

open class MediaItemOperationQueue: OperationQueue {
    private var processingMediaItems: [MediaItem] = []
    
    private func processSync(mediaItem: MediaItem, options: ProofGenerationOptions) -> MediaItem {
        if let existingMediaItem = processingMediaItems.first(where: { mediaItemInQueue in
            mediaItemInQueue.uniqueIdentifier == mediaItem.uniqueIdentifier
        }) {
            return existingMediaItem
        }
        processingMediaItems.append(mediaItem)
        let op = MediaItemProcessingOperation(mediaItem: mediaItem, options: options)
        op.completionBlock = {
            DispatchQueue.main.sync {
                self.processingMediaItems.removeAll { mediaItemInQueue in
                    mediaItemInQueue.uniqueIdentifier == mediaItem.uniqueIdentifier
                }
            }
        }
        self.addOperation(op)
        mediaItem.isGeneratingProof = true // Techincally not yet, but we are queued now, and want UI to show "generating proof..."
        return mediaItem
    }
    
    public func process(mediaItem: MediaItem, options: ProofGenerationOptions) -> MediaItem {
        if Thread.isMainThread {
            return processSync(mediaItem: mediaItem, options: options)
        }
        return DispatchQueue.main.sync {
            return processSync(mediaItem: mediaItem, options: options)
        }
    }
    
    /**
     Wait for all currently added operations to complete before continuing processing the queue
     */
    public func whenDone(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            self.addBarrierBlock {
                DispatchQueue.main.async {
                    block()
                }
            }
        } else {
            DispatchQueue.main.sync {
                self.addBarrierBlock {
                    DispatchQueue.main.async {
                        block()
                    }
                }
            }
        }
    }
}

public struct ProofGenerationOptions {
    public init(showDeviceIds: Bool, showLocation: Bool, showMobileNetwork: Bool, notarizationProviders: [NotarizationProvider]) {
        self.showDeviceIds = showDeviceIds
        self.showLocation = showLocation
        self.showMobileNetwork = showMobileNetwork
        self.notarizationProviders = notarizationProviders
    }
    
    var showDeviceIds: Bool
    var showLocation: Bool
    var showMobileNetwork: Bool
    var notarizationProviders: [NotarizationProvider]
}

open class Proof: NSObject {
    public static let shared = Proof()

    /**
        Default folder to use for generated proof files, if the individual MediaItems don't have "proofFolder" set.
     
     Useful if you are e.g. using app groups, you can then use something like: "Proof.shared.defaultDocumentFolder = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: 'your app group id')"
     
     in your SceneDelegate (or similar initialization code).
     */
    public var defaultDocumentFolder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    
    /**
     Whether to wait for notarization to complete before considering proof generated. Defaults to 'true'.
     */
    public var synchronousNotarization = true
    
    /**
     PGP key for signing proof. Set this before `getProof` is called, otherwise a default key will be generated and used.
     */
    public var pgpKey: Key?

    private var publicKey: Data? {
        if let keyData = try? pgpKey?.export(keyType: .public) {
            return keyData
        } else if let publicKeyFile = documentPath(for: "pub.asc"), let keyString = try? String(contentsOf: publicKeyFile, encoding: .ascii), let publicKey = try? Armor.readArmored(keyString) {
            // Old versions of the app stored public key in separate file, be backwards compatible here
            let pubKey = try? ObjectivePGP.readKeys(from: publicKey).first
            return try? pubKey?.export(keyType: .public)
        }
        return nil
    }

    private var _passphrase: String?

    /**
     The passphrase needed to decrypt the PGP key during signing and when generating a default key.

     If not set, a default passphrase will be used.
     */
    public var passphrase: String? {
        get {
            _passphrase ?? "password"
        }
        set {
            _passphrase = newValue
        }
    }

    
    lazy var processingQueue: MediaItemOperationQueue = {
        var queue = MediaItemOperationQueue()
        queue.name = "Proof processing queue"
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        return queue
    }()
    
    override init() {
        super.init()
    }
    
    public func initializeWithDefaultKeys() {
        pgpKey = nil

        guard let secretKeyFile = documentPath(for: "pkr.asc")
        else {
            return
        }

        if let content = try? String(contentsOf: secretKeyFile, encoding: .ascii),
           let privateKey = try? Armor.readArmored(content)
        {
            pgpKey = try? ObjectivePGP.readKeys(from: privateKey).first
        }

        // Generate new if there was no readable one.
        if pgpKey == nil {
            let key = KeyGenerator().generate(for: "noone@proofmode.witness.org", passphrase: passphrase)
            try? Armor.armored(key.export(), as: .secretKey).write(to: secretKeyFile, atomically: true, encoding: .ascii)
            pgpKey = key
        }
    }
    
    /**
     Call this to provide your own PGP key for proof signing.

     Must be called before `getProof` gets called, otherwise a default key will be generated, stored on disk and used.

     You can also use `pgpKey` and `passphrase` directly, so you don't need to armor your key.

     - parameter privateKey: Private PGP key as an armored string. (Implicitly containing the publc key.)
     - parameter passphrase: The passphrase to decrypt the PGP key during signing.
     */
    public func initializeWithKeys(privateKey: String, passphrase: String?) {
        if let key = try? Armor.readArmored(privateKey) {
            pgpKey = (try? ObjectivePGP.readKeys(from: key))?.first
            self.passphrase = passphrase
        }
        else {
            pgpKey = nil
            self.passphrase = nil
        }
    }

    public func publicKeyFingerprint() -> String? {
        guard let publicKey = publicKey,
              let key = (try? ObjectivePGP.readKeys(from: publicKey))?.first,
              let fingerprint = sha256(data: key.publicKey?.fingerprint.keyData)?.suffix(16)
        else {
            return nil
        }

        return String(fingerprint)
    }
    
    /**
     - returns: The public key as an armored string.
     */
    public func getPublicKeyString() -> String? {
        guard let publicKey = publicKey else {
            return nil
        }

        return Armor.armored(publicKey, as: .publicKey)
    }
    
    /**
     Add a media item to the media processing queue. This will generate proof for the media item.
     */
    open func process(mediaItem: MediaItem, options: ProofGenerationOptions, whenDone:((MediaItem) -> Void)? = nil) {
        let result = self.processingQueue.process(mediaItem: mediaItem, options: options)
        if let doneBlock = whenDone {
            self.whenDone {
                doneBlock(result)
            }
        }
    }

    /**
     Call the given callback (on the main thread) when all processing is done on the media processing queue.
     */
    open func whenDone(block: @escaping () -> Void) {
        self.processingQueue.whenDone(block)
    }

    open func getProof(for mediaItem: MediaItem, force: Bool, options: ProofGenerationOptions) -> String? {
        if self.pgpKey == nil {
            self.initializeWithDefaultKeys()
        }
        
        guard
            let pgpKey = pgpKey,
            let data = mediaItem.data,
            let hash = sha256(data: data)?.lowercased(),
            let signatureFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "asc"),
            let proofFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "proof.csv"),
            let proofSignatureFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "proof.csv.asc"),
            let proofJsonFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "proof.json"),
            let proofJsonSignatureFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "proof.json.asc")
        else { return nil }
        
        // Already has proof?
        if !force && signatureFileUrl.exists {
            return hash
        }
        
        let writeHeaders = !proofFileUrl.exists
        
        print("Building proof \(options.showDeviceIds) \(options.showLocation) \(options.showMobileNetwork)")
        
        do {
            // Sign the media file (data)
            let signature = try ObjectivePGP.sign(data, detached: true, using: [pgpKey], passphraseForKey: { (key) -> String? in
                return passphrase
            })
            let armoredSignature = Armor.armored(signature, as: .signature)
            try armoredSignature.write(to: signatureFileUrl, atomically: true, encoding: .utf8)
        } catch {
            print(error.localizedDescription)
        }
        
        do {
            // Build proof CSV File
            let proof = buildProof(mediaItem: mediaItem, shaHash: hash, writeHeaders: false, showDeviceIds: options.showDeviceIds, showLocation: options.showLocation, showMobileNetwork: options.showMobileNetwork)
            
            let notarizationGroup = DispatchGroup()
            
            // Notarize
            let synchronousNotarization = self.synchronousNotarization
            if !options.notarizationProviders.isEmpty {
                for notarizationProvider in options.notarizationProviders {
                    if synchronousNotarization {
                        notarizationGroup.enter()
                    }
                    notarizationProvider.notarize(hash: hash, media: data) { hash, result in
                        if let url = self.proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: notarizationProvider.fileExtension) {
                            if let outputData = Data(base64Encoded: result) {
                                try? outputData.write(to: url, options: [.atomic])
                            }
                        }
                        if synchronousNotarization {
                            notarizationGroup.leave()
                        }
                    } failure: { errCode, message in
                        print("Error, failed notarization: \(notarizationProvider.fileExtension)")
                        if synchronousNotarization {
                            notarizationGroup.leave()
                        }
                    }
                }
            }
            
            if synchronousNotarization {
                _ = notarizationGroup.wait(timeout: .now().advanced(by: .seconds(30)))
            }
            
            // Save CSV
            var result = String("")
            if writeHeaders {
                for key in proof.keys {
                    result.append(key.rawValue)
                    result.append(",")
                }
                result.append("\n")
            }
            for key in proof.keys {
                let val:String = proof[key] ?? ""
                // No commas allowed in CSV values
                result.append(val.replacingOccurrences(of: ",", with: " "))
                result.append(",")
            }
            result.append("\n")
            try result.write(to: proofFileUrl, atomically: true, encoding: .utf8)
            
            // Save JSON
            let encoder = JSONEncoder()
            if let jsonData = try? encoder.encode(proof), let jsonString = String(data: jsonData, encoding: .utf8) {
                try jsonString.write(to: proofJsonFileUrl, atomically: true, encoding: String.Encoding.utf8)
            }
            
            // Sign the proof file
            var data = try Data(contentsOf: proofFileUrl)
            var signature = try ObjectivePGP.sign(data, detached: true, using: [pgpKey], passphraseForKey: { (key) -> String? in
                return passphrase
            })
            var armoredSignature = Armor.armored(signature, as: .signature)
            try armoredSignature.write(to: proofSignatureFileUrl, atomically: true, encoding: .utf8)
            
            // Sign JSON proof file
            data = try Data(contentsOf: proofJsonFileUrl)
            signature = try ObjectivePGP.sign(data, detached: true, using: [pgpKey], passphraseForKey: { (key) -> String? in
                return passphrase
            })
            armoredSignature = Armor.armored(signature, as: .signature)
            try armoredSignature.write(to: proofJsonSignatureFileUrl, atomically: true, encoding: .utf8)
        } catch {
            print(error.localizedDescription)
        }
        
        return hash
    }
    
    open func hasProof(mediaItem: MediaItem) -> Bool {
        guard
            let data = mediaItem.data,
            let hash = sha256(data: data)?.lowercased(),
            let signatureFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "asc"),
            let proofJsonFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "proof.json")
        else { return false }
        if signatureFileUrl.exists, proofJsonFileUrl.exists {
            return true
        }
        return false
    }

    open func getProofData(mediaItem: MediaItem) -> [String: String]? {
        var proofJsonFileUrl: URL? = nil
        
        if let mediaItemHash = mediaItem.mediaItemHash {
            proofJsonFileUrl = proofFilePath(mediaItem: mediaItem, hash: mediaItemHash, fileExtension: "proof.json")
        } else {
            guard
                let data = mediaItem.data,
                let hash = sha256(data: data)?.lowercased()
            else {
                return nil
            }
            proofJsonFileUrl = proofFilePath(mediaItem: mediaItem, hash: hash, fileExtension: "proof.json")
        }
        guard let proofJsonFileUrl = proofJsonFileUrl else { return nil }
        if proofJsonFileUrl.exists, let data = try? Data(contentsOf: proofJsonFileUrl) {
            let decoder = JSONDecoder()
            if let collection = try? decoder.decode(ProofCollection.self, from: data) {
                return collection.toDict()
            }
        }
        return nil
    }
    
    private func buildProof(mediaItem:MediaItem, shaHash:String, writeHeaders:Bool, showDeviceIds:Bool, showLocation:Bool, showMobileNetwork:Bool) -> ProofCollection {
        let proof:ProofCollection = ProofCollection()
        
        let queue = OperationQueue()
        queue.name = "Proof gathering queue"
        queue.maxConcurrentOperationCount = 1
        
        
        if let filePath = mediaItem.fileName {
            proof[.filePath] = filePath
        }
        proof[.fileHashSha256] = shaHash
        if let modified = mediaItem.modified {
            proof[.fileModified] = modified
        }
        proof[.proofGenerated] = Util.fullDateFormatter.string(from: Date())
        
        if showDeviceIds {
            proof[.deviceId] = DevicePrivateInfo.getDeviceId()
            // Instead of "Wifi MAC address", which can't be gotten on iOS.
            proof[.deviceVendor] = DeviceInfo.getVendorIdentifier()
        } else {
            proof[.deviceId] = ""
        }
        
        // Divine-local (#9073): upstream records these on every proof, whatever
        // the options say. The proof is signed as it is written, so this is the
        // only place they can be left out.
        if showMobileNetwork {
            proof[.ipv4] = DeviceInfo.getDeviceInfo(device: .DEVICE_IP_ADDRESS_IPV4)
            proof[.ipv6] = DeviceInfo.getDeviceInfo(device: .DEVICE_IP_ADDRESS_IPV6)

            proof[.dataType] = DeviceInfo.getDeviceInfo(device: .DEVICE_DATA_TYPE)
            proof[.network] = DeviceInfo.getDeviceInfo(device: .DEVICE_NETWORK)

            proof[.networkType] = DeviceInfo.getDeviceInfo(device: .DEVICE_NETWORK_TYPE)
        }

        proof[.hardware] = DeviceInfo.getDeviceInfo(device: .DEVICE_HARDWARE_MODEL)
        proof[.manufacturer] = "Apple"
        proof[.screenSize] = DeviceInfo.getDeviceInfo(device: .DEVICE_SCREEN_SIZE)
        
        proof[.language] = DeviceInfo.getDeviceInfo(device: .DEVICE_LANGUAGE)
        proof[.locale] = DeviceInfo.getDeviceInfo(device: .DEVICE_LOCALE)
        
        if showLocation {
            queue.addOperation(BlockOperation(block: {
                proof.add(LocationManager.shared.getLocation())
            }))
        }
        else {
            proof.add(LocationManager.emptyLocation())
        }
        
        if showMobileNetwork {
            proof[.cellInfo] = DeviceInfo.getDeviceInfo(device: .DEVICE_CELL_INFO)
        }
        else {
            proof[.cellInfo] = "none"
        }
        
        queue.waitUntilAllOperationsAreFinished()
        
        return proof
    }
    
    func sha256(file: URL) -> String? {
        guard let data = try? Data(contentsOf: file)
        else {
            return nil
        }

        return SHA256.hash(data: data).hexStr
    }
    
    public func sha256(data: Data?) -> String? {
        guard let data = data else { return nil }
        return SHA256.hash(data: data).hexStr.lowercased()
    }
    
    func documentPath(for fileName: String, isDirectory: Bool = false) -> URL? {
        return self.defaultDocumentFolder?.appendingPathComponent(fileName, isDirectory: isDirectory)
    }
    
    /**
     Return the path where a proof file with the given name should be saved for the given media item.
     
     By default, the file will be created in the documents folder, in a subfolder named after the media item hash value, but this can be overridden by
        `MediaItem.proofFolder`.
     */
    public func proofFilePath(mediaItem: MediaItem, hash: String, fileExtension: String, fileSuffix: String? = nil) -> URL? {
        // Check if we have a folder override given in the media item, otherwise use default folder.
        guard let folder = mediaItem.proofFolder ?? documentPath(for: hash, isDirectory: true)
        else {
            return nil
        }

        // Create folder, if it doesn't exist.
        if !folder.exists {
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            }
            catch {
                print(error)
            }
        }

        // Remove leading dots, if any. `appendingPathExtension` adds that.
        var fileExtension = fileExtension
        while fileExtension.hasPrefix(".") {
            fileExtension.removeFirst()
        }

        if folder.isDirectory {
            return folder.appendingPathComponent("\(mediaItem.proofFilesBaseName ?? hash)\(fileSuffix ?? "")").appendingPathExtension(fileExtension)
        }

        return nil
    }
    
    /**
     Return the path for a folder containing all proof files for the given media item, or nil if no such folder is found.
     */
    public func proofFolder(for mediaItem: MediaItem) -> URL? {
        if let folder = mediaItem.proofFolder {
            return folder.isDirectory ? folder : nil
        }

        if let hash = mediaItem.mediaItemHash {
            if let folder = documentPath(for: hash, isDirectory: true),
               folder.exists && folder.isDirectory
            {
                return folder
            }
        }

        return nil
    }
}

extension URL {

    var isDirectory: Bool {
        (try? resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
    }

    var exists: Bool {
        (try? checkResourceIsReachable()) ?? false
    }
}
