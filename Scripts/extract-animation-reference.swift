import AppKit
let sheet=NSImage(contentsOfFile:"References/original-sheet.png")!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
let sequences:[(String,[Int])] = [("shrug",Array(40...50)),("clap",Array(10...15)),("present",Array(137...142)),("praise",Array(159...164)),("look-left",Array(143...146)),("look-right",Array(149...152))]
try FileManager.default.createDirectory(atPath:"References/Frames",withIntermediateDirectories:true)
for (name,frames) in sequences {
    let columns=min(6,frames.count), rows=(frames.count+columns-1)/columns
    let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:columns*200,pixelsHigh:rows*190,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:columns*800,bitsPerPixel:32)!
    NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)!
    NSColor(calibratedWhite:0.94,alpha:1).setFill();NSRect(x:0,y:0,width:columns*200,height:rows*190).fill()
    for (i,frame) in frames.enumerated() {
        let crop=sheet.cropping(to:CGRect(x:(frame%17)*200,y:(frame/17)*160,width:200,height:160))!
        let rep=NSBitmapImageRep(cgImage:crop)
        try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"References/Frames/\(frame).png"))
        let x=(i%columns)*200,y=(rows-1-i/columns)*190
        NSImage(cgImage:crop,size:NSSize(width:200,height:160)).draw(in:NSRect(x:x,y:y+24,width:200,height:160))
        NSAttributedString(string:"\(name) · frame \(frame)",attributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.darkGray]).draw(at:NSPoint(x:x+40,y:y+5))
    }
    NSGraphicsContext.restoreGraphicsState()
    try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"References/\(name)-sequence.png"))
}
