// Copyright © 2017 Lionheart Software LLC. All rights reserved.
// Swift adapter for the platform-independent Go splitting engine.
import Foundation
import HealthSplitter

protocol ParserDelegate {
  var targetDirectoryPath: String? { get }

  func savingChunk(part: Int)
  func parsingStarted()
  func chunkUpdate(part: Int, current: Int, total: Int)
  func chunkCompleted(part: Int)
  func parsingDidComplete()
  func parsingFailed(error: Error)
}

final class Parser: NSObject, HealthsplitterProgressProtocol {
  private let filename: String
  private let threshold: Int
  var delegate: ParserDelegate?

  init(filename: String, threshold: Int = 500000) {
    self.filename = filename
    self.threshold = threshold
    super.init()
  }

  // Synchronous, as before. The AppKit controller calls this on a worker queue.
  func start() {
    let output = delegate?.targetDirectoryPath ?? "/tmp"
    let engine = HealthsplitterEngine()
    do {
      try engine.splitFile(filename, outputDirectory: output, threshold: Int64(threshold), progress: self)
    } catch {
      delegate?.parsingFailed(error: error)
      return
    }
    delegate?.parsingDidComplete()
  }

  func started() {
    delegate?.parsingStarted()
  }

  func updated(_ part: Int64, current: Int64, total: Int64) {
    delegate?.chunkUpdate(part: Int(part), current: Int(current), total: Int(total))
  }

  func saving(_ part: Int64) {
    delegate?.savingChunk(part: Int(part))
  }

  func chunkCompleted(_ part: Int64) {
    delegate?.chunkCompleted(part: Int(part))
  }
}
