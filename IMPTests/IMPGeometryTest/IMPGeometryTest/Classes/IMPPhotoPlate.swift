//
//  IMPPhotoPlate.swift
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

public class IMPPhotoPlate: IMPFilter {

    public var keepAspectRatio = true
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        self.context.execute { (commandBuffer) -> Void in

            if let inputTexture = source.texture {
                
                var width  = inputTexture.width.float
                var height = inputTexture.height.float
                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        inputTexture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    if provider.texture != nil {
                        provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
                    }
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                self.aspectRatio = self.keepAspectRatio ? width/height : 1
                
                
                self.plate.render(commandBuffer, pipelineState: self.graphics.pipeline!, source: source, destination: provider)
            }
        }
        return provider
    }
    
    public var graphics:IMPGraphics!

    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_transformation", fragment: "fragment_transformation")
    }
    
    public func rotate(vector:float3){
        plate.angle = vector
    }
    
    public func translate(vector:float3){
        plate.translation=vector
    }
    
    public func scale(vector:float3){
        plate.scale = vector
    }
    
    public func move(vector:float2){
        plate.transition = vector
    }
    
    lazy var plate:Plate = {
        return Plate(context: self.context, aspectRatio:self.aspectRatio)
    }()
    
    
    var aspectRatio:Float = 4/3 {
        didSet {
            if oldValue != aspectRatio{
                plate.aspectRatio = aspectRatio
            }
        }
    }
    
    // Plate is a cube with virtual depth == 0
    class Plate: IMPNode {
        
        static func  newAspect (ascpectRatio a:Float) -> [IMPVertex] {
            // Front
            let A = IMPVertex(x: -1.0*a, y:   1.0, z:   0.1, tx: 0, ty: 0) // left-top
            let B = IMPVertex(x: -1.0*a, y:  -1.0, z:   0.1, tx: 0, ty: 1) // left-bottom
            let C = IMPVertex(x:  1.0*a, y:  -1.0, z:   0.1, tx: 1, ty: 1) // right-bottom
            let D = IMPVertex(x:  1.0*a, y:   1.0, z:   0.1, tx: 1, ty: 0) // right-top
            
            // Back
            let Q = IMPVertex(x: -1.0*a, y:   1.0, z:  -0.1, tx: 0, ty: 0) // virtual depth = 0
            let R = IMPVertex(x:  1.0*a, y:   1.0, z:  -0.1, tx: 0, ty: 0)
            let S = IMPVertex(x: -1.0*a, y:  -1.0, z:  -0.1, tx: 0, ty: 0)
            let T = IMPVertex(x:  1.0*a, y:  -1.0, z:  -0.1, tx: 0, ty: 0)
            
            return [
                A,B,C ,A,C,D,   // The main front plate. Here we put image.
                R,T,S ,Q,R,S,   // Back
                
                Q,S,B ,Q,B,A,   //Left
                D,C,T ,D,T,R,   //Right
                
                Q,A,D ,Q,D,R,   //Top
                B,S,T ,B,T,C    //Bot
            ]
        }
        
        var aspectRatio:Float! = 4/3 {
            didSet{
                if oldValue != aspectRatio {
                    vertices = Plate.newAspect(ascpectRatio: aspectRatio)
                }
            }
        }
        
        init(context: IMPContext, aspectRatio:Float){
            super.init(context: context, vertices: Plate.newAspect(ascpectRatio: aspectRatio))
        }
    }
}