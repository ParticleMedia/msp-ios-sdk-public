/*
* PubMatic Inc. ("PubMatic") CONFIDENTIAL
* Unpublished Copyright (c) 2006-2024 PubMatic, All Rights Reserved.
*
* NOTICE:  All information contained herein is, and remains the property of PubMatic. The intellectual and technical concepts contained
* herein are proprietary to PubMatic and may be covered by U.S. and Foreign Patents, patents in process, and are protected by trade secret or copyright law.
* Dissemination of this information or reproduction of this material is strictly forbidden unless prior written permission is obtained
* from PubMatic.  Access to the source code contained herein is hereby forbidden to anyone except current PubMatic employees, managers or contractors who have executed
* Confidentiality and Non-disclosure agreements explicitly covering such access or to such other persons whom are directly authorized by PubMatic to access the source code and are subject to confidentiality and nondisclosure obligations with respect to the source code.
*
* The copyright notice above does not evidence any actual or intended publication or disclosure  of  this source code, which includes
* information that is confidential and/or proprietary, and is a trade secret, of  PubMatic.   ANY REPRODUCTION, MODIFICATION, DISTRIBUTION, PUBLIC  PERFORMANCE,
* OR PUBLIC DISPLAY OF OR THROUGH USE  OF THIS  SOURCE CODE  WITHOUT  THE EXPRESS WRITTEN CONSENT OF PUBMATIC IS STRICTLY PROHIBITED, AND IN VIOLATION OF APPLICABLE
* LAWS AND INTERNATIONAL TREATIES.  THE RECEIPT OR POSSESSION OF  THIS SOURCE CODE AND/OR RELATED INFORMATION DOES NOT CONVEY OR IMPLY ANY RIGHTS
* TO REPRODUCE, DISCLOSE OR DISTRIBUTE ITS CONTENTS, OR TO MANUFACTURE, USE, OR SELL ANYTHING THAT IT  MAY DESCRIBE, IN WHOLE OR IN PART.
*/

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/** 
 @abstract Config class holding parameters required to initialize OpenWrap SDK.
 Use it with OpenWrapSDK's initialize API.
 */
@interface OpenWrapSDKConfig : NSObject

/**
 @abstract Identifier of the publisher.
 */
@property (nonatomic, readonly) NSString *publisherId;

/**
 @abstract Array of profile Identifier
 */
@property (nonatomic, readonly) NSArray<NSNumber *> *profileIds;

/**
 @abstract Initializes an instance of OpenWrapSDKConfig with a publisher id and list of profile ids.
 @param publisherId Unique publisher identifier assigned at the time of account creation.
 @param profileIds Array of Profile id
 @return An instance of OpenWrapSDKConfig initialized with the given publisher and profile IDs.
*/
- (instancetype)initWithPublisherId:(NSString *)publisherId andProfileIds:(NSArray<NSNumber *> *)profileIds;

/**
 @abstract Mark default initializer method as unavailable to prevents the creation of
 an OpenWrapSDKConfig instance without the necessary configuration parameters.
 */
- (instancetype)init NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
