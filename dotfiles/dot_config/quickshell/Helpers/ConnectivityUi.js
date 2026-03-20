.pragma library

// Format a KiB/s value as a fixed-width "NNN.D U" string (7 chars).
// Auto-scales: K → M → G → T when integer part would exceed 3 digits.
// Zero-pads integer part to exactly 3 digits.
var _units = ["K", "M", "G", "T"];

function formatScaledKiBps(value) {
    var v = Number(value);
    if (!isFinite(v) || v < 0) v = 0;
    var ui = 0;
    while (v >= 999.95 && ui < 3) {
        v = v / 1024;
        ui++;
    }
    var fixed = v.toFixed(1);
    var dot = fixed.indexOf(".");
    var intStr = fixed.slice(0, dot);
    var dec = fixed.slice(dot + 1);
    var padded = ("000" + intStr).slice(-3);
    return padded + "." + dec + " " + _units[ui];
}

function formatThroughput(rxKiBps, txKiBps) {
    var rx = Number(rxKiBps);
    var tx = Number(txKiBps);
    if ((!isFinite(rx) || rx <= 0) && (!isFinite(tx) || tx <= 0)) return "-/-";
    return formatScaledKiBps(rx) + "/" + formatScaledKiBps(tx);
}

function warningColor(settings, theme) {
    const warn = settings && settings.networkNoInternetColor;
    return warn || theme.warning;
}

function errorColor(settings, theme) {
    const err = settings && settings.networkNoLinkColor;
    return err || theme.error;
}

