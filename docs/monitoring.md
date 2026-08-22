# Monitoring

MachKit samples system metrics locally on your Mac. Nothing is uploaded to a server.

## Architecture

- **`SystemMonitorService`** (app target) owns a single `PerformanceMonitor` and `NetworkScanner`, so the performance page, home dashboard, and menu bar share counter baselines and reuse short-lived `nettop` results.
- **`PerformanceMonitor`** (app target) reads Mach APIs, IOKit, and optional SoCMetrics on Apple Silicon.
- **`NetworkScanner`** (`MachKitCore`) shells out to `nettop`, `lsof`, `netstat`, and related tools for network diagnostics.
- **`PerformanceSamplingMath`** (`MachKitCore`) contains pure helpers for rates, memory pressure, and bundle aggregation. These are covered by unit tests.

## Refresh cadence

| Surface | Interval | Work performed |
|---------|----------|----------------|
| Performance page | 2 s (active app) / 30 s (inactive) | Full snapshot |
| Home dashboard | 3 s (active) / 30 s (inactive) | CPU, memory pressure, thermal, primary interface speed |
| Menu bar popover | 2 s while open | CPU, memory, primary interface speed |

Sampling stops when you leave the relevant page or close the menu bar popover.

## Metrics and data sources

### CPU

- **System CPU** — `host_statistics` / `host_processor_info` deltas.
- **Per-core bars** — per-logical-core idle tick deltas, grouped by performance cluster when sysctl exposes `hw.perflevel*`.
- **Per-app CPU** — `proc_pidinfo(PROC_PIDTASKINFO)` user+system time deltas, shown as **share of total system capacity** (100% ≈ all logical cores busy). This matches Activity Monitor’s “% CPU” style better than a single-core percentage.

### GPU

- **Apple Silicon** — SoCMetrics (`IOReport`) `gpuActiveResidency`, sampled at most every 2 seconds inside the monitor loop.
- **Intel / fallback** — IOAccelerator `PerformanceStatistics` keys such as `Device Utilization %`.
- **Per-GPU-core bars** — macOS does not expose per-core GPU utilization; bars duplicate chip-level active residency for layout only.

### Neural Engine

- **Power (W)** — SoCMetrics ANE power when available.
- **Bar percentage** — estimated as `powerWatts / 8W × 100`, capped at 100%. This is a **heuristic**, not an official utilization counter.

### Memory

- **Used / cached / compressed** — `host_statistics64(HOST_VM_INFO64)`.
- **Pressure %** — MachKit estimate: `1 − reclaimable / physical`. Thresholds: Normal &lt; 75%, Elevated &lt; 90%, Critical ≥ 90%. This may differ from macOS Memory Pressure notifications.

### Disk and network (system)

- **Disk throughput** — IOBlockStorageDriver `Statistics` byte counters.
- **Network throughput** — `getifaddrs` interface byte counters (all up, non-loopback interfaces).

### Per-app network

- **Source** — `nettop -P -L 1` per-process `bytes_in` / `bytes_out`.
- **Aggregation** — helper processes whose executable lives inside a running app bundle are rolled up to that app’s main PID (e.g. browser renderer processes).
- **Limits** — only GUI apps listed by `NSWorkspace`; daemons and apps without a `.app` bundle are excluded.

## Permissions

| Tool / API | Typical need |
|------------|----------------|
| Mach / sysctl / IOKit | none beyond running the app |
| `nettop`, `lsof` | usually none; some environments restrict process visibility |
| Full Disk Access | not required for monitoring; may be needed elsewhere in MachKit for certain folders |

## Known limitations

1. First sample after launch shows `0` rates until a baseline exists (~2 s).
2. SoCMetrics requires Apple Silicon and a successful `SoCSampler` init.
3. App rankings omit headless daemons and CLI tools.
4. Neural Engine % is power-based, not comparable to CPU/GPU %.
5. Multiple MachKit instances are not supported; use one app instance for consistent baselines.

## Testing

```bash
swift test --filter PerformanceSamplingMath
swift test --filter networkScanner
```

## Dependencies

- [swift-soc-metrics](https://github.com/GoodOlClint/swift-soc-metrics) (Apple Silicon GPU / ANE, Xcode app target only)
