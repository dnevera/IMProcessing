//
//  IMPWarpPerspectiveFilter.swift
//  IMPGeometryTest
//
//  Created by denis svinarchuk on 29.04.16.
//  Copyright © 2016 ImageMetalling. All rights reserved.
//


import IMProcessing
import Metal

public class IMPWarpFilter: IMPFilter {
        
    public struct Quad {
        var left_bottom  = float2( -1, -1)
        var left_top     = float2( -1,  1)
        var right_bottom = float2(  1, -1)
        var right_top    = float2(  1,  1)
    }
    
    public var sourceQuad = Quad() {
        didSet{
            solver.source = sourceQuad
            dirty = true
        }
    }
    
    public var destinationQuad = Quad() {
        didSet{
            solver.destination = destinationQuad
            dirty = true
        }
    }
    
    public var graphics:IMPGraphics!
    
    required public init(context: IMPContext, vertex:String, fragment:String) {
        super.init(context: context)
        graphics = IMPGraphics(context: context, vertex: vertex, fragment: fragment)
    }
    
    convenience public required init(context: IMPContext) {
        self.init(context: context, vertex: "vertex_warpTransformation", fragment: "fragment_passthrough")
    }
    
    public override func main(source source:IMPImageProvider , destination provider: IMPImageProvider) -> IMPImageProvider {
        if let texture = source.texture{
            context.execute { (commandBuffer) in
                
                var width  = texture.width.float
                var height = texture.height.float
                                
                if width.int != provider.texture?.width || height.int != provider.texture?.height{
                    
                    let descriptor = MTLTextureDescriptor.texture2DDescriptorWithPixelFormat(
                        texture.pixelFormat,
                        width: width.int, height: height.int,
                        mipmapped: false)
                    
                    if provider.texture != nil {
                        provider.texture?.setPurgeableState(MTLPurgeableState.Empty)
                    }
                    
                    provider.texture = self.context.device.newTextureWithDescriptor(descriptor)
                }
                
                self.renderPassDescriptor.colorAttachments[0].texture = provider.texture
                self.renderPassDescriptor.colorAttachments[0].loadAction = .Clear
                self.renderPassDescriptor.colorAttachments[0].clearColor = MTLClearColor(red: 1, green: 1, blue: 1, alpha: 1)
                self.renderPassDescriptor.colorAttachments[0].storeAction = .Store
                
                let renderEncoder = commandBuffer.renderCommandEncoderWithDescriptor(self.renderPassDescriptor)
                                
                renderEncoder.setRenderPipelineState(self.graphics.pipeline!)
                
                renderEncoder.setVertexBuffer(self.vertexBuffer, offset: 0, atIndex: 0)
                renderEncoder.setVertexBuffer(self.matrixBuffer, offset: 0, atIndex: 1)
                
                renderEncoder.setFragmentTexture(source.texture, atIndex:0)
                
                renderEncoder.drawPrimitives(.Triangle, vertexStart: 0, vertexCount: self.vertices.count, instanceCount: self.vertices.count/3)
                renderEncoder.endEncoding()
            }
        }
        return provider
    }
    
    var renderPassDescriptor = MTLRenderPassDescriptor()
    
    var solver = IMPWarpSolver(source: Quad(), destination: Quad())
    
    lazy var _matrixBuffer:MTLBuffer = {
        return  self.context.device.newBufferWithLength(sizeofValue(self.solver.transformation), options: .CPUCacheModeDefaultCache)
    }()

    var matrixBuffer: MTLBuffer {
        get {
            var m = self.solver.transformation
            memcpy(_matrixBuffer.contents(), &m, _matrixBuffer.length)
            return _matrixBuffer
        }
    }
    
    lazy var vertexBuffer: MTLBuffer = {
        var vertexData = [Float]()
        for vertex in self.vertices{
            vertexData += vertex.raw
        }
        return self.context.device.newBufferWithBytes(vertexData, length: vertexData.count * sizeofValue(vertexData[0]), options: .CPUCacheModeDefaultCache)
    }()
    
    lazy var vertices:[IMPVertex] = {
        // Front
        let A = IMPVertex(x: -1, y:   1, z:  0, tx: 0, ty: 0) // left-top
        let B = IMPVertex(x: -1, y:  -1, z:  0, tx: 0, ty: 1) // left-bottom
        let C = IMPVertex(x:  1, y:  -1, z:  0, tx: 1, ty: 1)    // right-bottom
        let D = IMPVertex(x:  1, y:   1, z:  0, tx: 1, ty: 0)    // right-top
        return [
            A,B,C ,A,C,D,   // The main front plate. Here we put image.
        ]
    }()
            
    public class IMPWarpSolver {
        
        public var source = Quad() {
            didSet{            
                solve()
            }
        }
        
        public var destination = Quad(){
            didSet{
                solve()
            }
        }
        
        private var _transformation = float4x4()
        
        public var transformation:float4x4 {
            return _transformation
        }
        
        public init(source s: Quad, destination d:Quad){
            defer{
                source=s
                destination=d
            }
        }
        
        func solve(){
            
            var t = general2DProjection(x1s: source.left_bottom.x,
                                        y1s: source.left_bottom.y,
                                        x1d: destination.left_bottom.x,
                                        y1d: destination.left_bottom.y,
                                        x2s: source.left_top.x,
                                        y2s: source.left_top.y,
                                        x2d: destination.left_top.x,
                                        y2d: destination.left_top.y,
                                        x3s: source.right_bottom.x,
                                        y3s: source.right_bottom.y,
                                        x3d: destination.right_bottom.x,
                                        y3d: destination.right_bottom.y,
                                        x4s: source.right_top.x,
                                        y4s: source.right_top.y,
                                        x4d: destination.right_top.x,
                                        y4d: destination.right_top.y)
            
            for i in 0..<9 {
                t[i] =  t[i]/t[8]
            }
            
            let T = [
                [t[0], t[1], 0, t[2]],
                [t[3], t[4], 0, t[5]],
                [0   , 0   , 1, 0   ],
                [t[6], t[7], 0, t[8]]
            ];
            
            _transformation = float4x4(rows: T)
            
        }
        
        //
        // http://jsfiddle.net/dFrHS/1/
        //
        func adj(m m:[Float]) -> [Float] { // Compute the adjugate of m
            return [
                m[4]*m[8]-m[5]*m[7], m[2]*m[7]-m[1]*m[8], m[1]*m[5]-m[2]*m[4],
                m[5]*m[6]-m[3]*m[8], m[0]*m[8]-m[2]*m[6], m[2]*m[3]-m[0]*m[5],
                m[3]*m[7]-m[4]*m[6], m[1]*m[6]-m[0]*m[7], m[0]*m[4]-m[1]*m[3]
            ]
        }
        
        func multmm(a a:[Float], b:[Float]) -> [Float] { // multiply two matrices
            var c = [Float](count:9, repeatedValue:0)
            for i in 0 ..< 3 {
                for j in 0 ..< 3 {
                    var cij:Float = 0
                    for k in 0 ..< 3 {
                        cij += a[3*i + k]*b[3*k + j]
                    }
                    c[3*i + j] = cij
                }
            }
            return c
        }
        
        func multmv(m m:[Float], v:[Float]) -> [Float] { // multiply matrix and vector
            return [
                m[0]*v[0] + m[1]*v[1] + m[2]*v[2],
                m[3]*v[0] + m[4]*v[1] + m[5]*v[2],
                m[6]*v[0] + m[7]*v[1] + m[8]*v[2]
            ]
        }
        
        func basisToPoints(x1 x1:Float, y1:Float, x2:Float, y2:Float, x3:Float, y3:Float, x4:Float, y4:Float) -> [Float] {
            let m:[Float] = [
                x1, x2, x3,
                y1, y2, y3,
                1,  1,  1
            ]
            var v = multmv(m: adj(m: m), v: [x4, y4, 1]);
            return multmm(a: m, b: [
                v[0], 0, 0,
                0, v[1], 0,
                0, 0, v[2]
                ]);
        }
        
        func general2DProjection(
            x1s x1s:Float, y1s:Float, x1d:Float, y1d:Float,
                x2s:Float, y2s:Float, x2d:Float, y2d:Float,
                x3s:Float, y3s:Float, x3d:Float, y3d:Float,
                x4s:Float, y4s:Float, x4d:Float, y4d:Float
            ) -> [Float] {
            let s = basisToPoints(x1: x1s, y1: y1s, x2: x2s, y2: y2s, x3: x3s, y3: y3s, x4: x4s, y4: y4s)
            let d = basisToPoints(x1: x1d, y1: y1d, x2: x2d, y2: y2d, x3: x3d, y3: y3d, x4: x4d, y4: y4d)
            return multmm(a: d, b: adj(m: s));
        }
    }    
}