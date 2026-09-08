import AppKit
import MetalKit
import AVFoundation

final class BuddyPanel: NSPanel { override var canBecomeKey: Bool { true } }
final class BuddyView: MTKView {
    var showMenu: ((NSEvent) -> Void)?
    var clicked: (() -> Void)?
    override func mouseDown(with event: NSEvent) { if event.clickCount == 2 { clicked?() } else { window?.performDrag(with: event) } }
    override func rightMouseDown(with event: NSEvent) { showMenu?(event) }
    override var acceptsFirstResponder: Bool { true }
}
final class AppDelegate: NSObject, NSApplicationDelegate, AVSpeechSynthesizerDelegate {
    var panel: BuddyPanel!
    var renderer: Renderer!
    var view: BuddyView!
    var status: NSStatusItem!
    var control: NSWindow!
    var stats: NSTextField!
    var bubble: NSTextField!
    var input: NSTextField!
    var reminderStore:ReminderStore?
    var reminderTimer:Timer?
    var reminderLoadError:String?
    var reminderWindow:NSWindow?
    var reminderList:NSStackView?
    var reminderInput:NSTextField!
    var reminderDate:NSDatePicker!
    var expressionWindow:NSWindow?
    var expressionSliders:[Int:NSSlider]=[:]
    let speech = AVSpeechSynthesizer()
    var bubbleTimer: Timer?
    var visibilityTimer:Timer?
    var muted = UserDefaults.standard.bool(forKey:"muted")
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            guard let device = MTLCreateSystemDefaultDevice() else { throw failure("This Mac does not expose a Metal GPU.") }
            let useFan = !CommandLine.arguments.contains("--procedural-model") || CommandLine.arguments.contains("--fan-model") || CommandLine.arguments.contains("--onscreen-fan-validation")
            let fanValidation=useFan && (CommandLine.arguments.contains("--onscreen-fan-validation") || CommandLine.arguments.contains("--onscreen-validation"))
            if useFan {
                let assets=Bundle.main.resourceURL!.appendingPathComponent("FanModel")
                renderer=try Renderer(device:device,previewMesh:assets.appendingPathComponent("FanRigged.mesh"),rigURL:assets.appendingPathComponent("FanRig.json"))
                renderer.fanValidationMotion=false
                renderer.fanLiveActions=true
                renderer.fanTeethEnabled=true
            } else { renderer = try Renderer(device: device) }
            setupBuddy(device); setupMenu(); setupControls()
            if CommandLine.arguments.contains("--validate-presence-ui") {validatePresenceWindow();return}
            setupReminderService()
            if CommandLine.arguments.contains("--show-reminders") { showReminders() }
            if CommandLine.arguments.contains("--validate-reminder-ui") { validateReminderWindow() }
            if CommandLine.arguments.contains("--show-expressions") || CommandLine.arguments.contains("--validate-expression-ui") { showExpressions() }
            speech.delegate = self
            say("Hello! I'm Bonzi. Double-click me to chat, or right-click for a little fun.", aloud:false)
            renderer.character.play(.wave,at:renderer.time)
            if CommandLine.arguments.contains("--onscreen-validation") || fanValidation {
                let workload:[Action]=[.wave,.clap,.shrug,.lookLeft,.lookRight,.dance,.think,.surprised,.speak,.idle]
                for (index,action) in workload.enumerated() {
                    Timer.scheduledTimer(withTimeInterval:Double(index)+1,repeats:false) { [weak self] _ in
                        guard let self else { return }
                        self.renderer.character.play(action,at:self.renderer.time)
                    }
                }
                Timer.scheduledTimer(withTimeInterval:12,repeats:false) { [weak self] _ in
                    guard let self else { return }
                    let values = self.renderer.validationIntervals.sorted()
                    var report: [String:Any] = ["renderer":fanValidation ? "imported fan mesh, eight influences, 15 available facial targets, blink and teeth" : "skinned polygon mesh","msaaSampleCount":self.renderer.sampleCount,"softShadows":self.renderer.shadowsEnabled,"frames":values.count,"averageFPS":values.isEmpty ? 0 : 1000/(values.reduce(0,+)/Double(values.count)),"frameIntervalP95MS":values.isEmpty ? 0 : values[Int(Double(values.count)*0.95)],"screenMaximumFPS":self.panel.screen?.maximumFramesPerSecond ?? 0,"targetFPS":120,"presentation":self.renderer.presentationReport(),"stages":self.renderer.workloadReport(),"workload":workload.map{$0.rawValue},"secondsPerAction":1,"workloadStartSeconds":1,"note":"Top-level FPS/intervals measure draw callbacks; the presentation object separately measures drawable presentation timestamps." ]
                    report["device"]=self.renderer.device.name
                    report["drawableResolution"]=[Int(self.view.drawableSize.width),Int(self.view.drawableSize.height)]
                    if fanValidation { report["neutralSmile"]=self.renderer.fanNeutralSmile; report["teethTriangles"]=self.renderer.fanTeethIndexCount/3 }
                    do { let data = try JSONSerialization.data(withJSONObject:report,options:[.prettyPrinted,.sortedKeys]); try data.write(to:URL(fileURLWithPath:fanValidation ? "Validation/FanRigged/onscreen-performance.json" : "Validation/onscreen-performance.json")); print(String(decoding:data,as:UTF8.self)) } catch { fputs("Onscreen report failed: \(error)\n",stderr) }
                    NSApp.terminate(nil)
                }
            }
        } catch { let alert = NSAlert(error:error); alert.runModal(); NSApp.terminate(nil) }
    }
    func setupBuddy(_ device: MTLDevice) {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x:0,y:0,width:1200,height:800)
        panel = BuddyPanel(contentRect:NSRect(x:screen.maxX-430,y:screen.minY+35,width:400,height:400),styleMask:[.borderless,.nonactivatingPanel],backing:.buffered,defer:false)
        panel.isOpaque = false; panel.backgroundColor = .clear; panel.hasShadow = false; panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces,.fullScreenAuxiliary]; panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        let root = NSView(frame:NSRect(x:0,y:0,width:400,height:400))
        view = BuddyView(frame:NSRect(x:0,y:0,width:400,height:320),device:device)
        view.sampleCount = renderer.sampleCount
        view.colorPixelFormat = .bgra8Unorm; view.depthStencilPixelFormat = .depth32Float
        view.clearColor = MTLClearColorMake(0,0,0,0); view.wantsLayer = true; view.layer?.isOpaque = false
        view.preferredFramesPerSecond = 120; view.delegate = renderer
        view.setAccessibilityLabel("Bonzi, a purple 3D gorilla. Double-click to open controls.")
        view.clicked = { [weak self] in self?.showControls() }
        view.showMenu = { [weak self] event in guard let self else { return }; NSMenu.popUpContextMenu(self.makeMenu(),with:event,for:self.view) }
        root.addSubview(view)
        bubble = NSTextField(wrappingLabelWithString:"")
        bubble.frame = NSRect(x:60,y:322,width:280,height:72)
        bubble.font = .systemFont(ofSize:13); bubble.textColor = NSColor(calibratedWhite:0.15,alpha:1)
        bubble.drawsBackground = true; bubble.backgroundColor = NSColor(calibratedRed:1,green:0.99,blue:0.89,alpha:1)
        bubble.wantsLayer = true; bubble.layer?.cornerRadius = 10; bubble.layer?.masksToBounds = true
        root.addSubview(bubble); panel.contentView = root; panel.orderFrontRegardless()
    }
    func setupMenu() {
        status = NSStatusBar.system.statusItem(withLength:NSStatusItem.variableLength)
        status.button?.title = "Bonzi"; status.button?.toolTip = "Your local desktop buddy"
        status.menu = makeMenu()
    }
    func makeMenu() -> NSMenu {
        let menu = NSMenu()
        func item(_ title:String,_ selector:Selector,_ key:String = "") { let i = NSMenuItem(title:title,action:selector,keyEquivalent:key); i.target = self; menu.addItem(i) }
        item("Chat with Bonzi…",#selector(showControls))
        item("Reminders…",#selector(showReminders))
        if renderer.fanRig != nil { item("Facial expressions…",#selector(showExpressions)) }
        let views=NSMenu(),viewItem=NSMenuItem(title:"View from",action:nil,keyEquivalent:"")
        for (title,yaw,pitch) in [("Front",Float(0),Float(0.18)),("Three-quarter",Float.pi/4,Float(0.18)),("Left",-Float.pi/2,Float(0.18)),("Right",Float.pi/2,Float(0.18)),("Back",Float.pi,Float(0.18)),("Above",Float.pi/4,Float(0.4))] {
            let angle=NSMenuItem(title:title,action:#selector(setViewAngle(_:)),keyEquivalent:"")
            angle.target=self;angle.representedObject=[yaw,pitch]
            if abs(renderer.character.yaw-yaw)<0.001 && abs(renderer.character.pitch-pitch)<0.001 { angle.state = .on }
            views.addItem(angle)
        }
        viewItem.submenu=views;menu.addItem(viewItem)
        menu.addItem(.separator())
        for action in Action.allCases where action != .idle && action != .speak && action != .sunglasses && action != .headphones {
            let i = NSMenuItem(title:action.rawValue,action:#selector(animate(_:)),keyEquivalent:""); i.representedObject = action.rawValue; i.target = self; menu.addItem(i)
        }
        let glasses=NSMenuItem(title:"Sunglasses",action:#selector(toggleSunglasses),keyEquivalent:"")
        glasses.target=self;glasses.state=renderer.character.sunglassesEnabled ? .on:.off;menu.addItem(glasses)
        let headphones=NSMenuItem(title:"Headphones",action:#selector(toggleHeadphones),keyEquivalent:"")
        headphones.target=self;headphones.state=renderer.character.headphonesEnabled ? .on:.off;menu.addItem(headphones)
        item("Return to rest",#selector(finishRoutine))
        item("Tell a joke",#selector(joke)); item("Tell the time",#selector(tellTime))
        menu.addItem(.separator())
        item(muted ? "Enable voice" : "Mute voice",#selector(toggleMute))
        item(renderer.character.requestedVisible ? "Hide Bonzi" : "Show Bonzi",#selector(toggleVisible))
        item("Quit GNU BonziBuddy",#selector(quit),"q")
        return menu
    }
    func setupControls() {
        control = NSWindow(contentRect:NSRect(x:0,y:0,width:430,height:280),styleMask:[.titled,.closable,.miniaturizable],backing:.buffered,defer:false)
        control.title = "GNU BonziBuddy"; control.isReleasedWhenClosed = false; control.center()
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 16; stack.translatesAutoresizingMaskIntoConstraints = false
        let title = NSTextField(labelWithString:"A familiar friend. A fresh start."); title.font = .boldSystemFont(ofSize:21)
        stack.addArrangedSubview(title)
        let subtitle = NSTextField(wrappingLabelWithString:"Everything stays on your Mac. Type something for Bonzi to say, or choose an animation."); subtitle.textColor = .secondaryLabelColor; stack.addArrangedSubview(subtitle)
        input = NSTextField(string:""); input.placeholderString = "Hello, Bonzi!"; input.target = self; input.action = #selector(speakInput); stack.addArrangedSubview(input)
        let buttons = NSStackView(); buttons.spacing = 8
        for (title,selector) in [("Say it",#selector(speakInput)),("Joke",#selector(joke)),("Wave",#selector(wave))] { let b = NSButton(title:title,target:self,action:selector); b.bezelStyle = .rounded; buttons.addArrangedSubview(b) }
        stack.addArrangedSubview(buttons)
        stats = NSTextField(labelWithString:"Metal · targeting 120 fps"); stats.font = .monospacedDigitSystemFont(ofSize:11,weight:.regular); stats.textColor = .secondaryLabelColor; stack.addArrangedSubview(stats)
        renderer.onStats = { [weak self] text in self?.stats.stringValue = "Metal · \(text) · target 120 fps" }
        control.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo:control.contentView!.leadingAnchor,constant:24),stack.trailingAnchor.constraint(equalTo:control.contentView!.trailingAnchor,constant:-24),stack.topAnchor.constraint(equalTo:control.contentView!.topAnchor,constant:24),input.widthAnchor.constraint(equalTo:stack.widthAnchor)])
    }
    @objc func showControls() { control.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps:true) }
    @objc func setViewAngle(_ sender:NSMenuItem) {
        guard let angles=sender.representedObject as? [Float],angles.count==2 else { return }
        renderer.character.yaw=angles[0];renderer.character.pitch=angles[1]
        status.menu=makeMenu()
    }
    @objc func toggleHeadphones() {renderer.character.setHeadphonesEnabled(!renderer.character.headphonesEnabled,at:renderer.time);status.menu=makeMenu()}
    @objc func toggleSunglasses() { renderer.character.setSunglassesEnabled(!renderer.character.sunglassesEnabled,at:renderer.time);status.menu=makeMenu() }
    @objc func animate(_ sender:NSMenuItem) { guard let name = sender.representedObject as? String, let a = Action(rawValue:name) else { return }; renderer.character.request(a,at:renderer.time,mode:RoutineLibrary.definitions[a]?.holdRange == nil ? .once:.hold) }
    @objc func finishRoutine() { if !renderer.character.finishRoutine(at:renderer.time) {renderer.character.request(.idle,at:renderer.time)} }
    @objc func wave() { renderer.character.request(.wave,at:renderer.time) }
    @objc func speakInput() { let text = input.stringValue.trimmingCharacters(in:.whitespacesAndNewlines); if !text.isEmpty { say(String(text.prefix(2000))); input.stringValue = "" } }
    @objc func joke() { say(["Why did the banana go to the doctor? It wasn't peeling well!","I tried to catch some fog. I mist.","Why do programmers prefer dark mode? Because light attracts bugs!"].randomElement()!) }
    @objc func tellTime() { say("It's \(DateFormatter.localizedString(from:Date(),dateStyle:.none,timeStyle:.short)). Time flies when you're a gorilla!") }
    func say(_ text:String,aloud:Bool = true) {
        bubbleTimer?.invalidate(); bubble.stringValue = text; bubble.isHidden = false
        bubbleTimer = Timer.scheduledTimer(withTimeInterval:max(8,min(30,Double(text.count)/12)),repeats:false) { [weak self] _ in self?.bubble.isHidden = true }
        if aloud && !muted { speech.stopSpeaking(at:.immediate); let utterance = AVSpeechUtterance(string:text); utterance.rate = 0.43; utterance.pitchMultiplier = 0.85; speech.speak(utterance) }
    }
    func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didStart utterance:AVSpeechUtterance) { renderer.character.play(.speak,at:renderer.time) }
    func speechSynthesizer(_ synthesizer:AVSpeechSynthesizer,didFinish utterance:AVSpeechUtterance) { renderer.character.play(.idle,at:renderer.time) }
    @objc func toggleMute() { muted.toggle(); UserDefaults.standard.set(muted,forKey:"muted"); if muted { speech.stopSpeaking(at:.immediate); renderer.character.play(.idle,at:renderer.time) }; status.menu = makeMenu() }
    func syncVisibility() {
        visibilityTimer?.invalidate();visibilityTimer=nil
        let time=renderer.time,visible=renderer.character.isVisible(at:time)
        if visible {panel.orderFrontRegardless();view.isPaused=false}
        else {panel.orderOut(nil);view.isPaused=true}
        if let next=renderer.character.nextVisibilityChange(after:time) {
            visibilityTimer=Timer.scheduledTimer(withTimeInterval:max(0.001,next-time),repeats:false) { [weak self] _ in self?.syncVisibility() }
        }
        status.menu=makeMenu()
    }
    @objc func toggleVisible() {
        renderer.character.setVisible(!renderer.character.requestedVisible,at:renderer.time,entrance:renderer.fanRig == nil ? nil:.vineEntrance)
        syncVisibility()
    }
    @objc func quit() { NSApp.terminate(nil) }
}
