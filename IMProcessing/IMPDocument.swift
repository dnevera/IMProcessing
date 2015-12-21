//
//  IMPDocument.swift
//  ImageMetalling-07
//
//  Created by denis svinarchuk on 15.12.15.
//  Copyright © 2015 IMetalling. All rights reserved.
//

import Cocoa

enum IMPDocumentType{
    case Image
    case LUT
}

typealias IMPDocumentObserver = ((file:String, type:IMPDocumentType) -> Void)

class IMPDocument: NSObject {
    
    private override init() {}
    private var didUpdateDocumnetHandlers = [IMPDocumentObserver]()
    
    static let sharedInstance = IMPDocument()
    
    var currentFile:String?{
        didSet{
            for o in self.didUpdateDocumnetHandlers{
                o(file: currentFile!, type: .Image)
            }
        }
    }
    
    var currentLutFile:String?{
        didSet{
            for o in self.didUpdateDocumnetHandlers{
                o(file: currentLutFile!, type: .LUT)
            }
        }
    }
    
    func addDocumentObserver(observer:IMPDocumentObserver){
        didUpdateDocumnetHandlers.append(observer)
    }
    
    
}

