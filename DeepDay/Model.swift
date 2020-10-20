//
//  Model.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import Foundation

class Model: ObservableObject {
    var dataProvider: DataService?
    @Published private var todos: [String: EKReminder]
    @Published private var events: [String: EKEvent]
    var keys: [String] {
        return [String](todos.keys) + [String](events.keys)
    }
    
    // MARK: - todos
    
    func hasToDo(of id: String) -> Bool {
        return todos.contains(where: { todoID, _ in todoID == id })
    }
    
    func getToDos() -> [EKReminder] {
        return todos.values.sorted(by: { (l: EKReminder, r: EKReminder) in l.id < r.id })
    }
    
    func getToDo(by id: String) -> EKReminder? {
        return todos[id]
    }
    
    func add(reminder: EKReminder) {
        todos[reminder.id] = reminder
    }
    
    private func removeToDo(by id: String) {
        todos.removeValue(forKey: id)
    }
    
    // MARK: - events
    
    func events(on day: Date) -> [EKEvent] {
        let calendar = Calendar.current
        let dayInterval = calendar.dateInterval(of: .day, for: day)
        
        return
            [EKEvent](events.filter { _, event in dayInterval?.contains(event.date) ?? false }.values)
                .sorted(by: { $0.startSeconds == $1.startSeconds ? $0.timeInterval < $1.timeInterval : $0.startSeconds < $1.startSeconds })
    }
    
    func getEvent(by id: String) -> EKEvent? {
        return events[id]
    }
    
    func add(toToday event: EKEvent) {
        events[event.id] = event
    }
    
    // MARK: - scheduling
    
    func scheduleEvent(fromToDo id: String, from start: Int, to end: Int) {
//        if let todo = getToDo(by: id) {
//            add(toToday: Event(startSeconds: start,
//                               endSeconds: end,
//                               title: todo.text,
//                               activityType: todo.activityType))
//            removeToDo(by: id)
//        }
    }
    
    // MARK: - init
    
    private init() {
        todos = [:]
        events = [:]
    }
    
    class func fromUserEventData() -> Model {
        let emptyModel = Model()
        let provider = DataService(for: emptyModel)
        
        provider.request(data: .pastMonthEvents)
        provider.request(data: .incompleteReminders)
        
        emptyModel.dataProvider = provider
        return emptyModel
    }
    
    #if DEBUG
//    private init(reminders: [EKReminder], todayEvents: [EKEvent]) {
//        let todoKeys = reminders.map(\.id)
//        self.todos = Dictionary(uniqueKeysWithValues: zip(todoKeys, reminders))
//        let eventKeys = todayEvents.map(\.id)
//        events = Dictionary(uniqueKeysWithValues: zip(eventKeys, todayEvents))
//    }
//
//    static func mock() -> Model { Model(todos: MockCalendar.todos, todayEvents: MockCalendar.events) }
    #endif
}

extension Model: DataProviderDelegate {
    func receive(events: [EKEvent]) {
        self.events = Dictionary(zip(events.map(\.id), events), uniquingKeysWith: { a, _ in a })
    }
    
    func receive(reminders: [EKReminder]) {
        todos = Dictionary(zip(reminders.map(\.id), reminders), uniquingKeysWith: { a, _ in a })
    }
    
    func receive(error: Error) {
        print(error)
    }
}
