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
     var supportedFeatures = {
         sms: false,
         tel: false,
         calendar: false,
         storePicture: false,
         inlineVideo: false,
         vpaid: false,
         location: false,
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
             postToNative('expand');
         }
     };

     mraid.isViewable = function() { return isViewable; };

     mraid.playVideo = function(uri) {
         postToNative('playVideo', { uri: uri });
     };

     mraid.resize = function() {
         postToNative('resize');
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

     mraid.getOrientationProperties = function() { return Object.assign({}, orientationProperties); };

     mraid.setOrientationProperties = function(properties) {
         if (properties.hasOwnProperty('allowOrientationChange')) {
             orientationProperties.allowOrientationChange = properties.allowOrientationChange;
         }
         if (properties.hasOwnProperty('forceOrientation')) {
             orientationProperties.forceOrientation = properties.forceOrientation;
         }
     };

     mraid.getCurrentAppOrientation = function() { return ORIENTATIONS.NONE; };

     mraid.getCurrentPosition = function() { return { x: 0, y: 0, width: 0, height: 0 }; };

     mraid.getDefaultPosition = function() { return { x: 0, y: 0, width: 0, height: 0 }; };

     mraid.getState = function() { return state; };

     mraid.getExpandProperties = function() { return expandProperties; };

     mraid.setExpandProperties = function(properties) {
     };

     mraid.getMaxSize = function() { return { width: 0, height: 0 }; };

     mraid.getScreenSize = function() { return { width: 0, height: 0 }; };

     mraid.getResizeProperties = function() { return {}; };

     mraid.setResizeProperties = function(properties) {
     };

     mraid.getLocation = function() { return null; };

     // --- Native → JS Bridge ---
     mraid._fireEvent = function(event) {
         var listeners = eventListeners[event];
         if (listeners) {
             var args = Array.prototype.slice.call(arguments, 1);
             listeners.forEach(function(listener) {
                 try {
                     listener.apply(null, args);
                 } catch (e) {
                     console.warn("MRAID listener error:", e);
                 }
             });
         }
     };

     mraid._setState = function(newState) {
         if (state !== newState) {
             state = newState;
             this._fireEvent(EVENTS.STATE_CHANGE, state);
         }
     };

     mraid._setIsViewable = function(viewable) {
         if (isViewable !== viewable) {
             isViewable = viewable;
             this._fireEvent(EVENTS.VIEWABLE_CHANGE, isViewable);
         }
     };

     mraid._setPlacementType = function(newPlacementType) {
         placementType = newPlacementType;
     };

 })(window);
