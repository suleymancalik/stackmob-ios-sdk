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
 
 ## Using SMGeoPoint ##
 
 You can make an SMGeoPoint with a latitude and a longitude:
 
    NSNumber *lat = [NSNumber numberWithDouble:37.77215879638275];
    NSNumber *lon = [NSNumber numberWithDouble:-122.4064476357965];

    SMGeoPoint *location = [SMGeoPoint geoPointWithLatitude:lat longitude:lon];
 
 Alternatively, you can use a CLLocationCoordinate2D coordinate:
 
    CLLocationCoordinate2D renoCoordinate = CLLocationCoordinate2DMake(39.537940, -119.783936);

    SMGeoPoint *reno = [SMGeoPoint geoPointWithCoordinate:renoCoordinate];

 To save an SMGeoPoint, store it in a dictionary of arguments to be uploaded to StackMob:
 
    CLLocationCoordinate2D renoCoordinate = CLLocationCoordinate2DMake(39.537940, -119.783936);
      
    SMGeoPoint *location = [SMGeoPoint geoPointWithCoordinate:renoCoordinate];
     
    NSDictionary *arguments = [NSDictionary dictionaryWithObjectsAndKeys:@"My Location", @"name", location, @"location", nil];
     
    [[[SMClient defaultClient] dataStore] createObject:arguments inSchema:@"todo" onSuccess:^(NSDictionary *theObject, NSString *schema) {
        NSLog(@"Created object %@ in schema %@", theObject, schema);
     
    } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
        NSLog(@"Error creating object: %@", theError);
    }];
 
 **Important:** Make sure you configure the proper fields in your schema with the GeoPoint type.
 
 ## Using SMGeoPoint with Core Data ##
 
 GeoPoints are stored in Core Data using the NSTransformable type. To save an SMGeoPoint in Core Data, it must be archived into NSData:
 
     NSNumber *lat = [NSNumber numberWithDouble:37.77215879638275];
     NSNumber *lon = [NSNumber numberWithDouble:-122.4064476357965];
     
     SMGeoPoint *location = [SMGeoPoint geoPointWithLatitude:lat longitude:lon];
     
     NSData *data = [NSKeyedArchiver archivedDataWithRootObject:location];
 
 To query with SMGeoPoints, use the special predicate methods in SMPredicate:
 
     NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
     [fetchRequest setEntity:yourEntity];
     
     // Fisherman's Wharf
     CLLocationCoordinate2D coordinate;
     coordinate.latitude = 37.810317;
     coordinate.longitude = -122.418167;
     
     SMGeoPoint *geoPoint = [SMGeoPoint geoPointWithCoordinate:coordinate];
     SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithin:3.5 milesOfGeoPoint:geoPoint];
     [fetchRequest setPredicate:predicate];
 
 @note Fetching from the cache using SMPredicate is not supported, and will return an empty array of results.
 */
@interface SMGeoPoint : NSDictionary

/**
 Returns an instance of `SMGeoPoint` with the latitude and longitude provided.
 
 @param latitude The latitude, represented as an `NSNumber`.
 @param longitude The longitude, represented as an `NSNumber`.
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */
+ (SMGeoPoint *)geoPointWithLatitude:(NSNumber *)latitude longitude:(NSNumber *)longitude;

/**
 Returns an instance of `SMGeoPoint` with the `CLLocationCoordinate2D` provided
 
 @param coordinate The `CLLocationCoordinate2D` coordinate
 
 @return An `SMGeoPoint`, for use as an attribute or as part of a query.
 */
+ (SMGeoPoint *)geoPointWithCoordinate:(CLLocationCoordinate2D)coordinate;

/**
 Returns an instance of `SMGeoPoint` with coordinates provided by `SMLocationManager`
 
 @param successBlock <i>typedef void (^SMGeoPointSuccessBlock)(SMGeoPoint *geoPoint)</i>. A block object to execute upon success.
 @param failureBlock <i>typedef void (^SMFailureBlock)(NSError *error)</i>. A block object to execute upon failure.
  */
+ (void)getGeoPointForCurrentLocationOnSuccess:(SMGeoPointSuccessBlock)successBlock onFailure:(SMFailureBlock) failureBlock;

/**
 Returns an instance of `SMGeoPoint` with coordinates provided by `SMLocationManager`
 
 @param options An options object that contains configurations for this request.
 @param successBlock <i>typedef void (^SMGeoPointSuccessBlock)(SMGeoPoint *geoPoint)</i>. A block object to execute upon success.
 @param failureBlock <i>typedef void (^SMFailureBlock)(NSError *error)</i>. A block object to execute upon failure.
  */
+ (void)getGeoPointForCurrentLocationWithOptions:(SMRequestOptions *)options
                                       onSuccess:(SMGeoPointSuccessBlock)successBlock
                                       onFailure:(SMFailureBlock)failureBlock;

/**
 Returns an instance of `SMGeoPoint` with coordinates provided by `SMLocationManager`
 
 @param options An options object that contains configurations for this request.
 @param successCallbackQueue The dispatch queue used to execute the success block. If nil is passed, the main queue is used.
 @param failureCallbackQueue The dispatch queue used to execute the failure block. If nil is passed, the main queue is used.
 @param successBlock <i>typedef void (^SMGeoPointSuccessBlock)(SMGeoPoint *geoPoint)</i>. A block object to execute upon success.
 @param failureBlock <i>typedef void (^SMFailureBlock)(NSError *error)</i>. A block object to execute upon failure.
  */
+ (void)getGeoPointForCurrentLocationWithOptions:(SMRequestOptions *)options
                            successCallbackQueue:(dispatch_queue_t)successCallbackQueue
                            failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue
                                       onSuccess:(SMGeoPointSuccessBlock)successBlock
                                       onFailure:(SMFailureBlock)failureBlock;



@end

