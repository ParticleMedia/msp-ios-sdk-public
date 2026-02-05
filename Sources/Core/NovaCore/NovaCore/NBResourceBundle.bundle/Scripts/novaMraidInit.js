console.log('[MRAID Init] Starting MRAID initialization...');
if (window.mraid) {
    console.log('[MRAID Init] window.mraid exists, initializing state...');
    window.mraid._setState('default');
    window.mraid._setIsViewable(true);
    window.mraid._setPlacementType('inline');
    console.log('[MRAID Init] Firing ready event...');
    window.mraid._fireEvent('ready');
    console.log('[MRAID Init] Initialization complete!');
} else {
    console.error('[MRAID Init] ERROR: window.mraid does not exist!');
}
