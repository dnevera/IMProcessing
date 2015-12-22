//: Playground - noun: a place where people can play

import Cocoa
import simd
import Accelerate

extension Double{
    var float:Float{
        get{
            return Float(self)
        }
        set(newValue){
            self = Double(newValue)
        }
    }
}

extension Float{
    var double:Double{
        get{
            return Double(self)
        }
        set(newValue){
            self = Float(newValue)
        }
    }
}

extension Float{
    
    func gaussianPoint(fi fi:Float, mu:Float, sigma:Float) -> Float {
        return fi * exp( -(pow(( self - mu ),2)) / (2*pow(sigma, 2)) )
    }
    
    func gaussianPoint(fi fi:float2, mu:float2, sigma:float2) -> Float {
        
        let c1 = self <= mu.x ? 1.float : 0.float
        let c2 = self >= mu.y ? 1.float : 0.float
        
        let y1 = self.gaussianPoint(fi: fi.x, mu: mu.x, sigma: sigma.x) * c1 + (1.0-c1)
        let y2 = self.gaussianPoint(fi: fi.y, mu: mu.y, sigma: sigma.y) * c2 + (1.0-c2)
        
        return y1 * y2
    }
    
    func gaussianPoint(mu:Float, sigma:Float) -> Float {
        return self.gaussianPoint(fi: 1/(sigma*sqrt(2*M_PI.float)), mu: mu, sigma: sigma)
    }
    
    func gaussianPoint(mu:float2, sigma:float2) -> Float {
        return self.gaussianPoint(fi:float2(1), mu: mu, sigma: sigma)
    }
    
    static func range(r:Range<Int>) -> [Float]{
        return range(start: Float(r.startIndex), step: 1, end: Float(r.endIndex))
    }
    
    static func range(start start:Float, step:Float, end:Float) -> [Float] {
        let size       = Int((end-start)/step)
        
        var h:[Float]  = [Float](count: size, repeatedValue: 0)
        var zero:Float = start
        var v:Float    = step
        
        vDSP_vramp(&zero, &v, &h, 1, vDSP_Length(size))
        
        return h

    }
}

extension SequenceType where Generator.Element == Float {
    
    func gaussianDistribution(fi fi:Float, mu:Float, sigma:Float) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.gaussianPoint(fi: fi, mu: mu, sigma: sigma))
        }
        return a
    }
    
    func gaussianDistribution(fi fi:float2, mu:float2, sigma:float2) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.gaussianPoint(fi: fi, mu: mu, sigma: sigma))
        }
        return a
    }
    
    func gaussianDistribution(mu mu:Float, sigma:Float) -> [Float]{
        return self.gaussianDistribution(fi: 1/(sigma*sqrt(2*M_PI.float)), mu: mu, sigma: sigma)
    }
    
    func gaussianDistribution(mu mu:float2, sigma:float2) -> [Float]{
        return self.gaussianDistribution(fi: float2(1), mu: mu, sigma: sigma)
    }
    
    static func range(r:Range<Int>) -> [Float]{ return Float.range(r) }
    
    static func range(start start:Float, step:Float, end:Float) -> [Float] {
        return Float.range(start: start, step: step, end: end)
    }
}

extension Float{
    
    func hueWeight(ramp ramp:float4) -> Float {
        
        var sigma = (ramp.z-ramp.y)
        var mu    = (ramp.w+ramp.x)/2.0
        
        if ramp.y>ramp.z {
            sigma = (360.0-ramp.y+ramp.z)
            if (self >= 0.float) && (self <= 360.0/2.0) {
                mu    = (360.0-ramp.y-ramp.z) / 2.0
            }else{
                mu    = (ramp.y+ramp.z)
            }
        }
        
        return self.gaussianPoint(fi: 1, mu: mu, sigma: sigma)
    }
}

extension SequenceType where Generator.Element == Float {
    
    func hueWeightsDistribution(ramp ramp:float4) -> [Float]{
        var a = [Float]()
        for i in self{
            a.append(i.hueWeight(ramp: ramp))
        }
        return a
    }
    
    func hueWeightsDistribution(ramp ramp:float4) -> NSData {
        let f:[Float] = hueWeightsDistribution(ramp: ramp) as [Float]
        return NSData(bytes: f, length: f.count)
    }
    
}

var IMPHueRamps:[float4] = [
    float4(315.0, 345.0, 15.0,   45.0),
    float4( 15.0,  45.0, 75.0,  105.0),
    float4( 75.0, 105.0, 135.0, 165.0),
    float4(135.0, 165.0, 195.0, 225.0),
    float4(195.0, 225.0, 255.0, 285.0),
    float4(255.0, 285.0, 315.0, 345.0)
]

//var h = Float.range(0..<360).hueWeightsDistribution(ramp: IMPHueRamps[0])


public extension SequenceType where Generator.Element == float4 {
    func hueWeightsDistribution(range:Range<Int>) -> [[Float]]{
        var f = [[Float]]()
        for i in self {
            f.append(Float.range(range).hueWeightsDistribution(ramp: i))
        }
        return f
    }
}


let r = IMPHueRamps.hueWeightsDistribution(0..<360)

for c in r[0]{c}

for c in r[1]{c}
for c in r[2]{c}
for c in r[3]{c}
for c in r[4]{c}
for c in r[5]{c}

