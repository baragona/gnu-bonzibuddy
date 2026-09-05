import AppKit
import Foundation
struct Raster {
    var pixels:[UInt8]; var width:Int; var height:Int
    init(_ path:String) {
        let image = NSImage(contentsOfFile:path)!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
        width = image.width; height = image.height
        pixels = [UInt8](repeating:0,count:width*height*4)
        pixels.withUnsafeMutableBytes { raw in
            let context = CGContext(data:raw.baseAddress,width:width,height:height,bitsPerComponent:8,bytesPerRow:width*4,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image,in:CGRect(x:0,y:0,width:width,height:height))
        }
    }
    func foreground(_ i:Int) -> Bool {
        if pixels[i+3] < 100 { return false }
        // The reference sheet's flat matte is RGB 72, 54, 106.
        return abs(Int(pixels[i])-Int(pixels[0]))+abs(Int(pixels[i+1])-Int(pixels[1]))+abs(Int(pixels[i+2])-Int(pixels[2])) > 20 || pixels[3] < 100
    }
    func normalized() -> [UInt8] {
        var x0=width,y0=height,x1=0,y1=0
        for y in 0..<height { for x in 0..<width { if foreground((y*width+x)*4) { x0=min(x0,x);y0=min(y0,y);x1=max(x1,x);y1=max(y1,y) } } }
        let size=256, padding=12
        let factor = Double(size-padding*2)/Double(max(x1-x0+1,y1-y0+1))
        let dw = Double(x1-x0+1)*factor, dh = Double(y1-y0+1)*factor
        var output=[UInt8](repeating:0,count:size*size*4)
        for y in 0..<size { for x in 0..<size {
            let sx=Int(floor((Double(x)-(Double(size)-dw)/2)/factor))+x0
            let sy=Int(floor((Double(y)-(Double(size)-dh)/2)/factor))+y0
            if sx>=x0 && sx<=x1 && sy>=y0 && sy<=y1 {
                let i=(sy*width+sx)*4,j=(y*size+x)*4
                if foreground(i) { for c in 0..<3 { output[j+c]=pixels[i+c] }; output[j+3]=255 }
            }
        } }
        return output
    }
}
let renderPath=CommandLine.arguments.count>1 ? CommandLine.arguments[1] : "Validation/idle.png"
let outputFolder=CommandLine.arguments.count>2 ? CommandLine.arguments[2] : "Validation"
try FileManager.default.createDirectory(atPath:outputFolder,withIntermediateDirectories:true)
let reference=Raster("References/idle.png").normalized(), render=Raster(renderPath).normalized()
var output=[UInt8](repeating:255,count:768*256*4)
var intersection=0,union=0,error=0
for y in 0..<256 { for x in 0..<256 {
    let i=(y*256+x)*4
    let a=reference[i+3]>0,b=render[i+3]>0
    if a || b { union += 1 }; if a && b { intersection += 1 }
    for c in 0..<3 {
        let av=a ? Int(reference[i+c]) : 245, bv=b ? Int(render[i+c]) : 245
        output[(y*768+x)*4+c]=UInt8(av)
        output[(y*768+x+256)*4+c]=UInt8(bv)
        output[(y*768+x+512)*4+c]=UInt8(abs(av-bv))
        if a || b { error += abs(av-bv) }
    }
} }
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:768,pixelsHigh:256,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:768*4,bitsPerPixel:32)!
output.withUnsafeBytes { bitmap.bitmapData!.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:output.count) }
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(outputFolder)/comparison.png"))
let iou=Double(intersection)/Double(union),mae=Double(error)/Double(union*3)/255
// Fixed patches help distinguish material brightness from silhouette differences.
// They are diagnostic only and do not change the full-image acceptance gate.
var materialRegions:[[String:Any]]=[]
for (name,x0,y0,x1,y1) in [("muzzle",100,68,156,95),("belly",99,146,157,181),("arm fur",63,135,85,147),("resting hands",104,110,150,141)] {
    var a=[Double](repeating:0,count:3),b=a,n=0.0,regionError=0.0
    for y in y0..<y1 { for x in x0..<x1 {
        let i=(y*256+x)*4
        if reference[i+3]>0 && render[i+3]>0 {
            for c in 0..<3 { a[c]+=Double(reference[i+c]); b[c]+=Double(render[i+c]); regionError+=abs(Double(reference[i+c])-Double(render[i+c])) };n+=1
        }
    } }
    materialRegions.append(["region":name,"normalizedRectangle":[x0,y0,x1,y1],"samples":Int(n),"foregroundRGBMeanAbsoluteError":regionError/max(1,n*3)/255,"referenceMeanRGB":a.map{$0/max(1,n)},"renderMeanRGB":b.map{$0/max(1,n)}])
}
var silhouetteRows:[[String:Any]]=[]
for y in stride(from:20,through:240,by:10) {
    func spans(_ pixels:[UInt8])->[[Int]] {
        var result=[[Int]](),start:Int?=nil
        for x in 0...256 {
            let filled=x<256 && pixels[(y*256+x)*4+3]>0
            if filled && start==nil { start=x }
            if !filled,let first=start { result.append([first,x-1]);start=nil }
        }
        return result
    }
    silhouetteRows.append(["normalizedY":y,"referenceXSpans":spans(reference),"renderXSpans":spans(render)])
}
let report:[String:Any] = ["silhouetteRows":silhouetteRows,"materialRegions":materialRegions,"silhouetteIoU":iou,"foregroundRGBMeanAbsoluteError":mae,"passesNearIdenticalGate":iou>=0.95 && mae<=0.05,"gate":["minimumSilhouetteIoU":0.95,"maximumForegroundRGBMAE":0.05],"method":"Idle pose, foreground matte removal (20 RGB distance), independent bounding-box fit preserving aspect ratio into 256x256 with 12px padding, nearest-neighbor sampling. RGB MAE measured over union of foreground. This is a diagnostic, not proof of perceptual identity.","panels":["Original reference","Metal render","Absolute RGB difference"]]
let json=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]); try json.write(to:URL(fileURLWithPath:"\(outputFolder)/visual-metrics.json")); print(String(decoding:json,as:UTF8.self))
