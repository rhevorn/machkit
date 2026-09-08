import Foundation

public enum NetworkInterfaceKind: String, Codable, Sendable, CaseIterable {
    case wifi = "Wi-Fi"
    case ethernet = "Ethernet"
    case tunnel = "VPN / TUN"
    case loopback = "Loopback"
    case bridge = "Bridge"
    case other = "Other"
}

public struct NetworkInterfaceUsage: Identifiable, Sendable, Hashable {
    public let name: String
    public let displayName: String
    public let kind: NetworkInterfaceKind
    public let isUp: Bool
    public let addresses: [String]
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public var id: String { name }

    public init(
        name: String,
        displayName: String,
        kind: NetworkInterfaceKind,
        isUp: Bool,
        addresses: [String],
        receivedBytes: UInt64,
        sentBytes: UInt64,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double
    ) {
        self.name = name
        self.displayName = displayName
        self.kind = kind
        self.isUp = isUp
        self.addresses = addresses
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

public struct NetworkTransferRate: Sendable, Hashable {
    public let sampledAt: Date
    public let interfaceName: String?
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double

    public init(
        sampledAt: Date,
        interfaceName: String?,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double
    ) {
        self.sampledAt = sampledAt
        self.interfaceName = interfaceName
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
    }
}

public struct NetworkProcessUsage: Identifiable, Sendable, Hashable {
    public let processIdentifier: Int32
    public let name: String
    public let receivedBytes: UInt64
    public let sentBytes: UInt64
    public let downloadBytesPerSecond: Double
    public let uploadBytesPerSecond: Double
    public let connectionCount: Int

    public var id: Int32 { processIdentifier }

    public init(
        processIdentifier: Int32,
        name: String,
        receivedBytes: UInt64,
        sentBytes: UInt64,
        downloadBytesPerSecond: Double,
        uploadBytesPerSecond: Double,
        connectionCount: Int
    ) {
        self.processIdentifier = processIdentifier
        self.name = name
        self.receivedBytes = receivedBytes
        self.sentBytes = sentBytes
        self.downloadBytesPerSecond = downloadBytesPerSecond
        self.uploadBytesPerSecond = uploadBytesPerSecond
        self.connectionCount = connectionCount
    }
}

public struct NetworkConnection: Identifiable, Sendable, Hashable {
    public let id: String
    public let processIdentifier: Int32
    public let processName: String
    public let transport: NetworkTransport
    public let localAddress: String
    public let localPort: UInt16?
    public let remoteAddress: String?
    public let remotePort: UInt16?
    public let state: String?
    public let interfaceName: String?
    public let isListener: Bool

    public init(
        processIdentifier: Int32,
        processName: String,
        transport: NetworkTransport,
        localAddress: String,
        localPort: UInt16?,
        remoteAddress: String?,
        remotePort: UInt16?,
        state: String?,
        interfaceName: String?,
        isListener: Bool
    ) {
        self.id = [
            String(processIdentifier), transport.rawValue, localAddress,
            localPort.map(String.init) ?? "", remoteAddress ?? "",
            remotePort.map(String.init) ?? "", state ?? ""
        ].joined(separator: "|")
        self.processIdentifier = processIdentifier
        self.processName = processName
        self.transport = transport
        self.localAddress = localAddress
        self.localPort = localPort
        self.remoteAddress = remoteAddress
        self.remotePort = remotePort
        self.state = state
        self.interfaceName = interfaceName
        self.isListener = isListener
    }
}

public struct NetworkRoute: Identifiable, Sendable, Hashable {
    public let destination: String
    public let gateway: String
    public let flags: String
    public let interfaceName: String
    public let family: String

    public var id: String { "\(family)|\(destination)|\(gateway)|\(interfaceName)" }
    public var isDefault: Bool { destination == "default" }

    public init(destination: String, gateway: String, flags: String, interfaceName: String, family: String) {
        self.destination = destination
        self.gateway = gateway
        self.flags = flags
        self.interfaceName = interfaceName
        self.family = family
    }
}

public struct NetworkProxyConfiguration: Sendable, Hashable {
    public let services: [String]

    public var isEnabled: Bool { !services.isEmpty }
    public var summary: String { services.isEmpty ? "Direct Connection" : services.joined(separator: " · ") }

    public init(services: [String]) {
        self.services = services
    }
}

public struct NetworkRouteLookup: Sendable, Hashable {
    public let query: String
    public let destination: String
    public let gateway: String?
    public let interfaceName: String?
    public let errorMessage: String?

    public init(query: String, destination: String, gateway: String?, interfaceName: String?, errorMessage: String? = nil) {
        self.query = query
        self.destination = destination
        self.gateway = gateway
        self.interfaceName = interfaceName
        self.errorMessage = errorMessage
    }
}

public struct NetworkSnapshot: Sendable {
    public let sampledAt: Date
    public let interfaces: [NetworkInterfaceUsage]
    public let processes: [NetworkProcessUsage]
    public let connections: [NetworkConnection]
    public let routes: [NetworkRoute]
    public let defaultRoute: NetworkRouteLookup?
    public let proxy: NetworkProxyConfiguration
    public let errors: [String]

    public init(
        sampledAt: Date,
        interfaces: [NetworkInterfaceUsage],
        processes: [NetworkProcessUsage],
        connections: [NetworkConnection],
        routes: [NetworkRoute],
        defaultRoute: NetworkRouteLookup?,
        proxy: NetworkProxyConfiguration,
        errors: [String] = []
    ) {
        self.sampledAt = sampledAt
        self.interfaces = interfaces
        self.processes = processes
        self.connections = connections
        self.routes = routes
        self.defaultRoute = defaultRoute
        self.proxy = proxy
        self.errors = errors
    }
}
