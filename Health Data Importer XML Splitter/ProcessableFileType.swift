//
//  ProcessableFileType.swift
//  Health Data Importer XML Splitter
//
//  Created by Dan Loewenherz on 9/22/18.
//  Copyright © 2018 Lionheart Software LLC. All rights reserved.
//

import Cocoa

enum ProcessableFileType {
  case zip
  case xml

  init?(url: URL?) {
    guard let suffix = url?.path.split(separator: ".").last,
      ["xml", "zip"].contains(String(suffix))
    else {
      return nil
    }

    switch String(suffix) {
    case "xml": self = .xml
    case "zip": self = .zip
    default: return nil
    }
  }
}
