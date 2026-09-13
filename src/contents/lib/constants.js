// Centralized timing/window constants for the Nightscout widget.

// Nightscout publishes a new SGV every 5 minutes.
var POLL_PERIOD_MS = 300000;

// Smart-poll lower bound: never retry faster than this after a successful poll.
var MIN_POLL_DELAY_MS = 30000;

// Fixed retry delay after an error (HTTP error, network error, parse error).
var RETRY_DELAY_MS = 30000;

// XHR timeout for all API requests.
var REQUEST_TIMEOUT_MS = 15000;

// How much chart history to fetch (3 hours).
var CHART_HISTORY_MS = 3 * 60 * 60 * 1000;

// Max number of entries to retrieve for the chart.
var CHART_ENTRY_COUNT = 100;

// Show a time label on the X axis every N-th entry; the rest are blank.
var LABEL_EVERY_N = 6;

// A reading is "stale" once it is older than POLL_PERIOD_MS + pollPadding.
function staleAfterMs(pollPaddingSeconds) {
    return POLL_PERIOD_MS + pollPaddingSeconds * 1000;
}
