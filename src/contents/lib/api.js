// Nightscout API client. Centralizes HTTP and endpoint construction so the
// QML controllers stay declarative and URL strings cannot drift.

// Build a callback envelope that mimics the legacy {status, content} shape
// but adds an `error` field so callers can distinguish network failures from
// HTTP errors and parse failures.
function envelope(request, fallbackContent) {
    var content = null;
    var error = null;
    try {
        if (request.responseText) content = JSON.parse(request.responseText);
    } catch (e) {
        error = "parse: " + e.message;
    }
    if (!error && request.status >= 400) {
        error = "HTTP " + request.status;
    }
    return {
        status: request.status,
        content: content === null ? fallbackContent : content,
        error: error
    };
}

// Internal: perform an XHR with a timeout. The callback always fires exactly
// once with an envelope.
function xhr(method, url, body, headers, timeoutMs, callback) {
    var request = new XMLHttpRequest();
    var done = false;

    request.onreadystatechange = function () {
        if (request.readyState === XMLHttpRequest.DONE && !done) {
            done = true;
            callback(envelope(request, null));
        }
    };

    try {
        request.open(method, url);
        request.timeout = timeoutMs;
        if (headers) {
            Object.keys(headers).forEach(function (k) {
                request.setRequestHeader(k, headers[k]);
            });
        }
        request.send(body);
    } catch (e) {
        if (!done) {
            done = true;
            callback({ status: 0, content: null, error: "network: " + e.message });
        }
    }

    request.onerror = function () {
        if (!done) {
            done = true;
            callback({ status: 0, content: null, error: "network error" });
        }
    };

    request.ontimeout = function () {
        if (!done) {
            done = true;
            callback({ status: 0, content: null, error: "timeout" });
        }
    };
}

// GET <url>, callback(envelope). Default timeout from constants.
function request(url, callback, timeoutMs) {
    xhr("GET", url, null, null, timeoutMs || 15000, callback);
}

// POST <url> with JSON body, callback(envelope).
function post(url, body, callback, timeoutMs) {
    var bodyStr = JSON.stringify(body);
    var headers = { "Content-Type": "application/json" };
    xhr("POST", url, bodyStr, headers, timeoutMs || 15000, callback);
}

// --- Endpoint builders ------------------------------------------------------

function pebbleUrl(base, token) {
    var query = token ? "?token=" + encodeURIComponent(token) : "";
    return base + "/pebble/" + query;
}

function entriesUrl(base, token, sinceMs, count) {
    var url = base + "/api/v1/entries.json?find%5Bdate%5D%5B%24gte%5D=" + sinceMs
        + "&count=" + count;
    if (token) url += "&token=" + encodeURIComponent(token);
    return url;
}

function treatmentsUrl(base, token, sinceMs) {
    var iso = new Date(sinceMs).toISOString();
    var url = base + "/api/v1/treatments.json?find%5Bcreated_at%5D%5B%24gte%5D="
        + encodeURIComponent(iso);
    if (token) url += "&token=" + encodeURIComponent(token);
    return url;
}

function postTreatmentUrl(base, token) {
    var query = token ? "?token=" + encodeURIComponent(token) : "";
    return base + "/api/v1/treatments/" + query;
}

// DELETE <url>, callback(envelope).
function del(url, token, callback, timeoutMs) {
    var headers = {};
    if (token) {
        headers["api-secret"] = token;
    }
    xhr("DELETE", url, null, headers, timeoutMs || 15000, callback);
}

function deleteTreatmentUrl(base, token, id) {
    var query = token ? "?token=" + encodeURIComponent(token) : "";
    return base + "/api/v1/treatments/" + encodeURIComponent(id) + query;
}
