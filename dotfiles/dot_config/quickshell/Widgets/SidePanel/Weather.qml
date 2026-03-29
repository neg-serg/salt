import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import qs.Settings
import qs.Components
import "../../Helpers/Color.js" as Color
import "../../Helpers/WeatherIcons.js" as WeatherIcons
import qs.Services as Services
 
Rectangle {
    id: weatherRoot
    width: Math.round(Theme.sidePanelWeatherWidth * Theme.scale(Screen))
    height: Math.round(Theme.sidePanelWeatherHeight * Theme.scale(Screen))
    color: "transparent"
    anchors.horizontalCenterOffset: Theme.weatherCenterOffset
 
    property string city: Settings.settings.weatherCity !== undefined ? Settings.settings.weatherCity : ""
    property var weatherData: Services.Weather.weatherData
    property string errorString: Services.Weather.errorString
    property bool isVisible: false
    property int lastFetchTime: 0
    property bool isLoading: Services.Weather.isLoading
 
    Connections { target: Services.Weather; function onWeatherDataChanged() { weatherRoot.weatherData = Services.Weather.weatherData } }
 
    Component.onCompleted: { if (isVisible) Services.Weather.start() }
 
    function startWeatherFetch() { isVisible = true; Services.Weather.start() }

    function warnContrast(bg, fg, label) {
        try {
            if (!(Settings.settings && Settings.settings.debugLogs)) return;
            var ratio = Color.contrastRatio(bg, fg);
            var th = (Settings.settings && Settings.settings.contrastWarnRatio) ? Settings.settings.contrastWarnRatio : 4.5;
            if (ratio < th) console.debug('[Contrast]', label || 'text', 'ratio', ratio.toFixed(2));
        } catch (e) { console.warn("[Weather.warnContrast]", e) }
    }

    Rectangle {
        id: card
        anchors.fill: parent
        color: Color.withAlpha(Theme.accentDarkStrong, Theme.weatherCardOpacity)
        border.color: Theme.borderSubtle
        border.width: Theme.uiBorderWidth
        radius: Math.round(Theme.sidePanelCornerRadius * Theme.scale(Screen))
 
        ColumnLayout {
            anchors.fill: parent
        anchors.margins: Math.round(Theme.panelSideMargin * Theme.scale(Screen))
            spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))
 
 
            RowLayout {
                spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))
                Layout.fillWidth: true
 
 
                RowLayout {
                    spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))
                    Layout.preferredWidth: Math.round(weatherRoot.width * Theme.sidePanelWeatherLeftColumnRatio)
 
 
                    Spinner {
                        id: loadingSpinner
                        running: isLoading
                        color: Theme.accentPrimary
                        size: Math.round(Theme.uiIconSizeLarge * Theme.scale(Screen))
                        Layout.alignment: Qt.AlignVCenter
                        visible: isLoading
                    }

                    MaterialIcon {
                        id: weatherIcon
                        visible: !isLoading
                        icon: weatherData && weatherData.current ? WeatherIcons.materialSymbolForCode(weatherData.current.weather_code) : "cloud"
                        size: Math.round(Theme.uiIconSizeLarge * Theme.scale(Screen))
                        color: Theme.accentPrimary
                        Layout.alignment: Qt.AlignVCenter
                    }
 
                    ColumnLayout {
                        spacing: Math.round(Theme.sidePanelSpacingSmall * Theme.scale(Screen))
                        RowLayout {
                            spacing: Math.round(Theme.sidePanelSpacingSmall * Theme.scale(Screen))
                            Text {
                                text: city
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.round(Theme.fontSizeSmall * Theme.scale(Screen))
                                font.bold: true
                                color: Theme.textOn(card.color)
                            }
                            Text {
                                text: weatherData && weatherData.timezone_abbreviation ? `(${weatherData.timezone_abbreviation})` : ""
                                font.family: Theme.fontFamily
                                    font.pixelSize: Math.round(Theme.tooltipFontPx * Theme.tooltipSmallScaleRatio * Theme.scale(Screen))
                                color: Theme.textOn(card.color)
                                leftPadding: Math.round(Theme.sidePanelSpacingSmall * 0.5 * Theme.scale(Screen))
                            }
                        }
                        Text {
                            text: weatherData && weatherData.current ? ((Settings.settings.useFahrenheit !== undefined ? Settings.settings.useFahrenheit : false) ? `${Math.round(weatherData.current.temperature_2m * 9/5 + 32)}°F` : `${Math.round(weatherData.current.temperature_2m)}°C`) : ((Settings.settings.useFahrenheit !== undefined ? Settings.settings.useFahrenheit : false) ? "--°F" : "--°C")
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSizeHeader * Theme.weatherHeaderScale * Theme.scale(Screen))
                            font.bold: true
                            color: Theme.textOn(card.color)
                            Component.onCompleted: weatherRoot.warnContrast(card.color, color, 'weather.current')
                        }
                        RowLayout {
                            spacing: Math.round(Theme.sidePanelSpacingSmall * 0.5 * Theme.scale(Screen))
                            visible: weatherData && weatherData.current && typeof weatherData.current.wind_speed_10m === 'number'
                            MaterialIcon {
                                icon: "navigation"
                                rotationAngle: weatherData && weatherData.current ? WeatherIcons.windRotation(weatherData.current.wind_direction_10m) : 0
                                size: Math.round(Theme.fontSizeSmall * Theme.scale(Screen))
                                color: Theme.textOn(card.color)
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: weatherData && weatherData.current ? WeatherIcons.formatWindFull(weatherData.current.wind_speed_10m, weatherData.current.wind_direction_10m) : ""
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.round(Theme.fontSizeSmall * Theme.scale(Screen))
                                color: Theme.textOn(card.color)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                        RowLayout {
                            spacing: Math.round(Theme.sidePanelSpacingSmall * 0.5 * Theme.scale(Screen))
                            Text {
                                text: WeatherIcons.moonIcon(new Date())
                                font.pixelSize: Math.round(Theme.fontSizeSmall * Theme.scale(Screen))
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Text {
                                text: WeatherIcons.moonName(new Date())
                                font.family: Theme.fontFamily
                                font.pixelSize: Math.round(Theme.fontSizeSmall * Theme.scale(Screen))
                                color: Theme.textOn(card.color)
                                Layout.alignment: Qt.AlignVCenter
                            }
                        }
                    }
                }
 
                Item {
                    Layout.fillWidth: true
                }
            }
 
            RowLayout {
                spacing: Math.round(Theme.sidePanelSpacing * Theme.scale(Screen))
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: Math.round(Theme.sidePanelSpacing * 0.75 * Theme.scale(Screen))
                visible: weatherData && weatherData.daily && weatherData.daily.time
 
                Repeater {
                    model: weatherData && weatherData.daily && weatherData.daily.time ? 5 : 0
                    delegate: ColumnLayout {
                        spacing: Math.round(Theme.sidePanelSpacingSmall * Theme.scale(Screen))
                        Layout.alignment: Qt.AlignHCenter
                        Text {

                            text: Qt.formatDateTime(new Date(weatherData.daily.time[index]), "ddd")
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSizeCaption * Theme.scale(Screen))
                            color: Theme.textOn(card.color)
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                            Component.onCompleted: weatherRoot.warnContrast(card.color, color, 'weather.dailyLabel')
                        }
                        MaterialIcon {
                            icon: WeatherIcons.materialSymbolForCode(weatherData.daily.weathercode[index])
                            size: Math.round(Theme.panelPillIconSize * Theme.scale(Screen))
                            color: Theme.accentPrimary
                            Layout.alignment: Qt.AlignHCenter
                        }
                        Text {

                            text: weatherData && weatherData.daily ? ((Settings.settings.useFahrenheit !== undefined ? Settings.settings.useFahrenheit : false) ? `${Math.round(weatherData.daily.temperature_2m_max[index] * 9/5 + 32)}° / ${Math.round(weatherData.daily.temperature_2m_min[index] * 9/5 + 32)}°` : `${Math.round(weatherData.daily.temperature_2m_max[index])}° / ${Math.round(weatherData.daily.temperature_2m_min[index])}°`) : ((Settings.settings.useFahrenheit !== undefined ? Settings.settings.useFahrenheit : false) ? "--° / --°" : "--° / --°")
                            font.family: Theme.fontFamily
                            font.pixelSize: Math.round(Theme.fontSizeCaption * Theme.scale(Screen))
                            color: Theme.textPrimary
                            horizontalAlignment: Text.AlignHCenter
                            Layout.alignment: Qt.AlignHCenter
                            Component.onCompleted: weatherRoot.warnContrast(card.color, color, 'weather.daily')
                        }
                    }
                }
            }
 
 
            Text {
                text: errorString
                color: Theme.error
                visible: errorString !== ""
                font.family: Theme.fontFamily
                font.pixelSize: Math.round(Theme.tooltipFontPx * 0.71 * Theme.scale(Screen))
                horizontalAlignment: Text.AlignHCenter
                Layout.alignment: Qt.AlignHCenter
            }
        }
    }
}
