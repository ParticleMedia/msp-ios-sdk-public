(function(window) {
    'use strict';

    var mraid = window.mraid = {};

    // --- Constants ---
    var STATES = {
        LOADING: 'loading',
        DEFAULT: 'default',
        EXPANDED: 'expanded',
        RESIZED: 'resized',
        HIDDEN: 'hidden',
    };

    var PLACEMENT_TYPES = {
        INLINE: 'inline',
        INTERSTITIAL: 'interstitial',
    };

    var ORIENTATIONS = {
        PORTRAIT: "portrait",
        LANDSCAPE: "landscape",
        NONE: "none",
    };

    var EVENTS = {
        ERROR: "error",
        READY: "ready",
        SIZE_CHANGE: "sizeChange",
        STATE_CHANGE: "stateChange",
        EXPOSURE_CHANGE: "exposureChange",
        AUDIO_VOLUME_CHANGE: "audioVolumeChange",
        VIEWABLE_CHANGE: "viewableChange",
    };

    // --- Private properties ---
    var state = STATES.LOADING;
    var isViewable = false;
    var placementType = PLACEMENT_TYPES.INLINE;
    var eventListeners = {};
    var currentAppOrientation = ORIENTATIONS.NONE;
    var currentPositionRect = { x: 0, y: 0, width: 0, height: 0 };
    var defaultPositionRect = null;
    var lastExposurePayload = null;
    var lastKnownLocation = null;
    var locationRequested = false;
    var lastKnownVolume = 1;

    var supportedFeatures = {
        sms: false,
        tel: false,
        calendar: true,
        storePicture: true,
        inlineVideo: true,
        vpaid: false,
        location: !!navigator.geolocation,
    };
    var orientationProperties = {
        allowOrientationChange: true,
        forceOrientation: "none",
    };
    var expandProperties = {
        width: 0,
        height: 0,
        useCustomClose: false,
        isModal: false
    };
    var resizeProperties = {
        width: 0,
        height: 0,
        customClosePosition: 'top-right',
        offsetX: 0,
        offsetY: 0,
        allowOffscreen: true
    };

    function determineOrientation() {
        var orientation = ORIENTATIONS.NONE;
        if (window.screen && window.screen.orientation && window.screen.orientation.type) {
            orientation = window.screen.orientation.type.indexOf('landscape') === 0 ? ORIENTATIONS.LANDSCAPE : ORIENTATIONS.PORTRAIT;
        } else if (typeof window.orientation === 'number') {
            orientation = Math.abs(window.orientation) === 90 ? ORIENTATIONS.LANDSCAPE : ORIENTATIONS.PORTRAIT;
        } else if (window.innerWidth && window.innerHeight) {
            orientation = window.innerWidth >= window.innerHeight ? ORIENTATIONS.LANDSCAPE : ORIENTATIONS.PORTRAIT;
        }
        if (orientation !== currentAppOrientation) {
            currentAppOrientation = orientation;
        }
    }

    function measurePosition() {
        var width = Math.round(window.innerWidth || document.documentElement.clientWidth || 0);
        var height = Math.round(window.innerHeight || document.documentElement.clientHeight || 0);
        currentPositionRect = { x: 0, y: 0, width: width, height: height };
        if (!defaultPositionRect) {
            defaultPositionRect = Object.assign({}, currentPositionRect);
        }
        fireExposureChange();
    }

    function exposurePayloadsEqual(a, b) {
        if (!a || !b) {
            return false;
        }
        if (a.exposedPercentage !== b.exposedPercentage) {
            return false;
        }
        var geoA = a.geometry;
        var geoB = b.geometry;
        if (!geoA || !geoB) {
            return false;
        }
        if (geoA.x !== geoB.x || geoA.y !== geoB.y || geoA.width !== geoB.width || geoA.height !== geoB.height) {
            return false;
        }
        var visA = a.visibleRectangle || [];
        var visB = b.visibleRectangle || [];
        if (visA.length !== visB.length) {
            return false;
        }
        for (var i = 0; i < visA.length; i++) {
            if (visA[i] !== visB[i]) {
                return false;
            }
        }
        return true;
    }

    function fireExposureChange() {
        var exposedPercentage = isViewable ? 1 : 0;
        var payload = {
            exposedPercentage: exposedPercentage,
            geometry: Object.assign({}, currentPositionRect),
            visibleRectangle: isViewable ? [currentPositionRect.x, currentPositionRect.y, currentPositionRect.width, currentPositionRect.height] : [0, 0, 0, 0],
            occlusionRect: null
        };

        if (exposurePayloadsEqual(payload, lastExposurePayload)) {
            return;
        }

        lastExposurePayload = payload;
        mraid._fireEvent(EVENTS.EXPOSURE_CHANGE, payload);
    }

    function requestLocationIfNeeded() {
        if (lastKnownLocation || locationRequested || !navigator.geolocation) {
            return;
        }
        locationRequested = true;
        navigator.geolocation.getCurrentPosition(function(result) {
            lastKnownLocation = {
                lat: result.coords.latitude,
                lon: result.coords.longitude,
                type: result.coords.accuracy,
                accuracy: result.coords.accuracy,
                lastfix: Math.floor(result.timestamp / 1000)
            };
        }, function() {
            lastKnownLocation = null;
        }, { maximumAge: 60000, enableHighAccuracy: false });
    }

    function handleOrientationChange() {
        determineOrientation();
        fireExposureChange();
    }

    function handleVisibilityChange() {
        if (typeof document.hidden === 'boolean') {
            mraid._setIsViewable(!document.hidden);
        }
    }

    function handleAudioVolumeChange(event) {
        var target = event.target;
        if (target && typeof target.volume === 'number') {
            var newVolume = Math.max(0, Math.min(1, target.volume));
            if (newVolume !== lastKnownVolume) {
                lastKnownVolume = newVolume;
                mraid._fireEvent(EVENTS.AUDIO_VOLUME_CHANGE, lastKnownVolume);
            }
        }
    }

    function initializeSensors() {
        determineOrientation();
        measurePosition();
        requestLocationIfNeeded();
    }

    window.addEventListener('resize', measurePosition);
    window.addEventListener('scroll', measurePosition, true);
    window.addEventListener('orientationchange', handleOrientationChange);
    document.addEventListener('visibilitychange', handleVisibilityChange);
    document.addEventListener('volumechange', handleAudioVolumeChange, true);
    document.addEventListener('DOMContentLoaded', initializeSensors);
    window.addEventListener('load', initializeSensors);

    // --- Native communication ---
    var postToNative = function(action, params) {
        var message = { action: action, params: params || {} };

        // For iOS (WKWebView messageHandlers)
        if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mraidBridge) {
            window.webkit.messageHandlers.mraidBridge.postMessage(JSON.stringify(message));
        }
        // For Android (WebView JavaScript Interface)
        else if (window.MRAIDNativeBridge && window.MRAIDNativeBridge.postMessage) {
            window.MRAIDNativeBridge.postMessage(JSON.stringify(message));
        }
        // Fallback for older WebView (URL scheme)
        else {
            var iframe = document.createElement("iframe");
            var query = "";
            for (var key in params) {
                if (params.hasOwnProperty(key)) {
                    query += encodeURIComponent(key) + "=" + encodeURIComponent(params[key]) + "&";
                }
            }
            query = query.slice(0, -1);
            iframe.src = "mraid://" + action + "?" + query;
            document.body.appendChild(iframe);
            iframe.remove();
        }
    };

    // --- MRAID API ---
    mraid.getVersion = function() { return '3.0'; };

    mraid.addEventListener = function(event, listener) {
        eventListeners[event] = eventListeners[event] || [];
        eventListeners[event].push(listener);
    };

    mraid.removeEventListener = function(event, listener) {
        if (eventListeners[event]) {
            eventListeners[event] = eventListeners[event].filter(function(l) { return l !== listener; });
        }
    };

    mraid.open = function(url) {
        postToNative('open', { url: url });
    };

    mraid.close = function() {
        if (state === STATES.EXPANDED || state === STATES.RESIZED) {
            postToNative('close');
        }
    };

    mraid.useCustomClose = function() {
        // deprecated in MRAID 3.0
    };

    mraid.unload = function() {
        postToNative('unload');
    };

    mraid.expand = function() {
        if (state === STATES.DEFAULT && placementType === PLACEMENT_TYPES.INLINE) {
            postToNative('expand', expandProperties);
        } else {
        }
    };

    mraid.isViewable = function() { 
        return isViewable; 
    };

    mraid.playVideo = function(uri) {
        postToNative('playVideo', { uri: uri });
    };

    mraid.resize = function() {
        postToNative('resize', resizeProperties);
    };

    mraid.storePicture = function(uri) {
        postToNative('storePicture', { uri: uri });
    };

    mraid.createCalendarEvent = function(params) {
        postToNative('createCalendarEvent', params);
    };

    // --- MRAID Properties ---
    mraid.supports = function(feature) {
        return supportedFeatures[feature] === true;
    };

    mraid.getPlacementType = function() { return placementType; };

    mraid.getOrientationProperties = function() { 
        return Object.assign({}, orientationProperties); 
    };

    mraid.setOrientationProperties = function(properties) {
        if (properties.hasOwnProperty('allowOrientationChange')) {
            orientationProperties.allowOrientationChange = properties.allowOrientationChange;
        }
        if (properties.hasOwnProperty('forceOrientation')) {
            orientationProperties.forceOrientation = properties.forceOrientation;
        }
    };

    mraid.getCurrentAppOrientation = function() {
        determineOrientation();
        return currentAppOrientation;
    };

    mraid.getCurrentPosition = function() { 
        return Object.assign({}, currentPositionRect); 
    };

    mraid.getDefaultPosition = function() {
        if (defaultPositionRect) {
            return Object.assign({}, defaultPositionRect);
        }
        return Object.assign({}, currentPositionRect);
    };

    mraid.getState = function() { return state; };

    mraid.getExpandProperties = function() { 
        return Object.assign({}, expandProperties); 
    };

    mraid.setExpandProperties = function(properties) {
        if (properties && typeof properties === 'object') {
            ['width', 'height', 'useCustomClose', 'isModal'].forEach(function(key) {
                if (properties.hasOwnProperty(key)) {
                    expandProperties[key] = properties[key];
                }
            });
        }
    };

    mraid.getMaxSize = function() { 
        var width = Math.round(window.screen && window.screen.availWidth ? window.screen.availWidth : window.innerWidth || 0);
        var height = Math.round(window.screen && window.screen.availHeight ? window.screen.availHeight : window.innerHeight || 0);
        var maxSize = { width: width, height: height };
        return maxSize;
    };

    mraid.getScreenSize = function() {
        var width = Math.round(window.screen && window.screen.width ? window.screen.width : window.innerWidth || 0);
        var height = Math.round(window.screen && window.screen.height ? window.screen.height : window.innerHeight || 0);
        return { width: width, height: height };
    };

    mraid.getResizeProperties = function() { 
        return Object.assign({}, resizeProperties); 
    };

    mraid.setResizeProperties = function(properties) {
        if (properties && typeof properties === 'object') {
            ['width', 'height', 'customClosePosition', 'offsetX', 'offsetY', 'allowOffscreen'].forEach(function(key) {
                if (properties.hasOwnProperty(key)) {
                    resizeProperties[key] = properties[key];
                }
            });
        }
    };

    mraid.getLocation = function() {
        requestLocationIfNeeded();
        return lastKnownLocation ? Object.assign({}, lastKnownLocation) : null;
    };

    // --- Native → JS Bridge ---
    mraid._fireEvent = function(event) {
        var listeners = eventListeners[event];
        var args = Array.prototype.slice.call(arguments, 1);
        if (listeners) {
            listeners.forEach(function(listener) {
                try {
                    listener.apply(null, args);
                } catch (e) {
                    console.warn("[MRAID] Listener error for event:", event, "error:", e);
                }
            });
        } else {
        }
    };

    mraid._setState = function(newState) {
        if (state !== newState) {
            state = newState;
            this._fireEvent(EVENTS.STATE_CHANGE, state);
        } else {
        }
    };

    mraid._setIsViewable = function(viewable) {
        if (isViewable !== viewable) {
            isViewable = viewable;
            this._fireEvent(EVENTS.VIEWABLE_CHANGE, isViewable);
            fireExposureChange();
        } else {
        }
    };
    
    mraid._fireEvent(EVENTS.READY);

    mraid._setPlacementType = function(newPlacementType) {
        placementType = newPlacementType;
    };

})(window);
