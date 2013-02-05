/*
 * Copyright 2013 StackMob
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

typedef NS_ENUM(NSUInteger, SMPredicateOperatorType) {
    SMGeoQueryWithinMilesOperatorType = 0,
    SMGeoQueryWithinKilometersOperatorType,
    SMGeoQueryWithinBoundsOperatorType,
    SMGeoQueryNearOperatorType
};

#define GEOQUERY_FIELD @"field"
#define GEOQUERY_MILES @"miles"
#define GEOQUERY_KILOMETERS @"kilometers"
#define GEOQUERY_LAT @"latitude"
#define GEOQUERY_LONG @"longitude"
#define GEOQUERY_COORDINATE @"coordinate"
#define GEOQUERY_SW_BOUND @"sw"
#define GEOQUERY_NE_BOUND @"ne"

@interface SMPredicate : NSPredicate

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point;

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point;

+(SMPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne;

+(SMPredicate *)predicateWhere:(NSString *)field near:(CLLocationCoordinate2D)point;

@end
