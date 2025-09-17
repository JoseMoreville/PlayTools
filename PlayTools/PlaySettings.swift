import Foundation
import UIKit

let settings = PlaySettings.shared

@objc public final class PlaySettings: NSObject {
    @objc public static let shared = PlaySettings()

    let bundleIdentifier = Bundle.main.infoDictionary?["CFBundleIdentifier"] as? String ?? ""
    let settingsUrl: URL
    var settingsData: AppSettingsData

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
    }

    lazy var discordActivity = settingsData.discordActivity

    lazy var keymapping = settingsData.keymapping

    lazy var notch = settingsData.notch

    lazy var sensitivity = settingsData.sensitivity / 100

    @objc lazy var bypass = settingsData.bypass

    @objc dynamic var windowSizeHeight: CGFloat {
        get { CGFloat(settingsData.windowHeight) }
        set { updateWindowSize(width: nil, height: newValue, persist: false) }
    }

    @objc dynamic var windowSizeWidth: CGFloat {
        get { CGFloat(settingsData.windowWidth) }
        set { updateWindowSize(width: newValue, height: nil, persist: false) }
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

    @objc func cacheWindowSize(width: CGFloat, height: CGFloat) {
        updateWindowSize(width: width, height: height, persist: false)
    }

    @objc func persistWindowSize(width: CGFloat, height: CGFloat) {
        updateWindowSize(width: width, height: height, persist: true)
    }

    private func updateWindowSize(width: CGFloat?, height: CGFloat?, persist: Bool) {
        var didChange = false

        if let width { didChange = updateWidth(width) || didChange }
        if let height { didChange = updateHeight(height) || didChange }

        if persist, didChange {
            persistSettings()
        }
    }

    private func updateWidth(_ value: CGFloat) -> Bool {
        let normalized = normalizedDimension(from: value)
        guard settingsData.windowWidth != normalized else { return false }
        settingsData.windowWidth = normalized
        return true
    }

    private func updateHeight(_ value: CGFloat) -> Bool {
        let normalized = normalizedDimension(from: value)
        guard settingsData.windowHeight != normalized else { return false }
        settingsData.windowHeight = normalized
        return true
    }

    private func normalizedDimension(from value: CGFloat) -> Int {
        let clamped = max(value, 1)
        return Int(clamped.rounded())
    }

    private func persistSettings() {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        do {
            let data = try encoder.encode(settingsData)
            try data.write(to: settingsUrl, options: .atomic)
        } catch {
            print("[PlayTools] Failed to persist PlaySettings: \(error)")
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
