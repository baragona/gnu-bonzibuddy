import simd

enum GlobeRoutine {
    static let duration=6.2
    static func sample(at t:Double)->RoutinePose {
        // Search: raise, reveal, spin while following the globe, lower and stow.
        // Authored continuous poses follow the extracted Search/SearchingReturn beats.
        let weight=RoutineLibrary.smooth(t,0,0.75)*(1-RoutineLibrary.smooth(t,5.4,6.2))
        let reveal=RoutineLibrary.smooth(t,0.55,0.85)*(1-RoutineLibrary.smooth(t,5.25,5.55))
        let left=HandIntent(wrist:[-0.88,0.32,0.32],fingers:[-0.15,1,0],palm:[0,0,1],weight:weight,pointing:true)
        let right=HandIntent(wrist:[-0.33,0.25,0.46],fingers:[-0.8,0.45,0],palm:[0,0,1],openness:0.65,weight:weight,pointing:true)
        let spin=Float(max(0,t-0.85))*2.8*RoutineLibrary.smooth(t,0.85,1.2)
        let globe=PropCue(id:"search.globe",kind:.globe,anchor:.attachment(.wrist(.left)),offset:[-0.025,0.50,0],rotation:simd_quatf(angle:spin,axis:[0,1,0]),scale:SIMD3(repeating:0.35),visibility:reveal)
        return RoutinePose(hands:[.left:left,.right:right],bodyYaw:-0.65*weight,headYaw:-0.10*weight,headTilt:0.04*weight,face:FacialIntent(gaze:[-0.40*weight,0.15*weight]),props:reveal>0 ? [globe]:[])
    }
}
