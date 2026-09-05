import AppKit

extension AppDelegate {
    @objc func showExpressions() {
        if let expressionWindow { expressionWindow.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true);return }
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:440,height:560),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
        window.title="Bonzi’s expressions";window.isReleasedWhenClosed=false;window.center();expressionWindow=window
        let scroll=NSScrollView(frame:window.contentView!.bounds);scroll.autoresizingMask=[.width,.height];scroll.hasVerticalScroller=true
        let stack=NSStackView();stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=12;stack.edgeInsets=NSEdgeInsets(top:18,left:18,bottom:18,right:18)
        stack.translatesAutoresizingMaskIntoConstraints=false
        let intro=NSTextField(wrappingLabelWithString:"Combine expressions with the sliders. Reset restores his friendly resting face.");intro.preferredMaxLayoutWidth=380;stack.addArrangedSubview(intro)
        func slider(_ label:String,_ tag:Int,_ initial:Double,_ minimum:Double=0) {
            let row=NSStackView();row.orientation = .horizontal;row.spacing=12
            let title=NSTextField(labelWithString:label);title.widthAnchor.constraint(equalToConstant:155).isActive=true
            let control=NSSlider(value:initial,minValue:minimum,maxValue:1,target:self,action:#selector(expressionChanged(_:)));control.tag=tag;control.widthAnchor.constraint(equalToConstant:200).isActive=true
            control.setAccessibilityLabel(label);expressionSliders[tag]=control;row.addArrangedSubview(title);row.addArrangedSubview(control);stack.addArrangedSubview(row)
        }
        for (i,name) in renderer.fanExpressionNames.enumerated() {
            let label=name=="?" ? "Brow variant 1" : name=="¿" ? "Brow variant 2" : name.capitalized
            slider(label,i,Double(renderer.fanExpressionOverrides[i] ?? (i==2 ? 1:i==0 ? renderer.fanNeutralSmile:0)))
        }
        slider("Both eyes closed",100,Double(renderer.fanEyeClosure))
        slider("Left eye closed",103,Double(renderer.fanIndividualEyeClosure.x))
        slider("Right eye closed",104,Double(renderer.fanIndividualEyeClosure.y))
        slider("Gaze horizontal",101,Double(renderer.fanGaze.x),-1)
        slider("Gaze vertical",102,Double(renderer.fanGaze.y),-1)
        let automatic=NSButton(checkboxWithTitle:"Automatic blinking",target:self,action:#selector(toggleFanBlink(_:)));automatic.state=renderer.fanAutoBlink ? .on:.off;stack.addArrangedSubview(automatic)
        let reset=NSButton(title:"Reset expression",target:self,action:#selector(resetExpression));reset.bezelStyle = .rounded;stack.addArrangedSubview(reset)
        scroll.documentView=stack;window.contentView!.addSubview(scroll)
        NSLayoutConstraint.activate([stack.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor)])
        window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        window.contentView!.layoutSubtreeIfNeeded()
        scroll.contentView.scroll(to:NSPoint(x:0,y:stack.isFlipped ? 0:max(0,stack.frame.height-scroll.contentView.bounds.height)))
        scroll.reflectScrolledClipView(scroll.contentView)
        if CommandLine.arguments.contains("--validate-expression-ui") {
            DispatchQueue.main.asyncAfter(deadline:.now()+1) {
                guard let view=window.contentView else { return }
                view.layoutSubtreeIfNeeded()
                guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else { return }
                view.cacheDisplay(in:view.bounds,to:bitmap)
                try? FileManager.default.createDirectory(atPath:"Validation/FanFace",withIntermediateDirectories:true)
                try? bitmap.representation(using:.png,properties:[:])?.write(to:URL(fileURLWithPath:"Validation/FanFace/controls.png"))
            }
        }
    }
    @objc func expressionChanged(_ sender:NSSlider) {
        let value=sender.floatValue
        switch sender.tag {
        case 100:renderer.fanEyeClosure=value
        case 101:renderer.fanGaze.x=value
        case 102:renderer.fanGaze.y=value
        case 103:renderer.fanIndividualEyeClosure.x=value
        case 104:renderer.fanIndividualEyeClosure.y=value
        default:renderer.fanExpressionOverrides[sender.tag]=value
        }
    }
    @objc func toggleFanBlink(_ sender:NSButton) { renderer.fanAutoBlink=sender.state == .on }
    @objc func resetExpression() {
        renderer.fanExpressionOverrides.removeAll();renderer.fanEyeClosure=0;renderer.fanIndividualEyeClosure = .zero;renderer.fanGaze = .zero
        for (tag,slider) in expressionSliders { slider.doubleValue=tag==2 ? 1:tag==0 ? Double(renderer.fanNeutralSmile):0 }
    }
}
