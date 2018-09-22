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
    enum Status {
        case waiting
        case unzipping
        case splitting
    }

    var fileName: String?
    var directoryPath: String?
    var status = Status.waiting {
        didSet {
            DispatchQueue.main.async {
                switch self.status {
                case .waiting:
                    self.progressIndicator.isHidden = true
                    self.horizontalProgressIndicator.isHidden = true
                    self.imageView.isHidden = false
                    self.label.stringValue = ""
                    
                case .unzipping:
                    self.progressIndicator.isHidden = false
                    self.progressIndicator.startAnimation(nil)
                    self.imageView.isHidden = true
                    self.label.stringValue = "Unzipping..."
                    
                case .splitting:
                    self.progressIndicator.isHidden = true
                    self.horizontalProgressIndicator.isHidden = false
                    self.horizontalProgressIndicator.startAnimation(nil)
                    self.label.stringValue = "Splitting..."
                }
            }
        }
    }

    @IBOutlet weak var label: NSTextField!
    @IBOutlet weak var dragTargetView: DragTargetView!
    @IBOutlet weak var imageView: NSImageView!
    @IBOutlet weak var progressIndicator: NSProgressIndicator!
    @IBOutlet weak var horizontalProgressIndicator: NSProgressIndicator!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        label.stringValue = ""
    }
}

extension ViewController: DragViewDelegate {
    func dragView(didDragFileWith url: URL) {
        fileName = url.lastPathComponent
        status = .unzipping
        
        let zip = url.path
        let temp = NSTemporaryDirectory()
        directoryPath = temp
        
        DispatchQueue.global(qos: .default).async {
            SSZipArchive.unzipFile(atPath: zip, toDestination: temp, progressHandler: { entry, zipInfo, entryNumber, total in
                DispatchQueue.main.async {
                    self.progressIndicator.maxValue = Double(total)
                    self.progressIndicator.doubleValue = Double(entryNumber)
                }
            }) { path, succeeded, error in
                self.status = .splitting
                
                guard let url = URL(string: temp)?.appendingPathComponent("apple_health_export").appendingPathComponent("export.xml") else {
                    return
                }
                
                print(url.path)
                DispatchQueue.global(qos: .default).async {
                    let parser = Parser(filename: url.path)
                    parser.delegate = self
                    parser.start()
                }
                
                Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [temp])
            }
        }
        
//        let task = Process.launchedProcess(launchPath: "/usr/bin/unzip", arguments: ["-o", zip, "-d", temp])
//        NSWorkspace.shared.selectFile(temp, inFileViewerRootedAtPath: "")
    }
    
    func processXMLDocument(url: URL) {
        
    }
    
    func dragViewDidTouchUpInside() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        
//        panel.directoryURL = URL(fileURLWithPath: "file:///Users/dan/Downloads/", isDirectory: false)
        //        panel.directoryURL = URL(fileURLWithPath: "file:///Users/dan/Downloads/", isDirectory: true)
        //        let url = URL(fileURLWithPath: "file:///Users/dan/Documents/Minilogue%2017Sep2018.mnlglib")
        //        panel.urls = [url]
//        if panel.runModal() == .OK {
//            let fileName = panel.urls
//            print(fileName)
//        }
        
        guard let window = view.window else {
            return
        }
        
        panel.beginSheetModal(for: window) { response in
            
        }
    }
}

extension ViewController: ParserDelegate {
    func parsingFailed(error: Error) {
        status = .waiting
        print(error)
    }

    func parsingStarted() {
        status = .splitting
    }
    
    func parsingDidComplete() {
        status = .waiting
        print("ended")

//        Process.launchedProcess(launchPath: "/usr/bin/open", arguments: [temp])
    }
    
    func chunkCompleted(part: Int) {
    }
    
    var targetDirectoryPath: String? {
        return directoryPath
    }
}
