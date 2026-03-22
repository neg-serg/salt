// In-memory caches with TTL
var _geoCache = {}; // key: cityLower -> { value: {lat, lon}, expiry: ts, errorUntil?: ts }
var _weatherCache = {}; // key: cityLower -> { value: weatherObject, expiry: ts, errorUntil?: ts }

function _now() { return Date.now(); }

function _buildUrl(base, paramsObj) {
    var qs = [];
    var obj = paramsObj || {};
    for (var key in obj) {
        if (!obj.hasOwnProperty(key)) continue;
        var val = obj[key];
        if (val === undefined || val === null) continue;
        qs.push(encodeURIComponent(key) + "=" + encodeURIComponent(String(val)));
    }
    return qs.length ? (base + "?" + qs.join("&")) : base;
}

function _readCache(store, key) {
    var entry = store[key];
    if (!entry) return null;
    var t = _now();
    if (entry.errorUntil && t < entry.errorUntil)
        return { error: true, retryAt: entry.errorUntil };
    if (entry.expiry && t < entry.expiry)
        return { value: entry.value };
    delete store[key];
    return null;
}

function _writeCacheSuccess(store, key, value, ttlMs) {
    store[key] = { value: value, expiry: _now() + ttlMs };
}

function _writeCacheError(store, key, errTtl) {
    store[key] = { errorUntil: _now() + errTtl };
}

// Inline XMLHttpRequest — Qt.include() was removed in Qt 6, so Http.js/HttpCache.js
// cannot be included from JS. This self-contained implementation avoids that dependency.
function _httpGetJson(url, timeoutMs, success, fail, userAgent) {
    try {
        var xhr = new XMLHttpRequest();
        xhr.open("GET", url, true);
        if (timeoutMs !== undefined && timeoutMs !== null) xhr.timeout = timeoutMs;
        try {
            if (xhr.setRequestHeader) {
                try { xhr.setRequestHeader('Accept', 'application/json'); } catch (e1) { /* header API unavailable */ }
                var ua = (userAgent === undefined || userAgent === null) ? 'Quickshell' : String(userAgent).trim();
                if (!ua) ua = 'Quickshell';
                try { xhr.setRequestHeader('User-Agent', ua); } catch (e2) { /* header API unavailable */ }
            }
        } catch (e) { /* ignore header setting failures */ }
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== XMLHttpRequest.DONE) return;
            if (xhr.status === 200) {
                try { success && success(JSON.parse(xhr.responseText)); }
                catch (pe) { fail && fail({ type: 'parse', message: 'Failed to parse JSON' }); }
            } else {
                var retryAfter = 0;
                try {
                    var ra = xhr.getResponseHeader && xhr.getResponseHeader('Retry-After');
                    if (ra) retryAfter = Number(ra) * 1000;
                } catch (he) { /* Retry-After header unavailable */ }
                fail && fail({ type: 'http', status: xhr.status, retryAfter: retryAfter });
            }
        };
        xhr.ontimeout = function() { fail && fail({ type: 'timeout' }); };
        xhr.onerror = function() { fail && fail({ type: 'network' }); };
        xhr.send();
    } catch (e) {
        fail && fail({ type: 'exception', message: String(e) });
    }
}


// Defaults (can be overridden via options argument)
var DEFAULTS = {
    geocodeTtlMs: 24 * 60 * 60 * 1000,   // 24h
    weatherTtlMs: 5 * 60 * 1000,         // 5m
    errorTtlMs: 2 * 60 * 1000,           // 2m backoff for 429/5xx
    timeoutMs: 8000                      // 8s timeout
};

function fetchCoordinates(city, callback, errorCallback, options) {
    options = options || {};
    var cfg = {
        geocodeTtlMs: options.geocodeTtlMs || DEFAULTS.geocodeTtlMs,
        errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
        timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs
    };
    var key = String(city || "").trim().toLowerCase();
    if (!key) {
        if (errorCallback) errorCallback("City is empty");
        return;
    }

    var cached = _readCache(_geoCache, key);
    if (cached) {
        if (cached.error) {
            errorCallback && errorCallback("Geocoding temporarily unavailable; retry later");
            return;
        }
        if (cached.value) {
            callback(cached.value.lat, cached.value.lon);
            return;
        }
    }

    // Open-Meteo geocoding API (free, no key required)
    var geoBase = (options && options.geocodingApiBaseUrl) ? String(options.geocodingApiBaseUrl) : "https://geocoding-api.open-meteo.com/v1";
    var geoUrl = _buildUrl(geoBase + "/search", {
        name: city,
        language: "en",
        format: "json",
        count: 1
    });

    // Use shared HTTP helper with User-Agent
    var _ua = (options && options.userAgent) ? String(options.userAgent) : "Quickshell";
    var dbg = !!(options && options.debug);
    _httpGetJson(geoUrl, cfg.timeoutMs, function(geoData) {
        try {
            if (geoData && geoData.results && geoData.results.length > 0) {
                var lat = geoData.results[0].latitude;
                var lon = geoData.results[0].longitude;
                _writeCacheSuccess(_geoCache, key, { lat: lat, lon: lon }, cfg.geocodeTtlMs);
                callback(lat, lon);
            } else {
                _writeCacheError(_geoCache, key, cfg.errorTtlMs);
                errorCallback && errorCallback("City not found");
            }
        } catch (e) {
            _writeCacheError(_geoCache, key, cfg.errorTtlMs);
            errorCallback && errorCallback("Failed to parse geocoding data");
        }
    }, function(err) {
        if (err) {
            var backoff = (err.retryAfter && err.retryAfter > 0) ? err.retryAfter : 0;
            if (!backoff && (err.status === 429 || (err.status >= 500 && err.status <= 599))) backoff = cfg.errorTtlMs;
            if (backoff) _writeCacheError(_geoCache, key, backoff);
        }
        errorCallback && errorCallback("Geocoding error: " + (err.status || err.type || "unknown"));
    }, _ua);
}

function fetchWeather(latitude, longitude, callback, errorCallback, options) {
    options = options || {};
    var cfg = {
        weatherTtlMs: options.weatherTtlMs || DEFAULTS.weatherTtlMs,
        errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
        timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs,
        cityKey: options.cityKey || null
    };

    var cacheKey = cfg.cityKey ? String(cfg.cityKey).toLowerCase() : null;
    if (cacheKey) {
        var cached = _readCache(_weatherCache, cacheKey);
        if (cached) {
            if (cached.error) {
                errorCallback && errorCallback("Weather temporarily unavailable; retry later");
                return;
            }
            if (cached.value) {
                callback(cached.value);
                return;
            }
        }
    }

    // Open-Meteo forecast API (free, no key required)
    var weatherBase = (options && options.weatherApiBaseUrl) ? String(options.weatherApiBaseUrl) : "https://api.open-meteo.com/v1";
    var url = _buildUrl(weatherBase + "/forecast", {
        latitude: String(latitude),
        longitude: String(longitude),
        current_weather: "true",
        current: "relative_humidity_2m,surface_pressure",
        daily: "temperature_2m_max,temperature_2m_min,weathercode",
        wind_speed_unit: "ms",
        timezone: "auto"
    });
    var _ua = (options && options.userAgent) ? String(options.userAgent) : "Quickshell";
    var dbg = !!(options && options.debug);
    _httpGetJson(url, cfg.timeoutMs, function(weatherData) {
        if (cacheKey) _writeCacheSuccess(_weatherCache, cacheKey, weatherData, cfg.weatherTtlMs);
        callback(weatherData);
    }, function(err) {
        if (cacheKey && err) {
            var backoff = (err.retryAfter && err.retryAfter > 0) ? err.retryAfter : 0;
            if (!backoff && (err.status === 429 || (err.status >= 500 && err.status <= 599))) backoff = cfg.errorTtlMs;
            if (backoff) _writeCacheError(_weatherCache, cacheKey, backoff);
        }
        errorCallback && errorCallback("Weather fetch error: " + (err.status || err.type || "unknown"));
    }, _ua);
}

function fetchCityWeather(city, callback, errorCallback, options) {
    options = options || {};
    var cityKey = String(city || "").trim();
    fetchCoordinates(cityKey, function(lat, lon) {
        fetchWeather(lat, lon, function(weatherData) {
            callback({
                city: cityKey,
                latitude: lat,
                longitude: lon,
                weather: weatherData
            });
        }, errorCallback, {
            weatherTtlMs: options.weatherTtlMs || DEFAULTS.weatherTtlMs,
            errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
            timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs,
            cityKey: cityKey,
            weatherApiBaseUrl: options.weatherApiBaseUrl
        });
    }, errorCallback, {
        geocodeTtlMs: options.geocodeTtlMs || DEFAULTS.geocodeTtlMs,
        errorTtlMs: options.errorTtlMs || DEFAULTS.errorTtlMs,
        timeoutMs: options.timeoutMs || DEFAULTS.timeoutMs,
        geocodingApiBaseUrl: options.geocodingApiBaseUrl
    });
} 
