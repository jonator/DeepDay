//
//  BottomSheetView.swift
//  deepday
//
//  Created by Jon Ator on 10/9/20.
//

import EventKit
import SwiftUI

private enum Constants {
    static let radius: CGFloat = 16
    static let dragHandleHeight: CGFloat = 6
    static let dragHandleWidth: CGFloat = 60
    static let snapRatio: CGFloat = 0.25
    static let minHeightRatio: CGFloat = 0
}

struct SelectedItemBottomSheet: View {
    @EnvironmentObject var viewModel: ViewModel

    var body: some View {
        BottomSheetView(isOpen: $viewModel.sheetPresented, maxHeight: UIScreen.main.bounds.height * 0.3) {
            if case .toDoSelected(let id) = viewModel.state {
                if let todo = viewModel.attemptGetToDo(by: id) {
                    ToDoDetail(todo: todo, onChangeActivityType: viewModel.changeToDo(activityType:))
                }
            }
            if case .eventSelected(let id) = viewModel.state {
                if let event = viewModel.attemptGetEvent(by: id) {
                    EventDetail(event: event, onChangeActivityType: viewModel.changeEvent(activityType:))
                }
            }
        }
    }
}

struct ToDoDetail: View {
    let todo: EKReminder
    let onChangeActivityType: (ActivityType) -> ()

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 20) {
                Text(todo.title)
                    .font(.title2)
                    .fontWeight(.bold)
                ActivityTypeRadioButtons(activityType: todo.activityType, onUpdateActivityType: onChangeActivityType)
                    .frame(width: geo.size.width)
            }
            .padding([.leading, .trailing], 15)
        }
    }
}

struct EventDetail: View {
    let event: EKEvent
    let onChangeActivityType: (ActivityType) -> ()

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Text(event.title ?? "(reserved)")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                ActivityTypeRadioButtons(activityType: event.activityType, onUpdateActivityType: onChangeActivityType)
                    .frame(width: geo.size.width)
            }
            .padding([.leading, .trailing], 15)
        }
    }
}

struct ActivityTypeRadioButtons: View {
    @Environment(\.colorScheme) var colorScheme

    let activityType: ActivityType
    var onUpdateActivityType: (ActivityType) -> ()

    var color: Color {
        colorScheme == .light ? DesignPalette.Colors.primary : Color.gray
    }

    var isShallow: Bool {
        switch activityType {
        case .shallow: return true
        default: return false
        }
    }

    var body: some View {
        HStack(spacing: 50) {
            Text("Shallow")
                .font(.title2)
                .fontWeight(.bold)
                .if(isShallow) {
                    $0.underline()
                }
                .foregroundColor(color)
                .opacity(0.85)
                .onTapGesture {
                    onUpdateActivityType(.shallow)
                }

            Text("Deep")
                .font(.title2)
                .fontWeight(.bold)
                .if(!isShallow) {
                    $0.underline()
                }
                .foregroundColor(color)
                .onTapGesture {
                    onUpdateActivityType(.deep)
                }
        }
    }
}

struct BottomSheetView<Content: View>: View {
    @Binding var isOpen: Bool
    @GestureState private var translation: CGFloat = 0

    let maxHeight: CGFloat
    let minHeight: CGFloat
    let content: Content

    init(isOpen: Binding<Bool>, maxHeight: CGFloat, @ViewBuilder content: () -> Content) {
        self.minHeight = maxHeight * Constants.minHeightRatio
        self.maxHeight = maxHeight
        self.content = content()
        self._isOpen = isOpen
    }

    private var offset: CGFloat {
        isOpen ? 0 : maxHeight - minHeight
    }

    private var dragHandle: some View {
        RoundedRectangle(cornerRadius: Constants.radius)
            .fill(Color.secondary)
            .frame(
                width: Constants.dragHandleWidth,
                height: Constants.dragHandleHeight
            )
    }

    var body: some View {
        GeometryReader { geometry in
            VStack {
                self.dragHandle
                    .padding()
                self.content
            }
            .frame(width: geometry.size.width, height: self.maxHeight, alignment: .top)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(Constants.radius)
            .frame(height: geometry.size.height, alignment: .bottom)
            .offset(y: max(self.offset + self.translation, 0))
            .animation(.interactiveSpring())
            .gesture(
                DragGesture().updating(self.$translation) { value, state, _ in
                    state = value.translation.height
                }.onEnded { value in
                    let snapDistance = self.maxHeight * Constants.snapRatio
                    guard abs(value.translation.height) > snapDistance else {
                        return
                    }
                    self.isOpen = value.translation.height < 0
                }
            )
        }
    }
}

struct BottomSheet_Previews: PreviewProvider {
    @State private static var shown: Bool = true

    static var previews: some View {
        BottomSheetView(isOpen: $shown, maxHeight: 600) {
            Rectangle().fill(Color.red)
        }.edgesIgnoringSafeArea(.all)
    }
}
