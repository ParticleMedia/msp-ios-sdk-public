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
 * The POBDSATransparencyInfo class represents the transparency information for DSA (Digital Services Act) compliance.
 * It provides the domain name and user parameters for platform or sell-side use.
 */
@interface POBDSATransparencyInfo : NSObject

/** Domain of the entity that applied user parameters for DSA. */
@property (nonatomic) NSString *domainName;

/**
 * An array of NSNumber objects representing user parameters for platform or sell-side use.
 * This property stores an array of integers, encapsulated as NSNumber objects,
 * that can be used by the platform or sell-side for DSA compliance.
 */
@property (nonatomic) NSArray<NSNumber *> *userParams;

- (instancetype)init NS_UNAVAILABLE;

/**
 * Creates and returns a POBDSATransparencyInfo instance based on the provided dictionary.
 *
 * @param dsaInfo A dictionary containing the data needed to build a POBDSATransparencyInfo object.
 * @return A newly created POBDSATransparencyInfo instance populated with the data from the passed dictionary.
 */
+ (POBDSATransparencyInfo *)buildWithDictionary:(NSDictionary *)dsaInfo;

/**
 * Creates a unique, comma-separated string of user parameters from an array of transparency info objects.
 *
 * @param transparencyInfoArray An array of POBDSATransparencyInfo objects containing user parameters.
 * @return A string containing unique user parameters sorted in ascending order and joined by commas.
 *         Returns an empty string if the input array is empty or contains no user parameters.
 */
+ (NSString *)uniqueUserParamsStringFromArray:(NSArray<POBDSATransparencyInfo *> *)transparencyInfoArray;

@end

NS_ASSUME_NONNULL_END
