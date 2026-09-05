import AppKit
struct Pixels {
    var bytes:[UInt8]
    init(_ path:String) {
        let image=NSImage(contentsOfFile:path)!.cgImage(forProposedRect:nil,context:nil,hints:nil)!
        bytes=[UInt8](repeating:0,count:200*160*4)
        bytes.withUnsafeMutableBytes { raw in
            let context=CGContext(data:raw.baseAddress,width:200,height:160,bitsPerComponent:8,bytesPerRow:800,space:CGColorSpaceCreateDeviceRGB(),bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.interpolationQuality = .high
            context.draw(image,in:CGRect(x:0,y:0,width:200,height:160))
        }
    }
    func foreground(_ i:Int)->Bool {
        if bytes[i+3]<100 {return false}
        return bytes[3]<100 || (0..<3).reduce(0){$0+abs(Int(bytes[i+$1])-Int(bytes[$1]))}>20
    }
}
let clap=CommandLine.arguments.contains("--clap")
let left=CommandLine.arguments.contains("--look-left"),right=CommandLine.arguments.contains("--look-right")
let firstFrame=left ? 143 : right ? 149 : clap ? 10 : 40, lastOffset=left || right ? 3 : clap ? 5 : 10, folder=left ? "LookLeft" : right ? "LookRight" : clap ? "Clap" : "Shrug", name=folder.lowercased()
var reports:[[String:Any]]=[]
let selected=left || right ? [0,1,2,3] : clap ? [0,1,2,3,4,5] : [0,5,6,7,8,10]
let width=selected.count*200,height=570
let sheet=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:width,pixelsHigh:height,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:width*4,bitsPerPixel:32)!
NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:sheet)!
NSColor(calibratedWhite:0.96,alpha:1).setFill();NSRect(x:0,y:0,width:width,height:height).fill()
var passes=true
for frame in 0...lastOffset {
    let reference=Pixels("References/Frames/\(firstFrame+frame).png"),render=Pixels("Validation/\(folder)/\(frame*2).png")
    var intersection=0,union=0,error=0
    var panels=[[UInt8]](repeating:[UInt8](repeating:255,count:200*160*4),count:3)
    for i in stride(from:0,to:reference.bytes.count,by:4) {
        let a=reference.foreground(i),b=render.foreground(i)
        if a || b {union+=1};if a && b {intersection+=1}
        for c in 0..<3 {
            let av=a ? Int(reference.bytes[i+c]) : 245,bv=b ? Int(render.bytes[i+c]) : 245
            panels[0][i+c]=UInt8(av);panels[1][i+c]=UInt8(bv);panels[2][i+c]=UInt8(abs(av-bv))
            if a || b {error+=abs(av-bv)}
        }
    }
    let iou=Double(intersection)/Double(union),mae=Double(error)/Double(union*3)/255
    passes = passes && iou>=0.95 && mae<=0.05
    reports.append(["referenceFrame":firstFrame+frame,"timeSeconds":Double(frame)/15,"silhouetteIoU":iou,"foregroundRGBMeanAbsoluteError":mae])
    if let column=selected.firstIndex(of:frame) {
        for row in 0..<3 {
            let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:200,pixelsHigh:160,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:800,bitsPerPixel:32)!
            panels[row].withUnsafeBytes {bitmap.bitmapData!.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:200*160*4)}
            let image=NSImage(size:NSSize(width:200,height:160));image.addRepresentation(bitmap)
            let x=column*200,y=(2-row)*190
            image.draw(in:NSRect(x:x,y:y+25,width:200,height:160))
            let label=["Reference \(firstFrame+frame)",String(format:"Metal %.3f s",Double(frame)/15),String(format:"Diff · IoU %.1f%%",iou*100)][row]
            NSAttributedString(string:label,attributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.darkGray]).draw(at:NSPoint(x:x+30,y:y+7))
        }
    }
}
NSGraphicsContext.restoreGraphicsState()
try sheet.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/\(name)-comparison.png"))
let report:[String:Any]=["method":"Full fixed 200x160 reference canvas. Metal captures downsampled from 800x640; no per-frame bounding-box alignment. Foreground alpha threshold 100 and opaque matte RGB-distance threshold 20. RGB error is measured over foreground union; translucent desktop shadows are excluded.","passesNearIdenticalAnimationGate":passes,"gate":["minimumSilhouetteIoU":0.95,"maximumForegroundRGBMAE":0.05],"frames":reports]
let json=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try json.write(to:URL(fileURLWithPath:"Validation/\(name)-metrics.json"));print(String(decoding:json,as:UTF8.self))
