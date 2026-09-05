import AppKit
import MetalKit

func validateWritingTransfers() throws {
    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let renderer=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:URL(fileURLWithPath:"Resources/FanModel/FanRig.json"))
    renderer.fanLiveActions=true;renderer.fanTeethEnabled=true
    renderer.character.setHeadphonesEnabled(true,at:-5)
    renderer.character.setSunglassesEnabled(true,at:-5)
    renderer.character.play(.write,at:0,mode:.hold)
    let folder="Validation/WritingTransfers"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    var rendered=0
    for frame in 0...180 {
        let t=4.5+Double(frame)/60
        if frame==12 {renderer.character.request(.writePause,at:t,mode:.hold)}
        if frame==120 {renderer.character.request(.write,at:t,mode:.hold)}
        let selected=[0,12,59,60,66,90,119,120,126,150,180].contains(frame)
        for (view,yaw) in [Float(0),-Float.pi/4,-Float.pi/2].enumerated() {
            renderer.character.yaw=yaw
            let (texture,_)=try renderer.offscreen(width:400,height:320,at:t)
            if selected {try writePNG(texture,to:"\(folder)/transfer-\(frame)-\(view).png");rendered += 1}
        }
    }
    let report:[String:Any]=["timelineSamples":181,"renderedViews":543,"savedViews":rendered,"pauseRequestedAt":4.7,"pauseEnteredAt":5.5,"resumeRequestedAt":6.5,"note":"Visual sequence of in-place writing/pause/resume with both accessories; inspect alongside CPU scheduling and contact checks. Not a pixel-continuity or collision proof."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
}
