import AppKit
import Foundation
let paths=CommandLine.arguments.count>2 ? Array(CommandLine.arguments[1...2]) : ["Validation/FanPreview/front.png","Validation/FanRigged/source-pose.png"]
let outputPath=CommandLine.arguments.count>3 ? CommandLine.arguments[3] : "Validation/FanRigged/bind-image-check.json"
let images=try paths.map { path -> NSBitmapImageRep in
    guard let image=NSBitmapImageRep(data:try Data(contentsOf:URL(fileURLWithPath:path))) else { fatalError("Invalid image: \(path)") };return image
}
let a=images[0],b=images[1]
precondition(a.pixelsWide==b.pixelsWide && a.pixelsHigh==b.pixelsHigh)
var maxError:Double=0,total:Double=0,samples=0
for y in 0..<a.pixelsHigh { for x in 0..<a.pixelsWide {
    let c=a.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!,d=b.colorAt(x:x,y:y)!.usingColorSpace(.deviceRGB)!
    let aa=c.alphaComponent,ba=d.alphaComponent
    for (u,v) in [(c.redComponent*aa,d.redComponent*ba),(c.greenComponent*aa,d.greenComponent*ba),(c.blueComponent*aa,d.blueComponent*ba),(aa,ba)] {
        let error=Double(abs(u-v));total+=error;maxError=max(maxError,error);samples+=1
    }
} }
let report:[String:Any]=["premultipliedRGBAMAE":total/Double(samples),"maxChannelError":maxError,"staticSource":paths[0],"skinnedSource":paths[1],"note":"Render consistency between baked and GPU-deformed geometry, not original Bonzi likeness."]
let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
try data.write(to:URL(fileURLWithPath:outputPath))
print(String(decoding:data,as:UTF8.self))
precondition(total/Double(samples)<0.001,"Skinning altered the source-pose render")
