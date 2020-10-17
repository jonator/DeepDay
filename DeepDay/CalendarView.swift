//
//  CalendarView.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import SwiftUI

struct CalendarView: View {
    let timelineHeight = CGFloat(60)
    let timelineSpacing = CGFloat(90)
    
    @EnvironmentObject var viewModel: ViewModel
    
    var body: some View {
        TimeLines(height: timelineHeight, spacing: timelineSpacing)
            .overlay(
                GeometryReader { timelineGeo in
                    TimeBlocks()
                        .frame(width: timelineGeo.size.width - 90,
                               height: timelineGeo.size.height - self.timelineHeight)
                        .position(x: timelineGeo.frame(in: .local).origin.x + timelineGeo.size.width / 2 - (self.timelineHeight / 2),
                                  y: timelineGeo.size.height / 2)
                        .onAppear {
                            self.viewModel.timelineTranslator.updateHeight(to: timelineGeo.size.height - self.timelineHeight)
                            self.viewModel.timelineRect = timelineGeo.frame(in: .global)
                        }
                }
            )
    }
}

struct TimeLines: View {
    let height: CGFloat
    let spacing: CGFloat
    
    var body: some View {
        VStack(alignment: .center, spacing: spacing) {
            ForEach([6, 8, 10, 12, 14, 16, 18, 20, 22], id: \.self) { militaryHour in
                self.timeLine(for: militaryHour)
                    .frame(height: self.height)
            }
        }
    }
    
    private func timeLine(for hour: Int) -> some View {
        Group {
            if hour % 2 == 0 || hour == (10 + 12) {
                if hour == 12 {
                    LabeledTimeLine("NOON")
                } else {
                    LabeledTimeLine(String(hour > 12 ? hour - 12 : hour), rightPaddingInset: hour % 6 == 0 || hour == (10 + 12) ? 0 : 10)
                }
            } else {
                LabeledTimeLine(String(hour > 12 ? hour - 12 : hour), rightPaddingInset: 10)
            }
        }.opacity(hour % 6 == 0 ? 1 : 0.38)
    }
}

struct LabeledTimeLine: View {
    let text: String
    let rightPaddingInset: CGFloat
    
    init(_ text: String, rightPaddingInset: CGFloat = CGFloat.zero) {
        self.text = text
        self.rightPaddingInset = rightPaddingInset
    }
    
    var body: some View {
        HStack {
            TimeLine()
            Text(self.text)
        }
        .padding()
        .padding(.trailing, self.rightPaddingInset)
    }
}

struct TimeLine: View {
    var body: some View {
        GeometryReader { geo in
            VStack {
                Spacer()
                Rectangle().fill().frame(width: geo.size.width, height: 1)
                Spacer()
            }
        }
    }
}
var c = 0
struct TimeBlocks: View {
    @EnvironmentObject var viewModel: ViewModel
    @GestureState var isPotentialEventLongPress = false
    @GestureState var isPotentialEventDragging = false
    
    var body: some View {
        GeometryReader { geo in
            ForEach(self.viewModel.selectedDayEvents) { event in
                self.view(of: event, sized: geo.size)
            }
            ForEach(self.viewModel.todaysAvailTimes) { availTime in
                self.view(of: availTime, sized: geo.size)
            }
            self.viewOfChooseEventDurationContext(sized: geo.size)
        }
    }
    
    private func view(of event: EKEvent, sized size: CGSize) -> some View {
        let blockHeight: CGFloat = viewModel.timelineTranslator.points(given: event.endSeconds - event.startSeconds,
                                                                       for: size.height, by: .timeInterval)
        let y: CGFloat = viewModel.timelineTranslator.points(given: event.startSeconds,
                                                             for: size.height, by: .instant)
        var blurRadius = CGFloat.zero
        if case .draggingItem = viewModel.state {
            blurRadius = CGFloat(2)
        }
        
        if let selectedID = viewModel.selectedItemID {
            if selectedID != event.id {
                blurRadius = CGFloat(2)
            }
        }
        
        return TimeBlock(color: DesignPalette.Colors.primary,
                         title: event.title ?? "")
            .onTapGesture { viewModel.selectEvent(of: event.id) }
            .opacity(event.activityType == .shallow ? 0.85 : 1)
            .frame(width: size.width, height: blockHeight, alignment: .leading)
            .position(x: size.width / 2, y: y + (blockHeight / 2))
            .blur(radius: blurRadius)
    }
    
    private func view(of availableTime: ViewModel.AvailableTime, sized size: CGSize) -> some View {
        let blockHeight: CGFloat = viewModel.timelineTranslator.points(given: availableTime.endSeconds - availableTime.startSeconds,
                                                                       for: size.height, by: .timeInterval)
        let y: CGFloat = viewModel.timelineTranslator.points(given: availableTime.startSeconds,
                                                             for: size.height, by: .instant)
        var hide = true
        if case .draggingItem = viewModel.state {
            hide = false
        }
        
        return Group {
            if !hide {
                Rectangle()
                    .stroke(lineWidth: 3)
                    .cornerRadius(3)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear.onAppear {
                                self.viewModel.updateArea(of: availableTime.id, to: geo.frame(in: .global))
                            }
                        }
                    )
                    .frame(width: size.width, height: blockHeight, alignment: .leading)
                    .position(x: size.width / 2, y: y + (blockHeight / 2))
            }
        }
    }

    private func viewOfChooseEventDurationContext(sized size: CGSize) -> some View {
        if case .chooseEventDuration(todoID: let todoID,
                                     startSeconds: let start,
                                     endSeconds: let end,
                                     startDelta: let startDelta,
                                     endDelta: let endDelta,
                                     _,
                                     draggedBounds: let dragBounds) = viewModel.state
        {
            let todo = viewModel.attemptGetToDo(by: todoID)!
            let translatedStart = start + startDelta
            let translatedEnd = end + endDelta
            let blockHeight: CGFloat = viewModel.timelineTranslator.points(given: translatedEnd - translatedStart, for: size.height, by: .timeInterval)
            let y: CGFloat = viewModel.timelineTranslator.points(given: translatedStart, for: size.height, by: .instant)
            let timeDisplaySpace: CGFloat = 20
            let eitherBoundsDragging = dragBounds.0 || dragBounds.1
            
            return AnyView(Group {
                TimeBlock(color: DesignPalette.Colors.primary, title: todo.title)
                    .opacity(isPotentialEventDragging || isPotentialEventLongPress ? 0.97 : 1)
                    .frame(width: size.width, height: blockHeight, alignment: .leading)
                    .position(x: size.width / 2, y: y + (blockHeight / 2))
                    .gesture(
                        LongPressGesture(minimumDuration: 0.8, maximumDistance: 10)
                            .updating($isPotentialEventLongPress, body: { isPressed, state, _ in
                                state = isPressed
                            })
                            .sequenced(before: DragGesture(coordinateSpace: .global))
                            .updating($isPotentialEventDragging, body: { sequenceGesture, state, _ in
                                if case .second(true, let drag) = sequenceGesture {
                                    if let d = drag { self.viewModel.itemDragged("", d.location, d.startLocation) }
                                    state = true
                                }
                            })
                            .onEnded { gestureSequence in
                                if case .second(true, _) = gestureSequence {
                                    self.viewModel.endChooseEventTimeDrag()
                                }
                            }
                    )
                if dragBounds.0 {
                    self.view(ofSecondsAsText: translatedStart)
                        .position(x: -timeDisplaySpace, y: y)
                }
                self.viewOfTimePickers(surrounding: blockHeight, at: y, showButtons: !eitherBoundsDragging && !isPotentialEventLongPress && !isPotentialEventDragging)
                    .opacity(isPotentialEventLongPress ? 0.7 : 1)
                if dragBounds.1 {
                    self.view(ofSecondsAsText: translatedEnd)
                        .position(x: -timeDisplaySpace, y: y + blockHeight)
                }
            })
        } else {
            return AnyView(EmptyView())
        }
    }
    
    private func viewOfTimePickers(surrounding height: CGFloat, at y: CGFloat, showButtons: Bool) -> some View {
        let w: CGFloat = 38
        let h: CGFloat = w
        let space: CGFloat = 25
        let eventStartY: CGFloat = y - space
        let eventEndY: CGFloat = y + height + space
        
        return GeometryReader { geo in
            TimePicker(direction: .up)
                .frame(width: w, height: h)
                .position(x: geo.size.width / 2, y: eventStartY)
                .zIndex(100)
            if showButtons {
                CircleButton(text: "✓", color: DesignPalette.Colors.confirm)
                    .frame(width: w, height: h)
                    .position(x: -space, y: y + (height / 2) - space)
                    .zIndex(200)
                    .onTapGesture { self.viewModel.confirmChosenEventTime() }
                CircleButton(text: "𝖷", color: DesignPalette.Colors.cancel)
                    .frame(width: w, height: h)
                    .position(x: -space, y: y + (height / 2) + space)
                    .zIndex(200)
                    .onTapGesture { self.viewModel.cancelChooseEventTime() }
            }
            TimePicker(direction: .down)
                .frame(width: w, height: h)
                .position(x: geo.size.width / 2, y: eventEndY)
                .zIndex(100)
        }
    }
    
    private func view(ofSecondsAsText seconds: Int) -> some View {
        Text(display(seconds))
            .font(.caption)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
    
    func display(_ seconds: Int) -> String {
        let minutes = Int((seconds % 3600) / 60)
        let minutesString = minutes == 0 ? "00" : minutes < 10 ? "0\(minutes)" : String(minutes)
        var hours = Int(seconds / 3600)
        if hours > 12 { hours -= 12 }
        return "\(hours):\(minutesString)"
    }
}

struct TimeBlock: View {
    let color: Color
    let title: String
    
    var body: some View {
        Group {
            Rectangle().fill(color)
            Text(title).padding(.leading, 10)
        }
        .cornerRadius(3)
        .foregroundColor(Color.white)
    }
}

struct TimePicker: View {
    enum Direction {
        case up
        case down
    }
    
    @EnvironmentObject var viewModel: ViewModel
    var direction: Direction
    var triangleDegrees: Double {
        if case .down = direction { return 180.0 }
        else { return 0.0 }
    }
    
    var drag: some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .global)
            .onChanged {
                let yDelta = $0.translation.height
                switch self.direction {
                case .up: self.viewModel.updateEventStartTimeDelta(withTimelineYDelta: yDelta)
                case .down: self.viewModel.updateEventEndTimeDelta(withTimelineYDelta: yDelta)
                }
            }
            .onEnded { _ in self.viewModel.endChooseEventTimeDrag() }
    }
    
    var body: some View {
        GeometryReader { geo in
            Circle().fill(DesignPalette.Colors.confirm)
            Triangle().fill(Color.white)
                .frame(width: geo.size.width / 3, height: geo.size.height / 4)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
                .rotationEffect(Angle(degrees: triangleDegrees))
        }
        .gesture(drag)
    }
}

struct CircleButton: View {
    let text: String
    let color: Color
    
    var body: some View {
        GeometryReader { geo in
            Circle().fill(color)
            Text(self.text)
                .foregroundColor(Color.white)
                .fontWeight(.bold)
                .frame(width: geo.size.width / 2, height: geo.size.height / 2)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }
}

struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()

        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))

        return path
    }
}

struct CalendarView_Previews: PreviewProvider {
//    static let scheduler = ViewModel(dataModel: Model.mock())
    
    static var previews: some View {
        CalendarView() // .environmentObject(scheduler)
    }
}
