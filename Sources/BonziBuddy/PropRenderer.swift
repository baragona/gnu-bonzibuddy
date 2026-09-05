import MetalKit
import simd

struct PropVertex { var position:SIMD4<Float>; var normal:SIMD4<Float>; var uv:SIMD4<Float> }
struct PropUniforms { var model:simd_float4x4; var color:SIMD4<Float>; var material:SIMD4<Float> }
struct PropDraw { var id:String; var kind:PropKind; var model:simd_float4x4 }

// Keeps retiring props alive briefly on interruption. They contract at their last
// attachment point instead of teleporting to a new routine's hand or disappearing.
final class PropMotion {
    private var action:Action?
    private var started:Double?
    private var lastTime:Double = -.infinity
    private var shown:[PropDraw]=[]
    private var retiring:[PropDraw]=[]
    private var retiredAt:Double=0
    func sample(action next:Action,started nextStart:Double,at time:Double,cues:[PropCue],rig:FanRig,bones:[Instance],yaw:Float,pitch:Float)->[PropDraw] {
        if time<lastTime { shown=[];retiring=[];action=nil;started=nil }
        if action != next || started != nextStart {
            retiring=shown;retiredAt=time;action=next;started=nextStart
        }
        var camera=bones[0].model
        camera.columns.3=[0,0,0,1]
        var draws:[PropDraw]=[]
        for cue in cues where cue.visibility>0.001 {
            var origin=bones[0].model*SIMD4(cue.offset,1)
            if case let .joint(joint)=cue.anchor {
                // Offsets stay in character axes; the anchor tracks the solved wrist.
                origin=bones[joint].model*rig.rest[joint].columns.3+camera*SIMD4(cue.offset,0)
            }
            let scale=cue.scale*max(0.001,cue.visibility)
            let scaling=simd_float4x4(diagonal:SIMD4(scale,1))
            let model=translation(SIMD3(origin.x,origin.y,origin.z))*camera*simd_float4x4(cue.rotation)*scaling
            draws.append(PropDraw(id:cue.id,kind:cue.kind,model:model))
        }
        let remaining=1-RoutineLibrary.smooth(time-retiredAt,0,0.20)
        if remaining>0.001 {
            for old in retiring where !draws.contains(where:{$0.id==old.id}) {
                var m=old.model
                m.columns.0 *= remaining;m.columns.1 *= remaining;m.columns.2 *= remaining
                draws.append(PropDraw(id:old.id,kind:old.kind,model:m))
            }
        } else { retiring=[] }
        shown=draws;lastTime=time
        return draws
    }
}

final class PropRenderer {
    let pipeline:MTLRenderPipelineState
    let shadowPipeline:MTLRenderPipelineState
    let vertices:MTLBuffer
    let indices:MTLBuffer
    let count:Int
    let globeTexture:MTLTexture
    init(device:MTLDevice,library:MTLLibrary,sampleCount:Int) throws {
        let descriptor=MTLRenderPipelineDescriptor()
        descriptor.vertexFunction=library.makeFunction(name:"propVertex")
        descriptor.fragmentFunction=library.makeFunction(name:"propFragment")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled=true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.rasterSampleCount=sampleCount
        pipeline=try device.makeRenderPipelineState(descriptor:descriptor)
        let shadow=MTLRenderPipelineDescriptor()
        shadow.vertexFunction=library.makeFunction(name:"propShadowVertex")
        shadow.depthAttachmentPixelFormat = .depth32Float
        shadowPipeline=try device.makeRenderPipelineState(descriptor:shadow)
        var v:[PropVertex]=[],idx:[UInt32]=[]
        let rings=48,sides=96
        for row in 0...rings {
            let t=Float(row)/Float(rings),latitude=Float.pi*(0.5-t)
            for column in 0...sides {
                let u=Float(column)/Float(sides),longitude=(u-0.5)*2*Float.pi
                let p=SIMD3<Float>(sin(longitude)*cos(latitude),sin(latitude),cos(longitude)*cos(latitude))
                v.append(PropVertex(position:SIMD4(p,1),normal:SIMD4(p,0),uv:[u,t,0,0]))
                if row<rings && column<sides {
                    let a=UInt32(row*(sides+1)+column),b=a+UInt32(sides+1)
                    if row>0 {idx += [a,b,a+1]}
                    if row<rings-1 {idx += [a+1,b,b+1]}
                }
            }
        }
        vertices=device.makeBuffer(bytes:v,length:v.count*MemoryLayout<PropVertex>.stride)!
        indices=device.makeBuffer(bytes:idx,length:idx.count*4)!;count=idx.count
        let url=Bundle.main.resourceURL?.appendingPathComponent("Props/globe-land.png")
        let path=url.flatMap { FileManager.default.fileExists(atPath:$0.path) ? $0:nil } ?? URL(fileURLWithPath:"Resources/Props/globe-land.png")
        globeTexture=try MTKTextureLoader(device:device).newTexture(URL:path,options:[.SRGB:false,.generateMipmaps:true])
    }
    func draw(_ draws:[PropDraw],encoder:MTLRenderCommandEncoder,shadow:Bool) {
        guard !draws.isEmpty else {return}
        encoder.setRenderPipelineState(shadow ? shadowPipeline:pipeline)
        encoder.setVertexBuffer(vertices,offset:0,index:0)
        if !shadow {encoder.setFragmentTexture(globeTexture,index:1)}
        for draw in draws {
            var uniforms=PropUniforms(model:draw.model,color:[1,1,1,1],material:[Float(draw.kind.rawValue),0,0,0])
            encoder.setVertexBytes(&uniforms,length:MemoryLayout<PropUniforms>.stride,index:5)
            if !shadow {encoder.setFragmentBytes(&uniforms,length:MemoryLayout<PropUniforms>.stride,index:5)}
            encoder.drawIndexedPrimitives(type:.triangle,indexCount:count,indexType:.uint32,indexBuffer:indices,indexBufferOffset:0)
        }
    }
}
