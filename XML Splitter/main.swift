//
//  main.swift
//  XML Splitter
//
//  Created by Daniel Loewenherz on 9/23/17.
//  Copyright © 2017 Lionheart Software LLC. All rights reserved.
//

import Foundation

final class CommandLineDelegate: ParserDelegate {
  var targetDirectoryPath: String? { return nil }
  var error: Error?

  func savingChunk(part: Int) { print("Saving chunk \(part + 1)...") }
  func parsingStarted() {}
  func chunkUpdate(part: Int, current: Int, total: Int) {}
  func chunkCompleted(part: Int) {}
  func parsingDidComplete() { print("Done.") }
  func parsingFailed(error: Error) { self.error = error }
}

guard CommandLine.arguments.count == 2 else {
  print("Usage: ./splitter FILENAME")
  exit(EXIT_FAILURE)
}

let filename = CommandLine.arguments[1]

print("Parsing \(filename)")

let parser = Parser(filename: filename)
let delegate = CommandLineDelegate()
parser.delegate = delegate
parser.start()

if let error = delegate.error {
  FileHandle.standardError.write(Data("\(error.localizedDescription)\n".utf8))
  exit(EXIT_FAILURE)
}
