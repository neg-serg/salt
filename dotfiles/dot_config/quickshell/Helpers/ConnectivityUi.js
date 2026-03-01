.pragma library

function formatKiBps(value) {
    const n = Number(value);
    if (!isFinite(n)) return "0.0";
    return n.toFixed(1);
}

function formatThroughput(rxKiBps, txKiBps) {
    const rx = Number(rxKiBps);
    const tx = Number(txKiBps);
    if ((!isFinite(rx) || rx === 0) && (!isFinite(tx) || tx === 0)) return "0";
    return `${formatKiBps(rx)}\/${formatKiBps(tx)}K`;
}

function warningColor(settings, theme) {
    const warn = settings && settings.networkNoInternetColor;
    return warn || theme.warning;
}

function errorColor(settings, theme) {
    const err = settings && settings.networkNoLinkColor;
    return err || theme.error;
}

