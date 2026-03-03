pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.Settings
import "../Helpers/AccentSampler.js" as AccentSampler

Item {
    id: root

    readonly property bool enabled: Settings.settings.wallpaperAccent !== false
    property color wallpaperAccent: "#000000"
    property bool hasAccent: false

    readonly property string _cachePath: (Quickshell.env("XDG_CACHE_HOME")
        || (Quickshell.env("HOME") + "/.cache")) + "/quickshell-wallpaper-path"

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
                var rgb = AccentSampler.sampleAccent(img);
                if (rgb) {
                    root.wallpaperAccent = Qt.rgba(rgb.r / 255.0, rgb.g / 255.0, rgb.b / 255.0, 1);
                    root.hasAccent = true;
                } else {
                    root.hasAccent = false;
                }
            } catch (e) {
                root.hasAccent = false;
            }
        }
    }
}
