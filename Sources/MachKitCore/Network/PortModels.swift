import Foundation

public enum NetworkTransport: String, CaseIterable, Codable, Sendable {
    case tcp = "TCP"
    case udp = "UDP"
}

public enum PortExposure: String, CaseIterable, Codable, Sendable {
    case loopback = "Local Only"
    case network = "Local Network"
    case allInterfaces = "All Interfaces"
}

public struct ListeningPort: Identifiable, Sendable, Hashable {
    public let id: String
    public let processIdentifier: Int32
    public let processName: String
    public let processDescription: String
    public let ownerUserID: UInt32
    public let transport: NetworkTransport
    public let localAddress: String
    public let port: UInt16
    public let exposure: PortExposure
    public let executableURL: URL?
    public let workingDirectoryURL: URL?
    public let commandLine: String?
    public let canTerminate: Bool
    public let protectionReason: String?

    public init(
        processIdentifier: Int32,
        processName: String,
        processDescription: String,
        ownerUserID: UInt32,
        transport: NetworkTransport,
        localAddress: String,
        port: UInt16,
        exposure: PortExposure,
        executableURL: URL?,
        workingDirectoryURL: URL?,
        commandLine: String?,
        canTerminate: Bool,
        protectionReason: String?
    ) {
        self.id = "\(processIdentifier)|\(transport.rawValue)|\(localAddress)|\(port)"
        self.processIdentifier = processIdentifier
        self.processName = processName
        self.processDescription = processDescription
        self.ownerUserID = ownerUserID
        self.transport = transport
        self.localAddress = localAddress
        self.port = port
        self.exposure = exposure
        self.executableURL = executableURL
        self.workingDirectoryURL = workingDirectoryURL
        self.commandLine = commandLine
        self.canTerminate = canTerminate
        self.protectionReason = protectionReason
    }
}

public struct PortScanResult: Sendable {
    public let ports: [ListeningPort]
    public let errorMessage: String?

    public init(ports: [ListeningPort], errorMessage: String? = nil) {
        self.ports = ports
        self.errorMessage = errorMessage
    }
}
