enum NovaAdEvent: String {
    case impression = "AD_EVENT_IMPRESSION"
    case click = "AD_EVENT_CLICK"
    case skipAd = "AD_EVENT_SKIP_AD"
    case hideAd = "hide_ad"
    case unhideAd = "unhide_ad"

    // video events
    case videoReady = "video_ready"
    case videoError = "video_error"
    case videoStart = "video_start"
    case videoFirstQuartile = "video_first_quartile"
    case videoMidPoint = "video_midpoint"
    case videoThirdQuartile = "video_third_quartile"
    case videoComplete = "video_complete"
    case videoPause = "video_pause"
    case videoResume = "video_resume"
    case videoMute = "video_mute"
    case videoUnMute = "video_unmute"

    case videoProgess = "video_progress"
    
    // web events
    case novaLandingPageLaunchFailed = "nova_landing_page_launch_failed"
    case novaLandingPageStart = "nova_landing_page_start"
    case novaLandingPageTextLoad = "nova_landing_page_text_load"
    case novaLandingPageAllLoad = "nova_landing_page_all_load"
    case novaLandingPageClose = "nova_landing_page_close"
    case novaLandingPageJumpOut = "nova_landing_page_jump_out"
    case novaLandingPageJumpIn = "nova_landing_page_jump_in"
    case novaLandingPageResignActive = "nova_landing_page_resign_active"
    case novaLandingPageAliveAfter5s = "nova_landing_page_alive_after_5s"
    case novaLandingPageRecycledAfter5s = "nova_landing_page_recyclerd_after_5s"
}
