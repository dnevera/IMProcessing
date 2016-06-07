//
//  IMPTransformFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

/// Transform filter can be imagine as a photo plate tool 
typealias IMPPhotoPlateFilter = IMPTransformFilter

/// Image textured on the model of Rendering Node is a Cube Node with virtual depth == 0
public class IMPPhotoPlateNode: IMPRenderNode {
    
    /// Cropping the plate region
    public var region = IMPRegion() {
        didSet{
            if
                region.left != oldValue.left ||
                    region.right != oldValue.right ||
                    region.top != oldValue.top ||
                    region.bottom != oldValue.bottom
            {
                vertices = IMPPhotoPlate(aspect: aspect, region: region)
            }
        }
    }
    
    var resetAspect:Bool = true
    
    override public var aspect:Float {
        didSet{
            if super.aspect != oldValue || resetAspect {
                super.aspect = aspect
                resetAspect = false
                vertices = IMPPhotoPlate(aspect: aspect, region: self.region)
            }
        }
    }
    
    public init(context: IMPContext, aspectRatio:Float, region:IMPRegion = IMPRegion()){
        super.init(context: context, vertices: IMPPhotoPlate(aspect: aspectRatio, region: self.region))
    }
}

/// Photo plate transformation filter
public class IMPTransformFilter: IMPFilter {

    public var backgroundColor:IMPColor {
        get {
            return plate.backgroundColor
        }
        set {
            plate.backgroundColor = newValue
        }
    }

    public override var source: IMPImageProvider? {
        didSet {
            updatePlateAspect(region)
        }
    }
    
    public var keepAspectRatio = true
    
    public var graphics:IMPGraphics!

    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_transformation", fragment: "fragment_transformation")
    }    
    
    public var viewPortSize: MTLSize? {
        didSet{
            if let s = source {
                plate.aspect = self.keepAspectRatio ? viewPortSize!.width.float/viewPortSize!.height.float : 1
                dirty = true
            }
        }
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        self.context.execute{ (commandBuffer) -> Void in

            if let inputTexture = source.texture {
                
                var width  = inputTexture.width.float
                var height = inputTexture.height.float

                if let s = self.viewPortSize {
                    width = s.width.float
                    height = s.height.float
                }
                
                width  -= width  * (self.plate.region.left   + self.plate.region.right);
                height -= height * (self.plate.region.bottom + self.plate.region.top);                            
                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        inputTexture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                                        
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                        
                self.plate.render(commandBuffer, pipelineState: self.graphics.pipeline!, source: source, destination: provider)
            }
        }
        return  provider //super.main(source: provider, destination: provider)
    }
    
    public var aspect:Float {
        return plate.aspect
    }
    
    public var model:IMPTransfromModel {
            return plate.model
    }

    public var identityModel:IMPTransfromModel {
        return plate.identityModel
    }
    
    
    ///  Rotate plate on angle in radians arround axis
    ///
    ///  - parameter vector: angle in radians for x,y,z axis
    public var angle:float3 {
        set {
            plate.angle = newValue
            dirty = true
        }
        get {
            return plate.angle
        }
    }

    ///  Scale plate
    ///
    ///  - parameter vector: x,y,z scale factor
    public var scale:float3 {
        set {
            plate.scale = newValue
            dirty = true
        }
        get {
            return plate.scale
        }
    }
    
    ///  Scale plate with global 2D factor
    ///
    ///  - parameter factor:
    public func scale(factor f:Float){
        plate.scale = float3(f,f,1)
        dirty = true
    }
    
    
    ///  Move plate with vector
    ///
    ///  - parameter vector: vector
    public var translation: float2 {
        set{
            plate.translation = newValue
            dirty = true
        }
        get {
            return plate.translation
        }
    }
    
    ///  Cut the plate with crop region
    ///
    ///  - parameter region: crop region
    public var region:IMPRegion {
        set {
            guard (source != nil) else {return}
            updatePlateAspect(newValue)
            plate.region = newValue
            dirty = true
        }
        get {
            return plate.region
        }
    }
    
    /// Set/get reflection
    public var reflection:(horizontal:IMPRenderNode.ReflectMode, vertical:IMPRenderNode.ReflectMode) {
        set{
            plate.reflectMode = newValue
            dirty = true
        }
        get{
            return plate.reflectMode
        }
    }
        
    lazy var plate:PhotoPlate = {
        return PhotoPlate(context: self.context, aspectRatio:4/3)
    }()
    
    func updatePlateAspect(region:IMPRegion)  {
        if let s = source {
            let width  = s.width - s.width  * (region.left   + region.right);
            let height = s.height - s.height * (region.bottom + region.top);
            plate.aspect = self.keepAspectRatio ? width/height : 1
        }
    }
    
    // Plate is a cube with virtual depth == 0
    class PhotoPlate: IMPPhotoPlateNode {}
}

