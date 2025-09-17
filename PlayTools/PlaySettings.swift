import Dispatch
import Foundation
import UIKit

let settings = PlaySettings.shared

@objc public final class PlaySettings: NSObject {
    @objc public static let shared = PlaySettings()

    let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    let settingsUrl: URL
    var settingsData: AppSettingsData
    private var cachedWindowSizeWidth: CGFloat
    private var cachedWindowSizeHeight: CGFloat
    private let windowSizeUpdateTolerance: CGFloat = 0.5
    private var pendingWindowSizeSave: DispatchWorkItem?

    override init() {
        settingsUrl = URL(fileURLWithPath: "/Users/\(NSUserName())/Library/Containers/io.playcover.PlayCover")
            .appendingPathComponent("App Settings")
            .appendingPathComponent("\(bundleIdentifier).plist")
        do {
            let data = try Data(contentsOf: settingsUrl)
            settingsData = try PropertyListDecoder().decode(AppSettingsData.self, from: data)
        } catch {
            settingsData = AppSettingsData()
            print("[PlayTools] PlaySettings decode failed.\n%@")
        }
        cachedWindowSizeWidth = CGFloat(settingsData.windowWidth)
        cachedWindowSizeHeight = CGFloat(settingsData.windowHeight)
        super.init()
    }

    lazy var discordActivity = settingsData.discordActivity

    lazy var keymapping = settingsData.keymapping

    lazy var notch = settingsData.notch

    lazy var sensitivity = settingsData.sensitivity / 100

    @objc lazy var bypass = settingsData.bypass

    @objc var windowSizeHeight: CGFloat {
        get { cachedWindowSizeHeight }
        set {
            if updateWindowHeightIfNeeded(newValue) {
                scheduleWindowSizeSave()
            }
        }
    }

    @objc var windowSizeWidth: CGFloat {
        get { cachedWindowSizeWidth }
        set {
            if updateWindowWidthIfNeeded(newValue) {
                scheduleWindowSizeSave()
            }
        }
    }

    @objc lazy var inverseScreenValues = settingsData.inverseScreenValues

    @objc lazy var adaptiveDisplay = settingsData.resolution == 0 ? false : true

    @objc lazy var deviceModel = settingsData.iosDeviceModel as NSString

    @objc lazy var oemID: NSString = {
        switch settingsData.iosDeviceModel {
        case "iPad6,7":
            return "J98aAP"
        case "iPad8,6":
            return "J320xAP"
        case "iPad13,8":
            return "J522AP"
        case "iPad14,5":
            return "A2436"
        case "iPad16,6":
            return "A2925"
        case "iPhone14,3":
            return "A2645"
        case "iPhone15,3":
            return "A2896"
        case "iPhone16,2":
            return "A2849"
        case "iPhone17,2":
            return "A3084"
        default:
            return "J320xAP"
        }
    }()

    @objc lazy var playChain = settingsData.playChain

    @objc lazy var playChainDebugging = settingsData.playChainDebugging

    @objc lazy var windowFixMethod = settingsData.windowFixMethod

    @objc lazy var customScaler = settingsData.customScaler

    @objc lazy var rootWorkDir = settingsData.rootWorkDir

    @objc lazy var noKMOnInput = settingsData.noKMOnInput

    @objc lazy var enableScrollWheel = settingsData.enableScrollWheel

    @objc lazy var hideTitleBar = settingsData.hideTitleBar

    @objc lazy var checkMicPermissionSync = settingsData.checkMicPermissionSync

    func persistWindowSize(width: CGFloat, height: CGFloat, isInverted: Bool) {
        let targetWidth = isInverted ? height : width
        let targetHeight = isInverted ? width : height

        let didUpdateWidth = updateWindowWidthIfNeeded(targetWidth)
        let didUpdateHeight = updateWindowHeightIfNeeded(targetHeight)

        if didUpdateWidth || didUpdateHeight {
            scheduleWindowSizeSave()
        }
    }

    private func updateWindowWidthIfNeeded(_ value: CGFloat) -> Bool {
        let normalized = normalizedWindowValue(value)
        guard abs(cachedWindowSizeWidth - normalized) > windowSizeUpdateTolerance else { return false }
        cachedWindowSizeWidth = normalized
        settingsData.windowWidth = Int(normalized)
        return true
    }

    private func updateWindowHeightIfNeeded(_ value: CGFloat) -> Bool {
        let normalized = normalizedWindowValue(value)
        guard abs(cachedWindowSizeHeight - normalized) > windowSizeUpdateTolerance else { return false }
        cachedWindowSizeHeight = normalized
        settingsData.windowHeight = Int(normalized)
        return true
    }

    private func normalizedWindowValue(_ value: CGFloat) -> CGFloat {
        let rounded = max(1, Int(round(value)))
        return CGFloat(rounded)
    }

    private func scheduleWindowSizeSave() {
        pendingWindowSizeSave?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.writeSettingsData()
        }
        pendingWindowSizeSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }

    private func writeSettingsData() {
        do {
            let encoded = try PropertyListEncoder().encode(settingsData)
            try encoded.write(to: settingsUrl)
        } catch {
            print("[PlayTools] PlaySettings save failed: \(error)")
        }
    }
}

struct AppSettingsData: Codable {
    var keymapping = true
    var sensitivity: Float = 50

    var disableTimeout = false
    var iosDeviceModel = "iPad13,8"
    var windowWidth = 1920
    var windowHeight = 1080
    var customScaler = 2.0
    var resolution = 2
    var aspectRatio = 1
    var notch = false
    var bypass = false
    var discordActivity = DiscordActivity()
    var version = "2.0.0"
    var playChain = false
    var playChainDebugging = false
    var inverseScreenValues = false
    var windowFixMethod = 0
    var rootWorkDir = true
    var noKMOnInput = false
    var enableScrollWheel = true
    var hideTitleBar = false
    var checkMicPermissionSync = false
}
