import AppKit
import MetalKit
import ImageIO

func validateReferenceAnimation(action:Action,folder:String,frames:Int,referenceFrames:[Int],duration:Double) throws {
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device)
    try FileManager.default.createDirectory(atPath:"Validation/\(folder)",withIntermediateDirectories:true)
    renderer.character.play(action,at:0)
    var clippedFrames:[Int]=[]
    let gifURL=URL(fileURLWithPath:"Validation/\(folder.lowercased())-animation.gif")
    guard let gif=CGImageDestinationCreateWithURL(gifURL as CFURL,"com.compuserve.gif" as CFString,frames,nil) else { throw failure("Cannot create animation preview") }
    CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
    for frame in 0..<frames {
        let time=Double(frame)/30
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:time)
        var pixels=[UInt8](repeating:0,count:800*640*4)
        texture.getBytes(&pixels,bytesPerRow:800*4,from:MTLRegionMake2D(0,0,800,640),mipmapLevel:0)
        let border=(0..<800).map { $0 }+(0..<800).map { 639*800+$0 }+(0..<640).map { $0*800 }+(0..<640).map { $0*800+799 }
        if border.contains(where:{ pixels[$0*4+3]>100 }) { clippedFrames.append(frame) }
        let path="Validation/\(folder)/\(frame).png"
        try writePNG(texture,to:path)
        if folder == "Clap" && [6,8].contains(frame) {
            renderer.character.yaw = -.pi/2
            let (side,_)=try renderer.offscreen(width:800,height:640,at:time)
            try writePNG(side,to:"Validation/Clap/\(frame)-side.png")
            renderer.character.yaw = 0
        }
        let source=NSImage(contentsOfFile:path)!
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:400,pixelsHigh:320,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1600,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)!
        NSColor(calibratedWhite:0.94,alpha:1).setFill();NSRect(x:0,y:0,width:400,height:320).fill()
        source.draw(in:NSRect(x:0,y:0,width:400,height:320))
        NSGraphicsContext.restoreGraphicsState()
        CGImageDestinationAddImage(gif,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(gif) else { throw failure("Cannot save animation preview") }
    let report:[String:Any]=["action":folder,"referenceFrames":referenceFrames,"referenceSequenceFPS":15,"renderCaptureFPS":30,"renderedFrames":frames,"durationSeconds":duration,"clippedFrames":clippedFrames,"viewport":[800,640],"note":"3D poses are manually retargeted from the community-hosted classic sprite sequence. Timing uses that client's 15 Hz tick, not authenticated original Windows timing. Hold duration or repeat count is chosen for this app. Preview GIF is 30 fps; native rendering targets 120 fps."]
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:folder == "Shrug" ? "Validation/animation.json" : "Validation/\(folder.lowercased())-animation.json"))
    guard clippedFrames.isEmpty else { throw failure("\(folder) is clipped in frames \(clippedFrames)") }
    print("Captured \(frames) \(folder) frames; no foreground touches the viewport boundary.")
}

func validateAnimations() throws {
    try validateReferenceAnimation(action:.lookLeft,folder:"LookLeft",frames:42,referenceFrames:Array(143...146),duration:LookAnimation.duration)
    try validateReferenceAnimation(action:.lookRight,folder:"LookRight",frames:42,referenceFrames:Array(149...152),duration:LookAnimation.duration)
    try validateReferenceAnimation(action:.shrug,folder:"Shrug",frames:66,referenceFrames:Array(40...50),duration:ShrugAnimation.duration)
    try validateReferenceAnimation(action:.clap,folder:"Clap",frames:48,referenceFrames:Array(10...15),duration:ClapAnimation.duration)
}

// Review the whole wave, including its return, from two cameras simultaneously.
func validateWave(action:Action = .wave,folder:String = "Wave",frames:Int = 120) throws {
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device)
    renderer.character.play(action,at:0)
    try FileManager.default.createDirectory(atPath:"Validation/\(folder)",withIntermediateDirectories:true)
    guard let gif=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"Validation/\(folder.lowercased())-animation.gif") as CFURL,"com.compuserve.gif" as CFString,frames,nil) else { throw failure("Cannot create wave preview") }
    CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
    var clipped:[Int]=[]
    for frame in 0..<frames {
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:800,pixelsHigh:320,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:3200,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState(); NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)!
        NSColor(calibratedWhite:0.94,alpha:1).setFill(); NSRect(x:0,y:0,width:800,height:320).fill()
        for (camera,yaw) in [Float(0),-Float.pi/2].enumerated() {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:Double(frame)/30)
            var pixels=[UInt8](repeating:0,count:800*640*4)
            texture.getBytes(&pixels,bytesPerRow:3200,from:MTLRegionMake2D(0,0,800,640),mipmapLevel:0)
            let border=(0..<800).map{$0}+(0..<800).map{639*800+$0}+(0..<640).map{$0*800}+(0..<640).map{$0*800+799}
            if border.contains(where:{pixels[$0*4+3]>100}) { clipped.append(frame) }
            let path="Validation/\(folder)/\(camera)-current.png"
            try writePNG(texture,to:path)
            NSImage(contentsOfFile:path)!.draw(in:NSRect(x:camera*400,y:0,width:400,height:320))
        }
        NSGraphicsContext.restoreGraphicsState()
        if [0,15,30,45,60,90,119,120,121,122,123,126,129].contains(frame) {
            try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/\(folder)/\(frame).png"))
        }
        CGImageDestinationAddImage(gif,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(gif) else { throw failure("Cannot save wave preview") }
    let report:[String:Any]=["action":folder,"renderedFrames":frames,"cameras":["front","left side"],"clippedFrames":Array(Set(clipped)).sorted(),"note":"Motion captured at 30 fps preview; animation is continuously evaluated by the native 120 fps renderer. Visual review, not authenticated original choreography."]
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"Validation/\(folder.lowercased())-animation.json"))
    guard clipped.isEmpty else { throw failure("\(folder) touches viewport boundary") }
    print("Captured \(folder) from front and side; no clipped frames.")
}
