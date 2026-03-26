user_pref("accessibility.typeaheadfind.flashBar", 0);
user_pref("browser.bookmarks.addedImportButton", false);
user_pref("browser.bookmarks.restore_default_bookmarks", false);
user_pref("browser.download.dir", "{{ home }}/dw");
user_pref("extensions.webextensions.restrictedDomains", "");
user_pref("general.warnOnAboutConfig", false);
user_pref("gfx.color_management.enabled", true);
user_pref("gfx.color_management.enablev4", true);
user_pref("gfx.color_management.mode", 1);
user_pref("extensions.autoDisableScopes", 0);
user_pref("xpinstall.signatures.required", false);
user_pref("toolkit.legacyUserProfileCustomizations.stylesheets", true);
user_pref("svg.context-properties.content.enabled", true);
user_pref("widget.non-native-theme.use-theme-accent", true);

/****************************************************************************************
 * Fastfox                                                                              *
 * "Non ducor duco"                                                                     *
 * priority: speedy browsing                                                            *
 * version: 118                                                                         *
 * url: https://github.com/yokoffing/Betterfox                                          *
 ***************************************************************************************/

// PREF: initial paint delay
user_pref("nglayout.initialpaint.delay", 0); // default=5
user_pref("nglayout.initialpaint.delay_in_oopif", 0); // default=5

// PREF: page reflow timer
user_pref("content.notify.interval", 100000); // (.10s); default=120000 (.12s)

/****************************************************************************
 * SECTION: EXPERIMENTAL                                                    *
 ****************************************************************************/

user_pref("layout.css.grid-template-masonry-value.enabled", true);
user_pref("dom.enable_web_task_scheduling", true);
user_pref("layout.css.has-selector.enabled", true);
user_pref("dom.security.sanitizer.enabled", true);

/****************************************************************************
 * SECTION: GFX RENDERING TWEAKS                                            *
 ****************************************************************************/

user_pref("gfx.canvas.accelerated.cache-items", 4096); // default=2048
user_pref("gfx.canvas.accelerated.cache-size", 512); // default=256
user_pref("gfx.content.skia-font-cache-size", 20); // default=5; Chrome=20

/****************************************************************************
 * SECTION: BROWSER CACHE                                                   *
 ****************************************************************************/

user_pref("browser.cache.disk.enable", false);

/****************************************************************************
 * SECTION: MEDIA CACHE                                                     *
 ****************************************************************************/

user_pref("media.memory_cache_max_size", 65536); // default=8192
user_pref("media.cache_readahead_limit", 7200); // 120 min; default=60
user_pref("media.cache_resume_threshold", 3600); // 60 min; default=30

/****************************************************************************
 * SECTION: IMAGE CACHE                                                     *
 ****************************************************************************/

user_pref("image.mem.decode_bytes_at_a_time", 32768); // default=16384

/****************************************************************************
 * SECTION: NETWORK                                                         *
 ****************************************************************************/

user_pref("network.buffer.cache.size", 262144); // 256 kb; default=32768
user_pref("network.buffer.cache.count", 128); // default=24
user_pref("network.http.max-connections", 1800); // default=900
user_pref("network.http.max-persistent-connections-per-server", 10); // default=6
user_pref("network.http.max-urgent-start-excessive-connections-per-host", 5); // default=3
user_pref("network.http.pacing.requests.enabled", false);
user_pref("network.dnsCacheEntries", 1000); // default=400
user_pref("network.dnsCacheExpiration", 86400); // 1 day; default=60
user_pref("network.dns.max_high_priority_threads", 8); // default=5
user_pref("network.ssl_tokens_cache_capacity", 10240); // default=2048

/****************************************************************************
 * SECTION: SPECULATIVE CONNECTIONS                                         *
 ****************************************************************************/

user_pref("network.http.speculative-parallel-limit", 0);
user_pref("network.dns.disablePrefetch", true);
user_pref("browser.urlbar.speculativeConnect.enabled", false);
user_pref("browser.places.speculativeConnect.enabled", false);
user_pref("network.prefetch-next", false);
user_pref("network.predictor.enabled", false);
user_pref("network.predictor.enable-prefetch", false);

/****************************************************************************
 * SECTION: ZEN THEME                                                       *
 ****************************************************************************/

user_pref("theme.supergradient.preset", "AmethystClaret");
user_pref("theme.supergradient.intensity", "Normal");
user_pref("uc.supergradient.desaturate", false);
user_pref("uc.supergradient.use-accent-color", false);
user_pref("uc.supergradient.switch-colors", false);
