//
//  SchedulerView.swift
//  DeepDay
//
//  Created by Jon Ator on 11/19/20.
//

import SwiftUI

struct SchedulerView: View {
    @EnvironmentObject var viewModel: ViewModel
    @Environment(\.calendar) var calendar
    
    var nextMonthDateInterval: DateInterval {
        return calendar.dateInterval(of: .month, for: Date())!
    }
    
    var yesterday: Date {
        let backOneDaySecs = -86400
        return Date().addingTimeInterval(TimeInterval(backOneDaySecs))
    }

    var toDos: some View {
        VStack(alignment: .trailing) {
            SectionHeaderText(text: "ToDos")
            ToDosView(todos: viewModel.getToDos(),
                      selectedID: viewModel.selectedItemID,
                      onToDoDragged: self.viewModel.itemDragged,
                      onToDoDragEnded: self.viewModel.itemDropped,
                      setToDoArea: { id, area in self.viewModel.updateArea(of: id, to: area) },
                      selectToDo: { id in self.viewModel.selectToDo(of: id) })
        }
        .padding(.leading, 10)
        .padding(.top, 20)
    }

    var timeline: some View {
        VStack {
            SectionHeaderText(text: viewModel.selectedDayView)
            TimelineView()
                .frame(width: 340)
        }
    }
    
    var calendarDayPicker: some View {
        CalendarView(interval: nextMonthDateInterval, onTapDay: { date in viewModel.selectedDay = date }) { date in
            let baseText = Text("--").hidden().padding(12)
            let circleColor = Color(hex: "267491")
            let dayOfMonth = self.calendar.component(.day, from: date)
            let selectedDayOfMonth = self.calendar.component(.day, from: viewModel.selectedDay)
            let isSelected = dayOfMonth == selectedDayOfMonth
            let eventCountOpacity = viewModel.calendarDayDotOpacity(on: date).clamped(to: 0.3...1)
            if date > yesterday {
                if isSelected {
                    baseText
                        .background(circleColor)
                        .clipShape(Circle())
                        .padding(.vertical, 4)
                        .overlay(
                            Text(String(dayOfMonth))
                                .foregroundColor(Color.white)
                                .fontWeight(.bold)
                        )
                        .opacity(eventCountOpacity)
                } else {
                    baseText
                        .background(circleColor)
                        .clipShape(Circle())
                        .padding(.vertical, 4)
                        .overlay(
                            Text(String(dayOfMonth))
                                .foregroundColor(Color.white)
                        )
                        .opacity(eventCountOpacity)
                }
            } else {
                baseText
                    .padding(.vertical, 4)
                    .overlay(
                        Circle().stroke(circleColor)
                            .overlay(
                                Text(String(dayOfMonth))
                            )
                    )
                    .opacity(eventCountOpacity)
            }
        }
        .padding(.leading, 30)
        .padding(.top, 20)
        .padding(.trailing, 20)
    }

    var todoOverlayPlaceholder: some View {
        Group {
            if case .draggingItem(let id, startPoint: let startPoint, point: let point, _) = viewModel.state {
                if let todo = viewModel.attemptGetToDo(by: id) {
                    let toDoArea = viewModel.itemAreas[id]!
                    let toDoPoint = CGPoint(x: toDoArea.midX, y: toDoArea.midY)
                    let timelineOffset = ToDoItem.size.width - (viewModel.timelineRect?.origin.x ?? 0)
                    DragToDoPlaceholder(todo: todo, state: viewModel.state)
                        .position(toDoPoint)
                        .offset(CGSize(width: point.x - startPoint.x + timelineOffset, height: point.y - startPoint.y))
                }
            }
        }
    }
    
    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 20) {
                    ScrollView(.vertical, showsIndicators: false) {
                        toDos
                    }
                    .id("todos")
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack {
                            ZStack {
                                timeline
                                    .id("timelinecontent")
                                GeometryReader{ geo in
                                    let timelineRect = geo.frame(in: .global)
                                    Color.clear.preference(key: TimelineRectPreferenceKey.self, value: timelineRect)
                                }
                            }
                            CalendarTipsView(todosCount: viewModel.getToDos().count,
                                             events: viewModel.selectedDayEvents,
                                             availableTime: viewModel.todaysAvailTimes,
                                             workCalendarID: viewModel.workCalendarID)
                        }
                        .padding(.leading, 30)
                        .padding([.top, .bottom], 20)
                    }
                    .onPreferenceChange(TimelineRectPreferenceKey.self) { value in
                        viewModel.timelineRect = value
                    }
                    .id("timeline")
                    if case .idle = viewModel.state { // prevent lag
                        calendarDayPicker
                    }
                }
                .overlay(todoOverlayPlaceholder)
            }
            .onAppear {
                viewModel.schedulerScrollProxy = proxy
            }
        }
        .overlay(SelectedItemBottomSheet())
        .ignoresSafeArea()
    }
}

struct SectionHeaderText: View {
    var text: String
    var body: some View {
        Text(text).font(.largeTitle)
            .padding([.top, .bottom], 10)
    }
}

struct TimelineRectPreferenceKey: PreferenceKey {
    typealias Value = CGRect
    
    static var defaultValue: CGRect = .zero
    
    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        value = nextValue()
    }
}

struct SchedulerView_Previews: PreviewProvider {
    static var previews: some View {
        SchedulerView()
    }
}
