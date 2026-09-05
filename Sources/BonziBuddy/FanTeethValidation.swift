import AppKit
import MetalKit

func validateFanTeeth() throws {
    guard let device=MTLCreateSystemDefaultDevice() else { throw failure("Metal GPU unavailable") }
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    guard renderer.fanTeethIndexCount>0 else { throw failure("Missing tooth geometry") }
    renderer.fanExpressionOverrides=[2:1];renderer.fanTeethEnabled=true
    let folder="Validation/FanTeeth"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    for (name,weights) in [("closed",SIMD2<Float>(0,0)),("neutral",SIMD2<Float>(0.2,0)),("jaw-quarter",SIMD2<Float>(0,0.25)),("jaw-half",SIMD2<Float>(0,0.5)),("jaw-open",SIMD2<Float>(0,1)),("smile",SIMD2<Float>(1,0)),("speech",SIMD2<Float>(0.15,0.6))] {
        renderer.fanMorphIndices=[0,1];renderer.fanMorphWeights=weights
        for (angle,yaw) in [("front",Float(0)),("quarter",-Float.pi/4),("left",-Float.pi/2)] {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
            try writePNG(texture,to:"\(folder)/\(name)-\(angle).png")
        }
    }
    renderer.fanMorphWeights = .zero
    for (index,name) in [(8,"sad"),(9,"epic-sad"),(10,"little-mouth"),(11,"oh-kiss"),(13,"mouth")] {
        renderer.fanExpressionOverrides=[2:1,index:1]
        for (angle,yaw) in [("front",Float(0)),("left",-Float.pi/2)] {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:800,height:640,at:0)
            try writePNG(texture,to:"\(folder)/\(name)-\(angle).png")
        }
    }
    renderer.fanExpressionOverrides=[2:1]
    renderer.fanMorphWeights = .zero;renderer.character.yaw=0;renderer.fanTeethEnabled=false
    let (bare,_)=try renderer.offscreen(width:800,height:640,at:0)
    try writePNG(bare,to:"\(folder)/closed-without-teeth.png")
    print("Rendered \(renderer.fanTeethIndexCount/3) tooth triangles across seven smile/jaw states in three angles and five additional expressions in two angles")
}
