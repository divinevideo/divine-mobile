//
//  MediaItem.swift
//  LibProofMode
//
//  Created by N-Pex on 2020-07-24.
//

import SwiftUI
import Photos
import LegacyUTType
import UniformTypeIdentifiers

open class MediaItem: NSObject {
    open var isGeneratingProof: Bool = false
    public var forceGenerateProof: Bool = true
    
    /**
        An optional URL for the directory in which to store proof files for the media item.
        
        By default this will be a folder named after the hash value, stored under the current user's documents directory.
     */
    public var proofFolder: URL?

    /**
     An optional file name base for the proof files, which will be used instead of the calculated hash.
     */
    public var proofFilesBaseName: String?
    
    lazy public var asset: PHAsset? = {
        if let assetAsset = assetAsset {
            return assetAsset
        } else if let assetIdentifier = assetIdentifier {
            if let asset = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil).firstObject {
                return asset
            }
        }
        return nil
    }()
    public var assetIdentifier: String?
    public var assetAsset: PHAsset?
    public var mediaUrl: URL?
    public var data: Data?
    public var mediaType: (any UTTypeProtocol)?
    public var mediaItemHash: String?
    public var fileName: String?
    public var modified: String?
    public var modifiedDate: Date? {
        didSet {
            if let date = modifiedDate {
                self.modified = Util.fullDateFormatter.string(from: date)
            }
        }
    }
    
    open var filenameOrDefault:String {
        if let filename = fileName {
            return filename
        }
        let date = modifiedDate ?? Date()

        let filename = "\(mediaType?.conforms(to: UTType.movie) ?? false ? "video" : (mediaType?.conforms(to: UTType.audio) ?? false ? "audio" : "photo"))_\(date.millisecondsSince1970).\(mediaType?.preferredFilenameExtension ?? "")"
        return filename
    }
    
    open var hasProof: Bool {
        // For now, if hash has been set, we have proof! TODO - maybe change this, so that
        // hash if just the hash value of the original file.
        return mediaItemHash != nil
    }
    
    open var uniqueIdentifier: String {
        if let asset = asset {
            return asset.localIdentifier
        }
        return mediaUrl?.absoluteString ?? ""
    }
    
    public init(asset: PHAsset) {
        self.assetAsset = asset
        super.init()
    }

    public init(assetIdentifier: String) {
        self.assetIdentifier = assetIdentifier
        super.init()
    }

    
    public init(mediaUrl: URL, mediaType: (any UTTypeProtocol)? = nil, fileName: String? = nil) {
        self.mediaUrl = mediaUrl
        self.mediaType = mediaType
        self.fileName = fileName

        super.init()
    }
    
    public init(mediaData: Data, mediaType: (any UTTypeProtocol)? = nil, modifiedDate: Date? = nil, fileName: String? = nil) {
        self.data = mediaData
        self.mediaType = mediaType
        self.modifiedDate = modifiedDate
        self.fileName = fileName

        super.init()
    }
    
    /// Divine-local (#10197): a file is hashed and signed by streaming it, so
    /// it is never read into `data`. A whole recording there can be more
    /// memory than iOS allows the app.
    var streamsFromFile: Bool {
        asset == nil && mediaUrl != nil
    }

    func createProof(options: ProofGenerationOptions, done:@escaping (Bool)->Void) {
        self.isGeneratingProof = true
        withData(onlyMeta: streamsFromFile) { data in
            self.data = data
            if self.data != nil || self.streamsFromFile {
                self.mediaItemHash = Proof.shared.getProof(for: self, force: self.forceGenerateProof, options: options)
                self.isGeneratingProof = false
                done(true)
            } else {
                self.isGeneratingProof = false
                done(false)
            }
        }
    }

    public func getProofData(done: @escaping ([String: String]?) -> Void) {
        withData(onlyMeta: streamsFromFile) { data in
            self.data = data
            done(Proof.shared.getProofData(mediaItem: self))
        }
    }
        
    open func withData(onlyMeta: Bool = false, callback:@escaping (Data?)-> Void) {
        if let asset = self.asset {
            if let originalPhoto = PHAssetResource.assetResources(for: asset).first(where: { (resource) -> Bool in
                resource.type == .photo || resource.type == .video
            }) {
                self.mediaType = originalPhoto.type == .video ? LegacyUTType.movie : LegacyUTType.image
                
                // Get modification date and original file name
                //
                self.modifiedDate = asset.modificationDate

                if fileName?.isEmpty ?? true {
                    fileName = originalPhoto.originalFilename
                }

                if fileName?.isEmpty ?? true, let creationDate = asset.creationDate {
                    fileName = Util.dateFormatter.string(from: creationDate)
                }
                
                let assetOptions = PHAssetResourceRequestOptions()
                assetOptions.isNetworkAccessAllowed = true
                
                if onlyMeta {
                    callback(nil)
                    return
                }
                
                var data = Data()
                PHAssetResourceManager.default().requestData(for: originalPhoto, options: assetOptions, dataReceivedHandler: { (chunk) in
                    data.append(chunk)
                }) { (error) in
                    if error == nil {
                        callback(data)
                    } else {
                        callback(nil)
                    }
                }
            } else {
                callback(nil)
            }
        } else if let mediaUrl = mediaUrl {
            do {
                let attr = try mediaUrl.resourceValues(forKeys: [.contentModificationDateKey, .creationDateKey])
                modifiedDate = attr.contentModificationDate

                if fileName?.isEmpty ?? true {
                    fileName = mediaUrl.lastPathComponent
                }

                if fileName?.isEmpty ?? true, let creationDate = attr.creationDate {
                    fileName = Util.dateFormatter.string(from: creationDate)
                }

                if onlyMeta {
                    callback(nil)
                    return
                }

                let fileCoordinator = NSFileCoordinator()
                var data: Data?
                var error: NSError?
                fileCoordinator.coordinate(readingItemAt: mediaUrl, error: &error) { url in
                    data = try? Data(contentsOf: url)
                }
                callback(data)
            } catch {
                callback(nil)
            }
        } else if let data = self.data {
            callback(data)
        } else {
            // Invalid type
            callback(nil)
        }
    }
}

extension Date {
    var millisecondsSince1970:Int64 {
        Int64((self.timeIntervalSince1970 * 1000.0).rounded())
    }
    
    init(milliseconds:Int64) {
        self = Date(timeIntervalSince1970: TimeInterval(milliseconds) / 1000)
    }
}
