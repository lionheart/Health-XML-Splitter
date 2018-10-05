//
//  ViewController.swift
//  Health Data Importer XML Splitter
//
//  Created by Dan Loewenherz on 9/22/18.
//  Copyright © 2018 Lionheart Software LLC. All rights reserved.
//

import Cocoa
import SSZipArchive

final class ViewController: NSViewController, NSDraggingDestination {
    enum Status: Equatable {
        case waiting
        case dragging(valid: Bool)
        case unzipping
        case splitting(Int, Int, Int)
        case saving(Int)
        case complete
        
        static func ==(lhs: Status, rhs: Status) -> Bool {
            switch (lhs, rhs) {
            case (.waiting, .waiting): return true
            case (.dragging, .dragging): return true
            case (.unzipping, .unzipping): return true
            case (.splitting, .splitting): return true
            case (.saving, .saving): return true
            case (.complete, .complete): return true
            default: return false
            }
        }
    }

    var fileName: String?
    var directoryPath: String?

    var status = Status.waiting {
        didSet {
            DispatchQueue.main.async {
                switch self.status {
                case .waiting:
                    self.inboxImageView.isHidden = false
                    self.progressIndicator.isHidden = true
                    self.horizontalProgressIndicator.isHidden = true
                    self.imageView.isHidden = false
                    self.label.isHidden = true
                    self.mainLabel.isHidden = false
                    self.inboxImageView.image = NSImage(named: "Inbox Light")
                    self.view.layer?.backgroundColor = NSColor.clear.cgColor
                    self.mainLabel.stringValue = "Drop Health Export Here"
                    
                case .dragging(let valid):
                    self.inboxImageView.isHidden = false
                    self.progressIndicator.isHidden = true
                    self.horizontalProgressIndicator.isHidden = true
                    self.imageView.isHidden = false
                    self.label.isHidden = true
                    self.mainLabel.isHidden = false

                    if valid {
                        self.mainLabel.stringValue = "Drop it!"
                        
                        self.inboxImageView.image = NSImage(named: "Inbox")
                        self.imageView.isHidden = false
                        self.view.layer?.backgroundColor = NSColor.white.cgColor
                    } else {
                        self.mainLabel.stringValue = "Please provide a export.xml or export.zip file to continue."

                        self.inboxImageView.image = NSImage(named: "Warning")
                        self.imageView.isHidden = true
                        let color = NSColor(calibratedRed: 1, green: 0, blue: 0, alpha: 0.2)
                        self.view.layer?.backgroundColor = color.cgColor
                    }
                    
                case .unzipping:
                    self.inboxImageView.isHidden = true
                    self.progressIndicator.isHidden = false
                    self.progressIndicator.startAnimation(nil)
                    self.imageView.isHidden = true
                    self.label.stringValue = "Unzipping..."
                    self.label.isHidden = false
                    self.mainLabel.isHidden = true
                    
                case .splitting(let chunk, let current, let maximum):
                    if self.status != oldValue {
                        self.inboxImageView.isHidden = true
                        self.progressIndicator.isHidden = true
                        self.horizontalProgressIndicator.isHidden = false
                        self.horizontalProgressIndicator.startAnimation(nil)
                        self.label.stringValue = "Splitting chunk \(chunk + 1)..."
                        self.label.isHidden = false
                        self.mainLabel.isHidden = true
                        self.horizontalProgressIndicator.isIndeterminate = false
                    } else {
                        self.horizontalProgressIndicator.maxValue = Double(maximum)
                        self.horizontalProgressIndicator.doubleValue = Double(current)
                    }

                case .saving(let current):
                    self.inboxImageView.isHidden = true
                    self.progressIndicator.isHidden = true
                    self.horizontalProgressIndicator.isHidden = false
                    self.horizontalProgressIndicator.startAnimation(nil)
                    self.label.stringValue = "Saving chunk \(current + 1)..."
                    self.label.isHidden = false
                    self.mainLabel.isHidden = true
                    self.horizontalProgressIndicator.isIndeterminate = true
                    
                case .complete:
                    self.inboxImageView.isHidden = false
                    self.progressIndicator.isHidden = true
                    self.horizontalProgressIndicator.isHidden = true
                    self.imageView.isHidden = false
                    self.label.isHidden = true
                    self.mainLabel.isHidden = false
                    self.label.stringValue = "All Done!"
                }
            }
        }
    }

    @IBOutlet weak var inboxImageView: NSImageView!
    @IBOutlet weak var mainLabel: NSTextField!
    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var dragTargetView: DragTargetView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var horizontalProgressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        label.stringValue = ""
    }
    
    func displayInvalidFileTypeAlert() {
        let alert = NSAlert()
        alert.addButton(withTitle: "OK")
        alert.messageText = "Please provide a valid Health.app XML export in either ZIP or XML format to use this utility."
        alert.alertStyle = .informational
        
        if let window = view.window {
            alert.beginSheetModal(for: window) { response in
                self.status = .waiting
            }
        }
    }

    func handleURL(url: URL) {
        guard let fileType = url.processableFileType else {
            return
        }

        displayOpenPanel(canChooseFiles: false) { directoryURL in
            self.directoryPath = directoryURL?.path
        
            switch fileType {
            case .xml: self.processXMLDocument(url: url)
            case .zip: self.processZipFile(url: url)
            }
        }
    }
}

extension ViewController: DragViewDelegate {
    func dragDidStart() {
        status = .dragging(valid: true)
    }
    
    func dragDidEnd() {
        status = .waiting
    }

    func invalidFileTypeDragged() {
        status = .dragging(valid: false)
    }
    
    func invalidFileTypeDropped() {
        status = .waiting
    }
    
    var busy: Bool {
        return ![Status.waiting, Status.complete].contains(status)
    }
    
    func dragView(didDragFileWith url: URL) {
        handleURL(url: url)
    }
    
    func processZipFile(url: URL) {
        fileName = url.lastPathComponent
        status = .unzipping
        
        let zip = url.path
        
        guard let directoryPath = directoryPath else {
            // TODO!!
            return
        }

        let directoryUrl = URL(fileURLWithPath: directoryPath)
        DispatchQueue.global(qos: .default).async {
            let manager = FileManager.default
            do {
                let urls = try manager.contentsOfDirectory(at: directoryUrl, includingPropertiesForKeys: nil, options: [])
                for url in urls {
                    try manager.removeItem(at: url)
                }
            } catch {
                
            }

            SSZipArchive.unzipFile(atPath: zip, toDestination: directoryPath, progressHandler: nil) { path, succeeded, error in
                var exportItem: URL?
                let enumerator1 = manager.enumerator(at: directoryUrl.appendingPathComponent("apple_health_export"), includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: nil)
                let enumerator2 = manager.enumerator(at: directoryUrl, includingPropertiesForKeys: [.isDirectoryKey], options: [], errorHandler: nil)
                outer: for enumerator in [enumerator1, enumerator2] {
                    while let item = enumerator?.nextObject() as? URL {
                        let resourceValues = try? item.resourceValues(forKeys: [.isDirectoryKey])
                        guard let isDirectory = resourceValues?.isDirectory, !isDirectory else {
                            continue
                        }
                        
                        let component = item.lastPathComponent
                        
                        // Skip __MACOSX, .DS_Store, and export_cda.xml
                        if component.contains("_") {
                            continue
                        }
                        
                        exportItem = item
                        break outer
                    }
                }
                
                guard let item = exportItem else {
                    self.status = .waiting
                    DispatchQueue.main.async {
                        self.displayInvalidFileTypeAlert()
                    }
                    
                    return
                }
                
                self.processXMLDocument(url: item)
            }
        }
    }
    
    func processXMLDocument(url: URL) {
        DispatchQueue.global(qos: .default).async {
            let parser = Parser(filename: url.path)
            parser.delegate = self
            parser.start()
        }
    }
    
    func dragViewDidTouchUpInside() {
        displayOpenPanel(canChooseFiles: true) { url in
            guard let url = url else {
                return
            }
            
            self.handleURL(url: url)
        }
    }
    
    func displayOpenPanel(canChooseFiles: Bool, _ callback: @escaping (URL?) -> ()) {
        let panel = NSOpenPanel()
        
        if !canChooseFiles {
            panel.message = "Select the folder in which you'd like the generated files to be placed."
        }
        
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = canChooseFiles
        panel.canChooseDirectories = !canChooseFiles
        
        guard let window = view.window else {
            callback(nil)
            return
        }
        
        panel.beginSheetModal(for: window) { response in
            guard let url = panel.url, response.rawValue == 1 else {
                callback(nil)
                return
            }
            
            callback(url)
        }
    }
}

extension ViewController: ParserDelegate {
    func savingChunk(part: Int) {
        status = .saving(part)
    }
    
    func parsingFailed(error: Error) {
        status = .waiting
        print(error)
    }
    
    func chunkUpdate(part: Int, current: Int, total: Int) {
        status = .splitting(part, current, total)
    }

    func parsingStarted() {
        status = .splitting(0, 0, 1)
    }
    
    func parsingDidComplete() {
        status = .complete
        print("ended")

        guard let directory = directoryPath,
            let scriptUrl = Bundle.main.url(forResource: "zipItUp", withExtension: "sh") else {
                return
        }
        
        let directoryUrl = URL(fileURLWithPath: directory)
        let newFileUrl = directoryUrl.appendingPathComponent("zipItUp.sh")
        
        try? FileManager.default.removeItem(at: newFileUrl)

        do {
            try FileManager.default.copyItem(at: scriptUrl, to: newFileUrl)
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/bash")
            process.arguments = [newFileUrl.path]
            process.currentDirectoryURL = directoryUrl
            try process.run()
            
            status = .waiting
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                alert.messageText = "Your health export has been split successfully! Click 'OK' to open the split files in Finder."
                alert.alertStyle = .informational
                
                if let window = self.view.window {
                    alert.beginSheetModal(for: window) { response in
                        self.status = .waiting

                        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [directory])
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.addButton(withTitle: "OK")
                alert.messageText = "An error was encountered while completing the splitting process. Please try again."
                alert.alertStyle = .critical
                
                if let window = self.view.window {
                    alert.beginSheetModal(for: window) { response in
                        self.status = .waiting
                    }
                }
            }
        }
    }
    
    func chunkCompleted(part: Int) {
    }
    
    var targetDirectoryPath: String? {
        return directoryPath
    }
}
