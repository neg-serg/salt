import QtQuick
import qs.Settings
import "." as LocalComponents

/*!
 * PanelTooltip applies shared defaults for tooltips used across the panel.
 * Consumers bind `visibleWhen` to any condition; the component manages the
 * underlying StyledTooltip.
 */
LocalComponents.StyledTooltip {
    id: root

    property bool visibleWhen: false
    property int delayMs: Theme.tooltipDelayMs
    delay: delayMs
    tooltipVisible: visibleWhen
}
