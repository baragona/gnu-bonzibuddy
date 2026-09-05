import AppKit

extension AppDelegate {
    func setupReminderService() {
        do {
            if CommandLine.arguments.contains("--validate-reminder-ui") {
                reminderStore=try ReminderStore { _ in }
                try reminderStore?.add("Stretch and take a short break",due:Date().addingTimeInterval(0.5))
                try reminderStore?.add("Check the kettle",due:Date().addingTimeInterval(300))
                muted=true
            } else {
                reminderStore=try ReminderStore(data:UserDefaults.standard.data(forKey:"localReminders.v1")) { UserDefaults.standard.set($0,forKey:"localReminders.v1") }
            }
            reminderTimer=Timer.scheduledTimer(withTimeInterval:1,repeats:true) { [weak self] _ in self?.deliverReminders() }
        } catch { reminderLoadError="Saved reminders could not be read. Your saved data has been kept." }
    }
    @objc func showReminders() {
        if reminderWindow==nil {
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:460,height:480),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
            window.title="Reminders";window.isReleasedWhenClosed=false;window.center();reminderWindow=window
            let root=NSStackView();root.orientation = .vertical;root.alignment = .leading;root.spacing=12;root.translatesAutoresizingMaskIntoConstraints=false
            let note=NSTextField(wrappingLabelWithString:reminderLoadError ?? "Saved on this Mac. Bonzi must be running to remind you; missed reminders appear next time you open him.")
            note.textColor = .secondaryLabelColor;root.addArrangedSubview(note)
            reminderInput=NSTextField(string:"");reminderInput.placeholderString="What should I remind you about?";reminderInput.setAccessibilityLabel("Reminder text");root.addArrangedSubview(reminderInput)
            reminderDate=NSDatePicker();reminderDate.datePickerElements=[.yearMonthDay,.hourMinute];reminderDate.datePickerStyle = .textFieldAndStepper;reminderDate.dateValue=Date().addingTimeInterval(300);reminderDate.setAccessibilityLabel("Reminder date and time")
            let row=NSStackView();row.spacing=12;row.addArrangedSubview(reminderDate)
            let add=NSButton(title:"Add reminder",target:self,action:#selector(addReminder));add.bezelStyle = .rounded;add.isEnabled=reminderStore != nil;row.addArrangedSubview(add);root.addArrangedSubview(row)
            let scroll=NSScrollView();scroll.hasVerticalScroller=true;scroll.translatesAutoresizingMaskIntoConstraints=false
            let list=NSStackView();list.orientation = .vertical;list.alignment = .leading;list.spacing=12;list.translatesAutoresizingMaskIntoConstraints=false;reminderList=list;scroll.documentView=list;root.addArrangedSubview(scroll)
            window.contentView!.addSubview(root)
            NSLayoutConstraint.activate([root.leadingAnchor.constraint(equalTo:window.contentView!.leadingAnchor,constant:20),root.trailingAnchor.constraint(equalTo:window.contentView!.trailingAnchor,constant:-20),root.topAnchor.constraint(equalTo:window.contentView!.topAnchor,constant:20),root.bottomAnchor.constraint(equalTo:window.contentView!.bottomAnchor,constant:-20),reminderInput.widthAnchor.constraint(equalTo:root.widthAnchor),scroll.widthAnchor.constraint(equalTo:root.widthAnchor),list.widthAnchor.constraint(equalTo:scroll.contentView.widthAnchor),scroll.heightAnchor.constraint(greaterThanOrEqualToConstant:220)])
        }
        refreshReminders();reminderWindow?.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    }
    func refreshReminders() {
        guard let list=reminderList else { return }
        for view in list.arrangedSubviews { list.removeArrangedSubview(view);view.removeFromSuperview() }
        guard let store=reminderStore else { return }
        if store.reminders.isEmpty { list.addArrangedSubview(NSTextField(labelWithString:"No reminders yet.")) }
        for reminder in store.reminders {
            let row=NSStackView();row.orientation = .vertical;row.alignment = .leading;row.spacing=4
            let text=NSTextField(wrappingLabelWithString:reminder.text);text.preferredMaxLayoutWidth=400;row.addArrangedSubview(text)
            let date=DateFormatter.localizedString(from:reminder.due,dateStyle:.medium,timeStyle:.short)
            let detail=NSTextField(labelWithString:"\(reminder.delivered ? "Due · ":"")\(date)");detail.textColor = reminder.delivered ? .systemOrange:.secondaryLabelColor
            let bottom=NSStackView();bottom.spacing=12;bottom.addArrangedSubview(detail)
            let remove=NSButton(title:reminder.delivered ? "Done":"Cancel",target:self,action:#selector(removeReminder(_:)));remove.identifier=NSUserInterfaceItemIdentifier(reminder.id.uuidString);remove.bezelStyle = .rounded;bottom.addArrangedSubview(remove);row.addArrangedSubview(bottom);list.addArrangedSubview(row)
        }
    }
    @objc func addReminder() {
        do { try reminderStore?.add(reminderInput.stringValue,due:reminderDate.dateValue);reminderInput.stringValue="";refreshReminders() }
        catch { let alert=NSAlert(error:error);if let reminderWindow { alert.beginSheetModal(for:reminderWindow) } }
    }
    @objc func removeReminder(_ sender:NSButton) {
        guard let raw=sender.identifier?.rawValue,let id=UUID(uuidString:raw) else { return }
        do { try reminderStore?.remove(id);refreshReminders() } catch { NSAlert(error:error).runModal() }
    }
    func deliverReminders() {
        guard let due=reminderStore?.deliverDue(at:Date()),!due.isEmpty else { return }
        panel.orderFrontRegardless();view.isPaused=false;showReminders()
        say(due.count==1 ? "Reminder: \(due[0].text)":"You have \(due.count) reminders due. I've opened your list.")
        status.menu=makeMenu()
    }
    func validateReminderWindow() {
        showReminders()
        Timer.scheduledTimer(withTimeInterval:2,repeats:false) { [weak self] _ in
            guard let self,let content=self.reminderWindow?.contentView,let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds) else { return }
            do {
                guard self.reminderStore?.reminders.filter({ $0.delivered }).count==1,self.bubble.stringValue=="Reminder: Stretch and take a short break" else { throw failure("Reminder UI delivery did not run") }
                content.cacheDisplay(in:content.bounds,to:bitmap)
                try FileManager.default.createDirectory(atPath:"Validation/Reminders",withIntermediateDirectories:true)
                try bitmap.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:"Validation/Reminders/ui.png"))
                print("Native reminder UI delivered one due reminder and retained one pending reminder; validation data was not persisted.")
            } catch { fputs("Reminder UI validation failed: \(error)\n",stderr);exit(1) }
            NSApp.terminate(nil)
        }
    }

}
