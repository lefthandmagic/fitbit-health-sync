import SwiftUI

// MARK: - Root

struct RootView: View {
    var body: some View {
        ZStack {
            AppBackground()

            TabView {
                HomeView()
                    .tabItem {
                        Label("Home", systemImage: "house.fill")
                    }
                SettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "slider.horizontal.3")
                    }
                ActivityView()
                    .tabItem {
                        Label("Activity", systemImage: "waveform.path.ecg")
                    }
            }
        }
        .tint(.indigo)
    }
}

// MARK: - App Background

private struct AppBackground: View {
    var body: some View {
        // Must match UIWindow.appearance().backgroundColor exactly.
        // .ignoresSafeArea() extends into the status bar and home indicator
        // areas so the SwiftUI layer also paints the same colour there.
        Color(.systemGroupedBackground)
            .ignoresSafeArea(.all)
    }
}

// MARK: - Home

private struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @State private var showDisconnectConfirm = false

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 16) {
                        connectionBanner
                        statusRow
                        syncButton
                        metricsSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Fitbit Health Sync")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .confirmationDialog(
            "Disconnect Fitbit?",
            isPresented: $showDisconnectConfirm,
            titleVisibility: .visible
        ) {
            Button("Disconnect", role: .destructive) { model.disconnectFitbit() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You will need to reconnect to sync data.")
        }
    }

    // MARK: Connection banner

    private var connectionBanner: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(model.isConnected ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: model.isConnected ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(model.isConnected ? .green : .orange)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(model.isConnected ? "Connected to Fitbit" : "Not Connected")
                    .font(.headline)
                Text(model.isConnected ? "Auto-sync Fitbit data to Apple Health" : "Tap below to connect your account")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if model.isConnected {
                Button {
                    showDisconnectConfirm = true
                } label: {
                    Image(systemName: "minus.circle")
                        .font(.title3)
                        .foregroundStyle(.red.opacity(0.7))
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    model.isConnected ? Color.green.opacity(0.25) : Color.orange.opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    // MARK: Status row

    private var statusRow: some View {
        HStack(spacing: 12) {
            StatusTile(
                symbol: "clock.arrow.circlepath",
                label: "Last Sync",
                value: model.lastSyncText,
                tint: .indigo
            )
            StatusTile(
                symbol: model.isSyncing ? "arrow.triangle.2.circlepath" : "checkmark.circle",
                label: "Status",
                value: model.isSyncing ? "Syncing..." : "Idle",
                tint: model.isSyncing ? .blue : .green
            )
        }
    }

    // MARK: Sync button

    private var syncButton: some View {
        VStack(spacing: 12) {
            if !model.isConnected {
                Button {
                    Task { await model.connectFitbit() }
                } label: {
                    Label("Connect Fitbit Account", systemImage: "person.crop.circle.badge.plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .tint(.indigo)
                .cornerRadius(14)
            }

            Button {
                Task {
                    do {
                        _ = try await model.syncNow()
                    } catch {
                        model.appendLog("Manual sync failed: \(error.localizedDescription)")
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if model.isSyncing {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                    Text(model.isSyncing ? "Syncing..." : "Sync Now")
                        .font(.headline)
                }
                .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .tint(model.isConnected ? .indigo : .gray)
            .cornerRadius(14)
            .disabled(model.isSyncing || !model.isConnected)
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: Metrics

    private var metricsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Syncing Metrics")
                .font(.headline)
                .padding(.horizontal, 4)

            let metrics = model.settingsStore.enabledMetrics.sorted { $0.title < $1.title }
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(metrics) { metric in
                    MetricChip(metric: metric)
                }
            }
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

// MARK: - Settings

private struct SettingsView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedInterval: SyncIntervalHours = .every4
    @State private var enabledMetrics: Set<SyncMetric> = []

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                List {
                    Section {
                        Picker("Interval", selection: $selectedInterval) {
                            ForEach(SyncIntervalHours.allCases) { interval in
                                Text(interval.shortTitle).tag(interval)
                            }
                        }
                        .pickerStyle(.segmented)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                    } header: {
                        Text("Background Sync Interval")
                    } footer: {
                        Text("Best-effort only — iOS schedules background tasks based on device usage patterns.")
                    }

                    Section("Metrics to Sync") {
                        ForEach(SyncMetric.allCases) { metric in
                            Toggle(isOn: Binding(
                                get: { enabledMetrics.contains(metric) },
                                set: { on in
                                    if on { enabledMetrics.insert(metric) } else { enabledMetrics.remove(metric) }
                                }
                            )) {
                                Label(metric.title, systemImage: metric.symbol)
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
        }
        .navigationViewStyle(.stack)
        .onAppear {
            selectedInterval = model.settingsStore.syncInterval
            enabledMetrics = model.settingsStore.enabledMetrics
        }
        .onChange(of: selectedInterval) { _, new in
            model.settingsStore.syncInterval = new
            model.backgroundScheduler.scheduleNext()
        }
        .onChange(of: enabledMetrics) { _, new in model.settingsStore.enabledMetrics = new }
    }
}

// MARK: - Activity

private struct ActivityView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        NavigationView {
            ZStack {
                AppBackground()
                Group {
                    if model.logs.isEmpty {
                        ContentUnavailableView(
                            "No Activity Yet",
                            systemImage: "waveform.path.ecg",
                            description: Text("Sync logs will appear here after your first sync.")
                        )
                    } else {
                        List(Array(model.logs.enumerated()), id: \.offset) { _, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.primary)
                                .textSelection(.enabled)
                                .listRowBackground(Color(.secondarySystemGroupedBackground))
                        }
                        .scrollContentBackground(.hidden)
                    }
                }
            }
            .navigationTitle("Activity")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if !model.logs.isEmpty {
                        Button("Clear", role: .destructive) {
                            model.clearLogs()
                        }
                    }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}

// MARK: - Reusable components

private struct StatusTile: View {
    let symbol: String
    let label: String
    let value: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: symbol.contains("circlepath"))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

private struct MetricChip: View {
    let metric: SyncMetric

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: metric.symbol)
                .font(.caption)
                .foregroundStyle(.indigo)
            Text(metric.title)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.indigo.opacity(0.15), lineWidth: 1)
        )
    }
}
