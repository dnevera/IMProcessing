//
//  IMPPhotoPlateFilter.swift
//  IMProcessing
//
//  Created by denis svinarchuk on 20.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//

import Metal

/// Photo Plate Node is a Cube Node with virtual depth == 0
public class IMPPlateNode: IMPRenderNode {
    
    /// Cropping the plate region
    public var region = IMPRegion() {
        didSet{
            if
                region.left != oldValue.left ||
                    region.right != oldValue.right ||
                    region.top != oldValue.top ||
                    region.bottom != oldValue.bottom
            {
                vertices = IMPPlate(aspect: self.aspect, region: self.region)
            }
        }
    }
    
    var resetAspect:Bool = true
    
    override public var aspect:Float {
        didSet{
            if super.aspect != oldValue || resetAspect {
                super.aspect = aspect
                resetAspect = false
                vertices = IMPPlate(aspect: aspect, region: self.region)
            }
        }
    }
    
    public init(context: IMPContext, aspectRatio:Float, region:IMPRegion = IMPRegion()){
        super.init(context: context, vertices: IMPPlate(aspect: aspectRatio, region: self.region))
    }
}

/// Photo plate transoration filter
public class IMPPhotoPlateFilter: IMPFilter {

    public var backgroundColor:IMPColor {
        get {
            return plate.backgroundColor
        }
        set {
            plate.backgroundColor = newValue
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
                                        
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                switch provider.orientation {
                case .Left, .Right, .LeftMirrored, .RightMirrored:
                    self.plate.aspect = self.keepAspectRatio ? height/width : 1
                default:
                    self.plate.aspect = self.keepAspectRatio ? width/height : 1
                }
                                                
                self.plate.render(commandBuffer, pipelineState: self.graphics.pipeline!, source: source, destination: provider)
            }
        }
        return provider
    }
    
    ///  Rotate plate on angle in radians arround axis
    ///
    ///  - parameter vector: angle in radians for x,y,z axis
    public func rotate(vector:float3){
        plate.angle = vector
        dirty = true
    }

    ///  Scale plate
    ///
    ///  - parameter vector: x,y,z scale factor
    public func scale(vector:float3){
        plate.scale = vector
        dirty = true
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
    public func move(vector:float2){
        plate.transition = vector
        dirty = true
    }
    
    ///  Cut the plate with crop region
    ///
    ///  - parameter region: crop region
    public func crop(region:IMPRegion){
        plate.region = region
        dirty = true
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
    
    public var region:IMPRegion {
        return plate.region
    }
        
    public final func addMatrixModelObserver(model observer:IMPRenderNode.MatrixModelHandler){
        plate.addMatrixModelObserver(model: observer)
    }
    
    lazy var plate:Plate = {
        return Plate(context: self.context, aspectRatio:4/3)
    }()
    
    
    // Plate is a cube with virtual depth == 0
    class Plate: IMPPlateNode {}
}