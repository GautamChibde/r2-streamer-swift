//
//  MetadataParser.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 3/17/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation
import AEXML

extension MetadataParser: Loggable {}

public class MetadataParser {

    /// Extracts the Rendition properties from the XML element metadata and fill
    /// then into the Metadata object instance.
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element containing the metadatas.
    ///   - metadata: The `Metadata` object.
    internal func parseRenditionProperties(from metadataElement: AEXMLElement,
                                           to metadata: inout Metadata)
    {
        // Layout
        var attribute = ["property" : "rendition:layout"]

        if let renditionLayouts = metadataElement.all(withAttributes: attribute),
            !renditionLayouts.isEmpty {
            let layouts = renditionLayouts[0].string

            metadata.rendition.layout = RenditionLayout(rawValue: layouts)
        }
        // Flow
        attribute = ["property" : "rendition:flow"]
        if let renditionFlows = metadataElement.all(withAttributes: attribute),
            !renditionFlows.isEmpty {
            let flows = renditionFlows[0].string

            metadata.rendition.flow = RenditionFlow(rawValue: flows)
        }
        // Orientation
        attribute = ["property" : "rendition:orientation"]
        if let renditionOrientations = metadataElement.all(withAttributes: attribute),
            !renditionOrientations.isEmpty {
            let orientation = renditionOrientations[0].string

            metadata.rendition.orientation = RenditionOrientation(rawValue: orientation)
        }
        // Spread
        attribute = ["property" : "rendition:spread"]
        if let renditionSpreads = metadataElement.all(withAttributes: attribute),
            !renditionSpreads.isEmpty {
            let spread = renditionSpreads[0].string

            metadata.rendition.spread = RenditionSpread(rawValue: spread)
        }
        // Viewport
        attribute = ["property" : "rendition:viewport"]
        if let renditionViewports = metadataElement.all(withAttributes: attribute),
            !renditionViewports.isEmpty {
            metadata.rendition.viewport = renditionViewports[0].string
        }
    }

    /// Parse and return the main title informations of the publication the from
    /// the OPF XML document `<metadata>` element.
    /// In the simplest cases it just return the value of the <dc:title> XML 
    /// element, but sometimes there are alternative titles (titles in other
    /// languages).
    /// See `MultilangString` for complementary informations.
    ///
    /// - Parameter metadata: The `<metadata>` element.
    /// - Returns: The content of the `<dc:title>` element, `nil` if the element
    ///            wasn't found.
    internal func mainTitle(from metadata: AEXMLElement) -> MultilangString? {
        // Return if there isn't any `<dc:title>` element
        guard let titles = metadata["dc:title"].all else {
            log(level: .error, "Error: Publication have no title")
            return nil
        }
        let multilangTitle = MultilangString()

        /// The default title to be returned, the first one, singleString.
        multilangTitle.singleString = metadata["dc:title"].string
        /// Now trying to see if multiString title (multi lang).
        guard let mainTitle = getMainTitleElement(from: titles, metadata) else {
            return multilangTitle
        }
        multilangTitle.fillMultiString(forElement: mainTitle, metadata)
        return multilangTitle
    }

    /// Parse and return the Epub unique identifier.
    ///
    /// - Parameters:
    ///   - metadata: The metadata XML element.
    ///   - Attributes: The XML document attributes.
    /// - Returns: The content of the `<dc:identifier>` element, `nil` if the
    ///            element wasn't found.
    internal func uniqueIdentifier(from metadata: AEXMLElement,
                                   with documentattributes: [String : String]) -> String?
    {
        // Look for `<dc:identifier>` elements.
        guard let identifiers = metadata["dc:identifier"].all else {
            return nil
        }
        // Get the one defined as unique by the `<package>` attribute `unique-identifier`.
        if identifiers.count > 1, let uniqueId = documentattributes["unique-identifier"] {
            let uniqueIdentifiers = identifiers.filter { $0.attributes["id"] == uniqueId }
            if !uniqueIdentifiers.isEmpty, let uid = uniqueIdentifiers.first {
                return uid.string
            }
        }
        // Returns the first `<dc:identifier>` content or an empty String.
        return identifiers[0].string
    }

    /// Parse the modifiedDate (date of last modification of the EPUB).
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the Publication Metadata.
    /// - Returns: The date generated from the <dcterms:modified> meta element,
    ///            or nil if not found.
    internal func modifiedDate(from metadataElement: AEXMLElement) -> Date? {
        let modifiedAttribute = ["property" : "dcterms:modified"]

        // Search if the XML element is present, else return.
        guard let modified = metadataElement["meta"].all(withAttributes: modifiedAttribute) else {
            return nil
        }
        let iso8601DateString = modified[0].string

        // Convert the XML element ISO8601DateString into a Date.
        // See Formatter/Date/String extensions for details.
        guard let dateFromString = iso8601DateString.dateFromISO8601 else {
            log(level: .warning, "Error converting the modifiedDate to a Date object")
            return nil
        }
        return dateFromString
    }

    /// Parse the <dc:subject> XML element from the metadata
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the metadata.
    ///   - metadata: The Metadata object to fill (inout).
    internal func subject(from metadataElement: AEXMLElement) -> Subject?
    {
        /// Find the first <dc:subject> (Epub 3.1)
        guard let subjectElement = metadataElement["dc:subject"].first else {
            return nil
        }
        /// Check if there is a value, mandatory field.
        guard let name = subjectElement.value else {
            log(level: .warning, "Invalid Epub, no value for <dc:subject>")
            return nil
        }
        let subject = Subject()

        subject.name = name
        subject.scheme = subjectElement.attributes["opf:authority"]
        subject.code = subjectElement.attributes["opf:term"]
        return subject
    }

    /// Parse all the Contributors objects of the model (`creator`, `contributor`,
    /// `publisher`) and add them to the metadata.
    ///
    /// - Parameters:
    ///   - metadataElement: The XML element representing the metadata.
    ///   - metadata: The Metadata object to fill (inout).
    ///   - epubVersion: The version of the epub document being parsed.
    internal func parseContributors(from metadataElement: AEXMLElement,
                                    to metadata: inout Metadata,
                                    _ epubVersion: Double?)
    {
        var allContributors = [AEXMLElement]()


        allContributors.append(contentsOf: findContributorsXmlElements(in: metadataElement))
        // <meta> DCTERMS parsing if epubVersion == 3.0
        if epubVersion == 3.0 {
            allContributors.append(contentsOf: findContributorsMetaXmlElements(in: metadataElement))
        }
        // Parse XML elements and fill the metadata object.
        for contributor in allContributors {
            parseContributor(from: contributor, in: metadataElement, to: &metadata)
        }
    }

    /// Parse a `creator`, `contributor`, `publisher` element from the OPF XML
    /// document, then builds and adds a Contributor to the metadata, to an
    /// array according to its role (authors, translators, etc.).
    ///
    /// - Parameters:
    ///   - element: The XML element to parse.
    ///   - metadataElement: The XML element containing the metadata informations.
    ///   - metadata: The Metadata object.
    ///   - epubVersion: The version of the epub being parsed.
    internal func parseContributor(from element: AEXMLElement, in metadataElement: AEXMLElement,
                                   to metadata: inout Metadata)
    {
        let contributor = createContributor(from: element, metadataElement)

        // Look up for possible meta refines for contributor's role.
        if let eid = element.attributes["id"] {
            let attributes = ["refines": "#\(eid)", "property": "role"]
            let metas = metadataElement["meta"].all(withAttributes: attributes)

            contributor.role = metas?.first?.string
        }
        // Add the contributor to the proper property according to the its `role`
        if let role = contributor.role {
            switch role {
            case "aut":
                metadata.authors.append(contributor)
            case "trl":
                metadata.translators.append(contributor)
            case "art":
                metadata.artists.append(contributor)
            case "edt":
                metadata.editors.append(contributor)
            case "ill":
                metadata.illustrators.append(contributor)
            case "clr":
                metadata.colorists.append(contributor)
            case "nrt":
                metadata.narrators.append(contributor)
            case "pbl":
                metadata.publishers.append(contributor)
            default:
                metadata.contributors.append(contributor)
            }
        } else {
            // No role, so do the branching using the element.name.
            // The remaining ones go to to the contributors.
            if element.name == "dc:creator" || element.attributes["property"] == "dcterms:contributor" {
                metadata.authors.append(contributor)
            } else if element.name == "dc:publisher" || element.attributes["property"] == "dcterms:publisher" {
                metadata.publishers.append(contributor)
            } else {
                metadata.contributors.append(contributor)
            }
        }
    }

    /// Builds a `Contributor` instance from a `<dc:creator>`, `<dc:contributor>`
    /// or <dc:publisher> element, or <meta> element with property == "dcterms:
    /// creator", "dcterms:publisher", "dcterms:contributor".
    ///
    /// - Parameters:
    ///   - element: The XML element reprensenting the contributor.
    /// - Returns: The newly created Contributor instance.
    internal func createContributor(from element: AEXMLElement, _ metadata: AEXMLElement) -> Contributor
    {
        // The 'to be returned' Contributor object.
        let contributor = Contributor()

        /// The default title to be returned, the first one, singleString.
        contributor._name.singleString = element.value
        contributor._name.fillMultiString(forElement: element, metadata)
        // Get role from role attribute
        if let role = element.attributes["opf:role"] {
            contributor.role = role
        }
        // Get sort name from file-as attribute
        if let sortAs = element.attributes["opf:file-as"] {
            contributor.sortAs = sortAs
        }
        return contributor
    }

    // Mark: - Private Methods.

    /// Return the XML element corresponding to the main title (title having
    /// `<meta refines="#.." property="title-type" id="title-type">main</meta>`
    ///
    /// - Parameters:
    ///   - titles: The titles XML elements array.
    ///   - metadata: The Publication Metadata XML object.
    /// - Returns: The main title XML element.
    private func getMainTitleElement(from titles: [AEXMLElement],
                                     _ metadata: AEXMLElement) -> AEXMLElement?
    {
        return titles.first(where: {
            guard let eid = $0.attributes["id"] else {
                return false
            }
            let attributes = ["refines": "#\(eid)", "property": "title-type"]
            let metas = metadata["meta"].all(withAttributes: attributes)

            return metas?.contains(where: { $0.string == "main" }) ?? false
        })
    }

    /// [EPUB 2.0 & 3.1+]
    /// Return the XML elements about the contributors.
    /// E.g.: `<dc:publisher "property"=".." >value<\>`.
    ///
    /// - Parameter metadata: The XML metadata element.
    /// - Returns: The array of XML element representing the contributors.
    private func findContributorsXmlElements(in metadata: AEXMLElement) -> [AEXMLElement] {
        var allContributors = [AEXMLElement]()

        // Get the Publishers XML elements.
        if let publishers = metadata["dc:publisher"].all {
            allContributors.append(contentsOf: publishers)
        }
        // Get the Creators XML elements.
        if let creators = metadata["dc:creator"].all {
            allContributors.append(contentsOf: creators)
        }
        // Get the Contributors XML elements.
        if let contributors = metadata["dc:contributor"].all {
            allContributors.append(contentsOf: contributors)
        }
        return allContributors
    }

    /// [EPUB 3.0]
    /// Return the XML elements about the contributors.
    /// E.g.: `<meta "property"="dcterms:publisher/creator/contributor"`.
    ///
    /// - Parameter metadata: The metadata XML element.
    /// - Returns: The array of XML element representing the <meta> contributors.
    private func findContributorsMetaXmlElements(in metadata: AEXMLElement) -> [AEXMLElement] {
        var allContributors = [AEXMLElement]()

        // Get the Publishers XML elements.
        let publisherAttributes = ["property": "dcterms:publisher"]
        if let publishersFromMeta = metadata["meta"].all(withAttributes: publisherAttributes),
            !publishersFromMeta.isEmpty {
            allContributors.append(contentsOf: publishersFromMeta)
        }
        // Get the Creators XML elements.
        let creatorAttributes = ["property": "dcterms:creator"]
        if let creatorsFromMeta = metadata["meta"].all(withAttributes: creatorAttributes),
            !creatorsFromMeta.isEmpty {
            allContributors.append(contentsOf: creatorsFromMeta)
        }
        // Get the Contributors XML elements.
        let contributorAttributes = ["property": "dcterms:contributor"]
        if let contributorsFromMeta = metadata["meta"].all(withAttributes: contributorAttributes),
            !contributorsFromMeta.isEmpty {
            allContributors.append(contentsOf: contributorsFromMeta)
        }
        return allContributors
    }
}