//
//  ContentView.swift
//  DeepDay
//
//  Created by Jon Ator on 10/9/20.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: ViewModel
    var topInset: CGFloat?

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
            if case .draggingItem(let id, _, offSet: let offset, _, _, _) = viewModel.state {
                if let todo = viewModel.attemptGetToDo(by: id) {
                    let toDoArea = viewModel.itemAreas[id]!
                    let toDoPoint = CGPoint(x: toDoArea.midX, y: toDoArea.midY)
                    DragToDoPlaceholder(todo: todo, state: viewModel.state)
                        .position(toDoPoint)
                        .offset(offset)
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
                                let offset =  geo.frame(in: .named("timeline")).minY
                                Color.clear.preference(key: ScrollOffsetPreferenceKey.self, value: offset)
                            }
                        }
                    }
                    .coordinateSpace(name: "timeline")
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                        viewModel.timelineContentOffset = value
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

struct ScrollOffsetPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    
    static var defaultValue: CGFloat = .zero
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


struct SectionHeaderText: View {
    var text: String
    var body: some View {
        Text(text).font(.largeTitle)
            .padding([.top, .bottom], 10)
    }
}

struct ContentView_Previews: PreviewProvider {
//    static let viewModel = ViewModel(dataModel: Model.mock())

    static var previews: some View {
        ContentView()
    }
}
