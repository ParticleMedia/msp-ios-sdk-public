function captureHttpRequest(source, url) {
    window.webkit.messageHandlers.mfusesdk.postMessage("logHTTPRequest:" + encodeURIComponent(url) + "&source=" + encodeURIComponent(source));
}

replaceAttributeWithCapture(HTMLImageElement.prototype, "src");
replaceAttributeWithCapture(HTMLIFrameElement.prototype, "src");
replaceAttributeWithCapture(HTMLScriptElement.prototype, "src");

function replaceAttributeWithCapture(proto, attribute) {
    const desc = Object.getOwnPropertyDescriptor(proto, attribute);
    const originalSet = desc.set;
    desc.set = function(url) {
        // Call the original setter:
        originalSet.call(this, url);

        // Capture this HTTP request:
        captureHttpRequest(this.tagName.toLowerCase(), url);
        this.dataset.mfCaptured = "1";
    };

    Object.defineProperty(proto, attribute, desc);
}

function checkDomForHttpTags() {
    checkTagAttributes(document.getElementsByTagName("img"), "src");
    checkTagAttributes(document.getElementsByTagName("iframe"), "src");
    checkTagAttributes(document.getElementsByTagName("script"), "src");
    checkTagAttributes(document.getElementsByTagName("link"), "href");
}

function checkTagAttributes(tags, attribute) {
    for (let i = 0; i < tags.length; i++) {
        if (tags[i].dataset.mfCaptured) continue;
        tags[i].dataset.mfCaptured = "1";
        let url = tags[i][attribute];
        if (!url) continue;
        captureHttpRequest(tags[i].tagName.toLowerCase(), url);
    }
}

// Hook into document.write - so we re-check the DOM when the document changes:
const originalDocumentWrite = document.write;
document.write = function(data){
    originalDocumentWrite.apply(this, arguments);
    checkDomForHttpTags();
}

// XMLHttpRequest:
const origOpen = XMLHttpRequest.prototype.open;
XMLHttpRequest.prototype.open = function(method, url){
    captureHttpRequest("XMLHttpRequest", url);
    return origOpen.apply(this, arguments);
}
