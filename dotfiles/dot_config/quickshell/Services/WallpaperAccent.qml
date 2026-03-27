pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Settings

Item {
    id: root

    enabled: Settings.settings.wallpaperAccent !== false
    property color wallpaperAccent: "#000000"
    property bool hasAccent: false

    readonly property string _cachePath: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/quickshell-wallpaper-path"

    // Push accent into Theme to avoid circular qs.Settings / qs.Services import
    onWallpaperAccentChanged: { Theme._wpAccent = wallpaperAccent; }
    onHasAccentChanged: { Theme._wpHasAccent = hasAccent; }

    FileView {
        id: pathFile
        path: root._cachePath
        watchChanges: true
        blockLoading: false
        onLoaded: root._onPathLoaded(text())
        onFileChanged: reload()
        onLoadFailed: { root.hasAccent = false; }
    }

    function _onPathLoaded(raw) {
        if (!root.enabled) return;
        var p = raw.trim();
        if (p.length === 0) { root.hasAccent = false; return; }
        wallpaperImg.source = "file://" + p;
    }

    Image {
        id: wallpaperImg
        visible: false
        fillMode: Image.PreserveAspectFit
        sourceSize.width: 64
        sourceSize.height: 64
        asynchronous: true
        onStatusChanged: {
            if (status === Image.Ready)
                sampleTimer.restart();
        }
    }

    Timer {
        id: sampleTimer
        interval: 50
        repeat: false
        onTriggered: sampler.requestPaint()
    }

    // Inline AccentSampler — relative JS imports don't work in singleton modules
    function _sampleAccent(imageData) {
        if (!imageData || !imageData.data) return null;
        var data = imageData.data;
        var len = data.length;
        var satMin = 10, lumMin = 20, lumMax = 235;
        var satRelax = 8, lumRelaxMin = 20, lumRelaxMax = 240;
        var rs = 0, gs = 0, bs = 0, n = 0;
        for (var i = 0; i < len; i += 4) {
            var a = data[i + 3]; if (a < 128) continue;
            var r = data[i], g = data[i + 1], b = data[i + 2];
            var maxv = Math.max(r, g, b), minv = Math.min(r, g, b);
            var sat = maxv - minv; if (sat < satMin) continue;
            var lum = (r + g + b) / 3; if (lum < lumMin || lum > lumMax) continue;
            rs += r; gs += g; bs += b; ++n;
        }
        if (n === 0) {
            rs = 0; gs = 0; bs = 0; n = 0;
            for (var j = 0; j < len; j += 4) {
                var a2 = data[j + 3]; if (a2 < 128) continue;
                var r2 = data[j], g2 = data[j + 1], b2 = data[j + 2];
                var max2 = Math.max(r2, g2, b2), min2 = Math.min(r2, g2, b2);
                var sat2 = max2 - min2; if (sat2 < satRelax) continue;
                var lum2 = (r2 + g2 + b2) / 3; if (lum2 < lumRelaxMin || lum2 > lumRelaxMax) continue;
                rs += r2; gs += g2; bs += b2; ++n;
            }
        }
        if (n > 0) return { r: Math.min(255, Math.round(rs / n)), g: Math.min(255, Math.round(gs / n)), b: Math.min(255, Math.round(bs / n)) };
        return null;
    }

    Canvas {
        id: sampler
        width: 48
        height: 48
        visible: false
        onPaint: {
            try {
                var ctx = getContext('2d');
                ctx.clearRect(0, 0, width, height);
                if (wallpaperImg.status !== Image.Ready) return;
                ctx.drawImage(wallpaperImg, 0, 0, width, height);
                var img = ctx.getImageData(0, 0, width, height);
                var rgb = root._sampleAccent(img);
                if (rgb) {
                    root.wallpaperAccent = Qt.rgba(rgb.r / 255.0, rgb.g / 255.0, rgb.b / 255.0, 1);
                    root.hasAccent = true;
                } else {
                    root.hasAccent = false;
                }
            } catch (e) {
                console.warn("[WallpaperAccent]", e);
                root.hasAccent = false;
            }
        }
    }
}
