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

let paths=["Validation/FaceDepth/before-left.png","Validation/angle-left-side.png","Validation/FaceDepth/before-quarter.png","Validation/angle-left-quarter.png"]
let w=280,h=230,zoom=2,width=w*zoom*2,height=h*zoom*2
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
for (panel,path) in paths.enumerated() {
 let source=Raster(path),output=bitmap.bitmapData!
 for y in 0..<h*zoom { for x in 0..<w*zoom {
  let i=((y/zoom+140)*source.width+x/zoom+250)*4,j=((y+(panel/2)*h*zoom)*width+x+(panel%2)*w*zoom)*4
  let alpha=Double(source.pixels[i+3])/255
  for c in 0..<3 { output[j+c]=UInt8(min(255,Double(source.pixels[i+c])+245*(1-alpha))) };output[j+3]=255
 } }
}
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/face-depth-review.png"))
