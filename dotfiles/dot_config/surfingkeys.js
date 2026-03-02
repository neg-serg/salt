// Surfingkeys configuration
// https://github.com/brookhong/Surfingkeys

// ========== Settings ==========
settings.hintAlign = "left";
api.Hints.setCharacters("qwertasdfg");
settings.omnibarSuggestion = false; // DISABLED: Using native address bar
settings.focusFirstCandidate = false;
settings.scrollStepSize = 120;
settings.smoothScroll = true;
settings.modeAfterYank = "Normal";

// ========== Theme ==========
settings.theme = `
:root {
  --font-mono: "Iosevka", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
  --font-size: 0.875rem;
  --bg:           #020202;
  --bg-alt:       #0a0a0a;
  --bg-highlight: #13384f;
  --fg:           #f0f1ff;
  --fg-muted:     rgba(240, 241, 255, 0.6);
  --accent:       #89cdd2;
  --border:       #0a3749;
  --hint-bg:      #002D59;
  --hint-fg:      #94E1F9;
  --hint-border:  #006FCC;
}

/* ── Base ────────────────────────────────────────── */
.sk_theme {
  font-family: var(--font-mono);
  font-size: var(--font-size);
  background: var(--bg);
  color: var(--fg);
}
.sk_theme tbody { color: var(--fg); }
.sk_theme input  { color: var(--fg); }

/* ── Omnibar text elements ───────────────────────── */
.sk_theme .url              { color: var(--accent); }
.sk_theme .annotation       { color: var(--fg-muted); }
.sk_theme .omnibar_highlight { color: var(--accent); font-weight: 600; }
.sk_theme .omnibar_timestamp { color: var(--fg-muted); }
.sk_theme .omnibar_visitcount { color: var(--fg-muted); }
.sk_theme .omnibar_folder   { color: var(--accent); }
.sk_theme .prompt           { color: var(--fg-muted); }
.sk_theme .separator        { color: var(--border); }

/* ── Omnibar container + result rows ─────────────── */
#sk_omnibar {
  border: 1px solid var(--border);
  box-shadow: 0 8px 32px rgba(0, 0, 0, 0.9);
  border-radius: 0;
}
.sk_theme #sk_omnibarSearchResult ul li:nth-child(odd) {
  background: var(--bg-alt);
}
.sk_theme #sk_omnibarSearchResult ul li.focused {
  background: var(--bg-highlight);
}

/* ── Banner ──────────────────────────────────────── */
#sk_banner {
  font-family: var(--font-mono);
  font-size: var(--font-size);
  font-weight: 600;
  background: var(--bg) !important;
  color: var(--fg) !important;
  border: 1px solid var(--border);
  border-radius: 0;
  box-shadow: none;
  padding: 4px 12px;
}

/* ── Keystroke overlay ───────────────────────────── */
#sk_keystroke {
  background: var(--bg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 0 !important;
  box-shadow: none !important;
  padding: 6px !important;
  color: var(--fg) !important;
}
#sk_keystroke kbd {
  font-family: var(--font-mono);
  font-size: var(--font-size);
  font-weight: 600;
  color: var(--hint-fg) !important;
  background: var(--hint-bg) !important;
  border: 1px solid var(--hint-border) !important;
  border-radius: 0;
  padding: 2px 4px;
  margin: 2px;
  box-shadow: none;
}
#sk_keystroke .annotation { color: var(--fg) !important; }
#sk_keystroke .candidates  { color: var(--accent) !important; }

/* ── Status line ─────────────────────────────────── */
#sk_status {
  font-family: var(--font-mono);
  font-size: var(--font-size);
  font-weight: 600;
  background: var(--bg) !important;
  color: var(--fg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 0;
}
#sk_status > span {
  padding: 4px 8px;
  color: var(--fg) !important;
  border-right: 1px solid var(--border);
}

/* ── Find bar + in-page highlights ───────────────── */
.sk_find_highlight {
  background: var(--bg-highlight) !important;
  color: var(--fg) !important;
  border-bottom: 2px solid var(--accent) !important;
}
#sk_find {
  background: var(--bg) !important;
  border: 1px solid var(--border) !important;
  color: var(--fg) !important;
}
#sk_find input {
  font-family: var(--font-mono) !important;
  font-weight: 600 !important;
  color: var(--fg) !important;
  background: transparent !important;
  border: none !important;
}

/* ── Bubble / Popup / Usage ──────────────────────── */
#sk_bubble, #sk_popup {
  background: var(--bg) !important;
  color: var(--fg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 0;
  box-shadow: none;
}
#sk_usage {
  background: var(--bg) !important;
  color: var(--fg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 0;
}
#sk_usage .feature_name {
  color: var(--accent) !important;
  border-bottom: 2px solid var(--border) !important;
}
#sk_usage .feature_name > span { border-bottom: none !important; }

/* ── Tab list (w key) ────────────────────────────── */
#sk_tabs {
  background: var(--bg) !important;
  border: 1px solid var(--border) !important;
  border-radius: 0;
}
.sk_tab {
  background: var(--bg-alt) !important;
  border: 1px solid var(--border) !important;
  color: var(--fg) !important;
  border-radius: 0;
}
.sk_tab_title { color: var(--fg) !important; }
.sk_tab.active  { background: var(--bg-highlight) !important; }
.sk_tab_hint {
  background: var(--hint-bg) !important;
  background-image: none !important;
  color: var(--hint-fg) !important;
  border: 1px solid var(--hint-border) !important;
  border-radius: 0 !important;
  box-shadow: none !important;
}
`;

// ========== Hints Styling (Shadow DOM) ==========
api.Hints.style(`
  div, mask {
    font-family: "Iosevka", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace !important;
    font-size: 0.875rem !important;
    font-weight: 600 !important;
    padding: 2px 4px !important;
    background: #002D59 !important;
    background-image: none !important;
    color: #94E1F9 !important;
    border: 1px solid #006FCC !important;
    border-radius: 0 !important;
    box-shadow: none !important;
  }

  mask {
    background: rgba(0, 111, 204, 0.3) !important;
    border: 1px solid #006FCC !important;
  }

  mask.activeInput {
    background: rgba(0, 111, 204, 0.6) !important;
    border: 2px solid #006FCC !important;
  }
`);

// Style for text/visual mode hints
api.Hints.style(`
  div {
    font-family: "Iosevka", ui-monospace, SFMono-Regular, Menlo, Consolas, monospace !important;
    font-size: 0.875rem !important;
    font-weight: 600 !important;
    padding: 2px 4px !important;
    background: #002D59 !important;
    background-image: none !important;
    color: #94E1F9 !important;
    border: 1px solid #006FCC !important;
    border-radius: 0 !important;
    box-shadow: none !important;
  }
  div.begin {
    color: #94E1F9 !important;
  }
`, "text");

// ========== Visual Mode ==========
api.map('V', 'v');  // V → enter visual/caret mode (v is remapped to scroll)
api.Visual.style('cursor', 'background-color: #006FCC; color: #f0f1ff;');
api.Visual.style('marks',  'background-color: rgba(0, 111, 204, 0.3); border-bottom: 1px solid #006FCC;');

// ========== Navigation ==========

// Unmap Omnibar-related default bindings to prevent accidental triggering
// Map 'o' to Local Focus Server (bypassing Content Script restrictions)
api.mapkey('o', 'Focus Address Bar', function () {
  fetch('http://localhost:18888/focus')
    .then(r => {
      if (!r.ok) api.Front.showBanner("Focus Error: " + r.statusText);
    })
    .catch(e => {
      api.Front.showBanner("Focus Failed: Is surfingkeys-server running?");
      console.error(e);
    });
});
api.mapkey('t', 'Open new tab (surfingkeys-accessible, auto-focus address bar)', function () {
  // Open blank.html served locally — Surfingkeys injects here (HTTP URL),
  // so 'd' works on the new tab. The page itself calls /focus to focus the address bar.
  api.RUNTIME('openLink', {tab: {tabbed: true, active: true}, url: 'http://localhost:18888/blank.html'});
});

api.unmap('b');
api.unmap('og'); // default open google
api.unmap('od'); // default open duckduckgo
api.unmap('oy'); // default open youtube
api.unmap('ow');
api.unmap('on');
api.unmap('ox');

// Large Scroll (Half Page)
api.mapkey('b', 'Scroll half page down', () => {
  api.Normal.scroll("pageDown");
});
api.mapkey('v', 'Scroll half page up', () => {
  api.Normal.scroll("pageUp");
});

// Tabs
// E = built-in "Go one tab left"  → RUNTIME("previousTab") — positional
// R = built-in "Go one tab right" → RUNTIME("nextTab")     — positional
api.unmap('e');       // free e from built-in scroll-half-page-up
api.map('e', 'R');    // e → next tab (positional right)
api.map('d', 'x');  // Close current tab (built-in x → RUNTIME("closeTab"))
api.mapkey('u', 'Restore closed tab', function() {
  api.RUNTIME('openLast');
});  // Restore tab
api.map('w', 'T');  // Tab list

// History
api.map('H', 'S');  // Back
api.map('L', 'D');  // Forward

// Open links
api.map('F', 'gf'); // Open link in new tab

// ========== Built-in bindings (no code needed, verified conflict-free) ==========
// Tab utilities:
//   <Ctrl-6>  — go to last used tab (MRU; differs from E→gT: uses goToLastTab)
//   gp        — jump to audible/playing tab
// URL navigation:
//   gu        — go up one path level (e.g. /a/b/c → /a/b; repeatable: 2gu)
// Scroll targeting:
//   cS        — reset scroll target (fix scroll stuck on sidebar/iframe)
//   cs        — cycle through scrollable elements (highlights current target)
// Scroll by ratio:
//   N%        — scroll to N% of page (50% → middle, 0% → top, 100% → bottom)

// Clipboard — yy (copy URL), yl (copy link) are built-in defaults

// Video speed
api.mapkey(']', 'Increase video speed', function () {
  const video = document.querySelector('video');
  if (video) {
    video.playbackRate += 0.25;
    api.Front.showBanner("Speed: " + video.playbackRate.toFixed(2) + "x");
  }
});
api.mapkey('[', 'Decrease video speed', function () {
  const video = document.querySelector('video');
  if (video) {
    video.playbackRate = Math.max(0.25, video.playbackRate - 0.25);
    api.Front.showBanner("Speed: " + video.playbackRate.toFixed(2) + "x");
  }
});
api.mapkey('\\', 'Reset video speed to 1x', function () {
  const video = document.querySelector('video');
  if (video) {
    video.playbackRate = 1;
    api.Front.showBanner("Speed: 1.00x");
  }
});

// ========== Quickmarks (Using Native Tab Open) ==========
// Since we disabled Omnibar, we just open these directly in new tabs or current tab
// but without passing through the Omnibar UI.

const quickmarks = {
  'A': { name: 'ArtStation', url: 'https://magazine.artstation.com/' },
  'E': { name: 'ProjectEuler', url: 'https://projecteuler.net/' },
  'L': { name: 'LibGen', url: 'https://libgen.li' },
  'c': { name: 'Twitch Cooller', url: 'https://twitch.tv/cooller' },
  'g': { name: 'Gmail', url: 'https://gmail.com' },
  'h': { name: 'SciHub', url: 'https://sci-hub.hkvisa.net/' },
  'k': { name: 'Reddit MechKeys', url: 'https://reddit.com/r/MechanicalKeyboards/' },
  'l': { name: 'LastFM', url: 'https://last.fm/user/e7z0x1' },
  's': { name: 'Steam Store', url: 'https://store.steampowered.com' },
  'u': { name: 'Reddit UnixPorn', url: 'https://reddit.com/r/unixporn' },
  'v': { name: 'VK', url: 'https://vk.com' },
  'y': { name: 'YouTube', url: 'https://youtube.com/' },
  'z': { name: 'Z-Lib', url: 'https://z-lib.is' }
};

Object.entries(quickmarks).forEach(([key, site]) => {
  // Open in current tab (go + key)
  api.mapkey('go' + key, 'Open ' + site.name, () => {
    window.location.href = site.url;
  });
  // Open in new tab (gn + key)
  api.mapkey('gn' + key, 'Open ' + site.name + ' in new tab', () => {
    api.tabOpenLink(site.url);
  });
});

// ========== Site-specific ==========

settings.blocklistPattern = /mail\.google\.com|docs\.google\.com|discord\.com|app\.slack\.com/i;

// ========== Clipboard Navigation ==========
// Open selected text or clipboard URL in new tab (uses extension Clipboard API internally)
api.map('p', 'cc');
// P restores to built-in: scroll full page down (fullPageDown)

// ========== Image Download ==========
api.mapkey('zi', 'Download image without dialog', function() {
    api.Hints.create('img', function(element) {
        var src = element.src;
        api.RUNTIME('download', {
            url: src,
            saveAs: false
        });
    });
});

// ========== Media Download ==========
function getMediaUrl(el) {
    // <img> — prefer srcset highest resolution, then src
    if (el.tagName === 'IMG') {
        if (el.srcset) {
            var best = el.srcset.split(',').map(function(s) {
                var parts = s.trim().split(/\s+/);
                var w = parseFloat(parts[1]) || 0;
                return { url: parts[0], w: w };
            }).sort(function(a, b) { return b.w - a.w; });
            if (best.length && best[0].url) return best[0].url;
        }
        return el.src || el.dataset.src || el.dataset.lazySrc || el.dataset.original;
    }
    // <picture> — grab the best <source> or fall back to inner <img>
    if (el.tagName === 'PICTURE') {
        var sources = el.querySelectorAll('source');
        if (sources.length) return sources[0].srcset.split(',')[0].trim().split(/\s+/)[0];
        var inner = el.querySelector('img');
        if (inner) return getMediaUrl(inner);
    }
    // <video> / <source>
    if (el.tagName === 'VIDEO') return el.src || (el.querySelector('source') || {}).src;
    if (el.tagName === 'SOURCE') return el.src;
    // <a> linking to media file
    if (el.tagName === 'A' && /\.(jpe?g|png|gif|webp|avif|svg|mp4|webm)(\?|$)/i.test(el.href)) {
        return el.href;
    }
    // <canvas>
    if (el.tagName === 'CANVAS') {
        try { return el.toDataURL('image/png'); } catch(e) { return null; }
    }
    // CSS background-image
    var bg = window.getComputedStyle(el).backgroundImage;
    if (bg && bg !== 'none') {
        var m = bg.match(/url\(["']?(.+?)["']?\)/);
        if (m) return m[1];
    }
    // Nested <img> inside clickable wrapper (div, a, figure, etc.)
    var nested = el.querySelector('img');
    if (nested) return getMediaUrl(nested);
    return null;
}

var mediaSelector = [
    'img',
    'picture',
    'video',
    'canvas',
    'a[href$=".jpg" i]', 'a[href$=".jpeg" i]', 'a[href$=".png" i]',
    'a[href$=".gif" i]', 'a[href$=".webp" i]', 'a[href$=".avif" i]',
    'a[href$=".svg" i]', 'a[href$=".mp4" i]',  'a[href$=".webm" i]',
    // Common wrappers that contain images
    'figure', 'div[style*="background-image"]',
    '[role="img"]'
].join(',');

api.mapkey(';i', 'Download media without dialog', function() {
    api.Hints.create(mediaSelector, function(element) {
        var url = getMediaUrl(element);
        if (url) {
            api.RUNTIME('download', { url: url, saveAs: false });
            api.Front.showBanner('Downloading: ' + url.substring(0, 80));
        } else {
            api.Front.showBanner('No media URL found for this element');
        }
    });
});

