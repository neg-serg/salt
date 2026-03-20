import QtQuick
import qs.Components
import qs.Settings
import qs.Services as Services
import "../../Helpers/SystemMonitorUi.js" as SysUi

/*!
 * SystemMonitorCapsule — grouped capsule showing 6 system metrics as
 * icon + vertical bar pairs. Click to open detail popup.
 */
OverlayToggleCapsule {
    id: root
    readonly property real capsuleScale: capsule.capsuleScale
    readonly property int iconBox: capsule.capsuleInner
    readonly property int barH: Math.round(Theme.panelHeight * 0.55 * capsuleScale)
    capsule.backgroundKey: "systemMonitor"
    capsule.centerContent: true
    capsule.cursorShape: Qt.PointingHandCursor
    capsule.implicitWidth: capsule.horizontalPadding * 2 + metricsRow.implicitWidth
    capsuleVisible: _anyVisible
    autoToggleOnTap: true
    overlayNamespace: "sysmon-popup"

    // ── Settings ──
    readonly property bool _hideIdle: Settings.settings.systemMonitorHideIdle !== false
    readonly property real _idleThreshold: {
        var v = Settings.settings.systemMonitorIdleThreshold;
        return (typeof v === "number" && v >= 0) ? v : 0.03;
    }
    readonly property real _iconScale: {
        var v = Settings.settings.systemMonitorIconScale;
        return (typeof v === "number" && v > 0) ? v : 0.75;
    }
    readonly property int _metricSpacing: {
        var v = Settings.settings.systemMonitorSpacing;
        return (typeof v === "number" && v >= 0) ? Math.round(v * capsuleScale) : Math.round(5 * capsuleScale);
    }
    readonly property real _warnThr: {
        var v = Settings.settings.systemMonitorWarnThreshold;
        return (typeof v === "number" && v > 0) ? v : 0.5;
    }
    readonly property real _critThr: {
        var v = Settings.settings.systemMonitorCritThreshold;
        return (typeof v === "number" && v > 0) ? v : 0.8;
    }
    readonly property int _iconSz: Math.round(iconBox * _iconScale)

    // ── Visibility (settings + idle hide) ──
    readonly property bool _showCpu: Settings.settings.showCpuMonitor !== false
        && (!_hideIdle || Services.SystemMonitor.cpuPercent >= _idleThreshold)
    readonly property bool _showRam: Settings.settings.showRamMonitor !== false
        && (!_hideIdle || Services.SystemMonitor.ramPercent >= _idleThreshold)
    readonly property bool _showIo: Settings.settings.showIoMonitor !== false
        && (!_hideIdle || Services.SystemMonitor.ioPercent >= _idleThreshold)
    readonly property bool _showGpu: Services.SystemMonitor.gpuAvailable
        && Settings.settings.showGpuMonitor !== false
        && (!_hideIdle || Services.SystemMonitor.gpuPercent >= _idleThreshold)
    readonly property bool _showTemp: Settings.settings.showTempMonitor !== false
        && (!_hideIdle || Services.SystemMonitor.cpuTempPercent >= _idleThreshold)
    readonly property bool _showSwap: Services.SystemMonitor.swapAvailable
        && Settings.settings.showSwapMonitor !== false
        && (!_hideIdle || Services.SystemMonitor.swapPercent >= _idleThreshold)
    readonly property bool _anyVisible: _showCpu || _showRam || _showIo || _showGpu || _showTemp || _showSwap

    Row {
        id: metricsRow
        anchors.centerIn: parent
        spacing: root._metricSpacing

        // ── CPU ──
        Row {
            visible: root._showCpu
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "memory_alt"
                size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.cpuPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, root._warnThr, root._critThr)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.cpuPercent
                barHeight: root.barH
                warnThreshold: root._warnThr
                critThreshold: root._critThr
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── RAM ──
        Row {
            visible: root._showRam
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "memory"
                size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.ramPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, root._warnThr, root._critThr)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.ramPercent
                barHeight: root.barH
                warnThreshold: root._warnThr
                critThreshold: root._critThr
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── I/O ──
        Row {
            visible: root._showIo
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "storage"
                size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.ioPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, root._warnThr, root._critThr)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.ioPercent
                barHeight: root.barH
                warnThreshold: root._warnThr
                critThreshold: root._critThr
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── GPU ──
        Row {
            visible: root._showGpu
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "developer_board"
                size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.gpuPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, root._warnThr, root._critThr)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.gpuPercent
                barHeight: root.barH
                warnThreshold: root._warnThr
                critThreshold: root._critThr
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Temperature ──
        Row {
            visible: root._showTemp
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "thermostat"
                size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.cpuTempPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.43, 0.71)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.cpuTempPercent
                barHeight: root.barH
                warnThreshold: 0.43
                critThreshold: 0.71
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Swap ──
        Row {
            visible: root._showSwap
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "swap_horiz"
                size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.swapPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, root._warnThr, root._critThr)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.swapPercent
                barHeight: root.barH
                warnThreshold: root._warnThr
                critThreshold: root._critThr
                screen: root.screen
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    overlayChildren: [
        SystemMonitorPopup {
            screen: root.screen
            scaleHint: capsuleScale
        }
    ]
}
