//
//  ViewModel.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import Combine
import EventKit
import Foundation
import SwiftUI

class ViewModel: ObservableObject {
    enum State {
        case idle
        case draggingItem(String,
                          startPoint: CGPoint,
                          point: CGPoint,
                          sizeMod: CGSize?)
        case chooseEventDuration(todoID: String,
                                 startSeconds: Int,
                                 endSeconds: Int,
                                 startDelta: Int,
                                 endDelta: Int,
                                 calendarBounds: (Int, Int),
                                 draggedBounds: (Bool, Bool))
        case toDoSelected(String)
        case eventSelected(String)
    }
    
    struct AvailableTime: Identifiable {
        var id: String
        var startSeconds: Int
        var endSeconds: Int
    }
    
    @Published private(set) var state: State = .idle
    @Published private(set) var selectedDay = Date() {
        didSet {
            selectedDayEvents = model.events(on: selectedDay)
        }
    }

    var horizontalScrollOffset = CGFloat.zero
    private let model: Model
    var timelineTranslator = TimelinePointTranslator()
    var didScrollToFutureTime = false
    var timelineRect: CGRect? {
        didSet {
            scrollToFutureTimeOnTimeline()
        }
    }
    var schedulerScrollProxy: ScrollViewProxy?
    private(set) var itemAreas = [String: CGRect]()
    
    // MARK: - presentation
    
    var sheetPresented: Bool {
        get {
            switch state {
            case .toDoSelected, .eventSelected: return true
            default: return false
            }
        }
        set {
            if !newValue {
                state = .idle
            }
        }
    }

    var selectedItemID: String? {
        switch state {
        case .toDoSelected(let id): return id
        case .eventSelected(let id): return id
        default: return nil
        }
    }

    var selectedDayEvents: [EKEvent] = [] {
        didSet {
            todaysAvailTimes = ViewModel.availableTimes(in: selectedDayEvents)
        }
    }

    var todaysAvailTimes: [AvailableTime] = []
    var selectedDayView: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US")
        df.setLocalizedDateFormatFromTemplate("MMMMd")
        return df.string(from: selectedDay)
    }

    func getToDos() -> [EKReminder] { model.getToDos() }
    func attemptGetToDo(by id: String) -> EKReminder? { model.getToDo(by: id) }
    func attemptGetEvent(by id: String) -> EKEvent? { model.getEvent(by: id) }

    // MARK: - state machine

    // Only set state here
    
    func itemDragged(_ id: String, _ point: CGPoint, _ dragStart: CGPoint) {
        switch state {
        case .idle:
            state = .draggingItem(id, startPoint: dragStart, point: point, sizeMod: nil)
            
        case .draggingItem(_, _, point: let prevPoint, sizeMod: _):
            // ios: x and y positive
            if let availTimeID = item(potentiallyHitBy: point) {
                let dragTarget = itemAreas[availTimeID]!
                withAnimation { // animating here keeps dragging and downsizing snappy, but upsizing smooth
                    state = .draggingItem(id, startPoint: dragStart, point: point, sizeMod: dragTarget.size)
                }
            } else {
                withAnimation {
                    state = .draggingItem(id, startPoint: dragStart, point: point, sizeMod: nil)
                }
            }
            autoHScroll(from: point, vs: prevPoint)
            autoTimelineVScroll(from: point, vs: prevPoint)
            
        case .chooseEventDuration(todoID: let todoID,
                                  startSeconds: let start,
                                  endSeconds: let end,
                                  startDelta: let startDelta,
                                  endDelta: let endDelta,
                                  calendarBounds: let bounds, _):
            if attemptGetToDo(by: id) == nil {
                let yDelta = -(dragStart.y - point.y)
                let timeDelta = timelineTranslator.seconds(from: yDelta)
                let (newStartDelta, newEndDelta) = updateDeltas(startDelta: timeDelta,
                                                                endDelta: timeDelta,
                                                                fromCurrent: start,
                                                                and: end,
                                                                oldStartDelta: startDelta,
                                                                oldEndDelta: endDelta,
                                                                in: bounds)
                state = .chooseEventDuration(todoID: todoID,
                                             startSeconds: start,
                                             endSeconds: end,
                                             startDelta: newStartDelta,
                                             endDelta: newEndDelta,
                                             calendarBounds: bounds,
                                             draggedBounds: (true, true))
            }
        default:
            state = .idle
        }
    }

    func itemDropped(_ id: String, _ point: CGPoint) {
        switch state {
        case .draggingItem:
            if let itemID = item(potentiallyHitBy: point),
               let todo = model.getToDo(by: id),
               let availableTime = todaysAvailTimes.first(where: { $0.id == itemID })
            {
                let bounds = (availableTime.startSeconds, availableTime.endSeconds)
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                state = .chooseEventDuration(todoID: todo.id,
                                             startSeconds: availableTime.startSeconds,
                                             endSeconds: availableTime.endSeconds,
                                             startDelta: 0,
                                             endDelta: 0,
                                             calendarBounds: bounds,
                                             draggedBounds: (false, false))
            } else {
                state = .idle
            }
            
        case .chooseEventDuration:
            return
        default:
            state = .idle
        }
    }
    
    func updateEventStartTimeDelta(withTimelineYDelta y: CGFloat) {
        if case .chooseEventDuration(todoID: let todoID,
                                     startSeconds: let start,
                                     endSeconds: let end,
                                     startDelta: let startDelta,
                                     endDelta: let endDelta,
                                     calendarBounds: let bounds,
                                     _) = state
        {
            let newStartSecondsDelta = timelineTranslator.seconds(from: y)
            let (newStart, _) = updateDeltas(startDelta: newStartSecondsDelta,
                                             endDelta: nil,
                                             fromCurrent: start,
                                             and: end,
                                             oldStartDelta: startDelta,
                                             oldEndDelta: endDelta,
                                             in: bounds)
            state = .chooseEventDuration(todoID: todoID,
                                         startSeconds: start,
                                         endSeconds: end,
                                         startDelta: newStart,
                                         endDelta: endDelta,
                                         calendarBounds: bounds,
                                         draggedBounds: (true, false))
        }
    }
    
    func updateEventEndTimeDelta(withTimelineYDelta y: CGFloat) {
        if case .chooseEventDuration(todoID: let todoID,
                                     startSeconds: let start,
                                     endSeconds: let end,
                                     startDelta: let startDelta,
                                     endDelta: let endDelta,
                                     calendarBounds: let bounds,
                                     _) = state
        {
            let newEndSecondsDelta = timelineTranslator.seconds(from: y)
            let (_, newEnd) = updateDeltas(startDelta: nil,
                                           endDelta: newEndSecondsDelta,
                                           fromCurrent: start,
                                           and: end,
                                           oldStartDelta: startDelta,
                                           oldEndDelta: endDelta,
                                           in: bounds)
            state = .chooseEventDuration(todoID: todoID,
                                         startSeconds: start,
                                         endSeconds: end,
                                         startDelta: startDelta,
                                         endDelta: newEnd,
                                         calendarBounds: bounds,
                                         draggedBounds: (false, true))
        }
    }
    
    func endChooseEventTimeDrag() {
        if case .chooseEventDuration(todoID: let todoID,
                                     startSeconds: let start,
                                     endSeconds: let end,
                                     startDelta: let startDelta,
                                     endDelta: let endDelta,
                                     calendarBounds: let bounds,
                                     draggedBounds: _) = state
        {
            state = .chooseEventDuration(todoID: todoID,
                                         startSeconds: start + startDelta,
                                         endSeconds: end + endDelta,
                                         startDelta: 0,
                                         endDelta: 0,
                                         calendarBounds: bounds,
                                         draggedBounds: (false, false))
        }
    }
    
    func confirmChosenEventTime() {
        if case .chooseEventDuration(todoID: let todoID,
                                     startSeconds: let start,
                                     endSeconds: let end,
                                     startDelta: let startDelta,
                                     endDelta: let endDelta,
                                     _, _) = state
        {
            model.scheduleEvent(fromToDo: todoID, from: start + startDelta, to: end + endDelta)
            state = .idle
        }
    }
    
    func cancelChooseEventTime() {
        DispatchQueue.main.async {
            withAnimation { self.schedulerScrollProxy?.scrollTo("todos") }
            self.state = .idle
        }
    }
    
    func autoHScroll(from point: CGPoint, vs prevPoint: CGPoint) {
        guard let timeline = timelineRect else { return }
        if !timeline.contains(prevPoint) && timeline.contains(point) {
            DispatchQueue.main.async {
                withAnimation {
                    self.schedulerScrollProxy?.scrollTo("timeline")
                }
            }
        }
    }
    
    func autoTimelineVScroll(from point: CGPoint, vs prevPoint: CGPoint) {
        guard let timeline = timelineRect else { return }
        if timeline.contains(point) {
            let screenSize = UIScreen.main.bounds
            let screenDenominator: CGFloat = 8
            let draggedToTop = { (p: CGPoint) in p.y < (screenSize.maxY / screenDenominator) }
            let draggedToBottom = { (p: CGPoint) in p.y > (screenSize.maxY - (screenSize.maxY / screenDenominator)) }
            let shouldInitiateTopScroll = !draggedToTop(prevPoint) && draggedToTop(point)
            let shouldInitiateBottomScroll = !draggedToBottom(prevPoint) && draggedToBottom(point)

            if shouldInitiateTopScroll {
                scrollTimeline(to: .top)
            } else if shouldInitiateBottomScroll {
                scrollTimeline(to: .bottom)
            }
        }
    }
    
    func scrollTimeline(to unitPoint: UnitPoint) {
        DispatchQueue.main.async {
            withAnimation {
                self.schedulerScrollProxy?.scrollTo("timelinecontent", anchor: unitPoint)
            }
        }
    }
    
    func selectToDo(of id: String) {
        if case .idle = state {
            state = .toDoSelected(id)
        }
    }
    
    func selectEvent(of id: String) {
        if case .idle = state {
            state = .eventSelected(id)
        }
    }
    
    private func newSize(from size: CGSize, potentiallyApplying transform: CGSize?) -> CGSize {
        if let t = transform { return CGSize(width: size.width + t.width, height: size.height + t.height) }
        else { return size }
    }
    
    private func pointBy(startingAt point: CGPoint, movingBy offset: CGSize) -> CGPoint {
        CGPoint(x: point.x + offset.width, y: point.y + offset.height)
    }
    
    private func sizeBetween(pointA: CGPoint, minus pointB: CGPoint) -> CGSize {
        CGSize(width: pointA.x - pointB.x, height: pointA.y - pointB.y)
    }
    
    // MARK: - scheduling available time
    
    func updateArea(of id: String, to rect: CGRect) {
        itemAreas[id] = rect
    }
    
    private func item(potentiallyHitBy point: CGPoint) -> String? {
        return itemAreas.first(where: { k, rect in
            return rect.contains(point)
        })?.key
    }
    
    func updateDeltas(startDelta: Int?,
                      endDelta: Int?,
                      fromCurrent start: Int,
                      and end: Int,
                      oldStartDelta: Int,
                      oldEndDelta: Int,
                      in bounds: (Int, Int)) -> (Int, Int)
    {
        var newStartDelta = oldStartDelta
        var newEndDelta = oldEndDelta
        let upToStartTime = bounds.0 - start
        let upToEndTime = bounds.1 - end
        if let startChange = startDelta {
            if newStartDeltaIsValid(startChange, appliedTo: start, startBound: bounds.0) {
                newStartDelta = startChange
            } else {
                newStartDelta = upToStartTime
            }
        }
        if let endChange = endDelta {
            if newEndDeltaIsValid(endChange, appliedTo: end, endBound: bounds.1) {
                newEndDelta = endChange
            } else {
                newEndDelta = upToEndTime
            }
        }
        if atLeast30Minutes(start: newStartDelta, end: newEndDelta, bounds: (start, end)) {
            return (newStartDelta, newEndDelta)
        } else {
            return deltasMaintaining30MinInterval(fromEvent: (start, end),
                                                  new: (newStartDelta, newEndDelta),
                                                  in: bounds,
                                                  updatingDeltas: (oldStartDelta != newStartDelta, oldEndDelta != newEndDelta))
        }
    }
    
    private func newStartDeltaIsValid(_ delta: Int, appliedTo startSeconds: Int, startBound: Int) -> Bool {
        startSeconds + delta >= startBound
    }
    
    private func newEndDeltaIsValid(_ delta: Int, appliedTo endSeconds: Int, endBound: Int) -> Bool {
        endSeconds + delta <= endBound
    }
    
    private func atLeast30Minutes(start: Int, end: Int, bounds: (Int, Int)) -> Bool {
        return ((end + bounds.1) - (start + bounds.0)) >= halfHour
    }
    
    private func deltasMaintaining30MinInterval(fromEvent bounds: (Int, Int),
                                                new newDeltas: (Int, Int),
                                                in timelineBounds: (Int, Int),
                                                updatingDeltas: (Bool, Bool)) -> (Int, Int)
    {
        let resultingStartTime = bounds.0 + newDeltas.0
        let resultingEndTime = bounds.1 + newDeltas.1
        let maintain30MinTimeAdjustment = halfHour - (resultingEndTime - resultingStartTime)
        let isAtStartTimelineBound = bounds.0 + newDeltas.0 <= timelineBounds.0
        let isAtEndTimelineBound = bounds.1 + newDeltas.1 >= timelineBounds.1
        if isAtStartTimelineBound {
            let adjustedStartDelta = newDeltas.0 + (timelineBounds.0 - resultingStartTime)
            let adjustedEndDelta = newDeltas.1 + maintain30MinTimeAdjustment
            return (adjustedStartDelta, adjustedEndDelta)
        } else if isAtEndTimelineBound {
            let adjustedEndDelta = newDeltas.1 - (resultingEndTime - timelineBounds.1)
            let adjustedStartDelta = newDeltas.0 - maintain30MinTimeAdjustment
            return (adjustedStartDelta, adjustedEndDelta)
        } else { // only one delta can be changing
            if updatingDeltas.0 {
                let adjustedStartDelta = newDeltas.0 - (resultingStartTime - (resultingEndTime - halfHour))
                return (adjustedStartDelta, newDeltas.1)
            } else {
                let adjustedEndDelta = newDeltas.1 + ((resultingStartTime + halfHour) - resultingEndTime)
                return (newDeltas.0, adjustedEndDelta)
            }
        }
    }
    
    private class func availableTimes(in events: [EKEvent]) -> [AvailableTime] {
        var schedulableTimes: [AvailableTime] = []
        let curTime = Date().secondsIntoDay
        let enoughTime = { (start: Int, end: Int) in end - start >= halfHour }
        let appendTime = { (id: String, start: Int, end: Int) in
            var s = start
            if end < curTime {
                return
            }
            if start...end ~= curTime {
                if enoughTime(curTime, end) {
                    s = curTime
                } else {
                    return
                }
            }
            schedulableTimes.append(AvailableTime(id: id, startSeconds: s, endSeconds: end))
        }
        
        if enoughTime(sixAM, events.first?.startSeconds ?? sixAM) {
            appendTime(events.first!.id, sixAM, events.first!.startSeconds)
        }
        
        for (i, _) in events.enumerated() {
            if i < events.count - 1 {
                let gapStart = events[i].endSeconds
                let gapEnd = events[i + 1].startSeconds
                if (enoughTime(gapStart, gapEnd)) {
                    let id = events[i].id + "," + events[i + 1].id
                    appendTime(id, gapStart, gapEnd)
                }
            }
        }
        
        if enoughTime(events.last?.endSeconds ?? tenPM, tenPM) {
            appendTime(events.last!.id, events.last!.endSeconds, tenPM)
        }
        
        return schedulableTimes
    }
    
    func updateActivityType(of id: String, to activityType: ActivityType) {
        objectWillChange.send()
        guard let calItem: EKCalendarItem = attemptGetEvent(by: id) ?? attemptGetToDo(by: id) else { return }        
        calItem.activityType = activityType
    }
    
    func scrollToFutureTimeOnTimeline() {
        if !didScrollToFutureTime {
            let anchor = getCurrentTimeAnchorPoint()
            schedulerScrollProxy?.scrollTo("future", anchor: anchor)
            didScrollToFutureTime = true
        }
    }
    
    private func getCurrentTimeAnchorPoint() -> UnitPoint {
        let currentTime = Date().secondsIntoDay
        guard let timeline = timelineRect else { return .center }
        let y = timelineTranslator.points(given: currentTime, for: timeline.height, by: .instant)
        let futureTimeHeight = timeline.height - y
        let screenHeight = UIScreen.main.bounds.height
        if futureTimeHeight > screenHeight - 30 {
            return .top
        } else {
            return .bottom
        }
    }
    
    // MARK: - init viewmodel
    
    var modelListener: AnyCancellable?
    init(dataModel: Model) {
        model = dataModel
        modelListener = dataModel.objectWillChange.makeConnectable().autoconnect().sink { _ in
            DispatchQueue.main.async {
                self.objectWillChange.send()
                self.updateViewModelFromModel()
            }
        }
    }
    
    private func updateViewModelFromModel() {
        selectedDayEvents = model.events(on: selectedDay)
    }
}

class TimelinePointTranslator {
    var timelineHeight: CGFloat?
    private let sixAM: CGFloat = 60 * 60 * 6
    private let tenPM: CGFloat = 60 * 60 * 22
    private let sixteenHours: CGFloat = 60 * 60 * 16
    
    enum Domain {
        case instant
        case timeInterval
    }
    
    func points(given seconds: Int, for height: CGFloat, by scenario: Domain) -> CGFloat {
        // see https://en.wikipedia.org/wiki/Normalization_(statistics)
        let x = CGFloat(seconds)
        let domain = domainValues(forCalculatingIn: scenario)
        return normalize(x: x, inRange: (0, height), andDomain: domain)
    }
    
    func seconds(from pixels: CGFloat) -> Int {
        return Int(normalize(x: pixels, inRange: (0, sixteenHours), andDomain: (0, timelineHeight!)))
    }
    
    private func domainValues(forCalculatingIn domain: Domain) -> (CGFloat, CGFloat) {
        switch domain {
        case .instant:
            return (sixAM, tenPM)
        default:
            return (0, sixteenHours)
        }
    }
    
    func normalize(x: CGFloat, inRange range: (CGFloat, CGFloat), andDomain domain: (CGFloat, CGFloat)) -> CGFloat {
        let x: CGFloat = x
        let a: CGFloat = range.0
        let b: CGFloat = range.1
        let x_min: CGFloat = domain.0
        let x_max: CGFloat = domain.1
        return a + (((x - x_min) * (b - a))
            /
            (x_max - x_min))
    }
}
