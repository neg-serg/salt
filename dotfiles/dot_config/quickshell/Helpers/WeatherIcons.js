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

// Wind direction degrees → compass label + Material Symbols arrow icon
// 0°=N wind (blowing FROM north → arrow points south/down)
function windDirection(deg) {
    var dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"];
    var idx = Math.round(deg / 45) % 8;
    return dirs[idx];
}

function windDirectionIcon(deg) {
    // Arrow shows where wind blows TO (opposite of meteorological "from")
    var icons = [
        "south",       // 0°   N wind → blows southward
        "south_west",  // 45°  NE wind
        "west",        // 90°  E wind
        "north_west",  // 135° SE wind
        "north",       // 180° S wind
        "north_east",  // 225° SW wind
        "east",        // 270° W wind
        "south_east"   // 315° NW wind
    ];
    var idx = Math.round(deg / 45) % 8;
    return icons[idx];
}

function formatWind(speed, deg) {
    if (typeof speed !== 'number') return "";
    var dir = windDirection(deg);
    return Math.round(speed) + " km/h " + dir;
}
