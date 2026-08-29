import AppKit
import Charts
import MachKitCore
import SwiftUI

extension ContentView {
    var networkView: some View {
        VStack(spacing: 0) {
            header(
                title: "Network",
                subtitle: L10n.string("Understand traffic, connections, routes, VPNs, and proxies"),
                trailing: AnyView(autoUpdateIndicator(
                    active: true,
                    detail: model.lastUpdatedText(for: .network)
                ))
            )
            .padding(.horizontal, 18).padding(.top, 18).padding(.bottom, 12)

            HStack(alignment: .bottom, spacing: 20) {
                ForEach(NetworkTab.allCases) { tab in
                    Button {
                        networkSearch = ""
                        networkTab = tab
                    } label: {
                        Text(tab.rawValue.localized)
                            .font(.system(size: 12, weight: networkTab == tab ? .semibold : .medium))
                            .foregroundStyle(networkTab == tab ? Color.primary : Color.secondary)
                            .padding(.bottom, 9)
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(networkTab == tab ? Color.accentColor : Color.clear)
                                    .frame(height: 2)
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                Button {
                    model.scanNetwork()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isLoading(.network))
            }
            .padding(.horizontal, 16).padding(.bottom, 14)

            if model.isLoading(.network), model.networkSnapshot == nil {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("Reading network activity…")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Inspecting interfaces, processes, routes, and proxy settings locally")
                        .font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                networkTabContent
            }
        }
    }

    @ViewBuilder
    var networkTabContent: some View {
        switch networkTab {
        case .overview: networkOverview
        case .traffic: networkTraffic
        case .activeConnections: activeConnectionsContent
        case .listeningPorts: portListContent
        case .routing: networkRouting
        }
    }

    var networkOverview: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                if let snapshot = model.networkSnapshot {
                    let primary = snapshot.interfaces.first { $0.name == snapshot.defaultRoute?.interfaceName }
                        ?? snapshot.interfaces.first { $0.kind != .loopback && $0.kind != .bridge }
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 10) {
                        networkMetricCard(
                            title: "Download",
                            value: formatNetworkRate(primary?.downloadBytesPerSecond ?? 0),
                            detail: primary?.name ?? "No active interface",
                            icon: "arrow.down",
                            color: .blue
                        )
                        networkMetricCard(
                            title: "Upload",
                            value: formatNetworkRate(primary?.uploadBytesPerSecond ?? 0),
                            detail: primary?.name ?? "No active interface",
                            icon: "arrow.up",
                            color: .mint
                        )
                        networkMetricCard(
                            title: "Default Interface",
                            value: snapshot.defaultRoute?.interfaceName ?? "—",
                            detail: snapshot.defaultRoute?.gateway ?? "No default route",
                            icon: "point.3.connected.trianglepath.dotted",
                            color: .orange
                        )
                        networkMetricCard(
                            title: "Proxy",
                            value: snapshot.proxy.isEnabled ? "Enabled" : "Direct",
                            detail: snapshot.proxy.summary,
                            icon: snapshot.proxy.isEnabled ? "shield.lefthalf.filled" : "arrow.triangle.branch",
                            color: snapshot.proxy.isEnabled ? .purple : .green
                        )
                    }

                    if !snapshot.errors.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(snapshot.errors, id: \.self) { error in
                                Label(L10n.diagnostic(error), systemImage: "exclamationmark.triangle.fill")
                                    .font(.caption).foregroundStyle(.orange)
                            }
                        }
                        .padding(11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
                    }

                    sectionTitle("Interfaces", detail: "Live speed and addresses for each active network interface")
                    VStack(spacing: 0) {
                        ForEach(Array(snapshot.interfaces.enumerated()), id: \.element.id) { index, interface in
                            networkInterfaceRow(interface, isPrimary: interface.name == snapshot.defaultRoute?.interfaceName)
                            if index < snapshot.interfaces.count - 1 { Divider().padding(.leading, 50) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                    if snapshot.interfaces.contains(where: { $0.kind == .tunnel }) {
                        Label(
                            "A VPN or TUN interface is active. Some destinations may bypass the default interface through more specific routes.",
                            systemImage: "network.badge.shield.half.filled"
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    ContentUnavailableView("Network Data Unavailable", systemImage: "network.slash")
                        .frame(minHeight: 280)
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    func networkMetricCard(
        title: String,
        value: String,
        detail: String,
        icon: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundStyle(color)
                Spacer()
                Text(title.localized).font(.caption).foregroundStyle(.secondary)
            }
            Text(value).font(.system(size: 18, weight: .semibold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
            Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 11))
        .overlay { RoundedRectangle(cornerRadius: 11).stroke(Color.primary.opacity(0.05)) }
    }

    func networkInterfaceRow(_ interface: NetworkInterfaceUsage, isPrimary: Bool) -> some View {
        HStack(spacing: 11) {
            Image(systemName: networkInterfaceIcon(interface.kind))
                .font(.system(size: 15, weight: .medium)).foregroundStyle(networkInterfaceColor(interface.kind))
                .frame(width: 30, height: 30)
                .background(networkInterfaceColor(interface.kind).opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(interface.displayName.localized).font(.system(size: 12, weight: .semibold))
                    Text(interface.name).font(.caption2.monospaced()).foregroundStyle(.secondary)
                    if isPrimary {
                        Text("Default").font(.system(size: 9, weight: .semibold)).foregroundStyle(Color.accentColor)
                            .padding(.horizontal, 6).padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.10), in: Capsule())
                    }
                }
                Text(interface.addresses.joined(separator: " · "))
                    .font(.caption2.monospaced()).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Label(formatNetworkRate(interface.downloadBytesPerSecond), systemImage: "arrow.down")
                    .foregroundStyle(Color.blue)
                Label(formatNetworkRate(interface.uploadBytesPerSecond), systemImage: "arrow.up")
                    .foregroundStyle(Color.mint)
            }
            .font(.caption.monospacedDigit()).labelStyle(.titleAndIcon)
            .frame(width: 108, alignment: .trailing)
        }
        .padding(.horizontal, 14).frame(minHeight: 58)
    }

    var networkTraffic: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                networkSearchField("Search processes or PIDs")
                if filteredNetworkProcesses.isEmpty {
                    ContentUnavailableView(
                        "No Process Traffic",
                        systemImage: "waveform.path.ecg",
                        description: Text("Traffic appears after an app sends or receives network data")
                    )
                    .frame(minHeight: 260)
                } else {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("Process").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Download").frame(width: 105, alignment: .trailing)
                            Text("Upload").frame(width: 105, alignment: .trailing)
                            Text("Total").frame(width: 105, alignment: .trailing)
                            Text("Connections").frame(width: 82, alignment: .trailing)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).frame(height: 34)
                        Divider()
                        ForEach(filteredNetworkProcesses) { process in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(process.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text("PID \(process.processIdentifier)")
                                        .font(.caption2).foregroundStyle(.tertiary).monospacedDigit()
                                }
                                Spacer()
                                Text(formatNetworkRate(process.downloadBytesPerSecond)).foregroundStyle(Color.blue)
                                    .frame(width: 105, alignment: .trailing)
                                Text(formatNetworkRate(process.uploadBytesPerSecond)).foregroundStyle(Color.mint)
                                    .frame(width: 105, alignment: .trailing)
                                Text(formatNetworkBytes(process.receivedBytes + process.sentBytes))
                                    .frame(width: 105, alignment: .trailing)
                                Text(String(process.connectionCount)).frame(width: 82, alignment: .trailing)
                            }
                            .font(.system(size: 11, design: .monospaced))
                            .padding(.horizontal, 14).frame(minHeight: 52)
                            Divider().padding(.leading, 13)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    var filteredNetworkProcesses: [NetworkProcessUsage] {
        let processes = model.networkSnapshot?.processes ?? []
        let query = networkSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return processes }
        return processes.filter { $0.name.lowercased().contains(query) || String($0.processIdentifier).contains(query) }
    }

    var activeConnectionsContent: some View {
        let filteredConnections = filteredActiveConnections
        let visibleConnections = Array(filteredConnections.prefix(250))
        return ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                networkSearchField("Search processes, addresses, ports, or interfaces")
                if filteredConnections.isEmpty {
                    ContentUnavailableView("No Active Connections", systemImage: "network.slash")
                        .frame(minHeight: 260)
                } else {
                    LazyVStack(spacing: 0) {
                        HStack {
                            Text("Process").frame(width: 170, alignment: .leading)
                            Text("Local").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Remote").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Interface").frame(width: 72, alignment: .leading)
                            Text("State").frame(width: 86, alignment: .leading)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).frame(height: 34)
                        Divider()
                        ForEach(visibleConnections) { connection in
                            HStack(spacing: 10) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(connection.processName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text("PID \(connection.processIdentifier) · \(connection.transport.rawValue)")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                                .frame(width: 170, alignment: .leading)
                                Text(networkEndpoint(connection.localAddress, connection.localPort))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(networkEndpoint(connection.remoteAddress ?? "—", connection.remotePort))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                Text(connection.interfaceName ?? "—").frame(width: 72, alignment: .leading)
                                Text(connection.state ?? "UDP").frame(width: 86, alignment: .leading)
                            }
                            .font(.system(size: 10.5, design: .monospaced)).padding(.horizontal, 14).frame(minHeight: 50)
                            Divider().padding(.leading, 13)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

                    if filteredConnections.count > visibleConnections.count {
                        Text("\(visibleConnections.count) / \(filteredConnections.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    var filteredActiveConnections: [NetworkConnection] {
        let connections = (model.networkSnapshot?.connections ?? []).filter { !$0.isListener }
        let query = networkSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return connections }
        return connections.filter { connection in
            [
                connection.processName, String(connection.processIdentifier), connection.transport.rawValue,
                connection.localAddress, connection.localPort.map(String.init) ?? "",
                connection.remoteAddress ?? "", connection.remotePort.map(String.init) ?? "",
                connection.interfaceName ?? "", connection.state ?? ""
            ].joined(separator: " ").lowercased().contains(query)
        }
    }

    var networkRouting: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                sectionTitle("Route Lookup", detail: "Check which interface macOS will use for a host or IP address")
                HStack(spacing: 9) {
                    Image(systemName: "scope").foregroundStyle(.secondary)
                    TextField("example.com or 1.1.1.1", text: $routeQuery)
                        .textFieldStyle(.plain).onSubmit { model.lookupNetworkRoute(routeQuery) }
                    Button("Check Route") { model.lookupNetworkRoute(routeQuery) }
                        .buttonStyle(.borderedProminent).controlSize(.small)
                        .disabled(routeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLookingUpRoute)
                }
                .padding(.horizontal, 12).frame(height: 40)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 9))

                if let route = model.routeLookup {
                    HStack(spacing: 12) {
                        Image(systemName: route.errorMessage == nil ? "arrow.triangle.turn.up.right.diamond.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 18)).foregroundStyle(route.errorMessage == nil ? Color.accentColor : Color.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.errorMessage ?? "\(route.query) → \(route.destination)")
                                .font(.system(size: 12, weight: .semibold)).textSelection(.enabled)
                            if let gateway = route.gateway {
                                Text("Gateway \(gateway)").font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let interfaceName = route.interfaceName {
                            Text(interfaceName).font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                        }
                    }
                    .padding(12).background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

                    if model.networkSnapshot?.proxy.isEnabled == true {
                        Label(
                            "A system proxy is enabled. Route lookup shows the Mac's outbound route; proxied apps connect to the local proxy first.",
                            systemImage: "info.circle"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                }

                if let snapshot = model.networkSnapshot {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        networkInfoCard(
                            title: "Default Route",
                            value: snapshot.defaultRoute?.interfaceName ?? "Unavailable",
                            detail: snapshot.defaultRoute?.gateway.map { "Gateway \($0)" } ?? "No gateway reported",
                            icon: "point.3.connected.trianglepath.dotted"
                        )
                        networkInfoCard(
                            title: "System Proxy",
                            value: snapshot.proxy.isEnabled ? "Enabled" : "Not Configured",
                            detail: snapshot.proxy.summary,
                            icon: "shield.lefthalf.filled"
                        )
                    }

                    sectionTitle("Route Table", detail: "IPv4 and IPv6 routes currently installed by macOS, VPNs, and TUN tools")
                    VStack(spacing: 0) {
                        HStack {
                            Text("Destination").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Gateway").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Interface").frame(width: 80, alignment: .leading)
                            Text("Family").frame(width: 54, alignment: .leading)
                            Text("Flags").frame(width: 90, alignment: .leading)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).frame(height: 34)
                        Divider()
                        ForEach(Array(snapshot.routes.prefix(300).enumerated()), id: \.element.id) { index, route in
                            HStack {
                                Text(route.destination).frame(maxWidth: .infinity, alignment: .leading)
                                Text(route.gateway).frame(maxWidth: .infinity, alignment: .leading)
                                Text(route.interfaceName).frame(width: 80, alignment: .leading)
                                Text(route.family).frame(width: 54, alignment: .leading)
                                Text(route.flags).frame(width: 90, alignment: .leading)
                            }
                            .font(.system(size: 10.5, design: .monospaced))
                            .padding(.horizontal, 14).frame(minHeight: 34)
                            if index < min(snapshot.routes.count, 300) - 1 { Divider().padding(.leading, 13) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, 16).padding(.bottom, 16)
        }
    }

    func networkInfoCard(title: String, value: String, detail: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 17)).foregroundStyle(Color.accentColor).frame(width: 26)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.caption).foregroundStyle(.secondary)
                Text(value.localized).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                Text(detail).font(.caption2).foregroundStyle(.tertiary).lineLimit(2).textSelection(.enabled)
            }
            Spacer()
        }
        .padding(12).frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func networkSearchField(_ placeholder: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField(placeholder.localized, text: $networkSearch).textFieldStyle(.plain)
            if !networkSearch.isEmpty {
                Button { networkSearch = "" } label: { Image(systemName: "xmark.circle.fill") }
                    .buttonStyle(.plain).foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 11).frame(height: 34)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    func sectionTitle(_ title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.localized).font(.system(size: 13, weight: .semibold))
            Text(detail.localized).font(.caption2).foregroundStyle(.secondary)
        }
    }

    func networkEndpoint(_ address: String, _ port: UInt16?) -> String {
        guard let port else { return address }
        return address.contains(":") ? "[\(address)]:\(port)" : "\(address):\(port)"
    }

    func formatNetworkRate(_ bytes: Double) -> String {
        let bytesPerSecond = max(0, bytes)
        if bytesPerSecond < 1_000 {
            return "\(Int(bytesPerSecond.rounded())) B/s"
        }
        if bytesPerSecond < 1_000_000 {
            return "\(formatNetworkNumber(bytesPerSecond / 1_000)) KB/s"
        }
        if bytesPerSecond < 1_000_000_000 {
            return "\(formatNetworkNumber(bytesPerSecond / 1_000_000)) MB/s"
        }
        return "\(formatNetworkNumber(bytesPerSecond / 1_000_000_000)) GB/s"
    }

    func formatNetworkNumber(_ value: Double) -> String {
        if value >= 100 { return String(format: "%.0f", value) }
        if value >= 10 { return String(format: "%.1f", value) }
        return String(format: "%.2f", value)
    }

    func formatNetworkBytes(_ bytes: UInt64) -> String {
        ByteCountFormatter.string(fromByteCount: Int64(clamping: bytes), countStyle: .file)
    }

    func networkInterfaceIcon(_ kind: NetworkInterfaceKind) -> String {
        switch kind {
        case .wifi: "wifi"
        case .ethernet: "cable.connector"
        case .tunnel: "network.badge.shield.half.filled"
        case .loopback: "arrow.triangle.2.circlepath"
        case .bridge: "point.3.connected.trianglepath.dotted"
        case .other: "network"
        }
    }

    func networkInterfaceColor(_ kind: NetworkInterfaceKind) -> Color {
        switch kind {
        case .wifi: .blue
        case .ethernet: .green
        case .tunnel: .purple
        case .loopback: .secondary
        case .bridge: .orange
        case .other: .cyan
        }
    }

    var portListContent: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 0) {
                    portSummaryItem(
                        title: "Port",
                        value: "\(model.listeningPorts.count)",
                        icon: "network",
                        color: .blue
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "Process",
                        value: "\(Set(model.listeningPorts.map(\.processIdentifier)).count)",
                        icon: "terminal.fill",
                        color: .indigo
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "TCP",
                        value: "\(model.listeningPorts.filter { $0.transport == .tcp }.count)",
                        icon: "arrow.left.arrow.right",
                        color: .mint
                    )
                    portSummaryDivider
                    portSummaryItem(
                        title: "Exposed",
                        value: "\(model.listeningPorts.filter { $0.exposure != .loopback }.count)",
                        icon: "exclamationmark.shield.fill",
                        color: .orange
                    )
                }
                .padding(.vertical, 11)
                .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
                .overlay {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                }

                if let error = model.portScanError {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                        Text(error).font(.system(size: 12)).textSelection(.enabled)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.orange.opacity(0.09), in: RoundedRectangle(cornerRadius: 9))
                }

                HStack(spacing: 10) {
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                        TextField("Search ports, processes, PIDs, paths, or commands", text: $portSearch)
                            .textFieldStyle(.plain)
                        if !portSearch.isEmpty {
                            Button { portSearch = "" } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 11).frame(height: 34)
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))

                    Picker("Filter", selection: $portFilter) {
                        ForEach(PortFilter.allCases) { filter in
                            Text(filter.rawValue.localized).tag(filter)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 278)
                }

                if filteredPorts.isEmpty {
                    ContentUnavailableView(
                        (portSearch.isEmpty ? "No Ports Found" : "No Results").localized,
                        systemImage: "network.slash",
                        description: Text(
                            (portSearch.isEmpty
                                ? "No TCP listeners or UDP bindings to display"
                                : "Try another port, process name, or path").localized
                        )
                    )
                    .frame(minHeight: 260)
                } else {
                    VStack(spacing: 0) {
                        HStack {
                            Text("Port").frame(width: 104, alignment: .leading)
                            Text("Bind Address").frame(width: 142, alignment: .leading)
                            Text("Process").frame(maxWidth: .infinity, alignment: .leading)
                            Text("Scope").frame(width: 80, alignment: .leading)
                            Color.clear.frame(width: 74)
                        }
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal, 14).frame(height: 34)
                        Divider()
                        ForEach(Array(filteredPorts.enumerated()), id: \.element.id) { index, port in
                            portRow(port)
                            if index < filteredPorts.count - 1 { Divider().padding(.leading, 13) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }

                Label(
                    "Graceful quit sends SIGTERM so the process can clean up before exiting. Force quit may lose unsaved data; launchd, containers, or supervisors may restart the process.",
                    systemImage: "info.circle"
                )
                .font(.caption).foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    var filteredPorts: [ListeningPort] {
        let query = portSearch.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return model.listeningPorts.filter { port in
            let matchesFilter: Bool
            switch portFilter {
            case .all: matchesFilter = true
            case .tcp: matchesFilter = port.transport == .tcp
            case .udp: matchesFilter = port.transport == .udp
            case .exposed: matchesFilter = port.exposure != .loopback
            }
            guard matchesFilter else { return false }
            guard !query.isEmpty else { return true }
            let searchable = [
                String(port.port),
                String(port.processIdentifier),
                port.processName,
                port.processDescription.localized,
                port.localAddress,
                port.executableURL?.path ?? "",
                port.workingDirectoryURL?.path ?? "",
                port.commandLine ?? ""
            ].joined(separator: " ").lowercased()
            return searchable.contains(query)
        }
    }

    func portSummaryItem(title: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 28, height: 28)
                .background(color.opacity(0.10), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(title.localized)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 19, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity)
    }

    var portSummaryDivider: some View {
        Divider()
            .frame(height: 34)
    }

    func portRow(_ port: ListeningPort) -> some View {
        HStack(spacing: 0) {
            HStack(spacing: 6) {
                Text(verbatim: String(port.port)).font(.system(size: 13, weight: .semibold)).monospacedDigit()
                Text(port.transport.rawValue.localized)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(port.transport == .tcp ? Color.blue : Color.purple)
                    .padding(.horizontal, 5).padding(.vertical, 2)
                    .background((port.transport == .tcp ? Color.blue : Color.purple).opacity(0.10), in: Capsule())
            }
            .frame(width: 104, alignment: .leading)

            Text(port.localAddress)
                .font(.system(size: 11, design: .monospaced)).lineLimit(1).truncationMode(.middle)
                .frame(width: 142, alignment: .leading)

            Button { selectedPort = port } label: {
                HStack(spacing: 9) {
                    processIcon(port)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(port.processName).font(.system(size: 12, weight: .medium)).lineLimit(1)
                        Text(port.processDescription.localized)
                            .font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        Text("PID \(port.processIdentifier) · \(portProcessSubtitle(port))")
                            .font(.caption2).foregroundStyle(.tertiary).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(port.exposure.rawValue.localized)
                .font(.caption.weight(.medium)).foregroundStyle(portExposureColor(port.exposure))
                .frame(width: 80, alignment: .leading)

            Button("Quit") { model.requestPortTermination(port) }
                .buttonStyle(.borderless)
                .foregroundStyle(port.canTerminate ? Color.red : Color.secondary)
                .disabled(!port.canTerminate)
                .help((port.protectionReason ?? "Quit the process using this port").localized)
                .frame(width: 74, alignment: .trailing)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 68)
        .contextMenu {
            Button("View Process Details") { selectedPort = port }
            if let executableURL = port.executableURL {
                Button("Show Executable in Finder") { reveal(executableURL) }
            }
            if let workingDirectoryURL = port.workingDirectoryURL {
                Button("Open Working Directory") { NSWorkspace.shared.open(workingDirectoryURL) }
            }
            Divider()
            Button("Quit Process", role: .destructive) { model.requestPortTermination(port) }
                .disabled(!port.canTerminate)
        }
    }

    @ViewBuilder
    func processIcon(_ port: ListeningPort) -> some View {
        if let executableURL = port.executableURL {
            Image(nsImage: NSWorkspace.shared.icon(forFile: executableURL.path))
                .resizable().frame(width: 28, height: 28)
        } else {
            Image(systemName: "terminal.fill")
                .foregroundStyle(.secondary).frame(width: 28, height: 28)
        }
    }

    func portProcessSubtitle(_ port: ListeningPort) -> String {
        if let workingDirectoryURL = port.workingDirectoryURL { return workingDirectoryURL.path }
        if let executableURL = port.executableURL { return executableURL.path }
        return port.commandLine ?? L10n.string("Process path unknown")
    }

    func portExposureColor(_ exposure: PortExposure) -> Color {
        switch exposure {
        case .loopback: .green
        case .network: .blue
        case .allInterfaces: .orange
        }
    }

    func portDetails(_ port: ListeningPort) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                processIcon(port)
                VStack(alignment: .leading, spacing: 3) {
                    Text(port.processName).font(.title3.weight(.semibold))
                    Text(port.processDescription.localized).font(.caption).foregroundStyle(.secondary)
                    Text("PID \(port.processIdentifier)").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                }
                Spacer()
                Text(verbatim: "\(port.transport.rawValue) \(port.localAddress):\(String(port.port))")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.accentColor.opacity(0.10), in: Capsule())
            }

            VStack(spacing: 0) {
                portDetailRow("Process Description", value: port.processDescription.localized)
                Divider().padding(.leading, 104)
                portDetailRow("Listening Scope", value: port.exposure.rawValue.localized)
                Divider().padding(.leading, 104)
                portDetailRow("Executable", value: port.executableURL?.path ?? L10n.string("Unable to Read"))
                Divider().padding(.leading, 104)
                portDetailRow("Working Directory", value: port.workingDirectoryURL?.path ?? L10n.string("Unable to Read"))
                Divider().padding(.leading, 104)
                portDetailRow("Launch Command", value: port.commandLine ?? L10n.string("Unable to Read"))
                Divider().padding(.leading, 104)
                portDetailRow("User UID", value: String(port.ownerUserID))
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))

            if let reason = port.protectionReason {
                Label(reason.localized, systemImage: "lock.shield.fill")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Label("Quitting terminates the entire process and releases every port it uses.", systemImage: "exclamationmark.triangle")
                    .font(.caption).foregroundStyle(.orange)
            }

            HStack {
                if let executableURL = port.executableURL {
                    Button("Show Executable") { reveal(executableURL) }
                }
                if let workingDirectoryURL = port.workingDirectoryURL {
                    Button("Open Working Directory") { NSWorkspace.shared.open(workingDirectoryURL) }
                }
                Spacer()
                Button("Close", role: .cancel) { selectedPort = nil }
                Button("Quit Process", role: .destructive) {
                    selectedPort = nil
                    model.requestPortTermination(port)
                }
                .disabled(!port.canTerminate)
            }
        }
        .padding(20)
        .frame(width: 620)
    }

    func portDetailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title.localized).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14).padding(.vertical, 9)
    }

    var portTerminationMessage: String {
        guard let port = model.portTerminationCandidate else { return "" }
        return L10n.format(
            "%@ (PID %d) is using %@ %@:%@. Graceful quit is safer; use force quit only if the process is unresponsive.",
            port.processName,
            port.processIdentifier,
            port.transport.rawValue,
            port.localAddress,
            String(port.port)
        )
    }

    var performanceView: some View {
        VStack(spacing: 0) {
            header(
                title: "Performance",
                subtitle: "Monitor CPU, GPU, memory, disk, network, and top apps locally"
            )
            .padding(18)

            if let snapshot = model.performanceSnapshot {
                performanceContent(snapshot)
            } else {
                VStack(spacing: 13) {
                    Spacer()
                    ProgressView().controlSize(.large)
                    Text("Collecting performance data…").font(.system(size: 14, weight: .semibold))
                    Text("The first CPU sample takes about 2 seconds").font(.caption).foregroundStyle(.secondary)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    func performanceContent(_ snapshot: PerformanceSnapshot) -> some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 14) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        cpuMetricCard(snapshot)
                        gpuMetricCard(snapshot)
                    }
                    VStack(spacing: 12) {
                        cpuMetricCard(snapshot)
                        gpuMetricCard(snapshot)
                    }
                }
                neuralEngineAndMemoryMetricCard(snapshot)
                systemActivityCard(snapshot)
                computeHardwareCard(snapshot.computeHardware)
                performanceTrendCard
                resourceApplicationList(snapshot)
                Text("Data updates locally every 2 seconds. GPU and Neural Engine metrics use SoCMetrics (IOReport) on Apple Silicon; per-GPU-core bars reflect chip-level active residency because macOS does not expose per-core utilization. Neural Engine percentage is estimated from power draw, not a system utilization counter. App CPU is shown as a share of total system capacity; network rates aggregate helper processes into their parent app. Sampling stops when you leave this page. App rankings include identifiable graphical app processes only.")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    private func compactMetricProgressRow<Trailing: View>(
        title: String,
        icon: String,
        progress: Double?,
        tint: Color,
        valueText: String,
        detail: String?,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        let clamped = min(1, max(0, progress ?? 0))
        let barTint = clamped >= 0.85 ? Color.orange : tint
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Label(title, systemImage: icon)
                    .font(.system(size: 13, weight: .semibold))
                trailing()
                Spacer(minLength: 4)
                Text(valueText)
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(progress == nil ? .secondary : .primary)
            }
            if progress != nil {
                ProgressView(value: clamped, total: 1)
                    .tint(barTint)
            } else {
                ProgressView(value: 0, total: 1)
                    .tint(Color.secondary.opacity(0.25))
            }
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
        }
    }

    func neuralEngineAndMemoryMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        let memoryColor = memoryPressureColor(snapshot.memoryPressureLevel)
        let pressurePercent = snapshot.memoryPressure * 100
        let hasNE = snapshot.hasNeuralEngine
        let nePercent = snapshot.neuralEnginePercent
        return VStack(alignment: .leading, spacing: 12) {
            if hasNE {
                compactMetricProgressRow(
                    title: "Neural Engine",
                    icon: "brain.head.profile",
                    progress: nePercent.map { $0 / 100 },
                    tint: .purple,
                    valueText: nePercent.map { "\($0.formatted(.number.precision(.fractionLength(0))))%" } ?? "—",
                    detail: nePercent != nil
                        ? "\(L10n.string("Estimated")) · \(snapshot.neuralEnginePowerWatts.map { L10n.format("%.2f W", $0) } ?? "—")"
                        : "Neural Engine power counters are unavailable on this Mac."
                ) {
                    if nePercent != nil {
                        performanceStatusBadge("Live", color: .purple)
                    } else {
                        performanceStatusBadge("Unavailable", color: .secondary)
                    }
                }
            }

            compactMetricProgressRow(
                title: "Memory Usage",
                icon: "memorychip.fill",
                progress: snapshot.memoryPressure,
                tint: memoryColor,
                valueText: "\(pressurePercent.formatted(.number.precision(.fractionLength(0))))%",
                detail: "\(formatted(snapshot.usedMemory)) / \(formatted(snapshot.physicalMemory))"
            ) {
                Button { showingMemoryHelp.toggle() } label: {
                    Image(systemName: "questionmark.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Understand macOS memory management")
                .popover(isPresented: $showingMemoryHelp, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 9) {
                        Label("What Does Smart Release Do?", systemImage: "questionmark.circle.fill")
                            .font(.system(size: 14, weight: .semibold))
                        Text("macOS handles hidden apps that are marked for automatic termination and currently unused, while MachKit returns reclaimable pages from its own heap.")
                            .font(.system(size: 12)).fixedSize(horizontal: false, vertical: true)
                        Text("Regular foreground apps are not quit, processes are not force terminated, and administrator privileges are not required.")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(16)
                    .frame(width: 340, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                }
                performanceStatusBadge(snapshot.memoryPressureLevel.rawValue, color: memoryColor)
            }

            HStack(spacing: 10) {
                Text("Cached \(formatted(snapshot.cachedMemory))")
                Text("Compressed \(formatted(snapshot.compressedMemory))")
                Text("Swap \(formatted(snapshot.swapUsed))")
                Spacer(minLength: 4)
                Button(action: model.optimizeMemory) {
                    if model.isOptimizingMemory {
                        ProgressView().controlSize(.mini)
                    } else {
                        Label("Smart Release", systemImage: "wand.and.sparkles")
                    }
                }
                .fixedSize(horizontal: true, vertical: false)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(model.isOptimizingMemory)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            .monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func performanceStatusBadge(_ text: String, color: Color) -> some View {
        Text(text.localized)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(color.opacity(0.12), in: Capsule())
    }

    func cpuMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("CPU", systemImage: "cpu.fill").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                Label(thermalStateText(snapshot.thermalState), systemImage: "thermometer.medium")
                    .font(.caption).foregroundStyle(.secondary)
            }
            .frame(height: 20, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.cpuPercent.formatted(.number.precision(.fractionLength(0))))
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                Text("%").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            .frame(height: 38, alignment: .leading)

            if snapshot.cpuCores.isEmpty {
                ProgressView(value: snapshot.cpuPercent, total: 100)
                    .tint(snapshot.cpuPercent > 85 ? Color.orange : Color.accentColor)
                Text("Total System Usage")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                usageCoreBars(cpuCoreBarItems(snapshot.cpuCores))
                HStack(spacing: 10) {
                    Text("Per-core usage")
                    Spacer(minLength: 4)
                    ForEach(cpuClusterLegend(snapshot), id: \.self) { name in
                        Label(PerformanceMonitor.localizedClusterName(name), systemImage: "circle.fill")
                            .foregroundStyle(cpuClusterLegendColor(name))
                    }
                    if snapshot.cpuCores.contains(where: { $0.kind == .standard }) {
                        Label("Core", systemImage: "circle.fill")
                            .foregroundStyle(Color.accentColor)
                    }
                }
                .font(.caption).foregroundStyle(.secondary)
            }

            HStack(spacing: 12) {
                Text(L10n.format("User %@", percentText(snapshot.cpuUserPercent)))
                Text(L10n.format("System %@", percentText(snapshot.cpuSystemPercent)))
                Spacer(minLength: 0)
            }
            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private struct CoreBarItem: Identifiable {
        let index: Int
        let percent: Double
        let label: String
        let color: Color
        let helpText: String
        var id: Int { index }
    }

    private func cpuCoreBarItems(_ cores: [CPUCoreUsage]) -> [CoreBarItem] {
        cores.map { core in
            CoreBarItem(
                index: core.index,
                percent: core.percent,
                label: coreBarLabel(core, compact: cores.count > 16),
                color: coreBarColor(core),
                helpText: L10n.format("Core %lld · %lld%%", core.index + 1, Int64(core.percent.rounded()))
            )
        }
    }

    private func usageCoreBars(_ bars: [CoreBarItem]) -> some View {
        GeometryReader { geometry in
            let spacing: CGFloat = bars.count > 12 ? 2 : 3
            let barWidth = max(
                4,
                (geometry.size.width - spacing * CGFloat(max(bars.count - 1, 0))) / CGFloat(max(bars.count, 1))
            )
            HStack(alignment: .bottom, spacing: spacing) {
                ForEach(bars) { bar in
                    VStack(spacing: 3) {
                        Capsule()
                            .fill(bar.color.opacity(0.18))
                            .frame(width: barWidth, height: geometry.size.height - 14)
                            .overlay(alignment: .bottom) {
                                Capsule()
                                    .fill(bar.color)
                                    .frame(
                                        width: barWidth,
                                        height: max(2, (geometry.size.height - 14) * bar.percent / 100)
                                    )
                            }
                        Text(bar.label)
                            .font(.system(size: 8, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .frame(width: barWidth)
                    }
                    .help(bar.helpText)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
        }
        .frame(height: 78)
        .accessibilityElement(children: .contain)
    }

    func cpuCoreBars(_ cores: [CPUCoreUsage]) -> some View {
        usageCoreBars(cpuCoreBarItems(cores))
    }

    func coreBarColor(_ core: CPUCoreUsage) -> Color {
        let base = cpuClusterLegendColor(core.clusterName)
        return core.percent > 85 ? .orange : base
    }

    func cpuClusterLegend(_ snapshot: PerformanceSnapshot) -> [String] {
        if !snapshot.computeHardware.cpuClusters.isEmpty {
            return snapshot.computeHardware.cpuClusters
                .filter { cluster in snapshot.cpuCores.contains { $0.clusterName == cluster.name } }
                .map(\.name)
        }
        var seen = Set<String>()
        return snapshot.cpuCores.compactMap { core in
            guard seen.insert(core.clusterName).inserted else { return nil }
            return core.clusterName
        }
    }

    func cpuClusterLegendColor(_ clusterName: String) -> Color {
        switch clusterName.lowercased() {
        case "super":
            return .purple
        case "performance":
            return Color.accentColor
        case "efficiency":
            return .teal
        default:
            return Color.accentColor
        }
    }

    func coreBarLabel(_ core: CPUCoreUsage, compact: Bool) -> String {
        if compact { return "\(core.index + 1)" }
        return "\(coreBarPrefix(core.clusterName))\(core.clusterIndex + 1)"
    }

    func coreBarPrefix(_ clusterName: String) -> String {
        switch clusterName.lowercased() {
        case "super":
            return "S"
        case "performance":
            return "P"
        case "efficiency":
            return "E"
        default:
            return "C"
        }
    }

    func gpuMetricCard(_ snapshot: PerformanceSnapshot) -> some View {
        let gpuLive = snapshot.gpuPercent != nil
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Label("GPU", systemImage: "display").font(.system(size: 14, weight: .semibold))
                Spacer(minLength: 8)
                Text((gpuLive ? "Live" : "Unavailable").localized)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(gpuLive ? Color.blue : Color.secondary)
            }
            .frame(height: 20, alignment: .leading)

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(snapshot.gpuPercent.map { $0.formatted(.number.precision(.fractionLength(0))) } ?? "—")
                    .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                if gpuLive {
                    Text("%").font(.system(size: 15, weight: .medium)).foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
            }
            .frame(height: 38, alignment: .leading)

            if snapshot.gpuCores.isEmpty {
                if let gpuPercent = snapshot.gpuPercent {
                    ProgressView(value: gpuPercent, total: 100)
                        .tint(gpuPercent > 85 ? Color.orange : Color.blue)
                } else {
                    Text("The graphics driver does not expose live utilization on this Mac.")
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
            } else {
                usageCoreBars(gpuCoreBarItems(snapshot.gpuCores))
            }
            HStack(spacing: 18) {
                compactMetric("Renderer", value: optionalPercentText(snapshot.gpuRendererPercent))
                compactMetric("Tiler", value: optionalPercentText(snapshot.gpuTilerPercent))
                if let frequency = snapshot.gpuFrequencyMHz {
                    compactMetric("Frequency", value: L10n.format("%lld MHz", Int64(frequency.rounded())))
                }
                compactMetric("GPU Memory", value: snapshot.gpuMemoryBytes > 0 ? formatted(snapshot.gpuMemoryBytes) : "—")
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    private func gpuCoreBarItems(_ cores: [GPUCoreUsage]) -> [CoreBarItem] {
        cores.map { core in
            CoreBarItem(
                index: core.index,
                percent: core.percent,
                label: "\(core.index + 1)",
                color: core.percent > 85 ? .orange : .blue,
                helpText: L10n.format("GPU core %lld · %lld%%", core.index + 1, Int64(core.percent.rounded()))
            )
        }
    }

    func systemActivityCard(_ snapshot: PerformanceSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 13) {
            Label("System Activity", systemImage: "waveform.path.ecg")
                .font(.system(size: 14, weight: .semibold))
            HStack(spacing: 18) {
                activityGroup(
                    title: "Disk I/O",
                    icon: "internaldrive",
                    firstLabel: "Read",
                    firstValue: formatNetworkRate(snapshot.diskReadBytesPerSecond),
                    secondLabel: "Write",
                    secondValue: formatNetworkRate(snapshot.diskWriteBytesPerSecond),
                    color: .orange
                )
                activityGroup(
                    title: "Network",
                    icon: "network",
                    firstLabel: "Down",
                    firstValue: formatNetworkRate(snapshot.networkDownloadBytesPerSecond),
                    secondLabel: "Up",
                    secondValue: formatNetworkRate(snapshot.networkUploadBytesPerSecond),
                    color: .green
                )
            }
            Divider()
            HStack(spacing: 18) {
                compactMetric("Load Average", value: loadAverageText(snapshot.loadAverages))
                compactMetric("Processes", value: snapshot.processCount.formatted())
                compactMetric("Uptime", value: uptimeText(snapshot.systemUptime))
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func activityGroup(
        title: String,
        icon: String,
        firstLabel: String,
        firstValue: String,
        secondLabel: String,
        secondValue: String,
        color: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(title.localized, systemImage: icon).foregroundStyle(color)
                .font(.caption.weight(.semibold))
            HStack(spacing: 6) {
                Text(firstLabel.localized).foregroundStyle(.secondary)
                Text(firstValue).monospacedDigit()
            }
            HStack(spacing: 6) {
                Text(secondLabel.localized).foregroundStyle(.secondary)
                Text(secondValue).monospacedDigit()
            }
        }
        .font(.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func compactMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title.localized).font(.caption2).foregroundStyle(.secondary)
            Text(value).font(.caption.weight(.semibold)).monospacedDigit().lineLimit(1)
        }
    }

    func percentText(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))%"
    }

    func optionalPercentText(_ value: Double?) -> String {
        value.map(percentText) ?? "—"
    }

    func loadAverageText(_ values: [Double]) -> String {
        guard !values.isEmpty else { return "—" }
        return values.map { $0.formatted(.number.precision(.fractionLength(2))) }.joined(separator: " / ")
    }

    func uptimeText(_ interval: TimeInterval) -> String {
        let totalMinutes = max(0, Int(interval) / 60)
        let days = totalMinutes / (24 * 60)
        let hours = totalMinutes / 60 % 24
        let minutes = totalMinutes % 60
        if days > 0 { return L10n.format("%lldd %lldh", days, hours) }
        if hours > 0 { return L10n.format("%lldh %lldm", hours, minutes) }
        return L10n.format("%lldm", minutes)
    }

    func computeHardwareCard(_ hardware: ComputeHardwareInfo) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Compute Hardware")
                .font(.system(size: 14, weight: .semibold))
                .padding(.horizontal, 14).padding(.top, 13).padding(.bottom, 8)
            computeHardwareRow(
                icon: "cpu",
                title: "CPU",
                subtitle: L10n.format("%@ · %@", hardware.cpuName, cpuCoreSummary(hardware)),
                status: hardware.hasUnifiedMemory
                    ? "Apple Silicon"
                    : L10n.format("%lld threads", hardware.logicalCores),
                color: .orange
            )
            Divider().padding(.leading, 57)
            computeHardwareRow(
                icon: "display",
                title: "GPU",
                subtitle: hardware.recommendedGPUWorkingSet > 0
                    ? L10n.format("%@ · Recommended working set %@", hardware.gpuName, formatted(hardware.recommendedGPUWorkingSet))
                    : hardware.gpuName,
                status: hardware.hasUnifiedMemory ? "Unified Memory" : "Dedicated Memory",
                color: .blue
            )
            Divider().padding(.leading, 57)
            computeHardwareRow(
                icon: "sparkles",
                title: "Apple Intelligence",
                subtitle: hardware.appleIntelligence.detail,
                status: hardware.appleIntelligence.rawValue,
                color: hardware.appleIntelligence.isUsable ? .green : .purple
            )
        }
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func cpuCoreSummary(_ hardware: ComputeHardwareInfo) -> String {
        if hardware.cpuClusters.count > 1 {
            let parts = hardware.cpuClusters.map {
                L10n.format(
                    "%lld %@",
                    Int64($0.physicalCores),
                    PerformanceMonitor.localizedClusterName($0.name)
                )
            }
            return L10n.format(
                "%lld cores (%@)",
                hardware.physicalCores,
                parts.joined(separator: " + ")
            )
        }
        if hardware.performanceCores > 0, hardware.efficiencyCores > 0 {
            return L10n.format(
                "%lld cores (%lldP + %lldE)",
                hardware.physicalCores,
                hardware.performanceCores,
                hardware.efficiencyCores
            )
        }
        if hardware.logicalCores > hardware.physicalCores {
            return L10n.format(
                "%lld cores · %lld threads",
                hardware.physicalCores,
                hardware.logicalCores
            )
        }
        return L10n.format("%lld cores", hardware.physicalCores)
    }

    func computeHardwareRow(icon: String, title: String, subtitle: String, status: String, color: Color) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 7).fill(color.opacity(0.12))
                Image(systemName: icon).foregroundStyle(color)
            }
            .frame(width: 32, height: 32)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.localized).font(.system(size: 12, weight: .semibold))
                Text(subtitle.localized).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            }
            Spacer()
            Text(status.localized)
                .font(.caption.weight(.semibold)).foregroundStyle(color)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(color.opacity(0.10), in: Capsule())
        }
        .padding(.horizontal, 14).frame(minHeight: 55)
    }

    var performanceTrendCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Last 60 Seconds").font(.system(size: 14, weight: .semibold))
                Spacer()
                Label("CPU", systemImage: "circle.fill").foregroundStyle(Color.orange)
                Label("GPU", systemImage: "circle.fill").foregroundStyle(Color.blue)
                Label("Memory Usage", systemImage: "circle.fill").foregroundStyle(Color.purple)
            }
            .font(.caption)
            Chart(model.performanceHistory) { point in
                LineMark(
                    x: .value("Time", point.sampledAt),
                    y: .value("CPU", point.cpuPercent),
                    series: .value("Metric", "CPU")
                )
                .foregroundStyle(Color.orange)
                .interpolationMethod(.catmullRom)
                if let gpuPercent = point.gpuPercent {
                    LineMark(
                        x: .value("Time", point.sampledAt),
                        y: .value("GPU", gpuPercent),
                        series: .value("Metric", "GPU")
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.catmullRom)
                }
                LineMark(
                    x: .value("Time", point.sampledAt),
                    y: .value("Memory Usage", point.memoryPressurePercent),
                    series: .value("Metric", "Memory Usage")
                )
                .foregroundStyle(Color.purple)
                .interpolationMethod(.catmullRom)
            }
            .chartYScale(domain: 0...100)
            .chartXAxis(.hidden)
            .chartYAxis {
                AxisMarks(position: .leading, values: [0, 50, 100]) { value in
                    AxisGridLine().foregroundStyle(Color.secondary.opacity(0.12))
                    AxisValueLabel { if let number = value.as(Int.self) { Text("\(number)%") } }
                }
            }
            .frame(height: 138)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
    }

    func resourceApplicationList(_ snapshot: PerformanceSnapshot) -> some View {
        let applications = snapshot.applications.sorted { lhs, rhs in
            switch performanceSort {
            case .cpu:
                lhs.cpuPercentOfSystem > rhs.cpuPercentOfSystem
            case .memory:
                lhs.memoryBytes > rhs.memoryBytes
            case .network:
                lhs.networkBytesPerSecond > rhs.networkBytesPerSecond
            }
        }
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Top Resource-Using Apps").font(.system(size: 15, weight: .semibold))
                Spacer()
                Picker("Sort", selection: $performanceSort) {
                    ForEach(PerformanceSort.allCases) { sort in Text(sort.rawValue.localized).tag(sort) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Sort")
                .frame(width: 220)
            }
            VStack(spacing: 0) {
                HStack {
                    Text("Apps").frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU").frame(width: 70, alignment: .trailing)
                    Text("Memory").frame(width: 92, alignment: .trailing)
                    Text("Network").frame(width: 88, alignment: .trailing)
                }
                .font(.caption).foregroundStyle(.secondary)
                .padding(.horizontal, 14).frame(height: 32)
                Divider()
                ForEach(Array(applications.prefix(12).enumerated()), id: \.element.id) { index, application in
                    resourceApplicationRow(application)
                    if index < min(applications.count, 12) - 1 { Divider().padding(.leading, 48) }
                }
            }
            .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    func resourceApplicationRow(_ application: ApplicationResourceUsage) -> some View {
        HStack(spacing: 10) {
            Group {
                if let url = application.bundleURL {
                    Image(nsImage: NSWorkspace.shared.icon(forFile: url.path)).resizable()
                } else {
                    Image(systemName: "app.fill").resizable().scaledToFit().padding(5).foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(application.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                Text("PID \(application.processIdentifier)").font(.caption2).foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(application.cpuPercentOfSystem.formatted(.number.precision(.fractionLength(1))))%")
                .font(.system(size: 12)).monospacedDigit().frame(width: 70, alignment: .trailing)
                .help(L10n.string("Share of total CPU capacity across all cores."))
            Text(formatted(application.memoryBytes))
                .font(.system(size: 12)).monospacedDigit().frame(width: 92, alignment: .trailing)
            Text(formatNetworkRate(application.networkBytesPerSecond))
                .font(.system(size: 12)).monospacedDigit().frame(width: 88, alignment: .trailing)
                .foregroundStyle(application.networkBytesPerSecond > 0 ? Color.blue : .secondary)
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .contextMenu {
            if let url = application.bundleURL { Button("Show in Finder") { reveal(url) } }
        }
    }

    func memoryPressureColor(_ level: MemoryPressureLevel) -> Color {
        switch level {
        case .normal: .green
        case .elevated: .orange
        case .critical: .red
        }
    }

    func thermalStateText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("Thermal State Normal")
        case .fair: L10n.string("Thermal State Elevated")
        case .serious: L10n.string("Thermal State High")
        case .critical: L10n.string("Thermal State Critical")
        @unknown default: L10n.string("Thermal State Unknown")
        }
    }

    func thermalStateShortText(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: L10n.string("Normal")
        case .fair: L10n.string("Elevated")
        case .serious: L10n.string("High")
        case .critical: L10n.string("Critical")
        @unknown default: L10n.string("Unknown")
        }
    }

    func thermalStateColor(_ state: ProcessInfo.ThermalState) -> Color {
        switch state {
        case .nominal: .green
        case .fair, .serious: .orange
        case .critical: .red
        @unknown default: .secondary
        }
    }
}
