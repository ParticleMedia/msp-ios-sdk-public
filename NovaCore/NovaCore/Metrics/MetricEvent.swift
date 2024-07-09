@objc public enum MetricEvent: Int, CaseIterable {
    case facebookLogin
    case feedbackTextSubmitted
    case articleFeedback
    case articleRating

    // Ads
    case adClick
    case adSlotImpression
    case adRevenueImpression
    case adDeDuplicated
    case adBlocked
    case adSendFeedback
    case adPaid
    case adWinnerDecided
    case loadItemsWithoutAds
    case adResponse
    case adRequest
    case adClickEmptyArea
    case appContentDisplayed
    case adCacheExpired

    case enterFullArticleWithAdSlot
    case enterFullArticleWithAdFilled
    case clickPushDoc
    case clickPushOthers
    case invalidPushContent
    case getPushContentFailed
    case clickDoc
    case enterNews
    case clickSocial
    case enterSocial
    case enterNewsByWebUrl
    case popBtnView
    case popBtnClick
    case novaLandingPageLaunchFailed
    case novaLandingPageStart
    case novaLandingPageTextLoad
    case novaLandingPageAllLoad
    case novaLandingPageClose
    case novaLandingPageJumpOut
    case novaLandingPageJumpIn
    case novaLandingPageResignActive
    case novaLandingPageAliveAfter5s
    case novaLandingPageRecycledAfter5s
    case prebidBannerPresentModal
    case imageDownloadReport
    case imageDownloadErrorReport

    case openApp
    case closeApp
    case firstOpen
    case tabBarViewTime
    case tabAddClick
    case tabManage
    case goTab2
    case topSearchBoxShow
    case topSearchBoxClick
    case systemPushNotificationAllowed
    case systemPushNotificationDenied
    case googleLogin
    case appleLogin
    case emailLogin
    case registerPush
    case detectApp
    case apiReport
    case networkError
    case negativeFeedback
    case shareViaEmail
    case shareViaSMS
    case shareViaWhatsapp
    case viewStream
    case channelViewTime
    case changeChannel
    case leaveNews
    case pageLoadDetail
    case clickVideo
    case videoPlay
    case videoPlaying
    case videoEnd
    case videoFailed
    case videoLoadTime
    case fullArticleFinishedLoading
    case pageLoadFailure
    case readFullArticle
    case followMediaAccount
    case unfollowMediaAccount
    case checkUserProfile
    case thumbUpDoc
    case thumbDownDoc
    case enterVideo
    case shareButton
    case shareDestination
    case shareSendResult
    case didGrantLocationPermission
    case didDenyLocationPermission
    case didLocationUndetermined
    case loadFeedReturnError
    case reactionDetailClick
    case showSearchHomePage
    case doSearch
    case fetchedSearchResults
    case searchResultClick
    case searchSortChange
    case fetchedNoResults
    case followWidgetExposure
    case clickHyperlink
    case autoLogin
    case getUserInfo

    // App State
    case newSession
    case usageDuration

    case clickFeedArticleMoreButton

    // Comment
    case commentTopShow
    case commentAllShow
    case commentShow
    case commentReplyClick
    case commentReplyFinish
    case commentCommentClick
    case commentCommentFinish
    case commentShowRepliesClick
    case thumbUpComment
    case thumbDownComment
    case commentThreePointClick
    case commentShareClick
    case commentDuration
    case commentReportShow
    case commentReportReason
    case commentBlockUser
    case commentCollapsedClick
    case viewComment
    case postComment
    case postReply
    case leaveCommentsView
    case commentGuidelinesClick
    case ugcPinComment
    case noCommentViewShow
    case writeCommentButtonClick

    // Notification Comment
    case notificationCommentShow
    case commentAppealClick
    case commentAppealComplete

    // negative feedback
    case negativeFeedbackShow
    case undoNegativeFeedbackClick
    case negativeFeedbackSubmit

    // location picker
    case showLocationPicker
    case clickPrimeLocationChange
    case clickAddMoreLocations
    case clickLocationSearchBar
    case setPrimeLocation
    case addLocationSearchSelect
    case removeLocation

    // ModuleView
    case moduleViewMore
    case moduleClick

    // Feed Prompt
    case feedActionPromptClick
    case feedActionPromptDismiss

    // Checked View Logging New
    case checkedViewNew

    // Topic follow
    case topicFollow
    case topicUnfollow
    case topicsSelected

    // Upload Video
    case ugcEnterPostManagement
    case ugcCreateVideo
    case ugcLostPermission
    case ugcVideoOpenCamera
    case ugcDiscardPost
    case ugcVideoUpload
    case ugcCreateVideoCompleted
    case ugcEnterMetadata
    case ugcEnterDetailedLocation
    case ugcSelectedLocation
    case ugcSubmitPost
    case ugcSubmitPostFinished

    // Video management
    case ugcEnterFollowerList
    case ugcClickFollower
    case ugcViewPost
    case ugcDeletePost
    case showInboxTab
    case ugcClickActivityMessage
    case carouselCreateVideo

    // Push Prompt
    case pushPromptClick

    //short post
    case ugcCommentDropdown

    // Profile
    case profilePageEnter

    // Save Article
    case likeDoc
    case unlikeDoc
    
    // Summary Article
    case summaryDoc

    //video campaign
    case ugcEnterPrompt
    case ugcCheckPrompt
    case ugcCreateFromPrompt

    // System Notification Change
    case pushStatusChange

    case clickPushChannel
    case clickPushWebUrl
    case beginSearchChannel
    case pushAlive
    case addChannels
    case removeChannels
    case streamRefresh
    case cancelPushDoc
    
    // Safety Map
    case safetyMapMarkersAgg
    case safetyMapMarkersScattered
    case safetyMapDuration
    case safetyMapAction
    case safetyMapNotificationOnBanner
    case safetyMapGpsOnBanner
    case safetyMapLocOpt
    case crimeReportDuration
    case shareCrimeReport
    
    // Onboarding
    case recAccountPage
    case recAccountYes
    case recAccountNo
    
    // Full Article
    case fullArticleCrimeMapBtnClick
    case fullArticleCrimeMapBtnView
    case fullArticleCrimeMapImgClick
    case fullArticleCrimeMapImgView
    case fullArticleShareBtnView
    case fullArticleShareBtnFacebookClick
    case fullArticleShareBtnSmsClick
    case fullArticleShareBtnEmailClick
    case fullArticleShareBtnMessengerClick
    case fullArticleShareBtnCopyClick
    
    // Election
    case elecNaviClick
    case elecStateSelect
    case elecStatePage
    case elecStateDone
    case elecCandClick
    
    //Shortcut
    case openShortcut
    
    //Spotlight
    case openSpotlight
}

extension MetricEvent {
    public var shouldForwardToApmTool: Bool {
        switch self {
        case .usageDuration:
            return false
        case .imageDownloadReport:
            return false
        case .imageDownloadErrorReport:
            return false
        case .openApp:
            return false
        case .closeApp:
            return false
        default:
            return true
        }
    }
}
