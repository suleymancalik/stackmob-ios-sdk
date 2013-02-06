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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

/**
 `SMPredicate` is a subclass of NSPredicate, with additional methods to build predicates that are specific to the StackMob API.  
 
 @note Fetching from the cache using SMPredicate is not supported, and will return an empty array of results.
 
 
 ## References ##
 
 [Apple's NSPredicate class reference](https://developer.apple.com/library/mac/#documentation/Cocoa/Reference/Foundation/Classes/NSPredicate_Class/Reference/NSPredicate.html)
 */

@interface SMPredicate : NSPredicate


#pragma mark - Creating an SMPredicate
///-------------------------------
/// @name Initialize
///-------------------------------

/**
 Initializes an `SMPredicate` object.
 */
- (id)init;


#pragma mark - Where clauses
///-------------------------------
/// @name Geo Location Clauses
///-------------------------------

/**
 Add the predicate criteria: `field`'s location is within `miles` of `point`.
 
 @note StackMob will generate a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `point`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param miles Distance in miles.
 @param point The point around which to search.
 */

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point;

/**
 Add the predicate criteria: `field`'s location is within `kilometers` of `point`.
 
 @note StackMob will generate a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `point`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param kilometers Distance in kilometers.
 @param point The point around which to search.
 */

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point;

/**
 Add the predicate criteria: `field`'s location falls within the bounding box with corners `sw` and `ne`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param sw Location of the bounding box's southwest corner.
 @param ne Location of the bounding box's northeast corner.
 */

+(SMPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne;

/**
 StackMob will insert a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `location`.
 
 @note You probably want to apply a limit when including this predicate or you may end up with more results than intended.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param location The reference location.
 */

+(SMPredicate *)predicateWhere:(NSString *)field near:(CLLocationCoordinate2D)point;

@end
