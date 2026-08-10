import SwiftUI
import AppKit
import Combine
import Sparkle

struct NotchConfig {
    // Collapsed (Initial Base Notch) State
    var baseWidth: CGFloat = 170
    var baseHeight: CGFloat = 32
    var baseCornerRadius: CGFloat = 8
    var baseTopCornerRadius: CGFloat = 8
    var baseNotchCornerRadius: CGFloat = 8
    
    // Expanded State
    var expandedWidth: CGFloat = 530
    var expandedHeight: CGFloat = 164
    var expandedCornerRadius: CGFloat = 25
    var expandedTopCornerRadius: CGFloat = 18
    var expandedNotchCornerRadius: CGFloat = 18

    // Internal Cutout Bounds for Hover Detection
    var notchCutoutWidth: CGFloat = 210
    var notchCutoutHeight: CGFloat = 35
    
    // Typography & Spacing
    var taskFontSize: CGFloat = 22
    var dateFontSize: CGFloat = 13
    var rowSpacing: CGFloat = 7
    var horizontalPadding: CGFloat = 36
    var verticalTopPadding: CGFloat = 22
    var radioTextSpacing: CGFloat = 10
    var radioRadius: CGFloat = 9
    var radioHitboxMultiplier: CGFloat = 1.2
    var topOffset: CGFloat = 1
    
    var settingSize: CGFloat = 14
    var settingTopPadding: CGFloat = 10
    var settingTrailingPadding: CGFloat = 35
    
    // Shadow Parameters
    var shadowColor: Color = .black
    var shadowRadius: CGFloat = 16
    var shadowOpacity: Double = 0.5
    var shadowX: CGFloat = 0
    var shadowY: CGFloat = 8
    var shadowPadding: CGFloat = 40
}

class NotchState: ObservableObject {
    @Published var isExpanded: Bool = false
}

@main
struct ManchotApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Sparkle Updater Controller
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        // Initialize Sparkle automatically
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    var body: some Scene {
        Settings {
            SettingsView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.updater.checkForUpdates()
                }
            }
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var panel: ManchotPanel!
    let notchState = NotchState()
    let config = NotchConfig()
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        let view = DynamicNotchTodoView(notchState: notchState)
        
        panel = ManchotPanel(contentView: view, notchState: notchState, config: config)
        panel.orderFront(nil)
    }
}

class ManchotPanel: NSPanel {
    var notchState: NotchState
    var config: NotchConfig
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    init<Content: View>(contentView: Content, notchState: NotchState, config: NotchConfig) {
        self.notchState = notchState
        self.config = config
        
        let pad = config.shadowPadding
        let panelWidth = config.expandedWidth + (config.expandedTopCornerRadius * 2) + (pad * 2)
        let panelHeight = config.expandedHeight + pad
        
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )
        
        self.isFloatingPanel = true
        self.level = .screenSaver
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.titlebarAppearsTransparent = true
        self.alphaValue = 1.0
        self.ignoresMouseEvents = true
        
        let hostingView = NSHostingView(rootView: contentView)
        self.contentView = hostingView
        
        if let screen = NSScreen.main {
            let xPos = screen.frame.midX - (panelWidth / 2)
            let yPos = screen.frame.maxY - panelHeight + config.topOffset
            self.setFrameOrigin(NSPoint(x: xPos, y: yPos))
        }
        
        setupMouseMonitors()
        
        notchState.$isExpanded
            .removeDuplicates()
            .sink { [weak self] expanded in
                guard let self = self else { return }
                if expanded {
                    self.ignoresMouseEvents = false
                } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        if !self.notchState.isExpanded {
                            self.ignoresMouseEvents = true
                        }
                    }
                }
            }
            .store(in: &cancellables)
    }

    private func setupMouseMonitors() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] _ in
            self?.evaluateHover()
        }
        
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.evaluateHover()
            return event
        }
    }

    private func evaluateHover() {
        guard let screen = NSScreen.main else { return }
        let mouseLoc = NSEvent.mouseLocation
        
        let screenMaxY = screen.frame.maxY
        let screenMidX = screen.frame.midX
        
        let cutoutRect = NSRect(
            x: screenMidX - (config.notchCutoutWidth / 2),
            y: screenMaxY - config.notchCutoutHeight,
            width: config.notchCutoutWidth,
            height: config.notchCutoutHeight
        )
        
        let expandedWidthTotal = config.expandedWidth + (config.expandedTopCornerRadius * 2)
        let expandedRect = NSRect(
            x: screenMidX - (expandedWidthTotal / 2),
            y: screenMaxY - config.expandedHeight,
            width: expandedWidthTotal,
            height: config.expandedHeight
        )
        
        if !notchState.isExpanded {
            if cutoutRect.contains(mouseLoc) {
                DispatchQueue.main.async {
                    self.ignoresMouseEvents = false
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        self.notchState.isExpanded = true
                    }
                }
            }
        } else {
            if !expandedRect.contains(mouseLoc) {
                DispatchQueue.main.async {
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.78)) {
                        self.notchState.isExpanded = false
                    }
                }
            }
        }
    }

    deinit {
        if let monitor = globalMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
