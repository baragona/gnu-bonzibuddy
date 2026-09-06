import MetalKit
import simd

struct PropVertex {
    var position:SIMD4<Float>; var normal:SIMD4<Float>; var uv:SIMD4<Float>
    var openedPosition=SIMD4<Float>.zero
    var openedNormal=SIMD4<Float>.zero
}
struct PropUniforms { var model:simd_float4x4; var color:SIMD4<Float>; var material:SIMD4<Float>; var deformation:SIMD4<Float> }
final class PropRenderer {
    let pipeline:MTLRenderPipelineState
    let shadowPipeline:MTLRenderPipelineState
    let meshes:[PropKind:PropMesh]
    let globeTexture:MTLTexture
    init(device:MTLDevice,library:MTLLibrary,sampleCount:Int) throws {
        precondition(MemoryLayout<PropVertex>.stride==80 && MemoryLayout<PropUniforms>.stride==112,"Prop buffer layout must match Metal")
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
        meshes=try Dictionary(uniqueKeysWithValues:PropKind.allCases.map { ($0,try PropMesh(device:device,kind:$0)) })
        let url=Bundle.main.resourceURL?.appendingPathComponent("Props/globe-land.png")
        let path=url.flatMap { FileManager.default.fileExists(atPath:$0.path) ? $0:nil } ?? URL(fileURLWithPath:"Resources/Props/globe-land.png")
        globeTexture=try MTKTextureLoader(device:device).newTexture(URL:path,options:[.SRGB:false,.generateMipmaps:true])
    }
    func packedDeformation(_ deformation:PropDeformation)->(Float,SIMD4<Float>) {
        switch deformation {
        case .rigid: return (0,[0,0,0,1])
        case let .peel(openings): return (1,SIMD4(simd_clamp(openings,SIMD3(repeating:0),SIMD3(repeating:1)),1))
        case let .page(curl): return (3,[min(1,max(0,curl)),0,0,1])
        case let .vine(bend): return (4,[min(2.5,max(-2.5,bend)),VineGeometry.length,0,1])
        case let .fruit(remaining): return (2,[0,0,0,min(1,max(0.001,remaining))])
        }
    }
    func draw(_ draws:[PropDraw],encoder:MTLRenderCommandEncoder,shadow:Bool) {
        guard !draws.isEmpty else {return}
        encoder.setRenderPipelineState(shadow ? shadowPipeline:pipeline)
        if !shadow {encoder.setFragmentTexture(globeTexture,index:1)}
        for draw in draws {
            let mesh=meshes[draw.kind]!
            encoder.setVertexBuffer(mesh.vertices,offset:0,index:0)
            let (deformationMode,parameters)=packedDeformation(draw.deformation)
            var uniforms=PropUniforms(model:draw.model,color:[1,1,1,1],material:[Float(draw.kind.rawValue),deformationMode,draw.kind == .sunglasses ? 0.75:0,0],deformation:parameters)
            encoder.setVertexBytes(&uniforms,length:MemoryLayout<PropUniforms>.stride,index:5)
            if !shadow {encoder.setFragmentBytes(&uniforms,length:MemoryLayout<PropUniforms>.stride,index:5)}
            encoder.drawIndexedPrimitives(type:.triangle,indexCount:mesh.indexCount,indexType:.uint32,indexBuffer:mesh.indices,indexBufferOffset:0)
        }
    }
}
