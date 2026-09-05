import AppKit
let views = [("front","Front"),("right-quarter","Right three-quarter"),("right-side","Right side"),("rear-quarter","Rear three-quarter"),("rear","Rear"),("left-side","Left side"),("left-quarter","Left three-quarter"),("above","Elevated")]
let width=1280,height=740,cellW=320,cellH=370
let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
let context=NSGraphicsContext(bitmapImageRep:bitmap)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=context
NSColor(calibratedWhite:0.94,alpha:1).setFill(); NSRect(x:0,y:0,width:width,height:height).fill()
for (i,entry) in views.enumerated() {
    let x=(i%4)*cellW,y=height-(i/4+1)*cellH
    let path="Validation/angle-\(entry.0).png"
    guard let image=NSImage(contentsOfFile:path) else { fatalError("Missing \(path)") }
    image.draw(in:NSRect(x:x+10,y:y+65,width:300,height:240))
    let title=NSAttributedString(string:entry.1,attributes:[.font:NSFont.systemFont(ofSize:15,weight:.medium),.foregroundColor:NSColor(calibratedWhite:0.2,alpha:1)])
    title.draw(at:NSPoint(x:CGFloat(x)+(CGFloat(cellW)-title.size().width)/2,y:CGFloat(y+12)))
}
NSGraphicsContext.restoreGraphicsState()
try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/angles.png"))
print("Saved Validation/angles.png")
let shadowBitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:640,pixelsHigh:370,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:640*4,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:shadowBitmap)!
NSColor(calibratedWhite:0.94,alpha:1).setFill(); NSRect(x:0,y:0,width:640,height:370).fill()
for (i,name) in ["off","on"].enumerated() {
    NSImage(contentsOfFile:"Validation/shadows-\(name).png")!.draw(in:NSRect(x:i*320+10,y:65,width:300,height:240))
    NSAttributedString(string:"Soft shadows \(name)",attributes:[.font:NSFont.systemFont(ofSize:15,weight:.medium),.foregroundColor:NSColor.darkGray]).draw(at:NSPoint(x:i*320+95,y:12))
}
NSGraphicsContext.restoreGraphicsState()
try shadowBitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/shadow-comparison.png"))

let speech=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1200,pixelsHigh:360,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4800,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:speech)!
NSColor(calibratedWhite:0.94,alpha:1).setFill(); NSRect(x:0,y:0,width:1200,height:360).fill()
for camera in 0..<2 { for (frame,time) in [0.0,0.2,0.3,0.46,0.6,0.7].enumerated() {
    let y=(1-camera)*180
    if let image=NSImage(contentsOfFile:"Validation/Speech/\(camera)-\(frame).png") {
        image.draw(in:NSRect(x:frame*200,y:y+20,width:200,height:160))
    }
    NSAttributedString(string:String(format:"%@ · %.2f s",camera==0 ? "Front" : "Three-quarter",time),attributes:[.font:NSFont.systemFont(ofSize:11),.foregroundColor:NSColor.darkGray]).draw(at:NSPoint(x:frame*200+40,y:y+3))
} }
NSGraphicsContext.restoreGraphicsState()
try speech.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/speech-review.png"))
