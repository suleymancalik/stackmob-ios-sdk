/*
 * Copyright 2012-2013 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import <CoreLocation/CoreLocation.h>
#import "SMResponseBlocks.h"
#import "SMRequestOptions.h"


/**
 This category provides helper methods to get the latitude and longitude from a GeoPoint dictionary. 
 */
@interface NSDictionary (GeoPoint)

- (NSNumber *)latitude;
- (NSNumber *)longitude;

@end

/**
 `SMGeoPoint` is a subclass of NSDictionary, with helper methods to build GeoPoint dictionaries that are specific to the StackMob API.
 */

@interface SMGeoPoint : NSDictionary

/**
 Initializes an `SMGeoPoint` with the latitude and longitude provided.
 
 @param latitude The latitude, represented as an `NSNumber`.
 @param longitude The longitude, represented as an `NSNumber`.
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */

+ (SMGeoPoint *)geoPointWithLatitude:(NSNumber *)latitude Longitude:(NSNumber *)longitude;

/**
 Initializes an `SMGeoPoint` with the `CLLocationCoordinate2D` provided
 
 @param coordinate The `CLLocationCoordinate2D` coordinate
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */
+ (SMGeoPoint *)geoPointWithCoordinate:(CLLocationCoordinate2D)coordinate;


/**
 Initializes an `SMGeoPoint` with coordinates provided by `SMLocationManager`
 
 @param successBlock <i>typedef void (^SMGeoPointSuccessBlock)(SMGeoPoint *geoPoint)</i>. A block object to execute upon success.
 @param failureBlock <i>typedef void (^SMFailureBlock)(NSError *error)</i>. A block object to execute upon failure.
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */
+ (void)getGeoPointForCurrentLocationOnSuccess:(SMGeoPointSuccessBlock)successBlock onFailure:(SMFailureBlock) failureBlock;

/**
 Initializes an `SMGeoPoint` with coordinates provided by `SMLocationManager`
 
 @param options An options object that contains configurations for this request.
 @param successBlock <i>typedef void (^SMGeoPointSuccessBlock)(SMGeoPoint *geoPoint)</i>. A block object to execute upon success.
 @param failureBlock <i>typedef void (^SMFailureBlock)(NSError *error)</i>. A block object to execute upon failure.
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */
+ (void)getGeoPointForCurrentLocationWithOptions:(SMRequestOptions *)options
                                       onSuccess:(SMGeoPointSuccessBlock)successBlock
                                       onFailure:(SMFailureBlock)failureBlock;

/**
 Initializes an `SMGeoPoint` with coordinates provided by `SMLocationManager`
 
 @param options An options object that contains configurations for this request.
 @param successCallbackQueue The dispatch queue used to execute the success block. If nil is passed, the main queue is used.
 @param failureCallbackQueue The dispatch queue used to execute the failure block. If nil is passed, the main queue is used.
 @param successBlock <i>typedef void (^SMGeoPointSuccessBlock)(SMGeoPoint *geoPoint)</i>. A block object to execute upon success.
 @param failureBlock <i>typedef void (^SMFailureBlock)(NSError *error)</i>. A block object to execute upon failure.
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */
+ (void)getGeoPointForCurrentLocationWithOptions:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMGeoPointSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock;



@end

