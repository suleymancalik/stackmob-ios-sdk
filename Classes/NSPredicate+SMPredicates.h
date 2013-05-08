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
#import "SMGeoPoint.h"

#define FIELD_DIV @"####"
#define GEO_DIV @"//"
#define GEOQUERY_MILES @"SMGeoQueryWithinMiles"
#define GEOQUERY_KILOMETERS @"SMGeoQueryWithinKilometers"
#define GEOQUERY_BOUNDS @"SMGeoQueryWithinBounds"
#define GEOQUERY_NEAR @"SMGeoQueryNear"



@interface NSPredicate (SMPredicates)

/**
 Add the predicate criteria: `field`'s location is within `miles` of `point`.
 
 StackMob will generate a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `point`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param miles Distance in miles.
 @param point The point around which to search.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point;

/**
 Add the predicate criteria: `field`'s location is within `miles` of `geoPoint`.
 
 StackMob will generate a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `geoPoint`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param miles Distance in miles.
 @param geoPoint The SMGeoPoint around which to search.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOfGeoPoint:(SMGeoPoint *)geoPoint;

/**
 Add the predicate criteria: `field`'s location is within `kilometers` of `point`.
 
 StackMob will generate a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `point`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param kilometers Distance in kilometers.
 @param point The point around which to search.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point;

/**
 Add the predicate criteria: `field`'s location is within `kilometers` of `geoPoint`.
 
 StackMob will generate a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `geoPoint`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param kilometers Distance in kilometers.
 @param geoPoint The SMGeoPoint around which to search.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOfGeoPoint:(SMGeoPoint *)geoPoint;

/**
 Add the predicate criteria: `field`'s location falls within the bounding box with corners `sw` and `ne`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param sw Location of the bounding box's southwest corner.
 @param ne Location of the bounding box's northeast corner.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne;

/**
 Add the predicate criteria: `field`'s location falls within the bounding box with corners `sw` and `ne`.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param sw SMGeoPoint of the bounding box's southwest corner.
 @param ne SMGeoPoint of the bounding box's northeast corner.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWGeoPoint:(SMGeoPoint *)sw andNEGeoPoint:(SMGeoPoint *)ne;

/**
 Add the predicate criteria: `field`'s location near point.
 
 StackMob will insert a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `point`.
 
 @note You probably want to apply a limit when including this predicate or you may end up with more results than intended.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param point The reference location.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field near:(CLLocationCoordinate2D)point;

/**
 Add the predicate criteria: `field`'s location near point.
 
 StackMob will insert a field `distance` and insert it into the response. This field is the distance between the query `field`'s location and `geoPoint`.
 
 @note You probably want to apply a limit when including this predicate or you may end up with more results than intended.
 
 @param field The geo field in the StackMob schema that is to be compared.
 @param geoPoint The reference SMGeoPoint.
 
 @return An SMPredicate instance ready to be added to a fetch request.
 
 @since Available in iOS SDK 1.5.0 and later.
 */
+ (NSPredicate *)predicateWhere:(NSString *)field nearGeoPoint:(SMGeoPoint *)geoPoint;

@end
