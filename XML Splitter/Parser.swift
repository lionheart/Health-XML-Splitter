//
//  Parser.swift
//  XML Splitter
//
//  Created by Daniel Loewenherz on 9/23/17.
//  Copyright © 2017 Lionheart Software LLC. All rights reserved.
//

import Foundation

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

    init(filename: String, threshold: Int = 500000) {
        super.init()

        self.url = URL(fileURLWithPath: filename)
        self.threshold = threshold
    }

    func start() {
        elementCount = 0

        guard let url = url,
            let inputStream = InputStream(url: url) else {
            fatalError()
        }

        let parser = XMLParser(stream: inputStream)
        parser.delegate = self
        parser.parse()
    }

    func writeToFile() {
        // Write to queue.
        let filename = "/tmp/export\(currentChunk).xml"
        guard let data = root?.stringValue.data(using: .utf8),
            let outputStream = OutputStream(toFileAtPath: filename, append: false) else {
                fatalError()
        }

        print("Chunk completed. Saving to \(filename).")

        outputStream.open()

        do {
            try outputStream.write(data: data)
        } catch OutputStreamWriteError.capacityReached {
            print("File System Reached Capacity")
        } catch OutputStreamWriteError.writeError {
            print("Write Error Occurred")
        } catch {}

        outputStream.close()

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
        } else if result == -1 {
            throw OutputStreamWriteError.writeError
        } else {
            return result
        }
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

        if elementCount > threshold && element.parent?.name == root?.name {
            writeToFile()
        }
    }

    func parserDidStartDocument(_ parser: XMLParser) {
        print("Parsing started.")
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        print("Parse error occurred: \(parseError.localizedDescription)")
    }

    func parserDidEndDocument(_ parser: XMLParser) {
        writeToFile()
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
