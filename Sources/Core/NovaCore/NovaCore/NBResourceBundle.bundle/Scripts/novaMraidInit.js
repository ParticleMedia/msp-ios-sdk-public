if (window.mraid) {
    window.mraid._setState('default');
    if (window.mraid._setPlacementType) {
        window.mraid._setPlacementType('inline');
    }
    window.mraid._setIsViewable(true);
    if (window.mraid._fireEvent) {
        window.mraid._fireEvent('ready');
    }
}
