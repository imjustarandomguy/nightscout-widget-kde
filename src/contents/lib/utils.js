// Configuration helpers. HTTP has moved to lib/api.js.

// Sentinel-default URL and token from the config dialog placeholders. A
// freshly-installed widget with these values is considered "not configured yet".
function isConfigDefault() {
    return nightscoutURL == "https://appname.herokuapp.com" || nightscoutToken == "plasmoid-0000000";
}

// Strip trailing occurrences of `charToTrim` from `s`. Used to normalize the
// Nightscout URL so we can append paths without producing "//".
function trimTrailingChars(s, charToTrim) {
    var regExp = new RegExp(charToTrim + "+$");
    return s.replace(regExp, "");
}
