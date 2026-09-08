import MetalKit

func validatePresence() throws {
    func require(_ value:Bool,_ message:String) throws {if !value {throw failure(message)}}
    var timeline=PresencePlayback()
    timeline.schedule(false,requestedAt:1,effectiveAt:3)
    try require(timeline.isVisible(at:2) && !timeline.isVisible(at:30) && timeline.isVisible(at:2),"Visibility sampling consumed its boundary")
    timeline.schedule(true,requestedAt:2,effectiveAt:2)
    try require(timeline.isVisible(at:30) && timeline.nextChange(after:2)==nil,"Cancel hide left a future hidden event")

    var sameTime=PresencePlayback()
    sameTime.schedule(false,requestedAt:0,effectiveAt:0)
    sameTime.schedule(true,requestedAt:0,effectiveAt:2)
    try require(!sameTime.isVisible(at:1),"Queued same-timestamp Show exposed the actor early")
    sameTime.schedule(false,requestedAt:0,effectiveAt:0)
    try require(!sameTime.isVisible(at:0) && !sameTime.isVisible(at:30),"Same-timestamp cancellation lost the hidden state")

    var player=CharacterPlayback()
    player.play(.juggle,at:0)
    player.setVisible(false,at:1)
    let hiddenAt=player.nextVisibilityChange(after:1)!
    try require(abs(hiddenAt-Action.juggle.duration)<0.00001 && player.isVisible(at:hiddenAt-0.001) && !player.isVisible(at:hiddenAt),"Hide interrupted prop stow")
    player.setVisible(true,at:2)
    try require(player.isVisible(at:30),"Show failed to cancel pending hide")

    var accessories=CharacterPlayback()
    accessories.setSunglassesEnabled(true,at:0)
    accessories.setHeadphonesEnabled(true,at:0)
    accessories.setVisible(false,at:0.1)
    let afterTransfers=accessories.nextVisibilityChange(after:0.1)!
    try require(afterTransfers>2 && accessories.isVisible(at:afterTransfers-0.001) && !accessories.isVisible(at:afterTransfers),"Hide cut off an accessory transfer")
    try require(accessories.sunglassesEnabled && accessories.headphonesEnabled,"Hiding cleared accessory intent")
    accessories.setVisible(true,at:10)
    accessories.request(.wave,at:10.1)
    try require(accessories.playbackSnapshot(at:11).action == .vineEntrance && accessories.playbackSnapshot(at:12.71).action == .wave,"Action request replaced the entrance")

    var deferred=CharacterPlayback()
    deferred.setVisible(false,at:0)
    deferred.setSunglassesEnabled(true,at:1)
    deferred.setVisible(true,at:1.1)
    let appeared=deferred.nextVisibilityChange(after:1.1)!
    try require(!deferred.isVisible(at:appeared-0.001) && deferred.isVisible(at:appeared),"Show exposed an unfinished hidden transfer")
    deferred.play(.speak,at:1.2)
    try require(deferred.playbackSnapshot(at:appeared+0.2).action == .vineEntrance && deferred.playbackSnapshot(at:appeared+2.71).action == .speak,"Direct play stole a scheduled entrance")
    deferred.setVisible(false,at:1.3)
    try require(!deferred.isVisible(at:30),"Cancelling a queued show resurrected the actor")

    guard let device=MTLCreateSystemDefaultDevice() else {throw failure("Metal unavailable")}
    let url=URL(fileURLWithPath:"Resources/FanModel/FanRig.json")
    func renderer() throws -> Renderer {
        let r=try Renderer(device:device,previewMesh:URL(fileURLWithPath:"Resources/FanModel/FanRigged.mesh"),rigURL:url)
        r.fanLiveActions=true;r.fanTeethEnabled=true
        r.character.setSunglassesEnabled(true,at:-5);r.character.setHeadphonesEnabled(true,at:-5)
        return r
    }
    let r=try renderer()
    _=try r.offscreen(width:400,height:320,at:0)
    r.character.setVisible(false,at:1)
    var maximumHiddenAlpha:UInt8=0
    for t in [1.0,5,50,2] {
        let (texture,_)=try r.offscreen(width:400,height:320,at:t)
        var bytes=[UInt8](repeating:0,count:400*320*4)
        texture.getBytes(&bytes,bytesPerRow:1600,from:MTLRegionMake2D(0,0,400,320),mipmapLevel:0)
        for i in stride(from:3,to:bytes.count,by:4) {maximumHiddenAlpha=max(maximumHiddenAlpha,bytes[i])}
    }
    try require(maximumHiddenAlpha==0,"Hidden body, prop, tooth or shadow pixels remain")
    // Simulate a paused desktop: no frame is encoded while hidden. First Show
    // must start at the tiny entrance pose, not blend from the old full-size body.
    let paused=try renderer(),fresh=try renderer()
    _=try paused.offscreen(width:400,height:320,at:0)
    paused.character.setVisible(false,at:1);paused.character.setVisible(true,at:5)
    fresh.character.play(.vineEntrance,at:5)
    var oldBones:[Instance]=[],freshBones:[Instance]=[]
    paused.onAuditFrame={oldBones=$0;_=$1;_=$2};fresh.onAuditFrame={freshBones=$0;_=$1;_=$2}
    _=try paused.offscreen(width:400,height:320,at:5)
    _=try fresh.offscreen(width:400,height:320,at:5)
    var error:Float=0
    for i in oldBones.indices {for c in 0..<4 {for j in 0..<4 {error=max(error,abs(oldBones[i].model[c][j]-freshBones[i].model[c][j]))}}}
    try require(error<0.00001,"Show blended from a stale hidden pose")
    let folder="Validation/Presence"
    try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
    let report:[String:Any]=["hideWaitsForStow":true,"hideWaitsForTransfers":true,"accessoryIntentPreserved":true,"queuedShowCancellationPassed":true,"entranceReservationPassed":true,"maximumHiddenAlpha":maximumHiddenAlpha,"pausedShowMatrixError":error,"note":"Playback scheduling plus actual transparent Metal output, including worn accessories and shadows. Show uses the entrance; Hide currently waits for stow then hides, without exit choreography."]
    let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
    try data.write(to:URL(fileURLWithPath:"\(folder)/checks.json"));print(String(decoding:data,as:UTF8.self))
}
