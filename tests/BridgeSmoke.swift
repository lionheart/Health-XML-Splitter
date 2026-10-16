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

    // A second run must return an owned error across the ABI without reporting
    // completion or overwriting the first run's files.
    let failedDelegate = Delegate(directory: output)
    parser.delegate = failedDelegate
    parser.start()
    precondition(failedDelegate.failure != nil && !failedDelegate.completed)
    let preserved = try String(contentsOf: output.appendingPathComponent("export0.xml"), encoding: .utf8)
    precondition(preserved == xml)
    print("Swift → C → Go bridge passed")
  }
}
