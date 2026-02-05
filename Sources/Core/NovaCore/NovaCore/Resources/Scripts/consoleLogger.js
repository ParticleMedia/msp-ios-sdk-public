(function() {
    // Intercept console methods and forward to native
    var originalLog = console.log;
    var originalWarn = console.warn;
    var originalError = console.error;
    var originalInfo = console.info;
    var originalDebug = console.debug;
    
    function sendToNative(level, args) {
        try {
            var message = Array.prototype.slice.call(args).map(function(arg) {
                if (typeof arg === 'object') {
                    try {
                        return JSON.stringify(arg);
                    } catch (e) {
                        return String(arg);
                    }
                }
                return String(arg);
            }).join(' ');
            
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.consoleLog) {
                window.webkit.messageHandlers.consoleLog.postMessage({
                    level: level,
                    message: message
                });
            }
        } catch (e) {
            // Silently fail to avoid breaking the page
        }
    }
    
    console.log = function() {
        sendToNative('log', arguments);
        originalLog.apply(console, arguments);
    };
    
    console.warn = function() {
        sendToNative('warn', arguments);
        originalWarn.apply(console, arguments);
    };
    
    console.error = function() {
        sendToNative('error', arguments);
        originalError.apply(console, arguments);
    };
    
    console.info = function() {
        sendToNative('info', arguments);
        originalInfo.apply(console, arguments);
    };
    
    console.debug = function() {
        sendToNative('debug', arguments);
        originalDebug.apply(console, arguments);
    };
    
    // Send a test message to confirm console logging is working
    console.log('[Console Logger] JavaScript console interception initialized');
})();
