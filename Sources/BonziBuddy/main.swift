import AppKit
import MetalKit

func validate() throws {
    guard let device = MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer = try Renderer(device:device)
    try FileManager.default.createDirectory(atPath:"Validation",withIntermediateDirectories:true)
    for action in Action.allCases {
        renderer.character.play(action,at:0)
        let (texture,_) = try renderer.offscreen(width:800,height:640,at:action == .idle ? 0 : action == .speak ? 0.46 : 1)
        try writePNG(texture,to:"Validation/\(action.rawValue.lowercased()).png")
    }
    try FileManager.default.createDirectory(atPath:"Validation/Speech",withIntermediateDirectories:true)
    for (camera,yaw) in [Float(0),Float.pi/3].enumerated() {
        let speechRenderer=try Renderer(device:device)
        speechRenderer.character.yaw=yaw
        speechRenderer.character.play(.speak,at:0)
        for (frame,time) in [0.0,0.2,0.3,0.46,0.6,0.7].enumerated() {
            let (texture,_)=try speechRenderer.offscreen(width:800,height:640,at:time)
            try writePNG(texture,to:"Validation/Speech/\(camera)-\(frame).png")
        }
    }
    renderer.character.yaw=0
    renderer.character.play(.idle,at:0)
    renderer.shadowsEnabled = false
    let (unshadowed,_) = try renderer.offscreen(width:800,height:640,at:1)
    try writePNG(unshadowed,to:"Validation/shadows-off.png")
    renderer.shadowsEnabled = true
    let (shadowed,_) = try renderer.offscreen(width:800,height:640,at:1)
    try writePNG(shadowed,to:"Validation/shadows-on.png")
    renderer.character.yaw = 0.65
    let (threeQuarter,_) = try renderer.offscreen(width:800,height:640,at:1)
    try writePNG(threeQuarter,to:"Validation/three-quarter.png")
    renderer.wireframe = true
    let (wireframe,_) = try renderer.offscreen(width:800,height:640,at:1)
    try writePNG(wireframe,to:"Validation/wireframe.png")
    renderer.wireframe = false; renderer.character.yaw = 0
    for (name,yaw,pitch) in [("front",Float(0),Float(0.18)),("right-quarter",Float.pi/4,Float(0.18)),("right-side",Float.pi/2,Float(0.18)),("rear-quarter",Float.pi*3/4,Float(0.18)),("rear",Float.pi,Float(0.18)),("left-side",-Float.pi/2,Float(0.18)),("left-quarter",-Float.pi/4,Float(0.18)),("above",Float.pi/4,Float(0.4))] {
        renderer.character.yaw = yaw; renderer.character.pitch = pitch
        let (angle,_) = try renderer.offscreen(width:800,height:640,at:1)
        try writePNG(angle,to:"Validation/angle-\(name).png")
    }
    renderer.character.yaw = 0; renderer.character.pitch = 0.18
    var timings:[Double] = []
    renderer.character.play(.dance,at:0)
    for i in 0..<360 {
        let (_,ms) = try renderer.offscreen(width:800,height:640,at:Double(i)/120)
        if i >= 60 { timings.append(ms) }
    }
    timings.sort()
    let report:[String:Any] = ["device":device.name,"msaaSampleCount":renderer.sampleCount,"softShadows":renderer.shadowsEnabled,"shadowMapResolution":2048,"resolution":[800,640],"samples":timings.count,"gpuMedianMS":timings[timings.count/2],"gpuP95MS":timings[Int(Double(timings.count)*0.95)],"gpuMaxMS":timings.last!,"budget120FPSMS":1000.0/120,"note":"Offscreen GPU execution only; excludes display pacing, compositor, and CPU allocations. Onscreen 120 Hz must be measured on a 120 Hz display."]
    let data = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"Validation/performance.json")); print(String(decoding:data,as:UTF8.self))
}
if CommandLine.arguments.contains("--validate-write") {
    do {try validateWrite()} catch {fputs("Write validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-read") {
    do {try validateRead()} catch {fputs("Read validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-butterfly-materials") {
    do {try validateButterflyMaterials()} catch {fputs("Butterfly material validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-butterfly") {
    do {try validateButterfly()} catch {fputs("Butterfly validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-headphones") {
    do {try validateHeadphones()} catch {fputs("Headphones validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-wearables") {
    do {try validateWearables()} catch {fputs("Wearable validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-sunglasses") {
    do {try validateSunglasses()} catch {fputs("Sunglasses validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-routines") {
    do {try validateRoutines()} catch {fputs("Routine validation failed: \(error)\n",stderr);exit(1)}
    exit(0)
}
if CommandLine.arguments.contains("--validate-juggle") {
    do { try validateJuggle() } catch { fputs("Juggle failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-props") {
    do { try validateProps() } catch { fputs("Props failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-fan-contacts") {
    do { try validateFanContacts() } catch { fputs("Fan contacts failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-reminders") {
    do { try validateReminders() } catch { fputs("Reminders failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-fan-transitions") {
    do { try validateFanTransitions() } catch { fputs("Fan transitions failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-fan-teeth") {
    do { try validateFanTeeth() } catch { fputs("Fan teeth failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-fan-actions") {
    do { try validateFanActions() } catch { fputs("Fan actions failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-fan-wave") {
    do { try validateFanWave() } catch { fputs("Fan wave failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--preview-fan") {
    do { try previewFan() } catch { fputs("Fan preview failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate-animations") {
    do { try validateAnimations(); try validateWave(); try validateWave(action:.idle,folder:"Idle",frames:150) } catch { fputs("Animation validation failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--check-mesh") {
    do { try checkMesh() } catch { fputs("Mesh check failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--bake-mesh") {
    do { try bakeMesh() } catch { fputs("Mesh bake failed: \(error)\n",stderr); exit(1) }
} else if CommandLine.arguments.contains("--validate") {
    do { try validate() } catch { fputs("Validation failed: \(error)\n",stderr); exit(1) }
} else {
    let app = NSApplication.shared
    let delegate = AppDelegate(); app.delegate = delegate; app.setActivationPolicy(.accessory); app.run()
}
