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

// ========== Site Blocklist ==========

settings.blocklistPattern = /mail\.google\.com|docs\.google\.com|discord\.com|app\.slack\.com/i;

// ========== Site-Specific Mappings ==========
// Adapted from https://github.com/b0o/surfingkeys-conf
// Domain-scoped blocks MUST come after global mappings so they can override (e.g. ;i)
// ========== Site-Specific Helpers ==========
// Adapted from https://github.com/b0o/surfingkeys-conf

const _hostname = window.location.hostname;

function _isInViewport(el) {
  const r = el.getBoundingClientRect();
  return r.top >= 0 && r.left >= 0
    && r.bottom <= (window.innerHeight || document.documentElement.clientHeight)
    && r.right <= (window.innerWidth || document.documentElement.clientWidth);
}

// ========== Global Utilities ==========

api.mapkey('yM', 'Copy page as Markdown link', () => {
  api.Clipboard.write(`[${document.title}](${window.location.href})`);
  api.Front.showBanner('Copied Markdown link');
});

api.mapkey('yI', 'Copy image URL', () => {
  api.Hints.create('img', (el) => {
    api.Clipboard.write(el.src);
    api.Front.showBanner('Copied: ' + el.src.substring(0, 60));
  });
});

api.mapkey('g.', 'Go to parent domain', () => {
  const parts = window.location.host.split('.');
  const parent = (parts.length > 2 ? parts.slice(1) : parts).join('.');
  window.location.href = window.location.protocol + '//' + parent;
});

api.mapkey('=a', 'View on Wayback Machine', () => {
  api.RUNTIME('openLink', {
    tab: { tabbed: true, active: true },
    url: 'https://web.archive.org/web/*/' + window.location.href,
  });
});

api.mapkey('=d', 'View DNS info for domain', () => {
  api.RUNTIME('openLink', {
    tab: { tabbed: true, active: true },
    url: 'http://centralops.net/co/DomainDossier.aspx?dom_dns=true&addr=' + _hostname,
  });
});

api.mapkey('=s', 'View social discussions for page', () => {
  api.RUNTIME('openLink', {
    tab: { tabbed: true, active: true },
    url: 'https://discu.eu/?q=' + encodeURIComponent(window.location.href),
  });
});

api.mapkey('ye', 'Copy last URL path segment', () => {
  const seg = window.location.pathname.split('/').filter(s => s).pop() || '';
  api.Clipboard.write(decodeURIComponent(seg));
  api.Front.showBanner('Copied: ' + decodeURIComponent(seg));
});

api.mapkey('yu', 'Copy URL without query/hash', () => {
  const clean = window.location.origin + window.location.pathname;
  api.Clipboard.write(clean);
  api.Front.showBanner('Copied: ' + clean.substring(0, 60));
});

api.mapkey('yT', 'Duplicate tab (background)', () => {
  api.RUNTIME('openLink', {
    tab: { tabbed: true, active: false },
    url: window.location.href,
  });
});

api.map('gxE', 'gxt');  // Close tab to left
api.map('gxR', 'gxT');  // Close tab to right

// ========== GitHub ==========

if (/github\.com$/.test(_hostname)) {
  const _ghRepo = () => {
    const p = window.location.pathname.split('/').filter(s => s);
    return p.length >= 2 ? { user: p[0], repo: p[1], base: '/' + p[0] + '/' + p[1] } : null;
  };
  const _ghPage = (path) => { const r = _ghRepo(); if (r) window.location.href = r.base + path; };

  // Repo navigation
  api.mapkey(';A', 'GitHub: Actions',       () => _ghPage('/actions'));
  api.mapkey(';C', 'GitHub: Commits',       () => _ghPage('/commits'));
  api.mapkey(';I', 'GitHub: Issues',        () => _ghPage('/issues'));
  api.mapkey(';N', 'GitHub: Notifications', () => { window.location.href = '/notifications'; });
  api.mapkey(';P', 'GitHub: Pull Requests', () => _ghPage('/pulls'));
  api.mapkey(';R', 'GitHub: Repo root',     () => _ghPage('/'));
  api.mapkey(';S', 'GitHub: Settings',      () => _ghPage('/settings'));
  api.mapkey(';W', 'GitHub: Wiki',          () => _ghPage('/wiki'));

  // Link hints — filtered by type
  api.mapkey(';a', 'GitHub: View repo', () => {
    const links = [...document.querySelectorAll('a[href]')].filter(a =>
      a.hostname === 'github.com' && /^\/[^/]+\/[^/]+\/?$/.test(a.pathname));
    if (links.length) api.Hints.create(links);
  });
  api.mapkey(';f', 'GitHub: View file',   () => api.Hints.create('a[href*="/blob/"], a[href*="/tree/"]'));
  api.mapkey(';i', 'GitHub: View issue',  () => api.Hints.create('a[href*="/issues/"]'));
  api.mapkey(';p', 'GitHub: View PR',     () => api.Hints.create('a[href*="/pull/"]'));
  api.mapkey(';c', 'GitHub: View commit', () => api.Hints.create('a[href*="/commit/"]'));
  api.mapkey(';e', 'GitHub: External link', () => api.Hints.create('a[rel=nofollow]'));

  // Actions
  api.mapkey(';s', 'GitHub: Toggle star', () => {
    const containers = [...document.querySelectorAll('div.starring-container')]
      .filter(e => window.getComputedStyle(e).display !== 'none');
    if (!containers.length) return;
    const c = containers[0];
    const starred = c.classList.contains('on');
    const btn = c.querySelector(starred
      ? '.starred button, button.starred'
      : '.unstarred button, button.unstarred');
    if (btn) btn.click();
    api.Front.showBanner(starred ? '☆ Unstarred' : '★ Starred');
  });

  api.mapkey(';y', 'GitHub: Copy project path', () => {
    const r = _ghRepo();
    if (r) {
      api.Clipboard.write(r.user + '/' + r.repo);
      api.Front.showBanner('Copied: ' + r.user + '/' + r.repo);
    }
  });

  api.mapkey(';l', 'GitHub: Toggle language stats', () => {
    const el = document.querySelector('.repository-lang-stats-graph');
    if (el) el.click();
  });

  // Smart go-parent (overrides default gu on GitHub)
  api.mapkey('gu', 'GitHub: Go up one path', () => {
    const parts = window.location.pathname.split('/').filter(s => s);
    if (parts.length <= 1) return;
    if (parts.length === 4 && (parts[2] === 'blob' || parts[2] === 'tree')) {
      window.location.href = '/' + parts[0] + '/' + parts[1];
    } else if (parts.length === 4 && parts[2] === 'pull') {
      window.location.href = '/' + parts[0] + '/' + parts[1] + '/pulls';
    } else {
      window.location.href = '/' + parts.slice(0, -1).join('/');
    }
  });
}

// ========== raw.githubusercontent.com ==========

if (_hostname === 'raw.githubusercontent.com') {
  api.mapkey(';R', 'Raw: Open repo page', () => {
    const p = window.location.pathname.split('/').filter(s => s);
    if (p.length >= 2) {
      api.RUNTIME('openLink', {
        tab: { tabbed: true, active: true },
        url: 'https://github.com/' + p[0] + '/' + p[1],
      });
    }
  });
  api.mapkey(';F', 'Raw: Open source file on GitHub', () => {
    const p = window.location.pathname.split('/');
    const parts = p.filter(s => s);
    if (parts.length >= 3) {
      const url = 'https://github.com/' + [parts[0], parts[1], 'tree', ...parts.slice(2)].join('/');
      api.RUNTIME('openLink', { tab: { tabbed: true, active: true }, url });
    }
  });
}

// ========== GitHub Pages (*.github.io) ==========

if (/\.github\.io$/.test(_hostname)) {
  api.mapkey(';R', 'GH Pages: Open repo on GitHub', () => {
    const user = _hostname.split('.')[0];
    const repo = window.location.pathname.split('/')[1] || '';
    api.RUNTIME('openLink', {
      tab: { tabbed: true, active: true },
      url: 'https://github.com/' + user + '/' + repo,
    });
  });
}

// ========== YouTube ==========

if (/youtube\.com$/.test(_hostname)) {
  api.mapkey(';A', 'YouTube: Open video (new tab)', () => {
    api.Hints.create('*[id="video-title"]', (el) => {
      const a = el.closest('a') || el;
      api.RUNTIME('openLink', { tab: { tabbed: true, active: true }, url: a.href });
    });
  });

  api.mapkey(';C', 'YouTube: Open channel', () => {
    api.Hints.create('*[id="byline"]');
  });

  api.mapkey(';H', 'YouTube: Subscriptions feed', () => {
    window.location.href = 'https://www.youtube.com/feed/subscriptions';
  });

  const _ytTimestampLink = () => {
    const el = document.querySelector('#ytd-player .ytp-time-current');
    if (!el) return null;
    const [ss, mm, hh = 0] = el.innerText.split(':').reverse().map(Number);
    const secs = (hh * 3600) + (mm * 60) + ss;
    const v = new URLSearchParams(window.location.search).get('v');
    return v ? 'https://youtu.be/' + v + '?t=' + secs : null;
  };

  api.mapkey(';t', 'YouTube: Copy timestamp link', () => {
    const link = _ytTimestampLink();
    if (link) {
      api.Clipboard.write(link);
      api.Front.showBanner('Copied: ' + link);
    } else {
      api.Front.showBanner('No video playing');
    }
  });

  api.mapkey(';m', 'YouTube: Copy timestamp markdown link', () => {
    const link = _ytTimestampLink();
    if (link) {
      const md = '[' + document.title + '](' + link + ')';
      api.Clipboard.write(md);
      api.Front.showBanner('Copied markdown link');
    } else {
      api.Front.showBanner('No video playing');
    }
  });
}

// ========== Reddit (old.reddit.com) ==========

if (/reddit\.com$/.test(_hostname)) {
  api.mapkey(';x', 'Reddit: Collapse comment (hints)', () => {
    api.Hints.create('.expand');
  });

  api.mapkey(';X', 'Reddit: Collapse next visible comment', () => {
    const comments = [...document.querySelectorAll('.noncollapsed.comment')]
      .filter(_isInViewport);
    if (comments.length) comments[0].querySelector('.expand').click();
  });

  api.mapkey(';s', 'Reddit: Upvote', () => api.Hints.create('.arrow.up'));
  api.mapkey(';S', 'Reddit: Downvote', () => api.Hints.create('.arrow.down'));
  api.mapkey(';e', 'Reddit: Expand', () => api.Hints.create('.expando-button'));

  api.mapkey(';a', 'Reddit: Open post', () => api.Hints.create('.title'));
  api.mapkey(';A', 'Reddit: Open post (new tab)', () => {
    api.Hints.create('.title', (el) => {
      const a = el.closest('a') || el;
      api.RUNTIME('openLink', { tab: { tabbed: true, active: false }, url: a.href });
    });
  });
  api.mapkey(';c', 'Reddit: Open comments', () => api.Hints.create('.comments'));
}

// ========== Hacker News ==========

if (/news\.ycombinator\.com$/.test(_hostname)) {
  api.mapkey(';x', 'HN: Collapse comment (hints)', () => api.Hints.create('.togg'));

  api.mapkey(';X', 'HN: Collapse next visible comment', () => {
    const toggles = [...document.querySelectorAll('a.togg')]
      .filter(e => e.innerText === '[–]' && _isInViewport(e));
    if (toggles.length) toggles[0].click();
  });

  api.mapkey(';s', 'HN: Upvote', () => api.Hints.create(".votearrow[title='upvote']"));

  api.mapkey(';a', 'HN: Open post link', () => api.Hints.create('.titleline>a'));
  api.mapkey(';A', 'HN: Open link + comments', () => {
    api.Hints.create('.athing', (el) => {
      const linkUrl = el.querySelector('.titleline>a').href;
      const commEl = el.nextElementSibling.querySelector("a[href^='item']:not(.titlelink)");
      if (commEl) api.RUNTIME('openLink', { tab: { tabbed: true, active: false }, url: commEl.href });
      api.RUNTIME('openLink', { tab: { tabbed: true, active: true }, url: linkUrl });
    });
  });
  api.mapkey(';c', 'HN: Open comments', () => api.Hints.create(".subline>a[href^='item']"));

  api.mapkey('gp', 'HN: Go to parent', () => {
    const par = document.querySelector(".navs>a[href^='item']");
    if (par) window.location.href = par.href;
  });

  api.mapkey(']]', 'HN: Next page', () => {
    const u = new URL(window.location.href);
    const page = parseInt(u.searchParams.get('p') || '1', 10);
    if (!isNaN(page)) { u.searchParams.set('p', page + 1); window.location.href = u.href; }
  });
  api.mapkey('[[', 'HN: Previous page', () => {
    const u = new URL(window.location.href);
    const page = parseInt(u.searchParams.get('p') || '1', 10);
    if (!isNaN(page) && page > 1) { u.searchParams.set('p', page - 1); window.location.href = u.href; }
  });
}

// ========== Google Search ==========

if (/google\.com$/.test(_hostname)) {
  const _gResultSel = ['a h3', 'h3 a', '.isv-r > a:first-child', '.WlydOe'].join(',');

  api.mapkey(';a', 'Google: Open search result', () => api.Hints.create(_gResultSel));
  api.mapkey(';A', 'Google: Open result (new tab)', () => {
    api.Hints.create(_gResultSel, (el) => {
      const a = el.closest('a') || el;
      api.RUNTIME('openLink', { tab: { tabbed: true, active: false }, url: a.href });
    });
  });

  api.mapkey(';d', 'Google: Same search in DuckDuckGo', () => {
    const u = new URL(window.location.href);
    const q = u.searchParams.get('q');
    if (!q) return;
    const ddg = new URL('https://duckduckgo.com');
    ddg.searchParams.set('q', q);
    const tbm = u.searchParams.get('tbm');
    if (tbm === 'isch') { ddg.searchParams.set('ia', 'images'); ddg.searchParams.set('iax', 'images'); }
    else if (tbm === 'vid') { ddg.searchParams.set('ia', 'videos'); ddg.searchParams.set('iax', 'videos'); }
    else if (tbm === 'nws') { ddg.searchParams.set('ia', 'news'); ddg.searchParams.set('iar', 'news'); }
    else { ddg.searchParams.set('ia', 'web'); }
    window.location.href = ddg.href;
  });
}

// ========== DuckDuckGo ==========

if (/duckduckgo\.com$/.test(_hostname)) {
  const _ddgSel = [
    "a[rel=noopener][target=_self]:not([data-testid=result-extras-url-link])",
    ".js-images-show-more",
    ".module--images__thumbnails__link",
  ].join(',');

  api.mapkey(';a', 'DDG: Open search result', () => api.Hints.create(_ddgSel));
  api.mapkey(';A', 'DDG: Open result (new tab)', () => {
    api.Hints.create(_ddgSel, (el) => {
      const a = el.closest('a') || el;
      api.RUNTIME('openLink', { tab: { tabbed: true, active: false }, url: a.href });
    });
  });

  api.mapkey(']]', 'DDG: Show more results', () => {
    const btn = document.querySelector('.result--more__btn');
    if (btn) btn.click();
  });

  api.mapkey(';g', 'DDG: Same search in Google', () => {
    const u = new URL(window.location.href);
    const q = u.searchParams.get('q');
    if (!q) return;
    const goog = new URL('https://google.com/search');
    goog.searchParams.set('q', q);
    const iax = u.searchParams.get('iax');
    const iar = u.searchParams.get('iar');
    const iaxm = u.searchParams.get('iaxm');
    if (iax === 'images') goog.searchParams.set('tbm', 'isch');
    else if (iax === 'videos') goog.searchParams.set('tbm', 'vid');
    else if (iar === 'news') goog.searchParams.set('tbm', 'nws');
    else if (iaxm === 'maps') goog.pathname = '/maps';
    window.location.href = goog.href;
  });

  // Site-scoped search toggles
  api.mapkey(';sgh', 'DDG: Toggle site:github.com', () => {
    const u = new URL(window.location.href);
    const q = u.searchParams.get('q') || '';
    const site = 'site:github.com';
    u.searchParams.set('q', q.includes(site) ? q.replace(site, '').trim() : q + ' ' + site);
    window.location.href = u.href;
  });
  api.mapkey(';sre', 'DDG: Toggle site:reddit.com', () => {
    const u = new URL(window.location.href);
    const q = u.searchParams.get('q') || '';
    const site = 'site:reddit.com';
    u.searchParams.set('q', q.includes(site) ? q.replace(site, '').trim() : q + ' ' + site);
    window.location.href = u.href;
  });
}

// ========== Wikipedia / ArchWiki ==========

if (/wikipedia\.org$|wiktionary\.org$|wikimedia\.org$|wiki\.archlinux\.org$/.test(_hostname)) {
  api.mapkey(';s', 'Wiki: Toggle simple/standard version', () => {
    const u = new URL(window.location.href);
    const parts = u.hostname.split('.');
    if (parts[0] === 'simple') parts.shift();
    else parts.unshift('simple');
    u.hostname = parts.join('.');
    window.location.href = u.href;
  });

  api.mapkey(';a', 'Wiki: Article link (hints)', () => {
    api.Hints.create('#bodyContent :not(sup):not(.mw-editsection) > a:not([rel=nofollow])');
  });
  api.mapkey(';e', 'Wiki: External link (hints)', () => api.Hints.create('a[rel=nofollow]'));

  api.mapkey(';y', 'Wiki: Copy summary as Markdown', () => {
    const el = document.querySelector('#mw-content-text p:not([class]):not([id])');
    if (!el) { api.Front.showBanner('No summary found'); return; }
    const clone = el.cloneNode(true);
    clone.querySelectorAll('sup').forEach(e => e.remove());
    clone.querySelectorAll('b').forEach(e => { e.innerText = '**' + e.innerText + '**'; });
    clone.querySelectorAll('i').forEach(e => { e.innerText = '_' + e.innerText + '_'; });
    const md = '> ' + clone.innerText.trim() + '\n\n\u2014 [' + document.title + '](' + window.location.href + ')';
    api.Clipboard.write(md);
    api.Front.showBanner('Summary copied as Markdown');
  });

  api.mapkey(';R', 'Wiki: View WikiRank', () => {
    const h = _hostname.split('.');
    const lang = h.length > 2 && h[0] !== 'www' ? h[0] : 'en';
    const p = window.location.pathname.split('/');
    if (p.length < 3 || p[1] !== 'wiki') return;
    api.RUNTIME('openLink', {
      tab: { tabbed: true, active: true },
      url: 'https://wikirank.net/' + lang + '/' + p.slice(2).join('/'),
    });
  });
}

// ========== StackOverflow / StackExchange ==========

if (/stackoverflow\.com$|stackexchange\.com$|serverfault\.com$|superuser\.com$|askubuntu\.com$/.test(_hostname)) {
  api.mapkey(';a', 'SO: View question', () => {
    api.Hints.create('a.question-hyperlink, a.s-link');
  });
}

// ========== AUR ==========

if (/aur\.archlinux\.org$/.test(_hostname)) {
  api.mapkey(';a', 'AUR: View package', () => {
    api.Hints.create("a[href^='/packages/'][href$='/']");
  });
}


