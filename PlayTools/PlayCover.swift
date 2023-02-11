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
        NotificationCenter.default.addObserver(
            forName: UIScene.didActivateNotification,
            object: nil,
            queue: OperationQueue.main
        ) { notif in
            checkResizability();
        }
        AKInterface.initialize()
        PlayInput.shared.initialize()
        DiscordIPC.shared.initialize()
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
                AKInterface.shared!.terminateApplication()
            }
        }
    }

//    static public func checkResizability() {
//        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
//            if let window = scene.windows.first {
//                if window.rootViewController?.view.autoresizingMask.contains(.flexibleWidth) ?? false {
//                    print("Resizable Yes")
//                } else {
//                    print("Resizable No")
//                }
//            }
//        }
//    }
    
    static public func checkResizability() {
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            if let window = scene.windows.first {
                if window.rootViewController?.view.autoresizingMask.contains(.flexibleWidth) ?? false {
                    print("Resizable UIApplication Yes")
                } else {
                    print("Resizable UIApplication No")
                }
            }
        } else {
            if let nsWindow = PlayScreen.shared.nsWindow {
                if let resizable = nsWindow.value(forKeyPath: "styleMask.resizable") as? Bool {
                    if resizable {
                        print("Resizable nsWindow Yes")
                    } else {
                        print("Resizable nsWindow No")
                    }
                }
            }
        }
    }

    static func delay(_ delay: Double, closure: @escaping () -> Void) {
        let when = DispatchTime.now() + delay
        DispatchQueue.main.asyncAfter(deadline: when, execute: closure)
    }
}
