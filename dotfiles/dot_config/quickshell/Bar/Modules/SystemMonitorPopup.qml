import QtQuick
import qs.Components
import qs.Settings
import qs.Services as Services
import "../../Helpers/SystemMonitorUi.js" as SysUi

/*!
 * SystemMonitorPopup — detail overlay showing exact numeric values
 * for all enabled system metrics.
 */
PanelOverlaySurface {
    id: root

    anchors.top: parent.top
    anchors.right: parent.right
    anchors.topMargin: Math.round(8 * overlayScale)
    anchors.rightMargin: Math.round(8 * overlayScale)

    readonly property int _iconSz: Math.round(Theme.fontSizeSmall * overlayScale)
    readonly property int _fontSize: Math.round(Theme.fontSizeSmall * overlayScale)
    readonly property int _pad: Math.round(10 * overlayScale)

    Column {
        id: popupContent
        padding: root._pad
        spacing: Math.round(6 * root.overlayScale)

        // ── CPU ──
        Row {
            visible: Settings.settings.showCpuMonitor !== false
            spacing: Math.round(6 * root.overlayScale)
            MaterialIcon {
                icon: "memory_alt"; size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.cpuPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "CPU"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: SysUi.formatPercent(Services.SystemMonitor.cpuPercent)
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── RAM ──
        Row {
            visible: Settings.settings.showRamMonitor !== false
            spacing: Math.round(6 * root.overlayScale)
            MaterialIcon {
                icon: "memory"; size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.ramPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "RAM"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Services.SystemMonitor.ramUsedGiB.toFixed(1) + " / " +
                      Services.SystemMonitor.ramTotalGiB.toFixed(1) + " GiB"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── GPU ──
        Row {
            visible: Services.SystemMonitor.gpuAvailable && Settings.settings.showGpuMonitor !== false
            spacing: Math.round(6 * root.overlayScale)
            MaterialIcon {
                icon: "developer_board"; size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.gpuPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "GPU"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: SysUi.formatPercent(Services.SystemMonitor.gpuPercent)
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Temperature ──
        Row {
            visible: Settings.settings.showTempMonitor !== false
            spacing: Math.round(6 * root.overlayScale)
            MaterialIcon {
                icon: "thermostat"; size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.cpuTempPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.43, 0.71)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Temp"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: SysUi.formatTemp(Services.SystemMonitor.cpuTempCelsius)
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── I/O ──
        Row {
            visible: Settings.settings.showIoMonitor !== false
            spacing: Math.round(6 * root.overlayScale)
            MaterialIcon {
                icon: "storage"; size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.ioPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "I/O"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "R:" + SysUi.formatKiBps(Services.SystemMonitor.ioReadKiBps) +
                      "  W:" + SysUi.formatKiBps(Services.SystemMonitor.ioWriteKiBps)
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── Swap (hidden until usage exceeds threshold, default 40%) ──
        Row {
            readonly property real _swapShowThr: {
                var v = Settings.settings.systemMonitorSwapShowThreshold;
                return (typeof v === "number" && v >= 0) ? v : 0.4;
            }
            visible: Services.SystemMonitor.swapAvailable
                && Settings.settings.showSwapMonitor !== false
                && Services.SystemMonitor.swapPercent >= _swapShowThr
            spacing: Math.round(6 * root.overlayScale)
            MaterialIcon {
                icon: "swap_horiz"; size: root._iconSz
                color: SysUi.thresholdColor(Services.SystemMonitor.swapPercent,
                    Theme.textSecondary, Theme.warning, Theme.error, 0.5, 0.8)
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: "Swap"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textSecondary
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: Services.SystemMonitor.swapUsedGiB.toFixed(1) + " / " +
                      Services.SystemMonitor.swapTotalGiB.toFixed(1) + " GiB"
                font.family: Theme.fontFamily
                font.pixelSize: root._fontSize
                color: Theme.textPrimary
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }
}
