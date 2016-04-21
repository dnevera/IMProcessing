//
//  IMPRender.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing

#if os(iOS)
    import UIKit
#else
    import Cocoa
#endif
import Metal

public class IMPRender: IMPFilter {

    public override func main(provider provider: IMPImageProvider) -> IMPImageProvider {
        return super.main(provider: provider)
    }
    
}