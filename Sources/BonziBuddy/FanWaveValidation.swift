import AppKit
import MetalKit
import ImageIO
import simd

func validateFanWave() throws {
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
    renderer.character.play(.wave,at:0)
    let rig=renderer.fanRig!,folder="Validation/FanWave"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    let frames=96
    guard let gif=CGImageDestinationCreateWithURL(URL(fileURLWithPath:"\(folder)/wave.gif") as CFURL,"com.compuserve.gif" as CFString,frames,nil) else { throw failure("Cannot create fan wave preview") }
    CGImageDestinationSetProperties(gif,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFLoopCount:0]] as CFDictionary)
    var pivotError:Float=0,forearmError:Float=0,fingerTravel:Float=0
    var clipped:[Int]=[]
    for frame in 0..<frames {
        let t=Double(frame)/30;rig.waveTime=t
        rig.waveSwingEnabled=false
        let fixed=rig.instances(yaw:0,pitch:0,at:t)
        rig.waveSwingEnabled=true
        let swinging=rig.instances(yaw:0,pitch:0,at:t)
        let wrist=rig.rest[42].columns.3
        pivotError=max(pivotError,length(swinging[42].model*wrist-fixed[42].model*wrist))
        for bone in [39,40,41] { for c in 0..<4 { for r in 0..<4 { forearmError=max(forearmError,abs(swinging[bone].model[c][r]-fixed[bone].model[c][r])) } } }
        let finger=rig.rest[48].columns.3
        fingerTravel=max(fingerTravel,length(swinging[48].model*finger-fixed[48].model*finger))
        let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:800,pixelsHigh:320,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:3200,bitsPerPixel:32)!
        NSGraphicsContext.saveGraphicsState();NSGraphicsContext.current=NSGraphicsContext(bitmapImageRep:bitmap)!
        NSColor(calibratedWhite:0.94,alpha:1).setFill();NSRect(x:0,y:0,width:800,height:320).fill()
        for (camera,yaw) in [Float(0),-Float.pi/4].enumerated() {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:t)
            var pixels=[UInt8](repeating:0,count:800*640*4)
            texture.getBytes(&pixels,bytesPerRow:3200,from:MTLRegionMake2D(0,0,800,640),mipmapLevel:0)
            let border=(0..<800).map{$0}+(0..<800).map{639*800+$0}+(0..<640).map{$0*800}+(0..<640).map{$0*800+799}
            if border.contains(where:{pixels[$0*4+3]>100}) { clipped.append(frame) }
            let path="\(folder)/\(camera)-current.png"
            try writePNG(texture,to:path)
            NSImage(contentsOfFile:path)!.draw(in:NSRect(x:camera*400,y:0,width:400,height:320))
        }
        NSGraphicsContext.restoreGraphicsState()
        if [0,8,15,25,35,50,70,82,95].contains(frame) {
            try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"\(folder)/\(frame).png"))
        }
        CGImageDestinationAddImage(gif,bitmap.cgImage!,[kCGImagePropertyGIFDictionary:[kCGImagePropertyGIFDelayTime:1.0/30]] as CFDictionary)
    }
    guard CGImageDestinationFinalize(gif) else { throw failure("Cannot save fan wave") }
    guard pivotError<0.00001,forearmError<0.00001,fingerTravel>0.01,clipped.isEmpty else { throw failure("Fan wave pivot/movement/framing validation failed") }
    renderer.character.play(.speak,at:4)
    _=try renderer.offscreen(width:800,height:640,at:4)
    let (speech,_)=try renderer.offscreen(width:800,height:640,at:4.1)
    guard renderer.fanMorphWeights.y>0,rig.waveTime==nil else { throw failure("Live speech did not drive fan morphs") }
    try writePNG(speech,to:"\(folder)/live-speech.png")
    renderer.character.play(.idle,at:5)
    _=try renderer.offscreen(width:800,height:640,at:5)
    _=try renderer.offscreen(width:800,height:640,at:5.2)
    guard renderer.fanMorphIndices.x==2,renderer.fanMorphWeights.x==1,renderer.fanMorphWeights.y==0,rig.waveTime==nil else { throw failure("Live fan action did not return to idle") }
    let report:[String:Any]=["liveWaveSpeechIdleRouting":true].merging(["wristPivotError":pivotError,"forearmChangeFromWristSwing":forearmError,"maximumFingerTravelFromWristSwing":fingerTravel,"frames":frames,"clippedFrames":clipped,"previewFPS":30,"note":"Hand-authored fan-rig wave: checks the wrist swing center, preceding arm transforms, visible movement and framing. Not a match to original choreography or proof against mesh intersections."]) { _,new in new }
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]);try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
}
