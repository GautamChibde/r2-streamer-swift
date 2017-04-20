//
//  EpubFetcher.swift
//  R2Streamer
//
//  Created by Olivier Körner on 21/12/2016.
//  Copyright © 2016 Readium. All rights reserved.
//

import Foundation

/// Error throw by the `Fetcher`.
///
/// - missingFile: The file is missing from the container.
/// - container: An Container error occurred.
/// - missingRootFile: The rootFile is missing from internalData
public enum FetcherError: Error {
    case missingFile(path: String)
    /// An Container error occurred, **underlyingError** thrown.
    case container(underlyingError: Error)
    /// No rootFile in internalData, unable to get path to publication
    case missingRootFile()
    /// The mimetype of the container is empty.
    case missingContainerMimetype()
}


/// The Fetcher object lets you get the data from the assets in the container.
/// It will fetch the data in the container and apply content filters
/// (decryption for example).

// Default implementation.
internal class Fetcher {
    /// The publication to fetch from
    let publication: Publication
    /// The container to access the resources from
    let container: Container
    /// The relative path to the directory holding the resources in the container
    let rootFileDirectory: String
    /// The content filter.
    let contentFilters: ContentFilters!

    internal init(publication: Publication, container: Container) throws {
        self.container = container
        self.publication = publication

        // Get the path of the directory of the rootFile, to access resources
        // relative to the rootFile
        guard let rootfilePath = publication.internalData["rootfile"] else {
            throw FetcherError.missingRootFile()
        }
        if !rootfilePath.isEmpty {
            rootFileDirectory = rootfilePath.deletingLastPathComponent
        } else {
            rootFileDirectory = ""
        }
        contentFilters = try Fetcher.getContentFilters(forMimeType: container.rootFile.mimetype)
    }

    /// Gets all the data from an resource file in a publication's container.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: The decrypted data of the asset.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func data(forRelativePath path: String) throws -> Data? {
        // Build the path relative to the container
        let relativePath = rootFileDirectory.appending(pathComponent: path)

        // Get the link information from the publication
        guard publication.resource(withRelativePath: path) != nil else {
            throw FetcherError.missingFile(path: path)
        }
        // Get the data from the container
        let data = try container.data(relativePath: relativePath)
//        try contentFilters.apply(to: data, of: publication, at: relativePath)
        return data
    }

    /// Get an input stream with the data of the resource.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: A seekable input stream with the decrypted data if the resource.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func dataStream(forRelativePath path: String) throws -> SeekableInputStream {
        // Build the path relative to the container
        let relativePath = rootFileDirectory.appending(pathComponent: path)
        var inputStream: SeekableInputStream

        // Get the link information from the publication
        guard let _ = publication.resource(withRelativePath: path) else {
            throw FetcherError.missingFile(path: path)
        }
        // Get an input stream from the container
        inputStream = try container.dataInputStream(relativePath: relativePath)
        // Apply content filters to inputStream data.
        inputStream = try contentFilters.apply(to: inputStream, of: publication, at: relativePath)

        return inputStream
    }

    /// Get the total length of the data in an resource file.
    ///
    /// - Parameter path: The relative path to the asset in the publication.
    /// - Returns: The length of the data.
    /// - Throws: `EpubFetcherError.missingFile`.
    internal func dataLength(forRelativePath path: String) throws -> UInt64 {
        // Build the path relative to the container
        let relativePath = rootFileDirectory.appending(pathComponent: path)

        // Get the link information from the publication
        guard let _ = publication.resource(withRelativePath: path) else {
            throw FetcherError.missingFile(path: path)
        }
        // Get the data length from the container
        guard let length = try? container.dataLength(relativePath: relativePath) else {
            throw FetcherError.missingFile(path: relativePath)
        }
        return length
    }

    /// Return the right ContentFilter subclass instance depending of the mime
    /// type.
    ///
    /// - Parameter mimeType: The mimetype string.
    /// - Returns: The corresponding ContentFilters subclass.
    /// - Throws: In case the mimetype is nil or invalid, throws a
    ///           `FetcherError.missingContainerMimetype`
    static func getContentFilters(forMimeType mimeType: String?) throws -> ContentFilters {
        guard let mimeType = mimeType else {
            throw FetcherError.missingContainerMimetype()
        }
        switch mimeType {
        case EpubConstant.mimetype :
            return ContentFiltersEpub()
        case EpubConstant.mimetypeOEBPS :
            return ContentFiltersEpub()
        case CbzConstant.mimetype :
            return ContentFiltersCbz()
        default:
            throw FetcherError.missingContainerMimetype()
        }
    }
}