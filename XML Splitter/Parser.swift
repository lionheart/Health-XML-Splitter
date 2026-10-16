// Copyright © 2017 Lionheart Software LLC. All rights reserved.
// Swift adapter for the platform-independent Go splitting engine.
import Foundation

protocol ParserDelegate {
  var targetDirectoryPath: String? { get }

  func savingChunk(part: Int)
  func parsingStarted()
  func chunkUpdate(part: Int, current: Int, total: Int)
  func chunkCompleted(part: Int)
  func parsingDidComplete()
  func parsingFailed(error: Error)
}

private struct SplitterError: LocalizedError {
  let message: String
  var errorDescription: String? { return message }
}

private func splitterProgress(
  _ context: UnsafeMutableRawPointer?, _ phase: Int32,
  _ part: Int64, _ current: Int64, _ total: Int64
) {
  guard let context = context else { return }
  let parser = Unmanaged<Parser>.fromOpaque(context).takeUnretainedValue()
  switch phase {
  case Int32(SplitterStarted): parser.delegate?.parsingStarted()
  case Int32(SplitterUpdated):
    parser.delegate?.chunkUpdate(part: Int(part), current: Int(current), total: Int(total))
  case Int32(SplitterSaving): parser.delegate?.savingChunk(part: Int(part))
  case Int32(SplitterChunkCompleted): parser.delegate?.chunkCompleted(part: Int(part))
  default: break
  }
}

final class Parser {
  private let filename: String
  private let threshold: Int
  var delegate: ParserDelegate?

  init(filename: String, threshold: Int = 500000) {
    self.filename = filename
    self.threshold = threshold
  }

  // Synchronous, as before. The AppKit controller calls this on a worker queue.
  func start() {
    let output = delegate?.targetDirectoryPath ?? "/tmp"
    let context = Unmanaged.passUnretained(self).toOpaque()
    let error = filename.withCString { input in
      output.withCString { destination in
        SplitterSplitXML(
          UnsafeMutablePointer(mutating: input), UnsafeMutablePointer(mutating: destination),
          Int64(threshold), splitterProgress, context)
      }
    }
    if let error = error {
      let message = String(cString: error)
      SplitterFreeString(error)
      delegate?.parsingFailed(error: SplitterError(message: message))
      return
    }
    delegate?.parsingDidComplete()
  }
}
