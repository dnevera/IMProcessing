//
//  IMPRandomDither.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 27.01.16.
//  Copyright © 2016 Dehancer.photo. All rights reserved.
//

import Foundation
import Metal

public class IMPDitheringFilter:IMPFilter,IMPAdjustmentProtocol{
    
    public var ditheringLut:[[UInt8]] {
        get {
            fatalError("IMPDitheringFilter: ditheringLut must be implemented...")
        }
    }
    
    public static let defaultAdjustment = IMPAdjustment(
        blending: IMPBlending(mode: NORMAL, opacity: 1))
    
    public var adjustment:IMPAdjustment!{
        didSet{
            updateDitheringLut(&ditherLut)
            self.updateBuffer(&adjustmentBuffer, context:context, adjustment:&adjustment, size:sizeofValue(adjustment))
            self.dirty = true
        }
    }
    
    public var adjustmentBuffer:MTLBuffer?
    public var kernel:IMPFunction!
    
    public required init(context: IMPContext) {
        super.init(context: context)
        kernel = IMPFunction(context: self.context, name: "kernel_dithering")
        self.addFunction(kernel)
        timerBuffer = context.device.newBufferWithLength(sizeof(Float), options: .CPUCacheModeDefaultCache)
        defer{
            self.adjustment = IMPDitheringFilter.defaultAdjustment
        }
    }
    
    var timerBuffer:MTLBuffer!
    
    public override func configure(function: IMPFunction, command: MTLComputeCommandEncoder) {
        if kernel == function {
            command.setTexture(ditherLut, atIndex: 2)
            command.setBuffer(adjustmentBuffer, offset: 0, atIndex: 0)
        }
    }
    
    
    var ditherLut:MTLTexture?
    func updateDitheringLut(inout lut:MTLTexture?){
        
        if ditheringLut.count > 256 {
            fatalError("IMPDitheringFilter.ditheringLut length must be less then 256...")
        }
        
        if let dl = lut {
            dl.update(ditheringLut)
        }
        else {
            lut = context.device.texture2D(ditheringLut)
        }
    }
}

public class IMPBayerDitheringFilter:IMPDitheringFilter{
    override public var ditheringLut:[[UInt8]] {
        get {
            //
            // https://en.wikipedia.org/wiki/Ordered_dithering
            // http://www.efg2.com/Lab/Library/ImageProcessing/DHALF.TXT
            //
            return [
                [0,  32,  8, 40,  2, 34, 10, 42],  /* 8x8 Bayer ordered dithering  */
                [48, 16, 56, 24, 50, 18, 58, 26],  /* pattern.  Each input pixel   */
                [12, 44,  4, 36, 14, 46,  6, 38],  /* is scaled to the 0..63 range */
                [60, 28, 52, 20, 62, 30, 54, 22],  /* before looking in this table */
                [3,  35, 11, 43,  1, 33,  9, 41],  /* to determine the action.     */
                [51, 19, 59, 27, 49, 17, 57, 25],
                [15, 47,  7, 39, 13, 45,  5, 37],
                [63, 31, 55, 23, 61, 29, 53, 21]
            ]
        }
    }
}

public class IMPRandomDitheringFilter:IMPDitheringFilter{
    override public var ditheringLut:[[UInt8]] {
        get {
            var data = [[UInt8]](count: 8, repeatedValue: [UInt8](count: 8, repeatedValue: 0))
            for i in 0 ..< data.count {
                SecRandomCopyBytes(kSecRandomDefault, data[i].count, UnsafeMutablePointer<UInt8>(data[i]))
                for j in 0 ..< data[i].count {
                    data[i][j] = data[i][j]/4
                }
            }
            return data
        }
    }
}
