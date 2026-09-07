import Foundation

enum DeviceFirmwareCachesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "device-firmware-caches",
        title: "Device Firmware Downloads",
        relativePaths: [
            "Library/iTunes/iPhone Software Updates",
            "Library/iTunes/iPad Software Updates",
            "Library/iTunes/iPod Software Updates",
            "Library/iTunes/Apple TV Software Updates",
        ],
        minimumAgeDays: 30,
        enumerationMode: .topLevelEntries,
        risk: .review,
        explanation: "Previously downloaded Apple device firmware packages. Devices may need to download the firmware again for a future restore or update."
    )
}
