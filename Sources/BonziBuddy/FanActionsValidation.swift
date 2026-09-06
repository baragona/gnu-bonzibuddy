import AppKit
import MetalKit
import ImageIO
import simd

func validateFanActions() throws {
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
    let withSunglasses=CommandLine.arguments.contains("--with-sunglasses")
    let withHeadphones=CommandLine.arguments.contains("--with-headphones")
    if withSunglasses {renderer.character.setSunglassesEnabled(true,at:-5)}
    if withHeadphones {renderer.character.setHeadphonesEnabled(true,at:-5)}
    let faceOnly=CommandLine.arguments.contains("--face-only")
    let folder=faceOnly ? "Validation/FanFace" : "Validation/FanActions"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    var reports:[[String:Any]]=[]
    let requested=CommandLine.arguments.firstIndex(of:"--action").flatMap { $0+1<CommandLine.arguments.count ? CommandLine.arguments[$0+1]:nil }
    let actions=Action.allCases.filter { requested == nil || $0.rawValue.lowercased()==requested!.lowercased() }
    if requested != nil && actions.isEmpty { throw failure("Unknown validation action") }
    let holdArgument=CommandLine.arguments.firstIndex(of:"--hold-seconds")
    let holdSeconds=holdArgument.flatMap {$0+1<CommandLine.arguments.count ? Double(CommandLine.arguments[$0+1]):nil}
    if holdArgument != nil {
        guard let holdSeconds,holdSeconds.isFinite,holdSeconds>0,actions.count==1,RoutineLibrary.definitions[actions[0]]?.holdRange != nil else {throw failure("Hold preview needs one hold-capable action and a positive duration")}
    }
    for action in faceOnly ? [] : actions {
        renderer.character.play(action,at:0,mode:holdSeconds == nil ? .once:.hold)
        let duration:Double
        if let holdSeconds {
            var planned=ActionPlayback();planned.play(action,at:0,mode:.hold);planned.finish(at:holdSeconds)
            guard let end=planned.completionTime else {throw failure("Held preview has no scheduled return")}
            duration=end
        } else {duration=action == .idle ? 4.6:action == .speak ? 2.0:action.duration}
        let frames=Int(ceil(duration*15))+1,name=action.rawValue.lowercased().replacingOccurrences(of:" ",with:"-")+(holdSeconds == nil ? "":"-held")+(withSunglasses ? "-sunglasses":"")+(withHeadphones ? "-headphones":"")
        guard let gif=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"\(folder)/\(name).gif") as CFURL,"com.compuserve.gif" as CFString,frames,nil) else { throw failure("Cannot create action preview") }
        CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
        var clipped=0,requestedReturn=false
        for frame in 0..<frames {
            let time=Double(frame)/15
            if let holdSeconds,time>=holdSeconds,!requestedReturn {
                renderer.character.finishRoutine(at:holdSeconds);requestedReturn=true
            }
            let output=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:1200,pixelsHigh:320,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:4800,bitsPerPixel:32)!
            NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:output)!
            NSColor(calibratedWhite:0.94,alpha:1).setFill();NSRect(x:0,y:0,width:1200,height:320).fill()
            for (camera,yaw) in [Float(0),-Float.pi/4,-Float.pi/2].enumerated() {
                renderer.character.yaw=yaw
                let (texture,_)=try renderer.offscreen(width:400,height:320,at:time)
                var bytes=[UInt8](repeating:0,count:400*320*4)
                texture.getBytes(&bytes,bytesPerRow:1600,from:MTLRegionMake2D(0,0,400,320),mipmapLevel:0)
                let border=(0..<400).map{$0}+(0..<400).map{319*400+$0}+(0..<320).map{$0*400}+(0..<320).map{$0*400+399}
                if border.contains(where:{bytes[$0*4+3]>100}) { clipped+=1 }
                for i in stride(from:0,to:bytes.count,by:4) { bytes.swapAt(i,i+2) }
                let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:400,pixelsHigh:320,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:1600,bitsPerPixel:32)!
                bytes.withUnsafeBytes { bitmap.bitmapData!.update(from:$0.bindMemory(to:UInt8.self).baseAddress!,count:bytes.count) }
                NSImage(cgImage:bitmap.cgImage!,size:NSSize(width:400,height:320)).draw(in:NSRect(x:camera*400,y:0,width:400,height:320))
            }
            NSGraphicsContext.restoreGraphicsState()
            if action == .giggle || action == .blowKiss || action == .wink || action == .shush || action == .chestBeat || frame==min(15,frames/2) || frame==frames/2 || (action == .clap && frame<=6) || (action == .shrug && [5,7,9,22,27,33].contains(frame)) || (action == .think && [5,10,20,45,55,60].contains(frame)) || ((action == .dance || action == .juggle || action == .banana || action == .bananaMiss || action == .sunglasses || action == .headphones || action == .butterfly || action == .read || action == .readLookUp || action == .write || action == .writePause || action == .writeOnce || action == .writeAgain || action == .mailEmpty || action == .mailRead || action == .mailNext || action == .mailFull) && frame%10==0) {
                try output.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(folder)/\(name)-\(frame).png"))
            }
            CGImageDestinationAddImage(gif,output.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/15]] as CFDictionary)
        }
        guard CGImageDestinationFinalize(gif) else { throw failure("Cannot save action preview") }
        reports.append(["action":action.rawValue,"frames":frames,"clippedViews":clipped,"playback":holdSeconds == nil ? "once":"held then return","returnRequestedAt":holdSeconds ?? -1]);print("Rendered \(action.rawValue), \(frames) frames, \(clipped) clipped views")
    }
    renderer.character.play(.idle,at:0);renderer.character.yaw=0
    for (name,time) in [("open",3.9),("half",4.04),("closed",4.10),("reopening",4.20)] {
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:time)
        try writePNG(texture,to:"\(folder)/blink-\(name).png")
    }
    for (name,gaze) in [("right",SIMD2<Float>(1,0)),("left",SIMD2<Float>(-1,0)),("up",SIMD2<Float>(0,1)),("down",SIMD2<Float>(0,-1)),("up-right",SIMD2<Float>(1,1)),("down-left",SIMD2<Float>(-1,-1))] {
        renderer.fanGaze=gaze
        let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
        try writePNG(texture,to:"\(folder)/gaze-\(name).png")
    }
    renderer.fanGaze = .zero
    for (angle,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2)] {
        renderer.character.yaw=yaw
        for enabled in [false,true] {
            renderer.fanEyeCatchlights=enabled
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
            try writePNG(texture,to:"\(folder)/eye-catchlight-\(angle)-\(enabled ? "on":"off").png")
        }
    }
    renderer.fanIndividualEyeClosure = .zero
    for (name,closure) in [("left",SIMD2<Float>(1,0)),("right",SIMD2<Float>(0,1)),("asymmetric",SIMD2<Float>(0.3,0.8))] {
        renderer.fanIndividualEyeClosure=closure
        for (angle,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2)] {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
            try writePNG(texture,to:"\(folder)/wink-\(name)-\(angle).png")
        }
    }
    renderer.fanIndividualEyeClosure = .zero
    renderer.fanEyeCatchlights=true;renderer.character.yaw=0
    renderer.fanExpressionOverrides=[2:0.4,7:0.5,8:0.2,12:0.3]
    let (combined,_)=try renderer.offscreen(width:800,height:640,at:0)
    try writePNG(combined,to:"\(folder)/combined-expression.png")
    let report:[String:Any]=["actions":reports,"morphNames":renderer.fanExpressionNames,"previewFPS":15,"note":"Full action duration and three-view framing review. Reuses the existing local action curves, retargeted to the fan joints; not proof of original choreography or collision-free motion. Blink is an animated skin-colored cover on the eye mesh surface."]
    try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]).write(to:URL(fileURLWithPath:"\(folder)/checks.json"))
}
