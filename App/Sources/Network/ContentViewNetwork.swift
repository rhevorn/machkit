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
            .padding(.horizontal, MachKitLayout.pageMargin).padding(.top, MachKitLayout.pageMargin).padding(.bottom, MachKitLayout.bannerPadding)

            HStack(alignment: .bottom, spacing: 20) {
                ForEach(NetworkTab.allCases) { tab in
                    Button {
                        networkSearch = ""
                        networkTab = tab
                    } label: {
                        Text(tab.rawValue.localized)
                            .font(.system(size: 12, weight: networkTab == tab ? .semibold : .medium))
                            .foregroundStyle(networkTab == tab ? Color.primary : Color.secondary)
                            .padding(.bottom, MachKitLayout.rowPaddingVertical)
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
            .padding(.horizontal, MachKitLayout.pageMargin).padding(.bottom, MachKitLayout.bannerPadding)

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
                        .padding(MachKitLayout.bannerPadding)
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
            .padding(.horizontal, MachKitLayout.pageMargin).padding(.bottom, MachKitLayout.pageMargin)
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
        .padding(MachKitLayout.bannerPadding).frame(maxWidth: .infinity, minHeight: 88, alignment: .leading)
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
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(minHeight: 58)
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
                        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(height: 34)
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
                            .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(minHeight: 52)
                            Divider().padding(.leading, 13)
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, MachKitLayout.pageMargin).padding(.bottom, MachKitLayout.pageMargin)
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
                        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(height: 34)
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
                            .font(.system(size: 10.5, design: .monospaced)).padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(minHeight: 50)
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
            .padding(.horizontal, MachKitLayout.pageMargin).padding(.bottom, MachKitLayout.pageMargin)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Host or IP".localized)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    HStack(alignment: .center, spacing: 10) {
                        TextField("example.com or 1.1.1.1".localized, text: $routeQuery)
                            .textFieldStyle(.roundedBorder)
                            .font(.system(size: 13))
                            .disabled(model.isLookingUpRoute)
                            .onSubmit { model.lookupNetworkRoute(routeQuery) }
                            .accessibilityLabel("Host or IP".localized)
                        if model.isLookingUpRoute {
                            ProgressView()
                                .controlSize(.small)
                        }
                        Button("Check Route".localized) { model.lookupNetworkRoute(routeQuery) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.regular)
                            .disabled(routeQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isLookingUpRoute)
                    }
                }
                .padding(MachKitLayout.bannerPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .textBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
                }

                if let route = model.routeLookup {
                    HStack(spacing: 12) {
                        Image(systemName: route.errorMessage == nil ? "arrow.triangle.turn.up.right.diamond.fill" : "exclamationmark.triangle.fill")
                            .font(.system(size: 18)).foregroundStyle(route.errorMessage == nil ? Color.accentColor : Color.orange)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(route.errorMessage ?? "\(route.query) → \(route.destination)")
                                .font(.system(size: 12, weight: .semibold)).textSelection(.enabled)
                            if let gateway = route.gateway {
                                Text(L10n.format("Gateway %@", gateway))
                                    .font(.caption.monospaced()).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if let interfaceName = route.interfaceName {
                            Text(interfaceName).font(.system(size: 12, weight: .bold, design: .monospaced))
                                .padding(.horizontal, 9).padding(.vertical, 5)
                                .background(Color.accentColor.opacity(0.10), in: Capsule())
                        }
                    }
                    .padding(MachKitLayout.bannerPadding).background(Color.accentColor.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))

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
                        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(height: 34)
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
                            .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(minHeight: 34)
                            if index < min(snapshot.routes.count, 300) - 1 { Divider().padding(.leading, 13) }
                        }
                    }
                    .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.horizontal, MachKitLayout.pageMargin).padding(.bottom, MachKitLayout.pageMargin)
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
        .padding(MachKitLayout.bannerPadding).frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
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
        .padding(.horizontal, MachKitLayout.bannerPadding).frame(height: 34)
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
                .padding(.vertical, MachKitLayout.bannerPadding)
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
                    .padding(MachKitLayout.bannerPadding)
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
                    .padding(.horizontal, MachKitLayout.bannerPadding).frame(height: 34)
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
                        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).frame(height: 34)
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
            .padding(.horizontal, MachKitLayout.pageMargin)
            .padding(.bottom, MachKitLayout.pageMargin)
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
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal)
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
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal)
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
        .padding(MachKitLayout.pageMargin)
        .frame(width: 620)
    }

    func portDetailRow(_ title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title.localized).font(.system(size: 12, weight: .medium)).foregroundStyle(.secondary)
                .frame(width: 80, alignment: .leading)
            Text(value).font(.system(size: 12, design: .monospaced))
                .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, MachKitLayout.rowPaddingHorizontal).padding(.vertical, MachKitLayout.rowPaddingVertical)
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
}
