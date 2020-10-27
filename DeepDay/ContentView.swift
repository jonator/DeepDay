//
//  ContentView.swift
//  DeepDay
//
//  Created by Jon Ator on 10/9/20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ViewModel

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
            CalendarView()
                .frame(width: 340)
        }
        .padding(.leading, 30)
        .padding(.top, 20)
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
                        ZStack {
                            timeline
                                .id("timelinecontent")
                            GeometryReader{ geo in
                                let timelineRect = geo.frame(in: .global)
                                Color.clear.preference(key: TimelineRectPreferenceKey.self, value: timelineRect)
                            }
                        }
                    }
                    .onPreferenceChange(TimelineRectPreferenceKey.self) { value in
                        viewModel.timelineRect = value
                    }
                    .id("timeline")
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

struct ContentView_Previews: PreviewProvider {
//    static let viewModel = ViewModel(dataModel: Model.mock())

    static var previews: some View {
        ContentView()
    }
}
