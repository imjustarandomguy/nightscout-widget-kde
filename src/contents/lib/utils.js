function sendJsonRequest(url, callback) {
    let request = new XMLHttpRequest();

    request.onreadystatechange = function () {
        if (request.readyState === XMLHttpRequest.DONE) {
            var content = null;
            try {
                if (request.responseText) content = JSON.parse(request.responseText);
            } catch(e) {}
            callback({ status: request.status, content: content });
        }
    }

    request.open("GET", url);
    request.send();
}

function sendJsonPost(url, body, callback) {
    let request = new XMLHttpRequest();

    request.onreadystatechange = function () {
        if (request.readyState === XMLHttpRequest.DONE) {
            var content = null;
            try {
                if (request.responseText) content = JSON.parse(request.responseText);
            } catch(e) {}
            callback({ status: request.status, content: content });
        }
    }

    request.open("POST", url);
    request.setRequestHeader("Content-Type", "application/json");
    request.send(JSON.stringify(body));
}

function padTo2Digits(num) {
    return String(num).padStart(2, '0');
}

function isConfigDefault() {
    return nightscoutURL == "https://appname.herokuapp.com" || nightscoutToken == "plasmoid-0000000";
}

function trimTrailingChars(s, charToTrim) {
  var regExp = new RegExp(charToTrim + "+$");
  var result = s.replace(regExp, "");

  return result;
}
