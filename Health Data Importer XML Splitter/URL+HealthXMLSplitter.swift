//
//  URL+HealthXMLSplitter.swift
//  Health Data Importer XML Splitter
//
//  Created by Dan Loewenherz on 9/22/18.
//  Copyright © 2018 Lionheart Software LLC. All rights reserved.
//

import Cocoa

extension URL {
    var processableFileType: ProcessableFileType? {
        return ProcessableFileType(url: self)
    }
}
