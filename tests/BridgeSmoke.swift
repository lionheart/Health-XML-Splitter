import Foundation

private final class Delegate: ParserDelegate {
  let targetDirectoryPath: String?
  var started = false
  var completed = false
  var failure: Error?
  var chunks: [Int] = []
  var updates = 0

  init(directory: URL) { targetDirectoryPath = directory.path }
  func savingChunk(part: Int) {}
  func parsingStarted() { started = true }
  func chunkUpdate(part: Int, current: Int, total: Int) { updates += 1 }
  func chunkCompleted(part: Int) { chunks.append(part) }
  func parsingDidComplete() { completed = true }
  func parsingFailed(error: Error) { failure = error }
}

@main
struct BridgeSmoke {
  static func main() throws {
    let manager = FileManager.default
    let directory = manager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try manager.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? manager.removeItem(at: directory) }
    let input = directory.appendingPathComponent("health é.xml")
    try "<HealthData><ExportDate value=\"today\"/><Record value=\"é 🫀\"/><Record/></HealthData>"
      .write(to: input, atomically: true, encoding: .utf8)

    let output = directory.appendingPathComponent("output é")
    let delegate = Delegate(directory: output)
    let parser = Parser(filename: input.path, threshold: 1)
    parser.delegate = delegate
    parser.start()
    precondition(delegate.started && delegate.completed && delegate.failure == nil)
    precondition(delegate.chunks == [0, 1] && delegate.updates == 3)
    let xml = try String(contentsOf: output.appendingPathComponent("export0.xml"), encoding: .utf8)
    precondition(xml.contains("é 🫀"))

    // A second run must throw a generated NSError through Swift without reporting
    // completion or overwriting the first run's files.
    let failedDelegate = Delegate(directory: output)
    parser.delegate = failedDelegate
    parser.start()
    precondition(failedDelegate.failure != nil && !failedDelegate.completed)
    precondition(failedDelegate.failure!.localizedDescription.contains("create chunk"))
    let preserved = try String(
      contentsOf: output.appendingPathComponent("export0.xml"), encoding: .utf8)
    precondition(preserved == xml)

    // Validation errors must also be delivered as Swift errors, before any
    // output is created or progress callbacks are emitted.
    let invalidOutput = directory.appendingPathComponent("invalid threshold")
    let invalidDelegate = Delegate(directory: invalidOutput)
    let invalidParser = Parser(filename: input.path, threshold: 0)
    invalidParser.delegate = invalidDelegate
    invalidParser.start()
    precondition(invalidDelegate.failure?.localizedDescription.contains("threshold") == true)
    precondition(!invalidDelegate.started && !invalidDelegate.completed)
    precondition(!manager.fileExists(atPath: invalidOutput.path))

    let malformed = directory.appendingPathComponent("malformed.xml")
    try "<HealthData><Record>".write(to: malformed, atomically: true, encoding: .utf8)
    let malformedOutput = directory.appendingPathComponent("malformed output")
    let malformedDelegate = Delegate(directory: malformedOutput)
    let malformedParser = Parser(filename: malformed.path)
    malformedParser.delegate = malformedDelegate
    malformedParser.start()
    precondition(!malformedDelegate.completed)
    precondition(malformedDelegate.failure?.localizedDescription.contains("parse xml") == true)
    let malformedFiles = try manager.contentsOfDirectory(atPath: malformedOutput.path)
    precondition(malformedFiles.isEmpty)
    print("Swift → gomobile → Go bridge passed")
  }
}
