import AppKit
// Natural Earth public-domain land polygons -> a small equirectangular land mask.
let input=CommandLine.arguments[1],output=CommandLine.arguments[2]
let doc=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:input))) as! [String:Any]
let w=1024,h=512
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:w*4,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)!
NSColor.black.setFill();NSRect(x:0,y:0,width:w,height:h).fill();NSColor.white.setFill()
for feature in doc["features"] as! [[String:Any]] {
 let geometry=feature["geometry"] as! [String:Any]
 let polygons = geometry["type"] as! String == "Polygon" ? [geometry["coordinates"] as! [[[Double]]]]:geometry["coordinates"] as! [[[[Double]]]]
 for polygon in polygons {
  let path=NSBezierPath();path.windingRule = .evenOdd
  for ring in polygon {
   for (i,p) in ring.enumerated() {
    let point=NSPoint(x:(p[0]+180)/360*Double(w),y:(p[1]+90)/180*Double(h))
    if i==0 {path.move(to:point)} else {path.line(to:point)}
   }
   path.close()
  }
  path.fill()
 }
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:output))
