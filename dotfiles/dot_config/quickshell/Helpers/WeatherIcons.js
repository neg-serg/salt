// WMO Weather Code → Material Symbols icon mapping
// Shared between Bar/Modules/WeatherButton.qml and Widgets/SidePanel/Weather.qml
// Reference: https://open-meteo.com/en/docs#weathervariables (WMO Weather interpretation codes)

function materialSymbolForCode(code) {
    if (code === 0) return "sunny";
    if (code === 1 || code === 2) return "partly_cloudy_day";
    if (code === 3) return "cloud";
    if (code >= 45 && code <= 48) return "foggy";
    if (code >= 51 && code <= 67) return "rainy";
    if (code >= 71 && code <= 77) return "weather_snowy";
    if (code >= 80 && code <= 82) return "rainy";
    if (code >= 95 && code <= 99) return "thunderstorm";
    return "cloud";
}
