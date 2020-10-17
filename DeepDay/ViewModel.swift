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
                          offSet: CGSize,
                          sizeMod: CGSize?,
                          offSetMod: CGSize?,
                          boundScrolledTo: (Bool, Bool))
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

    @Published var timelineContentOffset: CGFloat = .zero

    var horizontalScrollOffset = CGFloat.zero
    private let model: Model
    var timelineTranslator = TimelinePointTranslator()
    var timelineRect: CGRect?
    var schedulerScrollProxy: ScrollViewProxy?
    private(set) var itemAreas = [String: CGRect]()
    
    static let sixAM = 60 * 60 * 6
    static let tenPM = 60 * 60 * 22
    
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
    
    // MARK: - > scheduling event
    
    func itemDragged(_ id: String, _ dragPoint: CGPoint, _ dragStart: CGPoint) {
        switch state {
        case .idle:
            if model.hasToDo(of: id) {
                let dragSize = CGSize(width: dragPoint.x - dragStart.x, height: dragPoint.y - dragStart.y)
                state = .draggingItem(id, startPoint: dragStart, offSet: dragSize, sizeMod: nil, offSetMod: nil, boundScrolledTo: (false, false))
            }
            
        case .draggingItem(_, _, offSet: let oldOffset, sizeMod: _, offSetMod: let offsetMod, boundScrolledTo: let scrollBound):
            // ios: x and y positive
            let dragSize = sizeBetween(pointA: dragPoint, minus: dragStart)
            let newOffset = newSize(from: dragSize, potentiallyApplying: offsetMod)
            let offsetPoint = pointBy(startingAt: dragStart, movingBy: newOffset)
            if let availTimeID = item(potentiallyHitBy: offsetPoint) {
                let dragTarget = itemAreas[availTimeID]!
                withAnimation { // animating here keeps dragging and downsizing snappy, but upsizing smooth
                    state = .draggingItem(id, startPoint: dragStart, offSet: newOffset, sizeMod: dragTarget.size, offSetMod: offsetMod, boundScrolledTo: scrollBound)
                }
            } else {
                state = .draggingItem(id, startPoint: dragStart, offSet: newOffset, sizeMod: nil, offSetMod: offsetMod, boundScrolledTo: scrollBound)
            }
            autoHorizontalScroll(considering: offsetMod)
            autoTimelineVertScroll(from: offsetPoint, vs: pointBy(startingAt: dragStart, movingBy: oldOffset))
            
        case .chooseEventDuration(todoID: let todoID,
                                  startSeconds: let start,
                                  endSeconds: let end,
                                  startDelta: let startDelta,
                                  endDelta: let endDelta,
                                  calendarBounds: let bounds, _):
            if attemptGetToDo(by: id) == nil {
                let yDelta = -(dragStart.y - dragPoint.y)
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
    
    func transformToDoDrag(by transform: CGSize) {
        if case .draggingItem(let id, startPoint: let start, offSet: let offset, sizeMod: let sizeMod, offSetMod: _, boundScrolledTo: let bounds) = state {
            state = .draggingItem(id, startPoint: start, offSet: offset, sizeMod: sizeMod, offSetMod: transform, boundScrolledTo: bounds)
        }
    }

    func itemDropped(_ id: String, _ point: CGPoint) {
        switch state {
        case .draggingItem(_, startPoint: let start, _, _, offSetMod: let offsetMod, _):
            let dragSize = sizeBetween(pointA: point, minus: start)
            let newOffset = newSize(from: dragSize, potentiallyApplying: offsetMod)
            let offsetPoint = pointBy(startingAt: start, movingBy: newOffset)
            if let itemID = item(potentiallyHitBy: offsetPoint) {
                if let todo = model.getToDo(by: id),
                   let availableTime = todaysAvailTimes.first(where: { $0.id == itemID })
                {
                    let bounds = (availableTime.startSeconds, availableTime.endSeconds)
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
    
    func autoHorizontalScroll(considering offsetMod: CGSize?) {
        if isDragItemOffsetInTimeline(), offsetMod == nil {
            if case .draggingItem(let id, let dragStart, offSet: let offset, sizeMod: let sizeMod, offSetMod: _, boundScrolledTo: let scrollBound) = state {
                let offsetMod = CGSize(width: timelineRect!.midX - dragStart.x, height: 0)
                
                DispatchQueue.main.async {
                    withAnimation {
                        self.schedulerScrollProxy?.scrollTo("timeline")
                        self.state = .draggingItem(id, startPoint: dragStart, offSet: offset, sizeMod: sizeMod, offSetMod: offsetMod, boundScrolledTo: scrollBound)
                    }
                }
            }
        }
    }
    
    func autoTimelineVertScroll(from offsetPoint: CGPoint, vs previousOffset: CGPoint) {
        if isDragItemOffsetInTimeline() {
            if case .draggingItem(let id, let dragStart, offSet: let offset, sizeMod: let sizeMod, offSetMod: let offsetMod, boundScrolledTo: let scrollBound) = state {
                let screenSize = UIScreen.main.bounds
                let screenDenominator: CGFloat = 8
                let draggedToTop = { (p: CGPoint) in p.y < (screenSize.maxY / screenDenominator) }
                let draggedToBottom = { (p: CGPoint) in p.y > (screenSize.maxY - (screenSize.maxY / screenDenominator)) }
                let shouldInitiateTopScroll = !draggedToTop(previousOffset) && draggedToTop(offsetPoint)
                let shouldInitiateBottomScroll = !draggedToBottom(previousOffset) && draggedToBottom(offsetPoint)
                
                // check if we need to scroll
                if shouldInitiateTopScroll {
                    self.state = .draggingItem(id, startPoint: dragStart, offSet: offset, sizeMod: sizeMod, offSetMod: offsetMod, boundScrolledTo: (true, false))
                } else if shouldInitiateBottomScroll {
                    self.state = .draggingItem(id, startPoint: dragStart, offSet: offset, sizeMod: sizeMod, offSetMod: offsetMod, boundScrolledTo: (false, true))
                } else if scrollBound.0 || scrollBound.1 { // is in middle
                    self.state = .draggingItem(id, startPoint: dragStart, offSet: offset, sizeMod: sizeMod, offSetMod: offsetMod, boundScrolledTo: (false, false))
                }

                // scroll if we needed to in the past
                if scrollBound.0 {
                    scrollTimeline(to: .top)
                } else if scrollBound.1 {
                    scrollTimeline(to: .bottom)
                }
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
    
    // MARK: - > selecting item
    
    func selectToDo(of id: String) {
        if case .idle = state {
            state = .toDoSelected(id)
        }
    }
    
    func changeToDo(activityType: ActivityType) {
        if case .toDoSelected(let id) = state {
            model.updateActivityType(forToDoOf: id, to: activityType)
        }
    }
    
    func changeEvent(activityType: ActivityType) {
        if case .eventSelected(let id) = state {
            model.updateActivityType(forEventOf: id, to: activityType)
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
        let availTimeAreaAlreadySet = todaysAvailTimes.contains(where: { $0.id == id })
                                        && itemAreas.contains(where: { key, _ in key == id })
        if availTimeAreaAlreadySet {
            return
        }
        itemAreas[id] = rect
    }
    
    func isDragItemOffsetInTimeline() -> Bool {
        if case .draggingItem(_, startPoint: let point, offSet: let offset, _, _, _) = state {
            guard let timelineArea = timelineRect
            else { return false }
            if pointBy(startingAt: point, movingBy: offset).x >= timelineArea.minX - 30 {
                return true
            }
        }
        return false
    }
    
    private func item(potentiallyHitBy point: CGPoint) -> String? {
        return itemAreas.first(where: { _, rect in
            let timelineOffsetRect = CGRect(x: rect.origin.x,
                                            y: rect.origin.y + timelineContentOffset,
                                            width: rect.width,
                                            height: rect.height)
            return timelineOffsetRect.contains(point)
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
        let enoughTime = { (start: Int, end: Int) in end - start > halfHour }
        var schedulableTimes: [AvailableTime] = []
        
        if enoughTime(sixAM, events.first?.startSeconds ?? sixAM) {
            schedulableTimes.append(AvailableTime(id: events.first!.id, startSeconds: sixAM, endSeconds: events.first!.startSeconds))
        }
        
        for (i, _) in events.enumerated() {
            if i < events.count - 2, enoughTime(events[i].endSeconds, events[i + 1].startSeconds) {
                let gapStart = events[i].endSeconds
                let gapEnd = events[i + 1].startSeconds
                let id = events[i].id + "," + events[i + 1].id
                schedulableTimes.append(AvailableTime(id: id, startSeconds: gapStart, endSeconds: gapEnd))
            }
        }
        
        if enoughTime(events.last?.endSeconds ?? tenPM, tenPM) {
            schedulableTimes.append(AvailableTime(id: events.last!.id, startSeconds: events.last!.endSeconds, endSeconds: tenPM))
        }
        
        return schedulableTimes
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
        purgeItemAreas()
        selectedDayEvents = model.events(on: selectedDay)
    }
    
    private func purgeItemAreas() {
        let keys = model.keys
        itemAreas = itemAreas.filter { keys.contains($0.key) }
    }
}

class TimelinePointTranslator {
    private var timelineHeight: CGFloat?
    private let sixAM: CGFloat = 60 * 60 * 6
    private let tenPM: CGFloat = 60 * 60 * 22
    private let sixteenHours: CGFloat = 60 * 60 * 16
    
    enum Domain {
        case instant
        case timeInterval
    }
    
    func updateHeight(to points: CGFloat) {
        timelineHeight = points
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
