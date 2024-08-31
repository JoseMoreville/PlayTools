//
//  PlayCover.swift
//  PlayTools
//

import Foundation
import UIKit

public class PlayCover: NSObject {

    static let shared = PlayCover()
    var menuController: MenuController?

    @objc static public func launch() {
        quitWhenClose()
        AKInterface.initialize()
        PlayInput.shared.initialize()
        DiscordIPC.shared.initialize()

        if PlaySettings.shared.rootWorkDir {
            // Change the working directory to / just like iOS
            FileManager.default.changeCurrentDirectoryPath("/")
        }
        makeWindowResizable()
    }

    @objc static public func initMenu(menu: NSObject) {
        guard let menuBuilder = menu as? UIMenuBuilder else { return }
        shared.menuController = MenuController(with: menuBuilder)
    }

    static public func quitWhenClose() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name(rawValue: "NSWindowWillCloseNotification"),
            object: nil,
            queue: OperationQueue.main
        ) { notif in
            if PlayScreen.shared.nsWindow?.isEqual(notif.object) ?? false {
                // Step 1: Resign active
                for scene in UIApplication.shared.connectedScenes {
                    scene.delegate?.sceneWillResignActive?(scene)
                    NotificationCenter.default.post(name: UIScene.willDeactivateNotification,
                                                    object: scene)
                }
                UIApplication.shared.delegate?.applicationWillResignActive?(UIApplication.shared)
                NotificationCenter.default.post(name: UIApplication.willResignActiveNotification,
                                                object: UIApplication.shared)

                // Step 2: Enter background
                for scene in UIApplication.shared.connectedScenes {
                    scene.delegate?.sceneDidEnterBackground?(scene)
                    NotificationCenter.default.post(name: UIScene.didEnterBackgroundNotification,
                                                    object: scene)
                }
                UIApplication.shared.delegate?.applicationDidEnterBackground?(UIApplication.shared)
                NotificationCenter.default.post(name: UIApplication.didEnterBackgroundNotification,
                                                object: UIApplication.shared)

                // Step 2.5: End UIBackgroundTask
                // There is an expiration handler, but idk how to invoke it. Skip for now.

                // Step 3: Terminate
                UIApplication.shared.delegate?.applicationWillTerminate?(UIApplication.shared)
                NotificationCenter.default.post(name: UIApplication.willTerminateNotification,
                                                object: UIApplication.shared)
                DispatchQueue.main.async(execute: AKInterface.shared!.terminateApplication)

                // Step 3.5: End BGTask
                // BGTask typically runs in another process and is tricky to terminate.
                // It may run into infinite loops, end up silently heating the device up.
                // This actually happens for ToF. Hope future developers can solve this.
            }
        }
    }

    static func delay(_ delay: Double, closure: @escaping () -> Void) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }

    static private func makeWindowResizable() {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first,
                  let nsWindow = window.value(forKey: "nsWindow") as? NSObject else {
                print("Failed to get NSWindow")
                return
            }

            // Enable window resizing
            nsWindow.setValue(false, forKey: "styleMask")
            nsWindow.setValue(true, forKey: "isOpaque")
            nsWindow.setValue(false, forKey: "hasShadow")

            let styleMask: UInt =
                (1 << 0) |  // NSWindowStyleMaskTitled
                (1 << 1) |  // NSWindowStyleMaskClosable
                (1 << 2) |  // NSWindowStyleMaskMiniaturizable
                (1 << 3) |  // NSWindowStyleMaskResizable
                (1 << 4)    // NSWindowStyleMaskUnifiedTitleAndToolbar

            nsWindow.setValue(styleMask, forKey: "styleMask")
            // Set minimum and maximum sizes using CGSize
            let minSize = CGSize(width: 300, height: 300)
            let maxSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            nsWindow.setValue(minSize, forKey: "minSize")
            nsWindow.setValue(maxSize, forKey: "maxSize")

            // Force the window to update
            nsWindow.performSelector(onMainThread: Selector(("makeKeyAndOrderFront:")), with: nil, waitUntilDone: true)
        }
    }
}
