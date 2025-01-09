//
//  main.swift
//  XML Splitter
//
//  Created by Daniel Loewenherz on 9/23/17.
//  Copyright © 2017 Lionheart Software LLC. All rights reserved.
//

import Foundation

guard CommandLine.arguments.count == 2 else {
  print("Usage: ./splitter FILENAME")
  exit(EXIT_FAILURE)
}

let filename = CommandLine.arguments[1]

print("Parsing \(filename)")

let parser = Parser(filename: filename)
parser.start()
