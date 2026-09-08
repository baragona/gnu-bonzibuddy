import AppKit

extension AppDelegate {
    func validatePresenceWindow() {
        func require(_ condition:Bool,_ message:String) {
            if !condition {fputs("Presence UI failed: \(message)\n",stderr);exit(1)}
        }
        toggleVisible()
        require(!panel.isVisible && view.isPaused,"Hide did not pause and remove the panel")
        require(status.menu!.items.contains(where:{$0.title=="Show Bonzi"}),"Hidden menu has no Show command")
        toggleVisible()
        require(panel.isVisible && !view.isPaused,"Show did not resume the panel")
        require(renderer.character.playbackSnapshot(at:renderer.time).action == .vineEntrance,"Show did not launch entrance")
        toggleVisible() // Wait for the entrance to land before hiding.
        require(panel.isVisible && !view.isPaused && visibilityTimer != nil,"Hide cut off the entrance")
        require(status.menu!.items.contains(where:{$0.title=="Show Bonzi"}),"Pending Hide cannot be cancelled from the menu")
        Timer.scheduledTimer(withTimeInterval:VineEntranceRoutine.duration+0.2,repeats:false) { [weak self] _ in
            guard let self else {exit(1)}
            require(!self.panel.isVisible && self.view.isPaused,"Scheduled Hide left the window or renderer active")
            do {
                let folder="Validation/Presence"
                try FileManager.default.createDirectory(atPath:folder,withIntermediateDirectories:true)
                let report:[String:Any]=["menuRecoveryPassed":true,"windowPauseResumePassed":true,"scheduledHideTimerPassed":true,"showStartsEntrancePassed":true,"note":"Invokes the real AppKit menu target and verifies panel visibility, MTKView pause state, menu labels and the completion timer. Does not exercise physical mouse clicks or establish display pacing."]
                let data=try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys])
                try data.write(to:URL(fileURLWithPath:"\(folder)/ui-checks.json"));print(String(decoding:data,as:UTF8.self))
                NSApp.terminate(nil)
            } catch {fputs("Presence UI report failed: \(error)\n",stderr);exit(1)}
        }
    }
}
