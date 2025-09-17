//
//  MacPlugin.swift
//  AKInterface
//
//  Created by Isaac Marovitz on 13/09/2022.
//

import AppKit
import CoreGraphics
import Foundation

// Add a lightweight struct so we can decode only the flag we care about
private struct AKAppSettingsData: Codable {
    var hideTitleBar: Bool?
}

private struct WindowSize: Equatable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    init?(frame: CGRect) {
        guard frame.width > 0, frame.height > 0 else { return nil }
        let normalizedWidth = Int(max(frame.width, 1).rounded())
        let normalizedHeight = Int(max(frame.height, 1).rounded())
        self.init(width: normalizedWidth, height: normalizedHeight)
    }

    init?(dictionary: [String: Any]) {
        guard let widthValue = WindowSize.extractIntValue(forKey: "windowWidth", from: dictionary),
              let heightValue = WindowSize.extractIntValue(forKey: "windowHeight", from: dictionary) else {
            return nil
        }
        self.init(width: widthValue, height: heightValue)
    }

    private static func extractIntValue(forKey key: String, from dictionary: [String: Any]) -> Int? {
        if let number = dictionary[key] as? NSNumber {
            return number.intValue
        }
        if let stringValue = dictionary[key] as? String, let intValue = Int(stringValue) {
            return intValue
        }
        return dictionary[key] as? Int
    }
}

class AKPlugin: NSObject, Plugin {
    private static let appSettingsURL: URL = {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? ""
        return URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Containers/io.playcover.PlayCover")
            .appendingPathComponent("App Settings")
            .appendingPathComponent("\(bundleIdentifier).plist")
    }()

    private static var cachedWindowSize: WindowSize? = {
        guard let dictionary = loadAppSettingsDictionary() else { return nil }
        return WindowSize(dictionary: dictionary)
    }()

    private static func loadAppSettingsDictionary() -> [String: Any]? {
        guard let data = try? Data(contentsOf: appSettingsURL) else { return nil }
        return (try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)) as? [String: Any]
    }

    @discardableResult
    private static func persistAppSettingsDictionary(_ dictionary: [String: Any]) -> Bool {
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: dictionary, format: .binary, options: 0)
            try data.write(to: appSettingsURL, options: .atomic)
            return true
        } catch {
            print("[PlayTools] Failed to persist PlaySettings from plugin: \(error)")
            return false
        }
    }

    private weak var primaryWindow: NSWindow?
    private var pendingWindowSize: WindowSize?
    private var resizeDebounceWorkItem: DispatchWorkItem?
    private var resizeObserver: NSObjectProtocol?
    private var liveResizeObserver: NSObjectProtocol?

    required override init() {
        super.init()
        guard hideTitleBarSetting else { return }

        if let window = NSApplication.shared.windows.first {
            configureWindow(window)
        }

        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main) { [weak self] notif in
            guard let self, let win = notif.object as? NSWindow else { return }
            self.configureWindow(win)
        }

        resizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResizeNotification,
            object: nil,
            queue: .main) { [weak self] notif in
            guard let self, let window = notif.object as? NSWindow else { return }
            self.handleWindowDidResize(window)
        }

        liveResizeObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didEndLiveResizeNotification,
            object: nil,
            queue: .main) { [weak self] notif in
            guard let self, let window = notif.object as? NSWindow else { return }
            self.persistPendingWindowSize(for: window)
        }
    }

    deinit {
        if let observer = resizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = liveResizeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        resizeDebounceWorkItem?.cancel()
        persistPendingWindowSize()
    }

    private func configureWindow(_ window: NSWindow) {
        window.styleMask.insert([.resizable, .fullSizeContentView])
        window.collectionBehavior = [.fullScreenPrimary, .managed, .participatesInCycle]

        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = nil
        window.title = ""
        NSWindow.allowsAutomaticWindowTabbing = true

        if shouldTrack(window: window, allowAssignment: true) {
            updateTrackedWindowSize(using: window, persistImmediately: true)
        }
    }

    private func configureWindow(_ window: NSWindow) {
        window.styleMask.insert([.resizable, .fullSizeContentView])
        window.collectionBehavior = [.fullScreenPrimary, .managed, .participatesInCycle]

        window.isMovable = true
        window.isMovableByWindowBackground = true
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.toolbar = nil
        window.title = ""
        NSWindow.allowsAutomaticWindowTabbing = true
    }

    var screenCount: Int {
        NSScreen.screens.count
    }

    var mousePoint: CGPoint {
        NSApplication.shared.windows.first?.mouseLocationOutsideOfEventStream ?? CGPoint()
    }

    var windowFrame: CGRect {
        NSApplication.shared.windows.first?.frame ?? CGRect()
    }

    var isMainScreenEqualToFirst: Bool {
        return NSScreen.main == NSScreen.screens.first
    }

    var mainScreenFrame: CGRect {
        return NSScreen.main!.frame as CGRect
    }

    var isFullscreen: Bool {
        NSApplication.shared.windows.first!.styleMask.contains(.fullScreen)
    }

    var cmdPressed: Bool = false
    var cursorHideLevel = 0
    func hideCursor() {
        NSCursor.hide()
        cursorHideLevel += 1
        CGAssociateMouseAndMouseCursorPosition(0)
        warpCursor()
    }

    func hideCursorMove() {
        NSCursor.setHiddenUntilMouseMoves(true)
    }

    func warpCursor() {
        guard let firstScreen = NSScreen.screens.first else {return}
        let frame = windowFrame
        // Convert from NS coordinates to CG coordinates
        CGWarpMouseCursorPosition(CGPoint(x: frame.midX, y: firstScreen.frame.height - frame.midY))
    }

    func unhideCursor() {
        NSCursor.unhide()
        cursorHideLevel -= 1
        if cursorHideLevel <= 0 {
            CGAssociateMouseAndMouseCursorPosition(1)
        }
    }

    func terminateApplication() {
        NSApplication.shared.terminate(self)
    }

    private var modifierFlag: UInt = 0

    // swiftlint:disable:next function_body_length
    func setupKeyboard(keyboard: @escaping (UInt16, Bool, Bool, Bool) -> Bool,
                       swapMode: @escaping () -> Bool) {
        func checkCmd(modifier: NSEvent.ModifierFlags) -> Bool {
            if modifier.contains(.command) {
                self.cmdPressed = true
                return true
            } else if self.cmdPressed {
                self.cmdPressed = false
            }
            return false
        }
        NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { event in
            if checkCmd(modifier: event.modifierFlags) {
                return event
            }
            let consumed = keyboard(event.keyCode, true, event.isARepeat,
                                    event.modifierFlags.contains(.control))
            if consumed {
                return nil
            }
            return event
        })
        NSEvent.addLocalMonitorForEvents(matching: .keyUp, handler: { event in
            if checkCmd(modifier: event.modifierFlags) {
                return event
            }
            let consumed = keyboard(event.keyCode, false, false,
                                    event.modifierFlags.contains(.control))
            if consumed {
                return nil
            }
            return event
        })
        NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { event in
            if checkCmd(modifier: event.modifierFlags) {
                return event
            }
            let pressed = self.modifierFlag < event.modifierFlags.rawValue
            let changed = self.modifierFlag ^ event.modifierFlags.rawValue
            self.modifierFlag = event.modifierFlags.rawValue
            let changedFlags = NSEvent.ModifierFlags(rawValue: changed)
            if pressed && changedFlags.contains(.option) {
                if swapMode() {
                    return nil
                }
                return event
            }
            let consumed = keyboard(event.keyCode, pressed, false,
                                    event.modifierFlags.contains(.control))
            if consumed {
                return nil
            }
            return event
        })
    }

    func setupMouseMoved(_ mouseMoved: @escaping (CGFloat, CGFloat) -> Bool) {
        let mask: NSEvent.EventTypeMask = [.leftMouseDragged, .otherMouseDragged, .rightMouseDragged]
        NSEvent.addLocalMonitorForEvents(matching: mask, handler: { event in
            let consumed = mouseMoved(event.deltaX, event.deltaY)
            if consumed {
                return nil
            }
            return event
        })
        // transpass mouse moved event when no button pressed, for traffic light button to light up
        NSEvent.addLocalMonitorForEvents(matching: .mouseMoved, handler: { event in
            _ = mouseMoved(event.deltaX, event.deltaY)
            return event
        })
    }

    func setupMouseButton(left: Bool, right: Bool, _ consumed: @escaping (Int, Bool) -> Bool) {
        let downType: NSEvent.EventTypeMask = left ? .leftMouseDown : right ? .rightMouseDown : .otherMouseDown
        let upType: NSEvent.EventTypeMask = left ? .leftMouseUp : right ? .rightMouseUp : .otherMouseUp

        // Helper to detect whether the event is inside any of the window "traffic-light" buttons
        func isInTrafficLightArea(_ event: NSEvent) -> Bool {
            if self.hideTitleBarSetting == false {
                return false
            }
            guard let win = event.window else { return false }
            let pointInWindow = event.locationInWindow
            let buttonTypes: [NSWindow.ButtonType] = [.closeButton, .miniaturizeButton, .zoomButton, .fullScreenButton]
            for type in buttonTypes {
                if let button = win.standardWindowButton(type) {
                    let localPoint = button.convert(pointInWindow, from: nil) // convert from window coords
                    if button.bounds.contains(localPoint) {
                        return true
                    }
                }
            }
            return false
        }

        NSEvent.addLocalMonitorForEvents(matching: downType, handler: { event in
            // Always allow clicks on the window traffic-light buttons to pass through
            if isInTrafficLightArea(event) {
                return event
            }

            // Detect double-clicks on the title-bar area (respecting system preference)

            if left && event.clickCount == 2, self.hideTitleBarSetting, let win = event.window {
                let contentRect = win.contentLayoutRect
                // Title-bar area is the region above contentLayoutRect
                if event.locationInWindow.y > contentRect.maxY {
                    win.performZoom(nil)
                    return nil
                }
            }

            // For traffic light buttons when fullscreen
            if event.window != NSApplication.shared.windows.first! {
                return event
            }
            if consumed(event.buttonNumber, true) {
                return nil
            }
            return event
        })
        NSEvent.addLocalMonitorForEvents(matching: upType, handler: { event in
            // Always allow releases on the traffic-light buttons to pass through
            if isInTrafficLightArea(event) {
                return event
            }
            if consumed(event.buttonNumber, false) {
                return nil
            }
            return event
        })
    }

    func setupScrollWheel(_ onMoved: @escaping (CGFloat, CGFloat) -> Bool) {
        NSEvent.addLocalMonitorForEvents(matching: NSEvent.EventTypeMask.scrollWheel, handler: { event in
            var deltaX = event.scrollingDeltaX, deltaY = event.scrollingDeltaY
            if !event.hasPreciseScrollingDeltas {
                deltaX *= 16
                deltaY *= 16
            }
            let consumed = onMoved(deltaX, deltaY)
            if consumed {
                return nil
            }
            return event
        })
    }

    func urlForApplicationWithBundleIdentifier(_ value: String) -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: value)
    }

    func setMenuBarVisible(_ visible: Bool) {
        NSMenu.setMenuBarVisible(visible)
    }

    /// Convenience instance property that exposes the cached static preference.
    private var hideTitleBarSetting: Bool { Self.hideTitleBarPreference }

    fileprivate static var hideTitleBarPreference: Bool = {
        guard let data = try? Data(contentsOf: appSettingsURL),
              let decoded = try? PropertyListDecoder().decode(AKAppSettingsData.self, from: data) else {
            return false
        }
        return decoded.hideTitleBar ?? false
    }()

    private func handleWindowDidResize(_ window: NSWindow) {
        guard shouldTrack(window: window, allowAssignment: primaryWindow == nil) else { return }
        scheduleWindowSizePersistence(for: window)
    }

    private func shouldTrack(window: NSWindow, allowAssignment: Bool) -> Bool {
        if let tracked = primaryWindow {
            return tracked === window
        }
        if allowAssignment {
            primaryWindow = window
            return true
        }
        return false
    }

    private func updateTrackedWindowSize(using window: NSWindow, persistImmediately: Bool) {
        guard let size = WindowSize(frame: window.frame) else { return }
        pendingWindowSize = size
        if persistImmediately {
            persistPendingWindowSize()
        } else {
            scheduleFlushWorkItem()
        }
    }

    private func scheduleWindowSizePersistence(for window: NSWindow) {
        guard let size = WindowSize(frame: window.frame) else { return }
        pendingWindowSize = size
        scheduleFlushWorkItem()
    }

    private func scheduleFlushWorkItem() {
        resizeDebounceWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.persistPendingWindowSize()
        }
        resizeDebounceWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: workItem)
    }

    private func persistPendingWindowSize(for window: NSWindow? = nil) {
        if let window {
            guard shouldTrack(window: window, allowAssignment: primaryWindow == nil) else { return }
            if let size = WindowSize(frame: window.frame) {
                pendingWindowSize = size
            }
        }

        guard let size = pendingWindowSize else { return }
        pendingWindowSize = nil
        resizeDebounceWorkItem?.cancel()
        resizeDebounceWorkItem = nil

        if size == Self.cachedWindowSize {
            return
        }

        var dictionary = Self.loadAppSettingsDictionary() ?? [:]
        dictionary["windowWidth"] = size.width
        dictionary["windowHeight"] = size.height
        if Self.persistAppSettingsDictionary(dictionary) {
            Self.cachedWindowSize = size
        }
    }
}
