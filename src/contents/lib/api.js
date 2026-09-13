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
    return {
        status: request.status,
        content: content === null ? fallbackContent : content,
        error: error
    };
}

// Internal: perform an XHR with a timeout. The callback always fires exactly
// once with an envelope. `okReadyState` is XMLHttpRequest.DONE at the time the
// request finishes or aborts.
function xhr(method, url, body, headers, timeoutMs, callback) {
    var request = new XMLHttpRequest();
    var done = false;

    function finish() {
        if (done) return;
        done = true;
        request.abort();
        callback(envelope(request, null));
    }

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
    return base + "/pebble/?token=" + token;
}

function entriesUrl(base, token, sinceMs, count) {
    return base + "/api/v1/entries.json?find[date][$gte]=" + sinceMs
        + "&count=" + count + "&token=" + token;
}

function treatmentsUrl(base, token, sinceMs) {
    return base + "/api/v1/treatments.json?find[created_at][$gte]="
        + new Date(sinceMs).toISOString() + "&token=" + token;
}

function postTreatmentUrl(base, token) {
    return base + "/api/v1/treatments/?token=" + token;
}
