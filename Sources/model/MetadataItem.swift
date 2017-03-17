//
//  MetadataItem.swift
//  R2Streamer
//
//  Created by Alexandre Camilleri on 2/16/17.
//  Copyright © 2017 Readium. All rights reserved.
//

import Foundation

/// <#Description#>
open class MetadataItem {
    
    public var property: String?
    public var value: String?
    public var children: [MetadataItem] = [MetadataItem]()

    public init() {}
}