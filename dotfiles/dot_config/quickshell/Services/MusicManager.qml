pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import qs.Services
import qs.Settings
import qs.Components
import "../Helpers/MusicIds.js" as MusicIds
import "../Helpers/AccentSampler.js" as AccentSampler
// Settings are schema-validated; avoid runtime clamps

Item {
    id: manager

    function isCurrentMpdPlayer() { return MusicIds.isPlayerMpd(currentPlayer); }
    MusicPlayers { id: players }
    MusicPosition { id: position; currentPlayer: players.currentPlayer }
    property alias currentPlayer: players.currentPlayer
    property alias selectedPlayerIndex: players.selectedPlayerIndex
    property alias currentPosition: position.currentPosition

    // Playback state helpers
    property bool isPlaying:currentPlayer ? currentPlayer.isPlaying : false
    property bool isPaused:currentPlayer ? (currentPlayer.playbackState === MprisPlaybackState.Paused) : false
    property bool isStopped:currentPlayer ? (currentPlayer.playbackState === MprisPlaybackState.Stopped) : true
    property string trackTitle: currentPlayer ? (currentPlayer.trackTitle  || "") : ""
    property string trackArtist: currentPlayer ? (currentPlayer.trackArtist || "") : ""
    property string trackAlbum: currentPlayer ? (currentPlayer.trackAlbum  || "") : ""
    property string coverUrl: currentPlayer ? (currentPlayer.trackArtUrl || "") : ""
    property real trackLength:currentPlayer ? currentPlayer.length : 0  // raw from backend
    property bool canPlay:currentPlayer ? currentPlayer.canPlay : false
    property bool canPause:currentPlayer ? currentPlayer.canPause : false
    property bool canGoNext:currentPlayer ? currentPlayer.canGoNext : false
    property bool canGoPrevious:currentPlayer ? currentPlayer.canGoPrevious : false
    property bool canSeek:currentPlayer ? currentPlayer.canSeek : false
    property bool hasPlayer:players.hasPlayer

    MusicMeta { id: meta; currentPlayer: players.currentPlayer }
    property alias trackGenre: meta.trackGenre
    property alias trackLabel: meta.trackLabel
    property alias trackYear: meta.trackYear
    property alias trackBitrateStr: meta.trackBitrateStr
    property alias trackSampleRateStr: meta.trackSampleRateStr
    property alias trackDsdRateStr: meta.trackDsdRateStr
    property alias trackCodec: meta.trackCodec
    property alias trackCodecDetail: meta.trackCodecDetail
    property alias trackChannelsStr: meta.trackChannelsStr
    property alias trackBitDepthStr: meta.trackBitDepthStr
    property alias trackNumberStr: meta.trackNumberStr
    property alias trackDiscNumberStr: meta.trackDiscNumberStr
    property alias trackAlbumArtist: meta.trackAlbumArtist
    property alias trackComposer: meta.trackComposer
    property alias trackUrlStr: meta.trackUrlStr
    property alias trackDateStr: meta.trackDateStr
    property alias trackContainer: meta.trackContainer
    property alias trackFileSizeStr: meta.trackFileSizeStr
    property alias trackChannelLayout: meta.trackChannelLayout
    property alias trackQualitySummary: meta.trackQualitySummary
    

    Item { Component.onCompleted: players.updateCurrentPlayer() }
    function getAvailablePlayers() { return players.getAvailablePlayers(); }
    function updateCurrentPlayer() { return players.updateCurrentPlayer(); }

    function playPause() {
        if (!currentPlayer) return;
        if (currentPlayer.isPlaying) currentPlayer.pause(); else currentPlayer.play();
    }
    function play()     { if (currentPlayer && currentPlayer.canPlay)       currentPlayer.play(); }
    function pause()    { if (currentPlayer && currentPlayer.canPause)      currentPlayer.pause(); }
    function stop()     { if (currentPlayer && typeof currentPlayer.stop === "function") currentPlayer.stop(); }
    function next()     { if (currentPlayer && currentPlayer.canGoNext)     currentPlayer.next(); }
    function previous() { if (currentPlayer && currentPlayer.canGoPrevious) currentPlayer.previous(); }

    function seek(posMs) { position.seek(posMs); }

    // Audio spectrum bars (prefer active profile, then settings)
    readonly property bool visualizerAllowed: ((Quickshell.env("QS_DISABLE_VISUALIZER") || "") !== "1")
    Loader {
        id: cavaLoader
        active: manager.visualizerAllowed
        sourceComponent: Cava {
            id: cava
            count: (
                Settings.settings.visualizerProfiles
                && Settings.settings.visualizerProfiles[Settings.settings.activeVisualizerProfile]
                && Settings.settings.visualizerProfiles[Settings.settings.activeVisualizerProfile].cavaBars !== undefined
            ) ? Settings.settings.visualizerProfiles[Settings.settings.activeVisualizerProfile].cavaBars
              : Settings.settings.cavaBars
        }
    }
    property var cavaValues: cavaLoader.active && cavaLoader.item ? cavaLoader.item.values : []

    // ── Accent color extraction (centralized, cached by cover URL) ──
    property color accentColor: Theme.accentPrimary
    property bool accentReady: false
    property string _lastSampledUrl: ""
    property var _accentCache: ({})
    property int _accentRetryCount: 0

    onCoverUrlChanged: {
        var url = coverUrl || "";
        // Same URL as last sample → skip entirely (same album, no work needed)
        if (url === manager._lastSampledUrl) return;
        manager._lastSampledUrl = url;
        // Empty URL → reset to theme default
        if (!url) {
            manager.accentColor = Theme.accentPrimary;
            manager.accentReady = false;
            return;
        }
        // Cache hit → restore instantly, skip sampling
        if (manager._accentCache && manager._accentCache[url]) {
            manager.accentColor = manager._accentCache[url];
            manager.accentReady = true;
            return;
        }
        // Cache miss → debounced sampling
        manager.accentReady = false;
        manager._accentRetryCount = 0;
        _accentDebounce.restart();
    }

    // Hidden image for sampling (small, decoupled from display images)
    Image {
        id: _accentImage
        width: Theme.mediaAccentSamplerPx
        height: Theme.mediaAccentSamplerPx
        source: manager.coverUrl || ""
        visible: false
        fillMode: Image.PreserveAspectCrop
        onStatusChanged: {
            if (status === Image.Ready) {
                manager._accentRetryCount = 0;
                _accentDebounce.restart();
            }
        }
    }

    Canvas {
        id: _accentCanvas
        width: Theme.mediaAccentSamplerPx
        height: Theme.mediaAccentSamplerPx
        visible: false
        onPaint: {
            try {
                var ctx = getContext('2d');
                ctx.clearRect(0, 0, width, height);
                var url = manager.coverUrl || "";
                if (_accentImage.status !== Image.Ready) return;
                ctx.drawImage(_accentImage, 0, 0, width, height);
                var img = ctx.getImageData(0, 0, width, height);
                var rgb = AccentSampler.sampleAccent(img, {
                    satMin: Theme.mediaAccentSatMin,
                    lumMin: Theme.mediaAccentLumMin,
                    lumMax: Theme.mediaAccentLumMax,
                    satRelax: Theme.mediaAccentSatRelax,
                    lumRelaxMin: Theme.mediaAccentLumRelaxMin,
                    lumRelaxMax: Theme.mediaAccentLumRelaxMax
                });
                if (rgb) {
                    var col = Qt.rgba(rgb.r / 255.0, rgb.g / 255.0, rgb.b / 255.0, 1);
                    manager.accentColor = col;
                    manager.accentReady = true;
                    if (manager._accentCache) manager._accentCache[url] = col;
                } else {
                    var cached = manager._accentCache && manager._accentCache[url];
                    var fallback = cached || Theme.accentPrimary;
                    manager.accentColor = fallback;
                    manager.accentReady = !!cached;
                    if (manager._accentCache && !cached) manager._accentCache[url] = fallback;
                }
            } catch (e) { /* ignore */ }
        }
    }

    Timer {
        id: _accentDebounce
        interval: Theme.mediaArtDebounceMs
        repeat: false
        onTriggered: { _accentCanvas.requestPaint(); _accentRetry.restart(); }
    }

    Timer {
        id: _accentRetry
        interval: Theme.mediaAccentRetryMs
        repeat: false
        onTriggered: {
            _accentCanvas.requestPaint();
            if (!manager.accentReady && manager._accentRetryCount < Theme.mediaAccentRetryMax) {
                manager._accentRetryCount++;
                start();
            } else {
                manager._accentRetryCount = 0;
            }
        }
    }
}
