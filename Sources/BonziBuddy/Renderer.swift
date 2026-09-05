import AppKit
import MetalKit
import simd

struct RenderUniforms { var projection: simd_float4x4; var light: simd_float4x4; var ground: simd_float4x4; var options: SIMD4<Float>; var jawAxis: SIMD4<Float> }

struct FanEyeUniforms { var face:SIMD4<Float>; var closures:SIMD4<Float> }

struct FanMorphUniforms { var selection:SIMD4<UInt32>; var weights:(SIMD4<Float>,SIMD4<Float>,SIMD4<Float>,SIMD4<Float>); var face:SIMD4<Float> }

final class Renderer: NSObject, MTKViewDelegate {
    let device: MTLDevice
    let sampleCount: Int
    let queue: MTLCommandQueue
    let pipeline: MTLRenderPipelineState
    let shadowPipeline: MTLRenderPipelineState
    let groundPipeline: MTLRenderPipelineState
    let shadowTexture: MTLTexture
    let depthState: MTLDepthStencilState
    let vertices: MTLBuffer
    let indices: MTLBuffer
    let indexCount: Int
    let buffers: [MTLBuffer]
    let inFlight = DispatchSemaphore(value: 3)
    let character = Character()
    var fanRig: FanRig?
    var fanTeethEnabled=false
    var fanTeethVertices:MTLBuffer?
    var fanTeethIndices:MTLBuffer?
    var fanTeethIndexCount=0
    var fanValidationMotion=false
    var fanLiveActions=false
    let fanFaceMotion=FanFaceMotion()
    var propRenderer:PropRenderer?
    let propMotion=PropMotion()
    var fanNeutralSmile:Float=0.2
    var fanExpressionNames:[String]=[]
    var fanExpressionOverrides:[Int:Float]=[:]
    var fanAutoBlink=true
    var fanEyeCatchlights=true
    var fanUpperFaceLift=true
    var fanEyeClosure:Float=0
    var fanIndividualEyeClosure=SIMD2<Float>.zero
    var fanGaze=SIMD2<Float>(0,0)
    var fanMorphBuffer:MTLBuffer?
    var fanMorphVertexCount:UInt32=0
    var fanMorphCount:UInt32=0
    var fanMorphIndices=SIMD2<UInt32>(0,1)
    var fanMorphWeights=SIMD2<Float>(0,0)
    var fanPreview = false
    var shadowsEnabled = true
    var wireframe = false
    var frame = 0
    var epoch = CACurrentMediaTime()
    var onStats: ((String) -> Void)?
    var sampleStart = CACurrentMediaTime()
    var sampleFrames = 0
    var lastFrame: Double = 0
    var validationIntervals: [Double] = []
    private let presentationLock = NSLock()
    private var presentationTimes: [Double] = []
    private var cpuSubmissionMS:[Double]=[]
    private var drawableAcquireMS:[Double]=[],commandEncodingMS:[Double]=[]
    private var liveGPUTimeMS:[Double]=[]
    private var busySkips=0,drawableSkips=0
    func workloadReport()->[String:Any] {
        presentationLock.lock();let gpu=liveGPUTimeMS;presentationLock.unlock()
        func summary(_ values:[Double])->[String:Any] {
            let sorted=values.sorted()
            guard !sorted.isEmpty else { return ["samples":0] }
            return ["samples":sorted.count,"p50MS":sorted[sorted.count/2],"p95MS":sorted[Int(Double(sorted.count)*0.95)],"maxMS":sorted.last!]
        }
        return ["cpuSubmission":summary(cpuSubmissionMS),"drawableAcquire":summary(drawableAcquireMS),"commandEncodingAndCommit":summary(commandEncodingMS),"gpuExecution":summary(gpu),"inFlightLimitSkips":busySkips,"drawableUnavailableSkips":drawableSkips,"note":"Stage timings cover the 1200-frame presentation sampling window. Skip counters include warmup. CPU submission includes drawable acquisition and command encoding; GPU timings exclude compositor work."]
    }
    func presentationReport() -> [String:Any] {
        presentationLock.lock(); let captured=presentationTimes; presentationLock.unlock()
        let times=Array(Set(captured)).sorted()
        guard times.count>1 else { return ["available":false,"samples":times.count,"note":"The drawable did not provide enough nonzero presentation timestamps."] }
        let intervals=zip(times.dropFirst(),times).map { ($0-$1)*1000 }.sorted()
        return ["available":true,"samples":times.count,"averageFPS":Double(times.count-1)/(times.last!-times.first!),"intervalP50MS":intervals[intervals.count/2],"intervalP95MS":intervals[Int(Double(intervals.count)*0.95)],"maximumIntervalMS":intervals.last!,"intervalsOver12_5MS":intervals.filter{$0>12.5}.count,"duplicateTimestamps":captured.count-times.count,"source":"MTLDrawable.presentedTime after 120 submitted warmup frames"]
    }
    var intervals: [Double] = []
    var time: Double { CACurrentMediaTime()-epoch }
    init(device: MTLDevice, previewMesh: URL? = nil, rigURL: URL? = nil) throws {
        if let rigURL { fanRig=try FanRig(url:rigURL) }
        fanPreview = previewMesh != nil
        self.device = device
        sampleCount = device.supportsTextureSampleCount(4) ? 4 : (device.supportsTextureSampleCount(2) ? 2 : 1)
        guard let q = device.makeCommandQueue() else { throw failure("Metal command queue unavailable") }; queue = q
        #if SWIFT_PACKAGE
        let shaderURL = Bundle.module.url(forResource: "Shaders", withExtension: "metal")!
        #else
        let shaderURL = Bundle.main.url(forResource: "Shaders", withExtension: "metal") ?? URL(fileURLWithPath: "Sources/BonziBuddy/Shaders.metal")
        #endif
        let library = try device.makeLibrary(source: String(contentsOf: shaderURL, encoding: .utf8), options: nil)
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = library.makeFunction(name: rigURL == nil ? "vertexMain" : "fanVertexMain")
        descriptor.fragmentFunction = library.makeFunction(name: "fragmentMain")
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm
        descriptor.colorAttachments[0].isBlendingEnabled = true
        descriptor.colorAttachments[0].sourceRGBBlendFactor = .one
        descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
        descriptor.depthAttachmentPixelFormat = .depth32Float
        descriptor.rasterSampleCount = sampleCount
        pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        descriptor.vertexFunction = library.makeFunction(name:"groundVertex")
        descriptor.fragmentFunction = library.makeFunction(name:"groundFragment")
        groundPipeline = try device.makeRenderPipelineState(descriptor:descriptor)
        let shadowDescriptor = MTLRenderPipelineDescriptor()
        shadowDescriptor.vertexFunction = library.makeFunction(name:rigURL == nil ? "shadowVertex" : "fanShadowVertex")
        shadowDescriptor.depthAttachmentPixelFormat = .depth32Float
        shadowPipeline = try device.makeRenderPipelineState(descriptor:shadowDescriptor)
        let shadowMap = MTLTextureDescriptor.texture2DDescriptor(pixelFormat:.depth32Float,width:2048,height:2048,mipmapped:false)
        shadowMap.usage = [.renderTarget,.shaderRead]; shadowMap.storageMode = .private
        guard let map = device.makeTexture(descriptor:shadowMap) else { throw failure("Shadow map unavailable") }
        shadowTexture = map
        let depth = MTLDepthStencilDescriptor(); depth.depthCompareFunction = .less; depth.isDepthWriteEnabled = true
        depthState = device.makeDepthStencilState(descriptor: depth)!
        let meshURL = Bundle.main.url(forResource:"Bonzi",withExtension:"mesh") ?? URL(fileURLWithPath:"Resources/Bonzi.mesh")
        if rigURL != nil,let previewMesh {
            let mesh=try FanMeshData(url:previewMesh)
            vertices=mesh.vertices.withUnsafeBytes { device.makeBuffer(bytes:$0.baseAddress!,length:$0.count)! }
            indices=mesh.indices.withUnsafeBytes { device.makeBuffer(bytes:$0.baseAddress!,length:$0.count)! }
            indexCount=mesh.indexCount
            let data=try Data(contentsOf:rigURL!.deletingLastPathComponent().appendingPathComponent("FanMorphs.bin"))
            guard data.count>=16 else { throw failure("Truncated fan morphs") }
            let h=(0..<4).map { i in data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset:i*4,as:UInt32.self) } }
            guard h[0]==0x424D4F52,h[1]==1,h[2]==mesh.vertices.count/128,h[3]>0,data.count==16+Int(h[2])*Int(h[3])*32 else { throw failure("Invalid fan morph data") }
            guard h[3]<=16 else { throw failure("Too many facial targets") }
            let meta=try JSONSerialization.jsonObject(with:Data(contentsOf:rigURL!.deletingLastPathComponent().appendingPathComponent("FanMorphs.json"))) as? [String:Any]
            guard let names=meta?["names"] as? [String],names.count==Int(h[3]) else { throw failure("Missing facial target names") }
            fanExpressionNames=names
            let teethURL=rigURL!.deletingLastPathComponent().appendingPathComponent("FanTeeth.mesh")
            if FileManager.default.fileExists(atPath:teethURL.path) {
                let teeth=try FanMeshData(url:teethURL)
                fanTeethVertices=teeth.vertices.withUnsafeBytes { device.makeBuffer(bytes:$0.baseAddress!,length:$0.count)! }
                fanTeethIndices=teeth.indices.withUnsafeBytes { device.makeBuffer(bytes:$0.baseAddress!,length:$0.count)! }
                fanTeethIndexCount=teeth.indexCount
            }
            fanMorphVertexCount=h[2];fanMorphCount=h[3]
            fanMorphBuffer=data.withUnsafeBytes { device.makeBuffer(bytes:$0.baseAddress!.advanced(by:16),length:$0.count-16)! }
        } else {
        let mesh = try PolygonMesh.load(from:previewMesh ?? meshURL)
        vertices = device.makeBuffer(bytes:mesh.vertices,length:mesh.vertices.count*MemoryLayout<SkinVertex>.stride)!
        indices = device.makeBuffer(bytes:mesh.indices,length:mesh.indices.count*4)!
        indexCount = mesh.indices.count
        }
        buffers = (0..<3).map { _ in device.makeBuffer(length: 128*MemoryLayout<Instance>.stride, options: .storageModeShared)! }
        super.init()
        if rigURL != nil { propRenderer=try PropRenderer(device:device,library:library,sampleCount:sampleCount) }
    }
    func projection(width: Int, height: Int) -> simd_float4x4 {
        let aspect = Float(width)/Float(height), halfHeight: Float = 1.40
        var m = matrix_identity_float4x4
        m.columns.0.x = 1/(halfHeight*aspect); m.columns.1.y = 1/halfHeight
        m.columns.3.y = -0.205
        m.columns.2.z = -0.2; m.columns.3.z = 0.5
        return m
    }
    func encode(_ command: MTLCommandBuffer, pass: MTLRenderPassDescriptor, width: Int, height: Int, at time: Double, buffer: MTLBuffer) {
        var objects:[Instance]
        var automaticFace=FacialIntent()
        let playback=character.playbackSnapshot(at:time)
        if let fanRig {
            if fanLiveActions {
                fanRig.updateLiveAction(playback.action,started:playback.started,at:time)
                fanMorphIndices=[2,1]
                automaticFace=fanFaceMotion.sample(playback.action,started:playback.started,at:time)
                fanMorphWeights=[1,automaticFace.jawOpening]
            }
            if fanValidationMotion {
                character.yaw=0.65*sin(Float(time)*0.5)
                fanMorphIndices=[0,1];fanMorphWeights=[0.3,0.35+0.3*sin(Float(time)*8)]
            }
            objects=fanRig.instances(yaw:character.yaw,pitch:character.pitch,at:time)
        } else {
            objects=character.instances(at:time)
            if fanPreview { objects[0] = Instance(model:rotate(character.pitch,[1,0,0])*rotate(character.yaw,[0,1,0]),color:[1,1,1,1]) }
        }
        let props: [PropDraw]
        if let rig=fanRig,fanLiveActions {
            props=propMotion.sample(action:playback.action,started:playback.started,at:time,cues:rig.routine.props,rig:rig,bones:objects)
        } else { props=[] }
        objects.withUnsafeBytes { buffer.contents().copyMemory(from: $0.baseAddress!, byteCount: $0.count) }
        let lightDirection = normalize(SIMD3<Float>(-0.5,0.8,1.4))
        let right = normalize(cross(SIMD3<Float>(0,1,0),lightDirection)), up = cross(lightDirection,right)
        let lightMatrix = simd_float4x4(columns:(SIMD4(right.x/1.6,up.x/1.6,-lightDirection.x/5,0),SIMD4(right.y/1.6,up.y/1.6,-lightDirection.y/5,0),SIMD4(right.z/1.6,up.z/1.6,-lightDirection.z/5,0),SIMD4(0,0,0.5,1)))
        var uniforms = RenderUniforms(projection:projection(width:width,height:height),light:lightMatrix,ground:rotate(character.pitch,[1,0,0])*translation([0,-0.92,0]),options:[shadowsEnabled ? 1 : 0,0.28,character.mouthOpening,0],jawAxis:fanRig == nil ? normalize(objects[character.headBoneStart].model.columns.1) : SIMD4<Float>(0,1,0,0))
        var faceWeights=[Float](repeating:0,count:16)
        if fanLiveActions { faceWeights[0]=min(1,max(0,fanNeutralSmile+automaticFace.smileOffset)) }
        for lane in 0..<2 where fanMorphIndices[lane]<fanMorphCount { faceWeights[Int(fanMorphIndices[lane])]+=fanMorphWeights[lane] }
        for (index,value) in fanExpressionOverrides where index>=0 && index<Int(fanMorphCount) { faceWeights[index]=min(1,max(0,value)) }
        func chunk(_ i:Int)->SIMD4<Float> { SIMD4(faceWeights[i],faceWeights[i+1],faceWeights[i+2],faceWeights[i+3]) }
        var blink=(fanLiveActions || fanValidationMotion) && fanAutoBlink ? 1-BlinkAnimation.eyeOpen(at:time) : 0
        if fanLiveActions && fanAutoBlink { blink=max(blink,automaticFace.eyeClosure) }
        let gaze=fanGaze+automaticFace.gaze
        var morphUniforms=FanMorphUniforms(selection:[fanUpperFaceLift && fanRig?.sourcePose == false ? 1:0,0,fanMorphVertexCount,fanMorphCount],weights:(chunk(0),chunk(4),chunk(8),chunk(12)),face:[max(blink,fanEyeClosure),gaze.x,gaze.y,fanRig == nil ? 0:(fanEyeCatchlights ? 1:2)])
        let shadowPass = MTLRenderPassDescriptor()
        shadowPass.depthAttachment.texture = shadowTexture
        shadowPass.depthAttachment.loadAction = .clear; shadowPass.depthAttachment.storeAction = .store; shadowPass.depthAttachment.clearDepth = 1
        let shadowEncoder = command.makeRenderCommandEncoder(descriptor:shadowPass)!
        shadowEncoder.label = "Soft shadow depth"
        shadowEncoder.setRenderPipelineState(shadowPipeline); shadowEncoder.setDepthStencilState(depthState)
        shadowEncoder.setDepthBias(0.5,slopeScale:1,clamp:0.002)
        shadowEncoder.setVertexBuffer(vertices,offset:0,index:0);shadowEncoder.setVertexBuffer(buffer,offset:0,index:1)
        shadowEncoder.setVertexBytes(&uniforms,length:MemoryLayout<RenderUniforms>.stride,index:2)
        if let fanMorphBuffer {
            shadowEncoder.setVertexBuffer(fanMorphBuffer,offset:0,index:3)
            shadowEncoder.setVertexBytes(&morphUniforms,length:MemoryLayout<FanMorphUniforms>.stride,index:4)
        }
        if shadowsEnabled { shadowEncoder.drawIndexedPrimitives(type:.triangle,indexCount:indexCount,indexType:.uint32,indexBuffer:indices,indexBufferOffset:0) }
        if shadowsEnabled { drawFanTeeth(shadowEncoder);propRenderer?.draw(props,encoder:shadowEncoder,shadow:true) }
        shadowEncoder.endEncoding()
        let encoder = command.makeRenderCommandEncoder(descriptor: pass)!
        encoder.label = "Skinned mesh and soft desktop shadow"
        encoder.setRenderPipelineState(pipeline); encoder.setDepthStencilState(depthState)
        encoder.setTriangleFillMode(wireframe ? .lines : .fill)
        encoder.setVertexBuffer(vertices, offset: 0, index: 0)
        encoder.setVertexBuffer(buffer, offset: 0, index: 1)
        encoder.setVertexBytes(&uniforms,length:MemoryLayout<RenderUniforms>.stride,index:2)
        if let fanMorphBuffer {
            encoder.setVertexBuffer(fanMorphBuffer,offset:0,index:3)
            encoder.setVertexBytes(&morphUniforms,length:MemoryLayout<FanMorphUniforms>.stride,index:4)
        }
        var faceControl=FanEyeUniforms(face:fanRig == nil ? SIMD4<Float>(repeating:0) : morphUniforms.face,closures:fanRig == nil ? .zero : SIMD4(fanIndividualEyeClosure.x,fanIndividualEyeClosure.y,0,0))
        encoder.setFragmentBytes(&faceControl,length:MemoryLayout<FanEyeUniforms>.stride,index:3)
        encoder.setFragmentBytes(&uniforms,length:MemoryLayout<RenderUniforms>.stride,index:2)
        encoder.setFragmentTexture(shadowTexture,index:0)
        encoder.drawIndexedPrimitives(type: .triangle,indexCount: indexCount,indexType: .uint32,indexBuffer: indices,indexBufferOffset: 0)
        drawFanTeeth(encoder)
        propRenderer?.draw(props,encoder:encoder,shadow:false)
        if !wireframe && shadowsEnabled {
            encoder.setRenderPipelineState(groundPipeline)
            encoder.drawPrimitives(type:.triangle,vertexStart:0,vertexCount:6)
        }
        encoder.endEncoding()
    }
    private func drawFanTeeth(_ encoder:MTLRenderCommandEncoder) {
        guard fanTeethEnabled,let fanTeethVertices,let fanTeethIndices else { return }
        encoder.setVertexBuffer(fanTeethVertices,offset:0,index:0)
        encoder.drawIndexedPrimitives(type:.triangle,indexCount:fanTeethIndexCount,indexType:.uint32,indexBuffer:fanTeethIndices,indexBufferOffset:0)
    }
    func draw(in view: MTKView) {
        let submissionStart=CACurrentMediaTime()
        guard inFlight.wait(timeout: .now()) == .success else { busySkips += 1; return }
        guard let pass = view.currentRenderPassDescriptor, let drawable = view.currentDrawable, let command = queue.makeCommandBuffer() else { drawableSkips += 1; inFlight.signal(); return }
        let now = CACurrentMediaTime()
        if lastFrame > 0 { intervals.append((now-lastFrame)*1000); if frame > 120 && validationIntervals.count < 1200 { validationIntervals.append((now-lastFrame)*1000) } }; lastFrame = now
        encode(command,pass: pass,width: drawable.texture.width,height: drawable.texture.height,at: time,buffer: buffers[frame%3])
        let capture=frame>=120 && frame<1320
        if capture {
            drawable.addPresentedHandler { [weak self] presented in
                guard let self, presented.presentedTime>0 else { return }
                self.presentationLock.lock(); self.presentationTimes.append(presented.presentedTime); self.presentationLock.unlock()
            }
        }
        command.present(drawable)
        let semaphore = inFlight
        command.addCompletedHandler { [weak self] completed in
            if capture,completed.gpuEndTime>completed.gpuStartTime,let self {
                self.presentationLock.lock();self.liveGPUTimeMS.append((completed.gpuEndTime-completed.gpuStartTime)*1000);self.presentationLock.unlock()
            }
            semaphore.signal()
        }
        command.commit()
        if capture {
            let submitted=CACurrentMediaTime()
            cpuSubmissionMS.append((submitted-submissionStart)*1000)
            drawableAcquireMS.append((now-submissionStart)*1000)
            commandEncodingMS.append((submitted-now)*1000)
        }
        frame += 1; sampleFrames += 1
        if now-sampleStart >= 1 {
            let sorted = intervals.sorted(), p95 = sorted.isEmpty ? 0 : sorted[min(sorted.count-1,Int(Double(sorted.count)*0.95))]
            onStats?(String(format: "%.0f fps · %.1f ms p95",Double(sampleFrames)/(now-sampleStart),p95))
            intervals.removeAll(keepingCapacity: true); sampleFrames = 0; sampleStart = now
        }
    }
    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {}
    func offscreen(width: Int, height: Int, at time: Double) throws -> (MTLTexture, Double) {
        let d = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: width,height: height,mipmapped: false)
        d.usage = [.renderTarget]; d.storageMode = .shared
        guard let texture = device.makeTexture(descriptor: d) else { throw failure("Color texture unavailable") }
        let dd = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .depth32Float,width: width,height: height,mipmapped: false)
        dd.usage = [.renderTarget]; dd.storageMode = .private
        if sampleCount > 1 { dd.textureType = .type2DMultisample; dd.sampleCount = sampleCount }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].loadAction = .clear
        if sampleCount > 1 {
            let msaa = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm,width: width,height: height,mipmapped: false)
            msaa.textureType = .type2DMultisample; msaa.sampleCount = sampleCount
            msaa.usage = [.renderTarget]; msaa.storageMode = .private
            guard let multisampleTexture = device.makeTexture(descriptor: msaa) else { throw failure("MSAA texture unavailable") }
            pass.colorAttachments[0].texture = multisampleTexture
            pass.colorAttachments[0].resolveTexture = texture
            pass.colorAttachments[0].storeAction = .multisampleResolve
        } else {
            pass.colorAttachments[0].texture = texture; pass.colorAttachments[0].storeAction = .store
        }
        pass.colorAttachments[0].clearColor = MTLClearColorMake(0,0,0,0)
        pass.depthAttachment.texture = device.makeTexture(descriptor: dd); pass.depthAttachment.loadAction = .clear; pass.depthAttachment.clearDepth = 1
        let command = queue.makeCommandBuffer()!
        encode(command,pass: pass,width: width,height: height,at: time,buffer: buffers[0])
        command.commit(); command.waitUntilCompleted()
        if let error = command.error { throw error }
        return (texture,(command.gpuEndTime-command.gpuStartTime)*1000)
    }
}
func failure(_ message: String) -> NSError { NSError(domain: "BonziBuddy",code: 1,userInfo: [NSLocalizedDescriptionKey:message]) }
func writePNG(_ texture: MTLTexture, to path: String) throws {
    let w = texture.width, h = texture.height
    var bytes = [UInt8](repeating: 0,count:w*h*4)
    texture.getBytes(&bytes,bytesPerRow:w*4,from:MTLRegionMake2D(0,0,w,h),mipmapLevel:0)
    for i in stride(from:0,to:bytes.count,by:4) { bytes.swapAt(i,i+2) }
    let rep = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:w,pixelsHigh:h,bitsPerSample:8,samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:w*4,bitsPerPixel:32)!
    bytes.withUnsafeBytes { rep.bitmapData!.update(from: $0.bindMemory(to:UInt8.self).baseAddress!, count:bytes.count) }
    try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:path))
}
