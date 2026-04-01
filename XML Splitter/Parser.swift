//
//  Parser.swift
//  XML Splitter
//
//  Created by Daniel Loewenherz on 9/23/17.
//  Copyright © 2017 Lionheart Software LLC. All rights reserved.
//

import libxml2
import Foundation

enum ParserError: Error {
  case dataCouldNotBeRead
}

protocol ParserDelegate {
  var targetDirectoryPath: String? { get }

  func savingChunk(part: Int)
  func parsingStarted()
  func chunkUpdate(part: Int, current: Int, total: Int)
  func chunkCompleted(part: Int)
  func parsingDidComplete()
  func parsingFailed(error: Error)
}

let XMLCharacterMap: [(String, String)] = [
  ("&", "&amp;"),
  ("\"", "&quot;"),
  ("'", "&#39;"),
  (">", "&gt;"),
  ("<", "&lt;"),
]

extension String {
  var escaped: String {
    return XMLCharacterMap.reduce(self) { $0.replacingOccurrences(of: $1.0, with: $1.1) }
  }
}

class Element {
  var parent: Element?
  var name: String
  var attributes: [String: String]
  var children: [Element] = []
  var indentLevel = 0

  var stringValue: String {
    let attributesString = attributes.map({ "\($0.key)=\"\($0.value.escaped)\"" }).joined(
      separator: " ")
    var components: [String] = []
    components.append("<\(name) \(attributesString)>")
    if children.count > 0 {
      components.append("\n")
      for child in children {
        components.append("  \(child.stringValue)\n")
      }
    }
    components.append("</\(name)>")
    return components.joined()
  }

  init(name: String, attributes: [String: String]) {
    self.name = name
    self.attributes = attributes
  }
}

// MARK: - libxml2 SAX2 Callbacks

/// Recover the Parser instance from the libxml2 context pointer.
private func parserFrom(_ ctx: UnsafeMutableRawPointer?) -> Parser? {
  guard let ctx = ctx else { return nil }
  return Unmanaged<Parser>.fromOpaque(ctx).takeUnretainedValue()
}

/// Parse SAX2 attributes array into a Swift dictionary.
/// Each attribute is a group of 5 pointers: localname, prefix, URI, valueBegin, valueEnd.
/// Attribute values are NOT null-terminated — use (valueBegin, valueEnd) range.
private func parseAttributes(
  _ attributes: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?,
  count: Int32
) -> [String: String] {
  guard let attributes = attributes, count > 0 else { return [:] }

  var dict: [String: String] = [:]
  for i in 0..<Int(count) {
    let base = i * 5
    guard let localname = attributes[base] else { continue }

    let name = String(cString: localname)

    let valueBegin = attributes[base + 3]
    let valueEnd = attributes[base + 4]

    if let begin = valueBegin, let end = valueEnd {
      let length = end - begin
      let value = String(
        bytes: UnsafeBufferPointer(start: begin, count: length),
        encoding: .utf8
      ) ?? ""
      dict[name] = value
    } else {
      dict[name] = ""
    }
  }
  return dict
}

private func saxStartDocument(_ ctx: UnsafeMutableRawPointer?) {
  parserFrom(ctx)?.handleStartDocument()
}

private func saxEndDocument(_ ctx: UnsafeMutableRawPointer?) {
  parserFrom(ctx)?.handleEndDocument()
}

private func saxStartElementNs(
  _ ctx: UnsafeMutableRawPointer?,
  _ localname: UnsafePointer<xmlChar>?,
  _ prefix: UnsafePointer<xmlChar>?,
  _ URI: UnsafePointer<xmlChar>?,
  _ nb_namespaces: Int32,
  _ namespaces: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?,
  _ nb_attributes: Int32,
  _ nb_defaulted: Int32,
  _ attributes: UnsafeMutablePointer<UnsafePointer<xmlChar>?>?
) {
  guard let localname = localname else { return }
  let name = String(cString: localname)
  let attrs = parseAttributes(attributes, count: nb_attributes)
  parserFrom(ctx)?.handleStartElement(name: name, attributes: attrs)
}

private func saxEndElementNs(
  _ ctx: UnsafeMutableRawPointer?,
  _ localname: UnsafePointer<xmlChar>?,
  _ prefix: UnsafePointer<xmlChar>?,
  _ URI: UnsafePointer<xmlChar>?
) {
  guard let localname = localname else { return }
  let name = String(cString: localname)
  parserFrom(ctx)?.handleEndElement(name: name)
}

// MARK: - Parser

final class Parser {
  var root: Element?
  var element: Element?
  var exportDateElement: Element?
  var threshold: Int!
  var url: URL!
  var currentChunk = 0
  var elementCount = 0
  var delegate: ParserDelegate?

  /// Read chunk size for the push parser (64 KB).
  private let readBufferSize = 65536

  init(filename: String, threshold: Int = 500000) {
    self.url = URL(fileURLWithPath: filename)
    self.threshold = threshold
  }

  func start() {
    elementCount = 0

    guard let url = url,
      let rawStream = InputStream(url: url)
    else {
      fatalError()
    }

    let inputStream = SanitizingInputStream(stream: rawStream)
    inputStream.open()

    // Build SAX2 handler
    var handler = xmlSAXHandler()
    memset(&handler, 0, MemoryLayout<xmlSAXHandler>.size)
    handler.initialized = XML_SAX2_MAGIC
    handler.startDocument = saxStartDocument
    handler.endDocument = saxEndDocument
    handler.startElementNs = saxStartElementNs
    handler.endElementNs = saxEndElementNs

    let selfPtr = Unmanaged.passUnretained(self).toOpaque()

    guard let ctxt = xmlCreatePushParserCtxt(&handler, selfPtr, nil, 0, nil) else {
      fatalError("Failed to create libxml2 push parser context")
    }

    // Enable recovery mode and disable network access
    xmlCtxtUseOptions(ctxt, Int32(XML_PARSE_RECOVER.rawValue | XML_PARSE_NONET.rawValue))

    // Read and parse in chunks
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: readBufferSize)
    defer {
      buffer.deallocate()
      xmlFreeParserCtxt(ctxt)
      inputStream.close()
    }

    while inputStream.hasBytesAvailable {
      let bytesRead = inputStream.read(buffer, maxLength: readBufferSize)
      if bytesRead < 0 {
        print("Stream read error: \(inputStream.streamError?.localizedDescription ?? "unknown")")
        break
      }
      if bytesRead == 0 {
        break
      }

      buffer.withMemoryRebound(to: CChar.self, capacity: bytesRead) { charBuffer in
        xmlParseChunk(ctxt, charBuffer, Int32(bytesRead), 0)
      }
    }

    // Signal end of parsing
    xmlParseChunk(ctxt, nil, 0, 1)
  }

  // MARK: - SAX2 Handler Methods

  func handleStartDocument() {
    print("Parsing started.")
    delegate?.parsingStarted()
  }

  func handleEndDocument() {
    do {
      try writeToFile()
    } catch {
      delegate?.parsingFailed(error: error)
      return
    }

    delegate?.parsingDidComplete()
  }

  func handleStartElement(name: String, attributes: [String: String]) {
    let currentElement = Element(name: name, attributes: attributes)

    if exportDateElement == nil, name == "ExportDate" {
      exportDateElement = currentElement

      print("Starting new chunk.")
    }

    if let element = element {
      currentElement.parent = element
      self.element = currentElement
    } else {
      element = currentElement
      root = currentElement
    }
  }

  func handleEndElement(name: String) {
    guard let element = element, name == element.name else {
      // Keep going.
      return
    }

    // The element is closed. Add it to the parent, if it exists.
    element.parent?.children.append(element)
    elementCount += 1
    self.element = element.parent

    delegate?.chunkUpdate(part: currentChunk, current: elementCount, total: threshold)

    if elementCount > threshold && element.parent?.name == root?.name {
      do {
        try writeToFile()
      } catch {
        delegate?.parsingFailed(error: error)
        return
      }
    }
  }

  // MARK: - File Output

  func writeToFile() throws {
    delegate?.savingChunk(part: currentChunk)

    // Write to queue.
    let target = delegate?.targetDirectoryPath ?? "/tmp"
    let filename = "\(target)/export\(currentChunk).xml"
    guard let data = root?.stringValue.data(using: .utf8),
      let outputStream = OutputStream(toFileAtPath: filename, append: false)
    else {
      throw ParserError.dataCouldNotBeRead
    }

    print("Chunk completed. Saving to \(filename).")

    outputStream.open()

    do {
      try outputStream.write(data: data)
    } catch OutputStreamWriteError.capacityReached {
      print("File System Reached Capacity")
    } catch OutputStreamWriteError.writeError {
      print("Write Error Occurred")
    } catch {
      print(error)
    }

    outputStream.close()
    delegate?.chunkCompleted(part: currentChunk)

    elementCount = 0
    currentChunk += 1
    root?.children.removeAll()

    if let dateElement = exportDateElement {
      dateElement.parent = root
      root?.children.append(dateElement)
    }
  }
}

enum OutputStreamWriteError: Error {
  case capacityReached
  case writeError
}

extension OutputStream {
  @discardableResult
  func write(data: Data) throws -> Int {
    let result = data.withUnsafeBytes { write($0, maxLength: data.count) }
    if result == 0 {
      throw OutputStreamWriteError.capacityReached
    }

    if result == -1 {
      if let error = streamError {
        throw error
      } else {
        throw OutputStreamWriteError.writeError
      }
    }

    return result
  }
}
