"use strict";

function ownKeys(e, r) { var t = Object.keys(e); if (Object.getOwnPropertySymbols) { var o = Object.getOwnPropertySymbols(e); r && (o = o.filter(function (r) { return Object.getOwnPropertyDescriptor(e, r).enumerable; })), t.push.apply(t, o); } return t; }
function _objectSpread(e) { for (var r = 1; r < arguments.length; r++) { var t = null != arguments[r] ? arguments[r] : {}; r % 2 ? ownKeys(Object(t), !0).forEach(function (r) { _defineProperty(e, r, t[r]); }) : Object.getOwnPropertyDescriptors ? Object.defineProperties(e, Object.getOwnPropertyDescriptors(t)) : ownKeys(Object(t)).forEach(function (r) { Object.defineProperty(e, r, Object.getOwnPropertyDescriptor(t, r)); }); } return e; }
function _createForOfIteratorHelper(r, e) { var t = "undefined" != typeof Symbol && r[Symbol.iterator] || r["@@iterator"]; if (!t) { if (Array.isArray(r) || (t = _unsupportedIterableToArray(r)) || e && r && "number" == typeof r.length) { t && (r = t); var _n = 0, F = function F() {}; return { s: F, n: function n() { return _n >= r.length ? { done: !0 } : { done: !1, value: r[_n++] }; }, e: function e(r) { throw r; }, f: F }; } throw new TypeError("Invalid attempt to iterate non-iterable instance.\nIn order to be iterable, non-array objects must have a [Symbol.iterator]() method."); } var o, a = !0, u = !1; return { s: function s() { t = t.call(r); }, n: function n() { var r = t.next(); return a = r.done, r; }, e: function e(r) { u = !0, o = r; }, f: function f() { try { a || null == t["return"] || t["return"](); } finally { if (u) throw o; } } }; }
function _unsupportedIterableToArray(r, a) { if (r) { if ("string" == typeof r) return _arrayLikeToArray(r, a); var t = {}.toString.call(r).slice(8, -1); return "Object" === t && r.constructor && (t = r.constructor.name), "Map" === t || "Set" === t ? Array.from(r) : "Arguments" === t || /^(?:Ui|I)nt(?:8|16|32)(?:Clamped)?Array$/.test(t) ? _arrayLikeToArray(r, a) : void 0; } }
function _arrayLikeToArray(r, a) { (null == a || a > r.length) && (a = r.length); for (var e = 0, n = Array(a); e < a; e++) n[e] = r[e]; return n; }
function _defineProperty(e, r, t) { return (r = _toPropertyKey(r)) in e ? Object.defineProperty(e, r, { value: t, enumerable: !0, configurable: !0, writable: !0 }) : e[r] = t, e; }
function _typeof(o) { "@babel/helpers - typeof"; return _typeof = "function" == typeof Symbol && "symbol" == typeof Symbol.iterator ? function (o) { return typeof o; } : function (o) { return o && "function" == typeof Symbol && o.constructor === Symbol && o !== Symbol.prototype ? "symbol" : typeof o; }, _typeof(o); }
function _classCallCheck(a, n) { if (!(a instanceof n)) throw new TypeError("Cannot call a class as a function"); }
function _defineProperties(e, r) { for (var t = 0; t < r.length; t++) { var o = r[t]; o.enumerable = o.enumerable || !1, o.configurable = !0, "value" in o && (o.writable = !0), Object.defineProperty(e, _toPropertyKey(o.key), o); } }
function _createClass(e, r, t) { return r && _defineProperties(e.prototype, r), t && _defineProperties(e, t), Object.defineProperty(e, "prototype", { writable: !1 }), e; }
function _toPropertyKey(t) { var i = _toPrimitive(t, "string"); return "symbol" == _typeof(i) ? i : i + ""; }
function _toPrimitive(t, r) { if ("object" != _typeof(t) || !t) return t; var e = t[Symbol.toPrimitive]; if (void 0 !== e) { var i = e.call(t, r || "default"); if ("object" != _typeof(i)) return i; throw new TypeError("@@toPrimitive must return a primitive value."); } return ("string" === r ? String : Number)(t); }
// mraid.js
// Copyright 2021 MobileFuse LLC
var EventListener = /*#__PURE__*/function () {
  function EventListener(event) {
    _classCallCheck(this, EventListener);
    this.event = event;
    this.listeners = {};
  }
  return _createClass(EventListener, [{
    key: "add",
    value: function add(callback) {
      var id = String(callback);
      this.listeners[id] = callback;
    }
  }, {
    key: "remove",
    value: function remove(callback) {
      var id = String(callback);
      if (this.listeners[id]) {
        delete this.listeners[id];
        return true;
      }
      return false;
    }
  }, {
    key: "removeAll",
    value: function removeAll() {
      this.listeners = {};
    }
  }, {
    key: "invoke",
    value: function invoke(scope, args) {
      for (var callbackId in this.listeners) {
        if (!this.listeners.hasOwnProperty(callbackId)) {
          continue;
        }
        this.listeners[callbackId].apply(scope, args);
      }
    }
  }]);
}();
var NativeBridge = /*#__PURE__*/function () {
  function NativeBridge(mraid) {
    _classCallCheck(this, NativeBridge);
    this.mraid = mraid;
    this.queue = [];
    this.requestInFlight = false;
  }
  return _createClass(NativeBridge, [{
    key: "call",
    value: function call(method, args) {
      var callUri = "mraid://" + method;
      if (args) {
        callUri += "?" + this._buildQueryString(args);
      }
      this.queue.push(callUri);
      if (!this.requestInFlight) {
        this._next();
      }
    }
  }, {
    key: "_buildQueryString",
    value: function _buildQueryString(obj) {
      var str = [];
      for (var p in obj) {
        if (obj.hasOwnProperty(p)) {
          str.push(encodeURIComponent(p) + "=" + encodeURIComponent(obj[p]));
        }
      }
      return str.join("&");
    }
  }, {
    key: "_next",
    value: function _next() {
      if (this.queue.length === 0 || this.requestInFlight) {
        return;
      }
      var call = this.queue.shift();
      this.requestInFlight = true;
      this.mraid._debug("Bridge, calling native " + call);

      // This check will only succeed on iOS
      if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mfusesdk) {
        // Notify iOS layer
        window.webkit.messageHandlers.mfusesdk.postMessage("mraidBridgeCall:" + call);
      } else {
        // Notify Android layer
        var xhr = new XMLHttpRequest();
        var url = call.replace("mraid://", "https://sdk-webview.mobilefuse.com/mraid/");
        xhr.open('GET', url, true);
        xhr.send();
      }
    }
  }, {
    key: "nativeCallComplete",
    value: function nativeCallComplete() {
      if (!this.requestInFlight) return;
      this.requestInFlight = false;
      this._next();
    }

    // Interface methods for the native layer:
  }, {
    key: "init",
    value: function init(appDetails) {
      this.call("initBridge", appDetails);
    }
  }, {
    key: "setCurrentPosition",
    value: function setCurrentPosition(properties) {
      console.log("[mraid] :: setCurrentPosition(" + JSON.stringify(properties) + ")");
      this.mraid.currentPosition = this.mraid._assignProperties(properties, this.mraid.currentPosition);
    }
  }, {
    key: "setCurrentAppOrientation",
    value: function setCurrentAppOrientation(properties) {
      console.log("[mraid] :: setCurrentAppOrientation(" + JSON.stringify(properties) + ")");
      this.mraid.currentAppOrientation = this.mraid._assignProperties(properties, this.mraid.currentAppOrientation);
    }
  }, {
    key: "setDefaultPosition",
    value: function setDefaultPosition(properties) {
      console.log("[mraid] :: setDefaultPosition(" + JSON.stringify(properties) + ")");
      this.mraid.defaultPosition = this.mraid._assignProperties(properties, this.mraid.defaultPosition);
    }
  }, {
    key: "setMaxSize",
    value: function setMaxSize(properties) {
      this.mraid.maxSize = this.mraid._assignProperties(properties, this.mraid.maxSize);
    }
  }, {
    key: "setPlacementType",
    value: function setPlacementType(placementType) {
      this.mraid.placementType = placementType;
    }
  }, {
    key: "setScreenSize",
    value: function setScreenSize(properties) {
      console.log("[mraid] :: setScreenSize(" + JSON.stringify(properties) + ")");
      this.mraid.screenSize = this.mraid._assignProperties(properties, this.mraid.screenSize);
    }
  }, {
    key: "setState",
    value: function setState(state) {
      this.mraid.state = state;
      this.mraid._broadcastEvent(Mraid.Event.STATE_CHANGE, state);
    }
  }, {
    key: "setIsViewable",
    value: function setIsViewable(isViewable) {
      if (isViewable === this.mraid.viewable) return;
      this.mraid.viewable = isViewable;
      this.mraid._broadcastEvent(Mraid.Event.VIEWABLE_CHANGE, isViewable);
    }
  }, {
    key: "setExposureChange",
    value: function setExposureChange(exposurePercent, visibleRectangle, occlusionRectangles) {
      this.mraid._broadcastEvent(Mraid.Event.EXPOSURE_CHANGE, exposurePercent, visibleRectangle, occlusionRectangles);
    }
  }, {
    key: "setSupports",
    value: function setSupports(supports) {
      if (!supports) {
        this._broadcastEvent(Mraid.Event.ERROR, 'supports argument is not defined', 'setSupports');
      }
      this.mraid.supportProperties = this.mraid._assignProperties(supports, this.mraid.supportProperties);
    }
  }, {
    key: "setTransparentBackground",
    value: function setTransparentBackground(transparent) {
      this.mraid.transparentBackground = transparent;
      this.mraid._broadcastEvent(Mraid.Event.TRANSPARENT_BG_CHANGE, transparent);
    }
  }, {
    key: "notifyReadyEvent",
    value: function notifyReadyEvent() {
      this.mraid._broadcastEvent(Mraid.Event.READY);
    }
  }, {
    key: "notifySizeChangeEvent",
    value: function notifySizeChangeEvent(width, height) {
      this.mraid._broadcastEvent(Mraid.Event.SIZE_CHANGE, width, height);
    }
  }, {
    key: "notifyStateChangeEvent",
    value: function notifyStateChangeEvent() {
      this.mraid._broadcastEvent(Mraid.Event.STATE_CHANGE, this.mraid.state);
    }
  }, {
    key: "notifyViewableChangeEvent",
    value: function notifyViewableChangeEvent() {
      this.mraid._broadcastEvent(Mraid.Event.VIEWABLE_CHANGE, this.mraid.isViewable());
    }

    // Platform-specific tools
  }, {
    key: "isIOS",
    value: function isIOS() {
      return navigator.platform.substr(0, 2) === 'iP'; // iPhone, iPad, iPod
    }
  }, {
    key: "setLocation",
    value: function setLocation(location) {
      this.mraid.locationProperties = this.mraid._assignProperties(location, this.mraid.locationProperties);
    }
  }]);
}();
var SplashAd = /*#__PURE__*/function () {
  function SplashAd(bridge) {
    _classCallCheck(this, SplashAd);
    this.bridge = bridge;
  }
  return _createClass(SplashAd, [{
    key: "transition",
    value: function transition() {
      this.bridge.call('splashAdTransition');
    }
  }, {
    key: "expand",
    value: function expand() {
      this.bridge.call('splashAdExpand');
    }
  }]);
}();
var Mraid = /*#__PURE__*/function () {
  function Mraid(options) {
    _classCallCheck(this, Mraid);
    options = options || {};
    this.VERSION = "3.0";
    this.isMobileFuseSdk = true;
    this.DEBUG = options.DEBUG || false;
    this.bridge = new NativeBridge(this);

    // Internal mraid state:
    this.state = Mraid.State.LOADING;
    this.viewable = false;
    this.eventListeners = {};
    this.placementType = Mraid.PlacementType.UNKNOWN;

    // Our mraid properties:

    this.expandProperties = {
      width: false,
      height: false,
      useCustomClose: false,
      isModal: true
    };
    this.resizeProperties = {
      width: false,
      height: false,
      offsetX: false,
      offsetY: false,
      customClosePosition: 'top-right',
      allowOffscreen: true
    };
    this.orientationProperties = {
      allowOrientationChange: true,
      forceOrientation: "none"
    };
    this.supportProperties = {
      sms: false,
      tel: false,
      calendar: false,
      storePicture: false,
      inlineVideo: false,
      vpaid: false,
      location: false,
      // Updated by the SDK based on whether location permission is available

      // Extensions:
      ar: false,
      barometricPressure: false,
      transparentBackground: true,
      splashAd: true
    };
    this.locationProperties = {
      lat: 0,
      lon: 0,
      type: Mraid.LocationType.INVALID,
      accuracy: -1,
      lastfix: -1
    };

    // State:
    this.maxSize = {
      width: 0,
      height: 0
    };
    this.currentPosition = {
      x: 0,
      y: 0,
      width: 0,
      height: 0
    };
    this.currentAppOrientation = {
      orientation: "none",
      locked: false
    };
    this.defaultPosition = {
      x: 0,
      y: 0,
      width: 0,
      height: 0
    };
    this.screenSize = {
      width: 0,
      height: 0
    };
    this.transparentBackground = false;

    // SplashAd
    this.splashAd = new SplashAd(this.bridge);
  }
  return _createClass(Mraid, [{
    key: "_broadcastEvent",
    value:
    // Private/Helper methods:
    function _broadcastEvent() {
      var args = Array.prototype.slice.call(arguments);
      var event = args.shift();
      if (this.eventListeners[event]) {
        this.eventListeners[event].invoke(this, args);
      }
      if (event !== Mraid.Event.DEBUG_LOG) {
        this._debug("_broadcastEvent", event, args);
      }
    }
  }, {
    key: "_debug",
    value: function _debug() {
      if (!this.DEBUG) {
        return;
      }
      var logOutput = [];
      var _iterator = _createForOfIteratorHelper(arguments),
        _step;
      try {
        for (_iterator.s(); !(_step = _iterator.n()).done;) {
          var arg = _step.value;
          if (arg === null) {
            continue;
          }
          if (_typeof(arg) !== 'object') {
            logOutput.push(arg.toString());
            continue;
          }
          logOutput.push(JSON.stringify(arg));
        }
      } catch (err) {
        _iterator.e(err);
      } finally {
        _iterator.f();
      }
      if (!this.bridge.isIOS()) {
        // On iOS, this causes a log loop
        console.log("[mraid.js] " + logOutput.join(' '));
      }
      this._broadcastEvent(Mraid.Event.DEBUG_LOG, logOutput.join(' '));
    }
  }, {
    key: "_assignProperties",
    value: function _assignProperties(from, to, properties) {
      if (!properties) properties = Object.keys(to);
      var obj = _objectSpread({}, to);
      var _iterator2 = _createForOfIteratorHelper(properties),
        _step2;
      try {
        for (_iterator2.s(); !(_step2 = _iterator2.n()).done;) {
          var p = _step2.value;
          if (from.hasOwnProperty(p)) {
            obj[p] = from[p];
          }
        }
      } catch (err) {
        _iterator2.e(err);
      } finally {
        _iterator2.f();
      }
      return obj;
    }

    // Core MRAID 3.0 interface:
    // See: https://www.iab.com/wp-content/uploads/2017/07/MRAID_3.0_FINAL.pdf
    // Section 2.3 - Interface, Page 14
  }, {
    key: "getVersion",
    value: function getVersion() {
      if (!this.VERSION) {
        this._broadcastEvent(Mraid.Event.ERROR, 'VERSION is not defined', 'getVersion');
      }
      return this.VERSION;
    }
  }, {
    key: "addEventListener",
    value: function addEventListener(event, listener) {
      if (!listener) {
        this._broadcastEvent(Mraid.Event.ERROR, 'listener argument is not defined', 'addEventListener');
        return;
      }
      if (!event) {
        this._broadcastEvent(Mraid.Event.ERROR, 'event argument is not defined', 'addEventListener');
        return;
      }
      if (!this.eventListeners[event]) {
        this.eventListeners[event] = new EventListener(event);
      }
      this.eventListeners[event].add(listener);
      this.bridge.call('eventListenerWasAdded', {
        event: event
      });
    }
  }, {
    key: "removeEventListener",
    value: function removeEventListener(event, listener) {
      if (!event) {
        this._broadcastEvent(Mraid.Event.ERROR, 'event argument is not defined', 'removeEventListener');
        return;
      }
      if (listener) {
        // If we have a valid event, we'll try to remove the listener from it.
        var success = false;
        if (this.eventListeners[event]) {
          success = this.eventListeners[event].remove(listener);
        }

        // If we didn't have a valid event or couldn't remove the listener from the event, broadcast an error and return early.
        if (!success) {
          this._broadcastEvent(Mraid.Event.ERROR, 'removing event listener failed: there was no listener registered for the specified event', 'removeEventListener');
        }
      } else if (!listener && this.eventListeners[event]) {
        this.eventListeners[event].removeAll();
      }
    }
  }, {
    key: "open",
    value: function open(url) {
      if (!url) {
        this._broadcastEvent(Mraid.Event.ERROR, 'url is not defined', 'open');
      } else {
        this.bridge.call('open', {
          url: url
        });
      }
    }
  }, {
    key: "close",
    value: function close() {
      if (this.state === Mraid.State.HIDDEN) {
        this._broadcastEvent(Mraid.Event.ERROR, 'close failed: ad cannot be closed when it is already hidden', 'close');
      } else {
        this.bridge.call('close');
      }
    }

    // Deprecated
  }, {
    key: "useCustomClose",
    value: function useCustomClose(shouldUseCustomClose) {
      this.expandProperties.useCustomClose = shouldUseCustomClose;
      this.bridge.call('useCustomClose', {
        shouldUseCustomClose: shouldUseCustomClose
      });
    }
  }, {
    key: "unload",
    value: function unload() {
      console.log("[mraid] :: unload");
      this.bridge.call('unload');
    }
  }, {
    key: "expand",
    value: function expand(url) {
      if (!(this.state === Mraid.State.DEFAULT || this.state === Mraid.State.RESIZED)) {
        this._broadcastEvent(Mraid.Event.ERROR, 'expand failed: ad can only be expanded from the default or resized state', 'expand');
        return;
      }
      var args = _objectSpread({}, this.expandProperties);
      args.allowOrientationChange = this.orientationProperties.allowOrientationChange;
      args.forceOrientation = this.orientationProperties.forceOrientation;

      //        args.allowOrientationChange = true;
      //        args.forceOrientation = "landscape";

      if (url) {
        args.url = url;
      }
      this.bridge.call('expand', args);
    }

    // Deprecated
  }, {
    key: "isViewable",
    value: function isViewable() {
      if (this.viewable === null || this.viewable === undefined) {
        this._broadcastEvent(Mraid.Event.ERROR, 'viewable is not defined', 'isViewable');
      }
      return this.viewable;
    }
  }, {
    key: "playVideo",
    value: function playVideo(uri) {
      if (!mraid.isViewable()) {
        this._broadcastEvent(Mraid.Event.ERROR, 'playVideo cannot be called until the ad is viewable', 'playVideo');
        return;
      }
      if (!uri) {
        this._broadcastEvent(Mraid.Event.ERROR, 'playVideo must be called with a valid URI', 'playVideo');
      } else {
        this.bridge.call('playVideo', {
          uri: uri
        });
      }
    }
  }, {
    key: "resize",
    value: function resize() {
      if (!(this.getState() === Mraid.State.DEFAULT || this.getState() === Mraid.State.RESIZED)) {
        this._broadcastEvent(Mraid.Event.ERROR, 'resize failed: ad can only be resized from the default or resized state', 'resize');
      } else if (!this.resizeProperties.width || !this.resizeProperties.height) {
        this._broadcastEvent(Mraid.Event.ERROR, 'resize failed: must set resize properties before calling resize()', 'resize');
      } else {
        this.bridge.call('resize', this.resizeProperties);
      }
    }
  }, {
    key: "storePicture",
    value: function storePicture(uri) {
      if (!mraid.isViewable()) {
        this._broadcastEvent(Mraid.Event.ERROR, 'storePicture cannot be called until the ad is viewable', 'storePicture');
        return;
      }
      if (!uri) {
        this._broadcastEvent(Mraid.Event.ERROR, 'storePicture must be called with a valid URI', 'storePicture');
      } else {
        this.bridge.call('storePicture', {
          uri: uri
        });
      }
    }
  }, {
    key: "setTransparentBackground",
    value: function setTransparentBackground(transparent) {
      console.log("[mraid Transparent Interstitial] :: setTransparentBackground(" + transparent + ")");
      this.bridge.call('setTransparentBackground', {
        transparent: transparent
      });
    }
  }, {
    key: "createCalendarEvent",
    value: function createCalendarEvent(parameters) {
      //        throw "Not implemented :: createCalendarEvent()";
      if (!mraid.isViewable()) {
        this._broadcastEvent(Mraid.Event.ERROR, 'createCalendarEvent cannot be called until the ad is viewable', 'createCalendarEvent');
        return;
      }
      if (!parameters) {
        this._broadcastEvent(Mraid.Event.ERROR, 'createCalendarEvent must be called with a valid parameters', 'createCalendarEvent');
      } else {
        this.bridge.call('createCalendarEvent', {
          details: JSON.stringify(parameters)
        });
      }
    }

    // VPAID --
  }, {
    key: "initVpaid",
    value: function initVpaid(vpaidObject) {
      throw "Not implemented :: initVpaid()";
    }

    // Properties --
  }, {
    key: "supports",
    value: function supports(feature) {
      return this.supportProperties[feature];
    }
  }, {
    key: "getPlacementType",
    value: function getPlacementType() {
      if (!this.placementType || this.placementType === Mraid.PlacementType.UNKNOWN) {
        this._broadcastEvent(Mraid.Event.ERROR, 'placementType is not defined', 'getPlacementType');
      }
      return this.placementType;
    }
  }, {
    key: "getOrientationProperties",
    value: function getOrientationProperties() {
      console.log("[mraid] :: getOrientationProperties()");
      return _objectSpread({}, this.orientationProperties);
    }
  }, {
    key: "setOrientationProperties",
    value: function setOrientationProperties(properties) {
      console.log("[mraid] :: setOrientationProperties(" + JSON.stringify(properties) + ")");
      if (this.getState() === Mraid.State.LOADING) {
        this._broadcastEvent(Mraid.Event.ERROR, "setting orientation properties failed: setOrientationProperties cannot be called during the loading state", 'setOrientationProperties');
        return;
      }
      if (typeof properties === "undefined") {
        this._broadcastEvent(Mraid.Event.ERROR, "properties argument is not defined", 'setOrientationProperties');
        return;
      }
      if (!this.getCurrentAppOrientation().locked) {
        if (properties.forceOrientation === 'portrait' || properties.forceOrientation === 'landscape' || properties.forceOrientation === 'none') {
          this.orientationProperties.forceOrientation = properties.forceOrientation;
        } else {
          this._broadcastEvent(Mraid.Event.ERROR, "forceOrientation property was ignored because it had an unsupported value", 'setOrientationProperties');
        }
      }
      if (typeof properties.allowOrientationChange === "boolean") {
        this.orientationProperties.allowOrientationChange = properties.allowOrientationChange;
      } else {
        this._broadcastEvent(Mraid.Event.ERROR, "allowOrientationChange property was ignored because it was not a boolean value", 'setOrientationProperties');
      }

      /*this.orientationProperties = this._assignProperties(
          properties,
          this.orientationProperties
      );*/
      this.bridge.call('setOrientationProperties', this.orientationProperties);
    }
  }, {
    key: "getCurrentAppOrientation",
    value: function getCurrentAppOrientation() {
      console.log("[mraid] :: getCurrentAppOrientation()");
      return _objectSpread({}, this.currentAppOrientation);
    }
  }, {
    key: "getCurrentPosition",
    value: function getCurrentPosition() {
      if (!this.currentPosition) {
        this._broadcastEvent(Mraid.Event.ERROR, 'currentPosition is not defined', 'getCurrentPosition');
      }
      return _objectSpread({}, this.currentPosition);
    }
  }, {
    key: "getDefaultPosition",
    value: function getDefaultPosition() {
      if (!this.defaultPosition) {
        this._broadcastEvent(Mraid.Event.ERROR, 'defaultPosition is not defined', 'getDefaultPosition');
      }
      return _objectSpread({}, this.defaultPosition);
    }
  }, {
    key: "getState",
    value: function getState() {
      if (!this.state) {
        this._broadcastEvent(Mraid.Event.ERROR, 'state is not defined', 'getState');
      }
      return this.state;
    }
  }, {
    key: "getExpandProperties",
    value: function getExpandProperties() {
      if (!this.expandProperties) {
        this._broadcastEvent(Mraid.Event.ERROR, 'expandProperties is not defined', 'getExpandProperties');
      }
      return _objectSpread({}, this.expandProperties);
    }
  }, {
    key: "setExpandProperties",
    value: function setExpandProperties(properties) {
      if (!this.expandProperties) {
        this._broadcastEvent(Mraid.Event.ERROR, 'expandProperties is not defined', 'setExpandProperties');
      }
      if (!properties) {
        this._broadcastEvent(Mraid.Event.ERROR, 'properties argument is not defined', 'setExpandProperties');
      }
      this.expandProperties = this._assignProperties(properties, this.expandProperties);
    }
  }, {
    key: "getMaxSize",
    value: function getMaxSize() {
      console.log("[mraid] :: getMaxSize()" + JSON.stringify(this.maxSize));
      if (!this.maxSize) {
        this._broadcastEvent(Mraid.Event.ERROR, 'maxSize is not defined', 'getMaxSize');
      }
      return _objectSpread({}, this.maxSize);
    }
  }, {
    key: "getScreenSize",
    value: function getScreenSize() {
      console.log("[mraid] :: getScreenSize() " + JSON.stringify(this.screenSize));
      if (!this.screenSize) {
        this._broadcastEvent(Mraid.Event.ERROR, 'screenSize is not defined', 'getScreenSize');
      }
      return _objectSpread({}, this.screenSize);
    }
  }, {
    key: "getResizeProperties",
    value: function getResizeProperties() {
      return _objectSpread({}, this.resizeProperties);
    }
  }, {
    key: "setResizeProperties",
    value: function setResizeProperties(properties) {
      this._assignProperties(properties, this.resizeProperties);
    }
  }, {
    key: "getLocation",
    value: function getLocation() {
      var location = _objectSpread({}, this.locationProperties);
      if (location.lastfix instanceof Date) {
        // 'lastfix' should be number of seconds since the last GPS fix:
        location.lastfix = (new Date() - location.lastfix) / 1000;
      }
      if (location.lat === 0 && location.lon === 0) {
        this._broadcastEvent(Mraid.Event.ERROR, '-1', 'getLocation');
      }
      return location;
    }
  }]);
}();
_defineProperty(Mraid, "Event", {
  ERROR: 'error',
  READY: 'ready',
  SIZE_CHANGE: 'sizeChange',
  STATE_CHANGE: 'stateChange',
  EXPOSURE_CHANGE: 'exposureChange',
  AUDIO_VOLUME_CHANGE: 'audioVolumeChange',
  VIEWABLE_CHANGE: 'viewableChange',
  // Deprecated
  DEBUG_LOG: 'debugLog' // Extension
});
_defineProperty(Mraid, "LocationType", {
  INVALID: 0,
  GPS: 1,
  IP_ADDRESS: 2,
  USER_PROVIDED: 3
});
_defineProperty(Mraid, "State", {
  LOADING: 'loading',
  DEFAULT: 'default',
  EXPANDED: 'expanded',
  HIDDEN: 'hidden',
  RESIZED: 'resized'
});
_defineProperty(Mraid, "PlacementType", {
  UNKNOWN: 'unknown',
  INLINE: 'inline',
  INTERSTITIAL: 'interstitial'
});
if (!window.mraid || !window.mraid.isMobileFuseSdk) {
  var _mraid = window.mraid = new Mraid({
    DEBUG: MRAID_ENV.debug || false
  });
}