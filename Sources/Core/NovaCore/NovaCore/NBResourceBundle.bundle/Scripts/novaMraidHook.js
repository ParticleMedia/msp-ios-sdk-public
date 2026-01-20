(function() {
    try {
        function notifyMraidRequested(src) {
            try {
                if (
                    window.webkit &&
                    window.webkit.messageHandlers &&
                    window.webkit.messageHandlers.mraidBridge
                ) {
                    window.webkit.messageHandlers.mraidBridge.postMessage(
                        JSON.stringify({
                            action: 'mraidRequested',
                            params: { src: src || '' },
                        })
                    );
                }
            } catch (e) {
                // Swallow errors to avoid breaking creatives
            }
        }

        function hookScriptElement(el) {
            if (!el || el.__novaMraidHooked) {
                return;
            }
            el.__novaMraidHooked = true;

            var originalSetAttribute = el.setAttribute;
            el.setAttribute = function(name, value) {
                if (name && name.toLowerCase() === 'src') {
                    if (value && value.indexOf('mraid.js') !== -1) {
                        notifyMraidRequested(value);
                    }
                }
                return originalSetAttribute.call(this, name, value);
            };

            var proto = el.__proto__ || Object.getPrototypeOf(el);
            var srcDescriptor = Object.getOwnPropertyDescriptor(proto, 'src');
            if (srcDescriptor && srcDescriptor.configurable) {
                Object.defineProperty(el, 'src', {
                    get: function() {
                        return srcDescriptor.get ? srcDescriptor.get.call(this) : this.getAttribute('src');
                    },
                    set: function(value) {
                        if (value && value.indexOf('mraid.js') !== -1) {
                            notifyMraidRequested(value);
                        }
                        if (srcDescriptor.set) {
                            srcDescriptor.set.call(this, value);
                        } else {
                            this.setAttribute('src', value);
                        }
                    },
                });
            }
        }

        var originalCreateElement = document.createElement;
        document.createElement = function(tagName) {
            var el = originalCreateElement.call(document, tagName);
            try {
                if (String(tagName).toLowerCase() === 'script') {
                    hookScriptElement(el);
                }
            } catch (e) {
                // No-op
            }
            return el;
        };

        var originalAppendChild = Element.prototype.appendChild;
        Element.prototype.appendChild = function(child) {
            try {
                if (child && child.tagName && child.tagName.toLowerCase() === 'script') {
                    hookScriptElement(child);
                }
            } catch (e) {
                // No-op
            }
            return originalAppendChild.call(this, child);
        };

        // Scan any existing <script> tags for mraid.js once DOM is ready enough
        document.addEventListener(
            'DOMContentLoaded',
            function() {
                try {
                    var scripts = document.getElementsByTagName('script');
                    for (var i = 0; i < scripts.length; i++) {
                        var s = scripts[i];
                        var src = s.getAttribute('src') || '';
                        if (src && src.indexOf('mraid.js') !== -1) {
                            notifyMraidRequested(src);
                        }
                    }
                } catch (e) {
                    // No-op
                }
            },
            false
        );
    } catch (e) {
        // Top-level guard: never break the page
    }
})();
