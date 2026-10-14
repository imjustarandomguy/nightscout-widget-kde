// Configuration helpers. HTTP has moved to lib/api.js.

// Sentinel-default URL and token from the config dialog placeholders. A
// freshly-installed widget with these values is considered "not configured yet".
function isConfigDefault(url, token) {
    var checkUrl = (url !== undefined) ? url : (typeof nightscoutURL !== "undefined" ? nightscoutURL : "");
    var checkToken = (token !== undefined) ? token : (typeof nightscoutToken !== "undefined" ? nightscoutToken : "");
    return !checkUrl || checkUrl === "https://appname.herokuapp.com" || checkToken === "plasmoid-0000000";
}

// Strip trailing occurrences of `charToTrim` from `s`. Used to normalize the
// Nightscout URL so we can append paths without producing "//".
function trimTrailingChars(s, charToTrim) {
    if (!s) return "";
    var regExp = new RegExp(charToTrim + "+$");
    return s.replace(regExp, "");
}
