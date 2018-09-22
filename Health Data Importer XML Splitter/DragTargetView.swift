//
//  DragTargetView.swift
//  Health Data Importer XML Splitter
//
//  Created by Dan Loewenherz on 9/22/18.
//  Copyright © 2018 Lionheart Software LLC. All rights reserved.
//

import Cocoa

@objc
protocol DragViewDelegate {
    func dragView(didDragFileWith url: URL)
    func dragViewDidTouchUpInside()
}

class DragTargetView: NSView {
    @IBOutlet var delegate: DragViewDelegate?
    
    let acceptedFileExtensions: Set<String> = ["zip", "xml"]
    var isDroppedFileOk = false
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        
        registerForDraggedTypes([.fileURL])
    }
    
    override func mouseDown(with event: NSEvent) {
        delegate?.dragViewDidTouchUpInside()
    }
    
    func checkExtensionForDrag(_ drag: NSDraggingInfo) -> Bool {
        guard let urlString = drag.draggedFileURL?.absoluteString,
            let last = urlString.split(separator: ".").last else {
            return false
        }

        return acceptedFileExtensions.contains(String(last))
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDroppedFileOk = checkExtensionForDrag(sender)
        return []
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        guard isDroppedFileOk else {
            return []
        }

        return .generic
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        guard let url = sender.draggedFileURL else {
            return false
        }
        
        delegate?.dragView(didDragFileWith: url)
        return true
    }
}

extension NSDraggingInfo {
    var draggedFileURL: URL? {
        guard let data = draggingPasteboard.data(forType: .fileURL),
            let string = String(data: data, encoding: .utf8),
            let url = URL(string: string) else {
                return nil
        }

        return url
    }
}
