//
//  MSPConstants.swift
//  MSPiOSCore
//
//  Created by Huanzhi Zhang on 3/12/25.
//

public struct MSPConstants {
    public static let GOOGLE_AD_MULTI_CONTENT_URLS = "google_ads_multi_content_urls"
    public static let USER_ID = "user_id"
    public static let USE_NOVA_SANDBOX = "use_nova_sandbox"

    public static let TEST_PARAM_KEY_DEBUG_ITEM = "debug_item"

    // User defaults key used to store NB user id.
    public static let USER_DEFAULTS_KEY_MSP_USER_ID = "msp_user_id"
    /* User defaults key used to store msp id fetched from id server.
     * mspId is a parameter of MES user_signal event.
     * If there is already msp_user_id, propagate its value to msp_id.
     * Otherwise fetch an id from id server and set its value
     * to both msp_user_id and msp_id.
     */
    public static let USER_DEFAULTS_KEY_MSP_ID = "msp_id"

    public static let AD_INFO_OPENRTB_NURL = "nurl"
    public static let AD_INFO_OPENRTB_BURL = "burl"

    public static let AD_INFO_PRICE = "price"
    public static let AD_INFO_NETWORK_NAME = "networkName"
    public static let AD_INFO_NETWORK_AD_UNIT_ID = "networkAdUnitId"
    public static let AD_INFO_NETWORK_CREATIVE_ID = "networkCreativeId"
    public static let AD_INFO_BID_REQUEST_ID = "bidRequestId"

    public static let AD_INFO_NOVA_AD_ID = "novaAdId"
    public static let AD_INFO_NOVA_AD_SET_ID = "novaAdSetId"
    public static let AD_INFO_NOVA_AD_REQUEST_ID = "novaAdRequestId"
    public static let AD_INFO_NOVA_AD_ENCRYPTED_TOKEN = "novaEncryptedToken"

    public static let USER_SIGNAL_APP_INSTALL_TIME = "app_install_time"
    public static let USER_SIGNAL_IS_FIRST_INSTALL = "is_first_install"
    public static let USER_SIGNAL_PPID = "ppid"

    /// Wire-protocol value for the rewarded video ad format. Sent on the Nova bid request
    /// `ad_format` field (FR-017b) and on the rewarded MES `imp.ext.ad_format`. Defined by
    /// the Nova ad-serving contract; coordinate with backend before changing.
    public static let AD_FORMAT_REWARDED_VIDEO = "rewarded_video"
}
