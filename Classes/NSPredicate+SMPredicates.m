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

#import "NSPredicate+SMPredicates.h"

@implementation NSPredicate (SMPredicates)

+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point {
    
    NSString *pointString = [NSString stringWithFormat:@"%f%@%f",  point.latitude, GEO_DIV, point.longitude];
    
    return [NSPredicate predicateWithFormat:@"%@%@%@%@%f%@%@", GEOQUERY_MILES, FIELD_DIV, field, FIELD_DIV, miles, FIELD_DIV, pointString];
}

+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOfGeoPoint:(SMGeoPoint *)geoPoint {
    
    CLLocationCoordinate2D point;
    point.latitude = [geoPoint.latitude doubleValue];
    point.longitude = [geoPoint.longitude doubleValue];
    
    return [NSPredicate predicateWhere:field isWithin:miles milesOf:point];
}

+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point {
    
    NSString *pointString = [NSString stringWithFormat:@"%f%@%f",  point.latitude, GEO_DIV, point.longitude];
    
    return [NSPredicate predicateWithFormat:@"%@%@%@%@%f%@%@", GEOQUERY_KILOMETERS, FIELD_DIV, field, FIELD_DIV, kilometers, FIELD_DIV, pointString];
}

+ (NSPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOfGeoPoint:(SMGeoPoint *)geoPoint {
    
    CLLocationCoordinate2D point;
    point.latitude = [geoPoint.latitude doubleValue];
    point.longitude = [geoPoint.longitude doubleValue];
    
    return [NSPredicate predicateWhere:field isWithin:kilometers kilometersOf:point];
}

+ (NSPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne {
   
    NSString *swString = [NSString stringWithFormat:@"%f%@%f",  sw.latitude, GEO_DIV, sw.longitude];
    NSString *neString = [NSString stringWithFormat:@"%f%@%f",  ne.latitude, GEO_DIV, ne.longitude];
    
    return [NSPredicate predicateWithFormat:@"%@%@%@%@%@%@%@", GEOQUERY_BOUNDS, FIELD_DIV, field, FIELD_DIV, swString, FIELD_DIV, neString];
}

+ (NSPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWGeoPoint:(SMGeoPoint *)sw andNEGeoPoint:(SMGeoPoint *)ne {
    
    CLLocationCoordinate2D swCorner;
    swCorner.latitude = [sw.latitude doubleValue];
    swCorner.longitude = [sw.longitude doubleValue];
    
    CLLocationCoordinate2D neCorner;
    neCorner.latitude = [ne.latitude doubleValue];
    neCorner.longitude = [ne.longitude doubleValue];
    
    return [NSPredicate predicateWhere:field isWithinBoundsWithSWCorner:swCorner andNECorner:neCorner];
}

+ (NSPredicate *)predicateWhere:(NSString *)field near:(CLLocationCoordinate2D)point {
    
    NSString *pointString = [NSString stringWithFormat:@"%f%@%f",  point.latitude, GEO_DIV, point.longitude];
    
    return [NSPredicate predicateWithFormat:@"%@%@%@%@%@", GEOQUERY_NEAR, FIELD_DIV, field, FIELD_DIV, pointString];
}

+ (NSPredicate *)predicateWhere:(NSString *)field nearGeoPoint:(SMGeoPoint *)geoPoint {
    
    CLLocationCoordinate2D point;
    point.latitude = [geoPoint.latitude doubleValue];
    point.longitude = [geoPoint.longitude doubleValue];
    
    return [NSPredicate predicateWhere:field near:point];
}

@end
