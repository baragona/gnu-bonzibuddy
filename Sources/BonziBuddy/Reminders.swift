import Foundation

struct BuddyReminder:Codable,Identifiable {
    let id:UUID
    let text:String
    let due:Date
    var delivered:Bool
}
final class ReminderStore {
    private(set) var reminders:[BuddyReminder]
    private let persist:(Data)throws->Void
    init(data:Data?=nil,persist:@escaping(Data)throws->Void) throws {
        reminders=try data.map { try JSONDecoder().decode([BuddyReminder].self,from:$0) } ?? []
        self.persist=persist
    }
    private func commit(_ next:[BuddyReminder]) throws {
        let sorted=next.sorted { $0.due<$1.due }
        try persist(JSONEncoder().encode(sorted));reminders=sorted
    }
    func add(_ text:String,due:Date,now:Date=Date()) throws {
        let text=text.trimmingCharacters(in:.whitespacesAndNewlines)
        guard !text.isEmpty else { throw failure("Enter something for Bonzi to remind you about.") }
        guard due>now else { throw failure("Choose a time in the future.") }
        try commit(reminders+[BuddyReminder(id:UUID(),text:String(text.prefix(2000)),due:due,delivered:false)])
    }
    func remove(_ id:UUID) throws { try commit(reminders.filter { $0.id != id }) }
    func deliverDue(at now:Date)->[BuddyReminder] {
        let due=reminders.filter { !$0.delivered && $0.due<=now }
        guard !due.isEmpty else { return [] }
        let ids=Set(due.map(\.id))
        let next=reminders.map { value -> BuddyReminder in var value=value;if ids.contains(value.id) { value.delivered=true };return value }
        do { try commit(next);return due } catch { return [] } // Retain pending reminders if saving fails.
    }
}

func validateReminders() throws {
    let now=Date(timeIntervalSince1970:1000)
    var saved=Data()
    let store=try ReminderStore { saved=$0 }
    try store.add("  First  ",due:now.addingTimeInterval(10),now:now)
    try store.add("Second",due:now.addingTimeInterval(20),now:now)
    try store.add("Cancel",due:now.addingTimeInterval(5),now:now)
    try store.remove(store.reminders.first!.id)
    guard store.deliverDue(at:now).isEmpty else { throw failure("Reminder fired early") }
    let restored=try ReminderStore(data:saved) { saved=$0 }
    let due=restored.deliverDue(at:now.addingTimeInterval(15))
    guard due.map(\.text)==["First"],restored.deliverDue(at:now.addingTimeInterval(15)).isEmpty else { throw failure("Reminder delivery/order failed") }
    let restarted=try ReminderStore(data:saved) { saved=$0 }
    guard restarted.deliverDue(at:now.addingTimeInterval(30)).map(\.text)==["Second"],restarted.reminders.allSatisfy(\.delivered) else { throw failure("Reminder restart/overdue delivery failed") }
    do { try restarted.add(" ",due:now.addingTimeInterval(40),now:now);throw failure("Accepted blank reminder") } catch let error as NSError { guard error.localizedDescription=="Enter something for Bonzi to remind you about." else { throw error } }
    let failing=try ReminderStore(data:saved) { _ in throw failure("Simulated write failure") }
    let before=failing.reminders.count
    do { try failing.add("Unsaved",due:now.addingTimeInterval(40),now:now) } catch {}
    guard failing.reminders.count==before else { throw failure("Failed persistence changed reminder state") }
    print("Reminder checks passed: persistence, restart, overdue delivery, no duplicates, cancellation, blank input and atomic save failure.")
}
