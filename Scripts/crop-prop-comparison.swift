import AppKit
import Foundation

// Crop one native camera view and one original ACS base frame for compare.swift.
// Native action previews contain three 400x320 panels; ACS strips use 200x160 cells.
let args=CommandLine.arguments
guard args.count==6,let frame=Int(args[3]),frame>=0,let camera=Int(args[4]),(0...2).contains(camera) else {
    fputs("Usage: swift Scripts/crop-prop-comparison.swift native.png original-strip.png original-frame camera-index output-folder\n",stderr)
    exit(1)
}
let folder=URL(fileURLWithPath:args[5],isDirectory:true)
try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
for (path,rect,name) in [(args[1],CGRect(x:camera*400,y:0,width:400,height:320),"native.png"),(args[2],CGRect(x:frame*200,y:0,width:200,height:160),"original.png")] {
    guard let image=NSImage(contentsOfFile:path)?.cgImage(forProposedRect:nil,context:nil,hints:nil),
          CGRect(x:0,y:0,width:image.width,height:image.height).contains(rect),
          let crop=image.cropping(to:rect),
          let png=NSBitmapImageRep(cgImage:crop).representation(using:.png,properties:[:]) else {
        fputs("Invalid image or crop: \(path)\n",stderr);exit(1)
    }
    try png.write(to:folder.appendingPathComponent(name))
}
let metadata:[String:Any]=["nativeSource":args[1],"originalStrip":args[2],"originalFrame":frame,"nativeCamera":camera,"note":"Selected pose comparison; frames are not automatically time-aligned."]
try JSONSerialization.data(withJSONObject:metadata,options:[.prettyPrinted,.sortedKeys]).write(to:folder.appendingPathComponent("selection.json"))
