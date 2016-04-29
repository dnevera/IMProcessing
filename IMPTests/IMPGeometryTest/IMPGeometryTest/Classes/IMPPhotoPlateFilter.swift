//
//  IMPPhotoPlateFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import IMProcessing
import Metal

public class IMPPhotoPlateFilter: IMPFilter {

    public var keepAspectRatio = true
    
    public var graphics:IMPGraphics!

    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_transformation", fragment: "fragment_transformation")
    }

    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        self.context.execute { (commandBuffer) -> Void in

            if let inputTexture = source.texture {
                
                var width  = inputTexture.width.float
                var height = inputTexture.height.float
                
                width  -= width  * (self.plate.region.left   + self.plate.region.right);
                height -= height * (self.plate.region.bottom + self.plate.region.top);

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
    
    public func rotate(vector:float3){
        plate.angle = vector
        dirty = true
    }

    public func scale(vector:float3){
        plate.scale = vector
        dirty = true
    }
    
    public func move(vector:float2){
        plate.transition = vector
        dirty = true
    }
    
    public func crop(region:IMPRegion){
        plate.region = region
        dirty = true
    }
    
    public var region:IMPRegion {
        return plate.region
    }
        
    public final func addMatrixModelObserver(model observer:IMPRenderNode.MatrixModelHandler){
        plate.addMatrixModelObserver(model: observer)
    }

    lazy var plate:Plate = {
        return Plate(context: self.context, aspectRatio:self.aspectRatio)
    }()
    
    
    var aspectRatio:Float = 4/3 {
        didSet {
            if oldValue != aspectRatio{
                plate.aspectRatio = aspectRatio
                dirty = true
            }
        }
    }
    
    // Plate is a cube with virtual depth == 0
    class Plate: IMPPlateNode {}
}