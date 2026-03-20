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

    readonly property bool _showCpu: Settings.settings.showCpuMonitor !== false
    readonly property bool _showRam: Settings.settings.showRamMonitor !== false
    readonly property bool _showIo: Settings.settings.showIoMonitor !== false
    readonly property bool _showGpu: Services.SystemMonitor.gpuAvailable && Settings.settings.showGpuMonitor !== false
    readonly property bool _showTemp: Settings.settings.showTempMonitor !== false
    readonly property bool _showSwap: Services.SystemMonitor.swapAvailable && Settings.settings.showSwapMonitor !== false
    readonly property bool _anyVisible: _showCpu || _showRam || _showIo || _showGpu || _showTemp || _showSwap

    Row {
        id: metricsRow
        anchors.centerIn: parent
        spacing: Math.round(5 * capsuleScale)

        // ── CPU ──
        Row {
            visible: root._showCpu
            spacing: Math.round(2 * capsuleScale)
            anchors.verticalCenter: parent.verticalCenter
            MaterialIcon {
                icon: "memory_alt"
                size: Math.round(iconBox * 0.75)
                color: SysUi.thresholdColor(Services.SystemMonitor.cpuPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.cpuPercent
                barHeight: root.barH
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
                size: Math.round(iconBox * 0.75)
                color: SysUi.thresholdColor(Services.SystemMonitor.ramPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.ramPercent
                barHeight: root.barH
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
                size: Math.round(iconBox * 0.75)
                color: SysUi.thresholdColor(Services.SystemMonitor.ioPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.ioPercent
                barHeight: root.barH
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
                size: Math.round(iconBox * 0.75)
                color: SysUi.thresholdColor(Services.SystemMonitor.gpuPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.gpuPercent
                barHeight: root.barH
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
                size: Math.round(iconBox * 0.75)
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
                size: Math.round(iconBox * 0.75)
                color: SysUi.thresholdColor(Services.SystemMonitor.swapPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            MonitorBar {
                value: Services.SystemMonitor.swapPercent
                barHeight: root.barH
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
