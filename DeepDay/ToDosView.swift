//
//  ToDosView.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import SwiftUI

typealias ToDoAreaDelegate = (String, CGRect) -> ()
typealias ToDoDragDelegate = (String, CGPoint, CGPoint) -> ()
typealias ToDoDropDelegate = (String, CGPoint) -> ()
typealias ToDoSelectedDelegate = (String) -> ()

struct ToDosView: View {
    var todos: [EKReminder]
    var selectedID: String?

    var onToDoDragged: ToDoDragDelegate?
    var onToDoDragEnded: ToDoDropDelegate?
    var setToDoArea: ToDoAreaDelegate?
    var selectToDo: ToDoSelectedDelegate?

    enum DragState {
        case inactive
        case pressing(String)
        case dragging(String)

        var itemID: String? {
            switch self {
            case .inactive:
                return nil
            case .pressing(let id):
                return id
            case .dragging(let id):
                return id
            }
        }
    }

    @GestureState var dragState = DragState.inactive

    var body: some View {
        VStack {
            Group {
                if todos.count > 0 {
                    ForEach(self.todos) { todo in
                        GeometryReader { geo in
                            ToDoItem(todo: todo)
                                .onTapGesture { self.selectToDo?(todo.id) }
                                .gesture(longPressDrag(todo, in: geo))
                                .opacity(dragState.itemID == todo.id ? 0 : 1)
                                .blur(radius: selectedID == nil ? 0 : selectedID == todo.id ? 0 : 2)
                        }
                        .frame(width: ToDoItem.size.width, height: ToDoItem.size.height)
                        .padding([.bottom, .top], 5)
                    }
                } else {
                    Rectangle().fill(Color.clear)
                        .frame(width: ToDoItem.size.width)
                }
            }
        }
    }

    func longPressDrag(_ todo: EKReminder, in geo: GeometryProxy) -> some Gesture {
        LongPressGesture(minimumDuration: 0.8, maximumDistance: 5) // can't go lower than 0.8, will either throw exception or just not work
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .global))
            .updating($dragState) { sequence, state, _ in
                switch sequence {
                case .first(true):
                    DispatchQueue.main.async {
                        let toDoFrame = geo.frame(in: .global)
                        self.setToDoArea?(todo.id, toDoFrame)
                        let toDoMidPoint = CGPoint(x: toDoFrame.midX, y: toDoFrame.midY)
                        self.onToDoDragged?(todo.id, toDoMidPoint, toDoMidPoint)
                    }
                    state = .pressing(todo.id)
                case .second(true, let drag):
                    if let d = drag { self.onToDoDragged?(todo.id, d.location, d.startLocation) }
                    state = .dragging(todo.id)
                default:
                    state = .inactive
                }
            }
            .onEnded { sequence in
                switch sequence {
                case .second(true, let drag):
                    self.onToDoDragEnded?(todo.id, drag!.location)
                default:
                    self.onToDoDragEnded?(todo.id, .zero)
                }
            }
    }
}

struct ToDoItem: View {
    var todo: EKReminder
    static let size = CGSize(width: 250, height: 50)

    var body: some View {
        Rectangle().fill(DesignPalette.Colors.primary)
            .overlay(
                HStack {
                    Text(todo.title)
                        .foregroundColor(Color.white)
                        .padding(.leading, 10)
                        .lineLimit(2)
                    Spacer()
                }
            )
            .cornerRadius(3)
    }
}

struct DragToDoPlaceholder: View {
    var todo: EKReminder
    let state: ViewModel.State
    private let scaleAmount: CGFloat = 1.2
    @EnvironmentObject var viewModel: ViewModel

    var size: CGSize {
        var size = CGSize.zero
        if case .draggingItem(_, _, _, sizeMod: let sizemod, _, _) = viewModel.state {
            if let mod = sizemod {
                size = CGSize(width: mod.width / scaleAmount, height: mod.height / scaleAmount)
            }
        }
        if size == CGSize.zero {
            size = ToDoItem.size
        }
        return size
    }

    var body: some View {
        ToDoItem(todo: todo)
            .scaleEffect(scaleAmount)
            .frame(width: size.width, height: size.height)
    }
}

struct ToDos_Previews: PreviewProvider {
    static var previews: some View {
        ToDosView(todos: [] /* MockCalendar.todos */ )
    }
}
