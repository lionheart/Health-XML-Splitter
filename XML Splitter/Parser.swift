//
//  Parser.swift
//  XML Splitter
//
//  Created by Daniel Loewenherz on 9/23/17.
//  Copyright © 2017 Lionheart Software LLC. All rights reserved.
//

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
        let attributesString = attributes.map({ "\($0.key)=\"\($0.value.escaped)\"" }).joined(separator: " ")
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

final class Parser: NSObject {
    var root: Element?
    var element: Element?
    var exportDateElement: Element?
    var threshold: Int!
    var url: URL!
    var currentChunk = 0
    var elementCount = 0
    var delegate: ParserDelegate?

    init(filename: String, threshold: Int = 500000) {
        super.init()

        self.url = URL(fileURLWithPath: filename)
        self.threshold = threshold
    }

    func cleanStream(url: URL) -> InputStream? {
        guard let stream = InputStream(url: url) else {
            return nil
        }

        // https://stackoverflow.com/questions/42561020/reading-an-inputstream-into-a-data-object
        // https://www.objc.io/blog/2018/02/13/string-to-data-and-back/
        // Fixes the following parsing error:
        //      ATTLIST: no name for Attribute (row 156, column 1).
        // https://share.cleanshot.com/EJdVWQRVcw8qKgrAL76m
        var data = Data()
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 1)
        stream.open()
        var hasGoodDTD = true
        var count = 0
        while true {
            count += 1
            stream.read(buffer, maxLength: 1)
            data.append(buffer, count: 1)

            if count > 10000 {
                break
            }

            // We break at 10000 since at this point, there's probably nothing wrong.
            if let s = String(data: data, encoding: .utf8),
               s.hasSuffix("]>") {
                hasGoodDTD = false
                break
            }
        }

        if hasGoodDTD {
            // Return a fresh DTD--no alterations
            return InputStream(url: url)
        }

        return stream
    }

    func start() {
        elementCount = 0

        guard let url = url,
            let inputStream = cleanStream(url: url) else {
            fatalError()
        }

        let parser = XMLParser(stream: inputStream)
        parser.delegate = self
        parser.parse()
    }

    func writeToFile() throws {        
        delegate?.savingChunk(part: currentChunk)

        // Write to queue.
        let target = delegate?.targetDirectoryPath ?? "/tmp"
        let filename = "\(target)/export\(currentChunk).xml"
        guard let data = root?.stringValue.data(using: .utf8),
            let outputStream = OutputStream(toFileAtPath: filename, append: false) else {
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

        if let exportDateElement {
            exportDateElement.parent = root
            root?.children.append(exportDateElement)
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

// MARK: - XMLParserDelegate
extension Parser: XMLParserDelegate {
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        guard let element = element, elementName == element.name else {
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

    func parserDidStartDocument(_ parser: XMLParser) {
        print("Parsing started.")
        delegate?.parsingStarted()
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parse error occurred: \(parseError.localizedDescription)")
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        do {
            try writeToFile()
        } catch {
            delegate?.parsingFailed(error: error)
            return
        }

        delegate?.parsingDidComplete()
    }

    func parser(_ parser: XMLParser, validationErrorOccurred validationError: Error) {
        print("Validation error occurred: \(validationError.localizedDescription)")
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let currentElement = Element(name: elementName, attributes: attributeDict)

        if exportDateElement == nil, elementName == "ExportDate" {
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
}
