//
//  SanitizingInputStream.swift
//  XML Splitter
//
//  Wraps an InputStream and strips invalid XML 1.0 characters on read.
//  Valid XML 1.0 bytes: 0x09 (tab), 0x0A (LF), 0x0D (CR), >= 0x20.
//  Multi-byte UTF-8 sequences (bytes >= 0x80) pass through untouched.
//

import Foundation

final class SanitizingInputStream: InputStream {
  private let innerStream: InputStream
  private var _streamStatus: Stream.Status = .notOpen
  private var _streamError: Error?

  init(stream: InputStream) {
    self.innerStream = stream
    super.init(data: Data())  // Dummy init; we override everything
  }

  override var streamStatus: Stream.Status {
    return innerStream.streamStatus
  }

  override var streamError: Error? {
    return innerStream.streamError
  }

  override var hasBytesAvailable: Bool {
    return innerStream.hasBytesAvailable
  }

  override func open() {
    innerStream.open()
  }

  override func close() {
    innerStream.close()
  }

  override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
    // Read into a temporary buffer, then copy only valid XML bytes.
    let tempBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: len)
    defer { tempBuffer.deallocate() }

    let bytesRead = innerStream.read(tempBuffer, maxLength: len)
    if bytesRead <= 0 {
      return bytesRead  // EOF (0) or error (-1)
    }

    var writeIndex = 0
    for i in 0..<bytesRead {
      let byte = tempBuffer[i]
      if isValidXMLByte(byte) {
        buffer[writeIndex] = byte
        writeIndex += 1
      }
    }

    return writeIndex
  }

  override func getBuffer(
    _ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>,
    length len: UnsafeMutablePointer<Int>
  ) -> Bool {
    return false  // Not supported; forces callers to use read(_:maxLength:)
  }

  override func schedule(in aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
    innerStream.schedule(in: aRunLoop, forMode: mode)
  }

  override func remove(from aRunLoop: RunLoop, forMode mode: RunLoop.Mode) {
    innerStream.remove(from: aRunLoop, forMode: mode)
  }

  override func property(forKey key: Stream.PropertyKey) -> Any? {
    return innerStream.property(forKey: key)
  }

  override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
    return innerStream.setProperty(property, forKey: key)
  }

  // MARK: - Private

  /// Returns true if the byte is valid in XML 1.0.
  /// Valid: 0x09 (tab), 0x0A (newline), 0x0D (carriage return), >= 0x20.
  /// This correctly passes through all multi-byte UTF-8 (bytes >= 0x80).
  /// Strips: 0x00-0x08, 0x0B, 0x0C, 0x0E-0x1F (includes U+0001 SOH, U+0018 CAN).
  private func isValidXMLByte(_ byte: UInt8) -> Bool {
    return byte == 0x09 || byte == 0x0A || byte == 0x0D || byte >= 0x20
  }
}
