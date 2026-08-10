import SwiftUI
import AppKit
import Combine

struct TodoItem: Identifiable, Equatable, Codable {
    var id = UUID()
    var text: String
    var isCompleted: Bool = false
}

struct DynamicNotchTodoView: View {
    @ObservedObject var notchState: NotchState
    @State private var config = NotchConfig()
    
    @Environment(\.openSettings) private var openSettingsAction
    
    @AppStorage("Manchot_AccentColor_Hex") private var accentColorHex: String = "#F7BA00"
    @AppStorage("Manchot_StrikeThroughEnabled") private var strikeThroughEnabled: Bool = true
    @AppStorage("Manchot_FontWeight") private var fontWeightName: String = "Regular"
    
    private var accentColor: Color {
        Color(hex: accentColorHex) ?? Color(red: 0.97, green: 0.73, blue: 0.0)
    }

    private var resolvedFontWeight: NSFont.Weight {
        switch fontWeightName {
        case "Ultralight": return .ultraLight
        case "Thin": return .thin
        case "Light": return .light
        case "Regular": return .regular
        case "Medium": return .medium
        case "Semibold": return .semibold
        case "Bold": return .bold
        case "Heavy": return .heavy
        case "Black": return .black
        default: return .regular
        }
    }

    private static let storageKey = "Manchot_Saved_Todo_Items"

    @State private var tasks: [TodoItem] = DynamicNotchTodoView.loadTasks() {
        didSet {
            DynamicNotchTodoView.saveTasks(tasks)
        }
    }
    
    @FocusState private var focusedTaskId: UUID?

    private var currentWidth: CGFloat {
        notchState.isExpanded ? config.expandedWidth : config.baseWidth
    }
    
    private var currentHeight: CGFloat {
        notchState.isExpanded ? config.expandedHeight : config.baseHeight
    }
    
    private var currentTopRadius: CGFloat {
        notchState.isExpanded ? config.expandedTopCornerRadius : config.baseTopCornerRadius
    }
    
    private var currentNotchRadius: CGFloat {
        notchState.isExpanded ? config.expandedNotchCornerRadius : config.baseNotchCornerRadius
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(action: openSettings) {
                    Image("setting")
                        .resizable()
                        .renderingMode(.template)
                        .frame(width: config.settingSize, height: config.settingSize)
                        .foregroundColor(Color.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, config.settingTopPadding)
            .padding(.trailing, config.settingTrailingPadding)
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: config.rowSpacing) {
                    ForEach($tasks) { $task in
                        InlineTaskRow(
                            task: $task,
                            config: config,
                            customWeight: resolvedFontWeight,
                            focusedTaskId: $focusedTaskId,
                            accentColor: accentColor,
                            strikeThroughEnabled: strikeThroughEnabled,
                            onStatusChange: {
                                reorderTasks()
                            },
                            onDeleteEmpty: {
                                deleteSpecificTask(id: task.id)
                            },
                            onSubmit: {
                                insertNewTask(after: task.id)
                            }
                        )
                    }
                }
                .padding(.horizontal, config.horizontalPadding)
                .padding(.top, 6)
                .padding(.bottom, config.horizontalPadding)
            }
        }
        .opacity(notchState.isExpanded ? 1.0 : 0.0)
        .frame(width: currentWidth + (currentTopRadius * 2), height: currentHeight, alignment: .top)
        .clipShape(
            NotchDropShape(
                dynamicWidth: currentWidth,
                dynamicHeight: currentHeight,
                topRadius: currentTopRadius,
                bottomRadius: currentNotchRadius
            )
        )
        .background(
            NotchDropShape(
                dynamicWidth: currentWidth,
                dynamicHeight: currentHeight,
                topRadius: currentTopRadius,
                bottomRadius: currentNotchRadius
            )
            .fill(Color.black)
            .shadow(
                color: notchState.isExpanded ? config.shadowColor.opacity(config.shadowOpacity) : Color.clear,
                radius: notchState.isExpanded ? config.shadowRadius : 0,
                x: config.shadowX,
                y: config.shadowY
            )
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, config.shadowPadding)
        .padding(.bottom, config.shadowPadding)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: notchState.isExpanded)
        .onAppear {
            if let last = tasks.last {
                focusedTaskId = last.id
            }
        }
    }

    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            openSettingsAction()
        } else {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        }
    }

    private func insertNewTask(after targetId: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == targetId }) else { return }
        let newTask = TodoItem(text: "", isCompleted: false)
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            tasks.insert(newTask, at: index + 1)
        }
        focusedTaskId = newTask.id
    }

    private func deleteSpecificTask(id: UUID) {
        guard let index = tasks.firstIndex(where: { $0.id == id }) else { return }
        
        if tasks.count == 1 {
            tasks[0].text = ""
            return
        }
        
        let targetFocusId: UUID? = (index > 0) ? tasks[index - 1].id : tasks[1].id
        
        withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
            tasks.remove(at: index)
        }
        focusedTaskId = targetFocusId
    }

    private func reorderTasks() {
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            let activeTasks = tasks.filter { !$0.isCompleted }
            let completedTasks = tasks.filter { $0.isCompleted }
            tasks = activeTasks + completedTasks
        }
    }

    private static func loadTasks() -> [TodoItem] {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([TodoItem].self, from: data),
           !decoded.isEmpty {
            return decoded
        }
        return [
            TodoItem(text: "Start writing"),
        ]
    }

    private static func saveTasks(_ tasks: [TodoItem]) {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: storageKey)
        }
    }
}

struct NotchDropShape: Shape {
    var dynamicWidth: CGFloat
    var dynamicHeight: CGFloat
    var topRadius: CGFloat
    var bottomRadius: CGFloat
    
    var animatableData: AnimatableData {
        get {
            AnimatableData(
                AnimatablePair(dynamicWidth, dynamicHeight),
                AnimatablePair(topRadius, bottomRadius)
            )
        }
        set {
            dynamicWidth = newValue.first.first
            dynamicHeight = newValue.first.second
            topRadius = newValue.second.first
            bottomRadius = newValue.second.second
        }
    }
    
    typealias AnimatableData = AnimatablePair<
        AnimatablePair<CGFloat, CGFloat>,
        AnimatablePair<CGFloat, CGFloat>
    >
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let notchW = dynamicWidth
        let notchH = dynamicHeight
        
        let midX = rect.midX
        let topY = rect.minY
        let leftWallX = midX - (notchW / 2)
        let rightWallX = midX + (notchW / 2)
        
        path.move(to: CGPoint(x: rect.minX, y: topY))
        path.addLine(to: CGPoint(x: leftWallX - topRadius, y: topY))
        
        path.addArc(
            center: CGPoint(x: leftWallX - topRadius, y: topY + topRadius),
            radius: topRadius,
            startAngle: .degrees(270),
            endAngle: .degrees(0),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: leftWallX, y: topY + notchH - bottomRadius))
        
        path.addArc(
            center: CGPoint(x: leftWallX + bottomRadius, y: topY + notchH - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(90),
            clockwise: true
        )
        
        path.addLine(to: CGPoint(x: rightWallX - bottomRadius, y: topY + notchH))
        
        path.addArc(
            center: CGPoint(x: rightWallX - bottomRadius, y: topY + notchH - bottomRadius),
            radius: bottomRadius,
            startAngle: .degrees(90),
            endAngle: .degrees(0),
            clockwise: true
        )
        
        path.addLine(to: CGPoint(x: rightWallX, y: topY + topRadius))
        
        path.addArc(
            center: CGPoint(x: rightWallX + topRadius, y: topY + topRadius),
            radius: topRadius,
            startAngle: .degrees(180),
            endAngle: .degrees(270),
            clockwise: false
        )
        
        path.addLine(to: CGPoint(x: rect.maxX, y: topY))
        
        path.closeSubpath()
        return path
    }
}

struct InlineTaskRow: View {
    @Binding var task: TodoItem
    var config: NotchConfig
    var customWeight: NSFont.Weight
    var focusedTaskId: FocusState<UUID?>.Binding
    var accentColor: Color
    var strikeThroughEnabled: Bool
    var onStatusChange: () -> Void
    var onDeleteEmpty: () -> Void
    var onSubmit: () -> Void
    
    @State private var checkmarkProgress: CGFloat = 0.0

    var body: some View {
        HStack(spacing: config.radioTextSpacing) {
            ZStack {
                Circle()
                    .fill(task.isCompleted ? accentColor : Color.clear)
                    .frame(width: config.radioRadius * 2, height: config.radioRadius * 2)
                
                Circle()
                    .stroke(task.isCompleted ? accentColor : Color.white.opacity(0.35), lineWidth: 1.5)
                    .frame(width: config.radioRadius * 2, height: config.radioRadius * 2)
                
                CheckmarkShape()
                    .trim(from: 0, to: task.isCompleted ? checkmarkProgress : 0)
                    .stroke(Color.black, style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
                    .frame(width: config.radioRadius * 0.95, height: config.radioRadius * 0.95)
            }
            .contentShape(Rectangle().inset(by: -(config.radioRadius * (config.radioHitboxMultiplier - 1.0))))
            .onTapGesture {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.72)) {
                    task.isCompleted.toggle()
                }
                
                if task.isCompleted {
                    checkmarkProgress = 0.0
                    withAnimation(.easeInOut(duration: 0.25).delay(0.05)) {
                        checkmarkProgress = 1.0
                    }
                } else {
                    checkmarkProgress = 0.0
                }

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                    onStatusChange()
                }
            }

            BackspaceTextField(
                text: $task.text,
                fontSize: config.taskFontSize,
                fontWeight: customWeight,
                isCompleted: task.isCompleted,
                accentColor: accentColor,
                strikeThroughEnabled: strikeThroughEnabled,
                onDeleteEmpty: onDeleteEmpty,
                onSubmit: onSubmit
            )
            .focused(focusedTaskId, equals: task.id)

            Spacer()
        }
        .onAppear {
            if task.isCompleted {
                checkmarkProgress = 1.0
            }
        }
    }
}

class CustomNSTextField: NSTextField {
    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.type == .keyDown && event.modifierFlags.contains(.command) {
            switch event.charactersIgnoringModifiers?.lowercased() {
            case "a":
                return NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: self)
            case "z":
                if event.modifierFlags.contains(.shift) {
                    return NSApp.sendAction(#selector(UndoManager.redo), to: nil, from: self)
                } else {
                    return NSApp.sendAction(#selector(UndoManager.undo), to: nil, from: self)
                }
            default:
                break
            }
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct BackspaceTextField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat
    var fontWeight: NSFont.Weight
    var isCompleted: Bool
    var accentColor: Color
    var strikeThroughEnabled: Bool
    var onDeleteEmpty: () -> Void
    var onSubmit: () -> Void

    class Coordinator: NSObject, NSTextFieldDelegate {
        var parent: BackspaceTextField
        var isEditingLocally = false

        init(_ parent: BackspaceTextField) {
            self.parent = parent
        }

        func controlTextDidChange(_ notification: Notification) {
            if let textField = notification.object as? NSTextField {
                isEditingLocally = true
                parent.text = textField.stringValue
                isEditingLocally = false
            }
        }

        func textDidBeginEditing(_ notification: Notification) {
            if let textField = notification.object as? NSTextField,
               let fieldEditor = textField.currentEditor() as? NSTextView {
                fieldEditor.insertionPointColor = NSColor(parent.accentColor)
            }
        }

        func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.deleteBackward) {
                if parent.text.isEmpty {
                    parent.onDeleteEmpty()
                    return true
                }
            } else if commandSelector == #selector(NSResponder.insertNewline) {
                parent.onSubmit()
                return true
            }
            return false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSTextField {
        let textField = CustomNSTextField()
        textField.delegate = context.coordinator
        textField.isBordered = false
        textField.drawsBackground = false
        textField.focusRingType = .none
        textField.font = NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        textField.allowsEditingTextAttributes = true
        textField.stringValue = text
        return textField
    }

    func updateNSView(_ nsView: NSTextField, context: Context) {
        context.coordinator.parent = self
        
        if context.coordinator.isEditingLocally {
            return
        }
        
        if nsView.stringValue != text {
            nsView.stringValue = text
        }
        
        if let fieldEditor = nsView.currentEditor() as? NSTextView {
            fieldEditor.insertionPointColor = NSColor(accentColor)
        }
        
        let targetColor = isCompleted ? NSColor.white.withAlphaComponent(0.35) : NSColor.white
        var attributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: targetColor,
            .font: NSFont.systemFont(ofSize: fontSize, weight: fontWeight)
        ]
        
        if isCompleted && strikeThroughEnabled {
            attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
            attributes[.strikethroughColor] = targetColor
        } else {
            attributes[.strikethroughStyle] = 0
        }
        
        nsView.attributedStringValue = NSAttributedString(string: text, attributes: attributes)
    }
}

struct CheckmarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + rect.width * 0.1, y: rect.midY + rect.height * 0.05))
        path.addLine(to: CGPoint(x: rect.minX + rect.width * 0.38, y: rect.maxY - rect.height * 0.1))
        path.addLine(to: CGPoint(x: rect.maxX - rect.width * 0.05, y: rect.minY + rect.height * 0.15))
        return path
    }
}
