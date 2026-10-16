// Centralized timing/window constants for the Nightscout widget.

// Nightscout publishes a new SGV every 5 minutes.
var POLL_PERIOD_MS = 300000;

// Smart-poll lower bound: never retry faster than this after a successful poll.
var MIN_POLL_DELAY_MS = 30000;

// Fixed retry delay after an error (HTTP error, network error, parse error).
var RETRY_DELAY_MS = 30000;

// A reading is "stale" once it is older than POLL_PERIOD_MS + pollPadding.
function staleAfterMs(pollPaddingSeconds) {
    return POLL_PERIOD_MS + pollPaddingSeconds * 1000;
}
