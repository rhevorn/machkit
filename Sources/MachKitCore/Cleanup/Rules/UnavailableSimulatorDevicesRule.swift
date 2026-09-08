import Foundation

enum UnavailableSimulatorDevicesRule: CleanupRuleDefinition {
    static let rule = ScanRule(
        id: "unavailable-simulator-devices",
        title: "Unavailable Simulator Devices",
        relativePath: "Library/Developer/CoreSimulator/Devices",
        minimumAgeDays: 0,
        enumerationMode: .unavailableSimulatorDevices,
        risk: .review,
        explanation: "Simulator device data that Xcode reports as unavailable (usually after a runtime was removed). Active simulators are left alone."
    )
}
