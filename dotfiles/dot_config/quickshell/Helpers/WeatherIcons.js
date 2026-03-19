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

// Wind direction: degrees → compass label, rotation angle for arrow icon
// Meteorological convention: 0°=N means wind blows FROM north
function windDirection(deg) {
    var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    var idx = Math.round(deg / 45) % 8;
    return dirs[idx];
}

// Rotation for a "navigation" icon (▲ points up at 0°).
// Add 180° so arrow shows where wind blows TO (matching meteorological convention).
function windRotation(deg) {
    return (typeof deg === 'number') ? (deg + 180) % 360 : 0;
}

// Compact format for bar: "3.2"
function formatWindSpeed(speed) {
    if (typeof speed !== 'number') return "";
    return speed.toFixed(1);
}

// Verbose format for tooltip/panel: "3.2 m/s N"
function formatWindFull(speed, deg) {
    if (typeof speed !== 'number') return "";
    return speed.toFixed(1) + " m/s " + windDirection(deg);
}
