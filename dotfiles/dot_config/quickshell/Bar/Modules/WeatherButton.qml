import QtQuick
import qs.Components
import qs.Settings
import qs.Widgets.SidePanel
import qs.Services as Services
import "../../Helpers/TooltipText.js" as TooltipText
import "../../Helpers/WeatherIcons.js" as WeatherIcons

OverlayToggleCapsule {
    id: root
    readonly property real capsuleScale: capsule.capsuleScale
    readonly property int iconBox: capsule.capsuleInner
    capsule.backgroundKey: "weather"
    capsule.centerContent: true
    capsule.cursorShape: Qt.PointingHandCursor
    capsule.implicitWidth: capsule.horizontalPadding * 2 + weatherContent.implicitWidth
    capsuleVisible: true
    autoToggleOnTap: true
    overlayNamespace: "sideleft-weather"

    readonly property var _weatherData: Services.Weather.weatherData
    readonly property var _current: _weatherData && _weatherData.current_weather ? _weatherData.current_weather : null
    readonly property string weatherIcon: _current && typeof _current.weathercode === 'number'
        ? WeatherIcons.materialSymbolForCode(_current.weathercode)
        : "partly_cloudy_day"
    readonly property string temperatureText: {
        try {
            if (_current && typeof _current.temperature === 'number') {
                var c = Math.round(_current.temperature);
                var useF = Settings.settings.useFahrenheit || false;
                return useF ? Math.round(c * 9/5 + 32) + "°F" : c + "°C";
            }
        } catch (e) { /* guard */ }
        return (Settings.settings.useFahrenheit || false) ? "--°F" : "--°C";
    }
    readonly property string windText: {
        try {
            if (_current && typeof _current.windspeed === 'number') {
                return WeatherIcons.formatWind(_current.windspeed, _current.winddirection);
            }
        } catch (e) { /* guard */ }
        return "";
    }

    Row {
        id: weatherContent
        anchors.centerIn: parent
        spacing: Math.round(4 * capsuleScale)

        MaterialIcon {
            id: weatherIconItem
            icon: root.weatherIcon
            size: iconBox
            color: Theme.accentPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: tempLabel
            text: root.temperatureText
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSizeSmall * capsuleScale)
            color: Theme.textPrimary
            anchors.verticalCenter: parent.verticalCenter
        }

        Text {
            id: windLabel
            visible: root.windText !== ""
            text: "· " + root.windText
            font.family: Theme.fontFamily
            font.pixelSize: Math.round(Theme.fontSizeSmall * capsuleScale * 0.85)
            color: Theme.textSecondary
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    HoverHandler {
        id: hoverArea
    }

    overlayChildren: [
        PanelOverlaySurface {
            id: popup
            screen: root.screen
            scaleHint: capsuleScale
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.topMargin: Math.round(Theme.sidePanelSpacingMedium * capsuleScale)
            anchors.leftMargin: Math.round(Theme.panelSideMargin * capsuleScale)

            Weather {
                id: weather
                width: Math.round(Theme.sidePanelWeatherWidth * capsuleScale)
                height: Math.round(Theme.sidePanelWeatherHeight * capsuleScale)
            }
        }
    ]

    PanelTooltip {
        id: weatherTip
        targetItem: weatherContent
        text: root.tooltipText()
        visibleWhen: hoverArea.hovered
    }

    function tooltipText() {
        try {
            const city = Settings.settings.weatherCity || "";
            const data = Services.Weather.weatherData;
            if (data && data.current_weather && typeof data.current_weather.temperature === 'number') {
                const c = Math.round(data.current_weather.temperature);
                const useF = Settings.settings.useFahrenheit || false;
                const t = useF ? Math.round(c * 9/5 + 32) + "°F" : c + "°C";
                const wind = WeatherIcons.formatWindFull(data.current_weather.windspeed, data.current_weather.winddirection);
                var sub = wind ? [wind] : [];
                return TooltipText.compose(city || "Weather", t, sub);
            }
            return TooltipText.compose("Weather", city, []);
        } catch (e) {
            return "Weather";
        }
    }

    Connections { target: Services.Weather; function onWeatherDataChanged() { weatherTip.text = root.tooltipText(); } }
}
