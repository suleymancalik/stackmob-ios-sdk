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

#import "SMQuery.h"

#define CONCAT(prefix, suffix) ([NSString stringWithFormat:@"%@%@", prefix, suffix])

#define EARTH_RADIAN_MILES 3956.6
#define EARTH_RADIAN_KM    6367.5

@implementation SMQuery

@synthesize requestParameters = _requestParameters;
@synthesize requestHeaders = _requestHeaders;
@synthesize schemaName = _schemaName;
@synthesize entity = _entity;

- (id)initWithEntity:(NSEntityDescription *)entity
{
    
    NSString *schemaName = [[entity name] lowercaseString];
    return [self initWithSchema:schemaName entity:entity];
    
}

- (id)initWithSchema:(NSString *)schema
{
    return [self initWithSchema:schema entity:nil];
}

- (id)initWithSchema:(NSString *)schema entity:(NSEntityDescription *)entity
{
    self = [super init];
    if (self) {
        _entity = entity;
        _schemaName = [schema lowercaseString];
        _requestParameters = [NSMutableDictionary dictionaryWithCapacity:1];
        _requestHeaders = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return self;
}

- (void)where:(NSString *)field isEqualTo:(id)value
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    if(value == nil) {
        [requestParametersCopy setObject:@"true"
                                  forKey:CONCAT(field, @"[null]")];
    } else {
        [requestParametersCopy setObject:[self marshalValue:value] 
                                  forKey:field];
    }
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isNotEqualTo:(id)value
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    if(value == nil) {
        [requestParametersCopy setObject:@"false"
                                  forKey:CONCAT(field, @"[null]")];
    } else {
        [requestParametersCopy setObject:[self marshalValue:value]
                                  forKey:CONCAT(field, @"[ne]")];
    }
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isLessThan:(id)value
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    [requestParametersCopy setObject:[self marshalValue:value]
                              forKey:CONCAT(field, @"[lt]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isLessThanOrEqualTo:(id)value
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    [requestParametersCopy setObject:[self marshalValue:value]
                              forKey:CONCAT(field, @"[lte]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isGreaterThan:(id)value
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    [requestParametersCopy setObject:[self marshalValue:value]
                              forKey:CONCAT(field, @"[gt]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isGreaterThanOrEqualTo:(id)value
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    [requestParametersCopy setObject:[self marshalValue:value]
                              forKey:CONCAT(field, @"[gte]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isIn:(NSArray *)valuesArray
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    NSString *possibleValues = [valuesArray componentsJoinedByString:@","];
    [requestParametersCopy setObject:possibleValues
                              forKey:CONCAT(field, @"[in]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    double radius = miles / EARTH_RADIAN_MILES;
    NSString *withinParam = [NSString stringWithFormat:@"%.6f,%.6f,%.6f",
                             point.latitude, 
                             point.longitude, 
                             radius];
    
    [requestParametersCopy setObject:withinParam
                              forKey:CONCAT(field, @"[within]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isWithin:(double)miles milesOfGeoPoint:(SMGeoPoint *)geoPoint {
    CLLocationCoordinate2D point;
    point.latitude = [geoPoint.latitude doubleValue];
    point.longitude = [geoPoint.longitude doubleValue];
    
    [self where:field isWithin:miles milesOf:point];
}

- (void)where:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    double radius = kilometers / EARTH_RADIAN_KM;
    NSString *withinParam = [NSString stringWithFormat:@"%.6f,%.6f,%.6f",
                             point.latitude, 
                             point.longitude, 
                             radius];
    [requestParametersCopy setObject:withinParam
                              forKey:CONCAT(field, @"[within]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOfGeoPoint:(SMGeoPoint *)geoPoint {
    CLLocationCoordinate2D point;
    point.latitude = [geoPoint.latitude doubleValue];
    point.longitude = [geoPoint.longitude doubleValue];
    
    [self where:field isWithin:kilometers kilometersOf:point];
}

- (void)where:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne
{
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    NSString *withinParam = [NSString stringWithFormat:@"%.6f,%.6f,%.6f,%.6f",
                             sw.latitude, 
                             sw.longitude,
                             ne.latitude,
                             ne.longitude];                            
    [requestParametersCopy setObject:withinParam
                              forKey:CONCAT(field, @"[within]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field isWithinBoundsWithSWGeoPoint:(SMGeoPoint *)sw andNEGeoPoint:(SMGeoPoint *)ne {
    CLLocationCoordinate2D swCorner;
    swCorner.latitude = [sw.latitude doubleValue];
    swCorner.longitude = [sw.longitude doubleValue];
    
    CLLocationCoordinate2D neCorner;
    neCorner.latitude = [ne.latitude doubleValue];
    neCorner.longitude = [ne.longitude doubleValue];
    
    [self where:field isWithinBoundsWithSWCorner:swCorner andNECorner:neCorner];
}

// TODO: how do we highlight to the user that this is going to add a 'distance' field and will ignore order by criteria
- (void)where:(NSString *)field near:(CLLocationCoordinate2D)point {
    NSMutableDictionary *requestParametersCopy = [self.requestParameters mutableCopy];
    NSString *nearParam = [NSString stringWithFormat:@"%f,%f",
                           point.latitude, point.longitude];
    
    [requestParametersCopy setObject:nearParam 
                              forKey:CONCAT(field, @"[near]")];
    self.requestParameters = [NSDictionary dictionaryWithDictionary:requestParametersCopy];
}

- (void)where:(NSString *)field nearGeoPoint:(SMGeoPoint *)geoPoint {
    CLLocationCoordinate2D point;
    point.latitude = [geoPoint.latitude doubleValue];
    point.longitude = [geoPoint.longitude doubleValue];
    
    [self where:field near:point];
}

- (void)fromIndex:(NSUInteger)start toIndex:(NSUInteger)end
{
    NSString *rangeHeader = [NSString stringWithFormat:@"objects=%i-%i", (int)start, (int)end];
    
    NSMutableDictionary *requestHeadersCopy = [self.requestHeaders mutableCopy];
    [requestHeadersCopy setObject:rangeHeader forKey:@"Range"];
    
    self.requestHeaders = [NSDictionary dictionaryWithDictionary:requestHeadersCopy];
}

// TODO: verify that asking for Range 0-N where N is > the # records doesn't explode
- (void)limit:(NSUInteger)count {
    [self fromIndex:0 toIndex:count-1];
}

- (void)orderByField:(NSString *)field ascending:(BOOL)ascending
{
    NSString *ordering = ascending ? @"asc" : @"desc";
    NSString *orderBy = [NSString stringWithFormat:@"%@:%@", field, ordering];
    
    NSString *existingOrderByHeader = [self.requestHeaders objectForKey:@"X-StackMob-OrderBy"];
    NSString *orderByHeader;
    
    if (existingOrderByHeader == nil) {
        orderByHeader = orderBy; 
    } else {
        orderByHeader = [NSString stringWithFormat:@"%@,%@", existingOrderByHeader, orderBy];
    }
    NSMutableDictionary *requestHeadersCopy = [self.requestHeaders mutableCopy];
    [requestHeadersCopy setObject:orderByHeader forKey:@"X-StackMob-OrderBy"];
    
    self.requestHeaders = [NSDictionary dictionaryWithDictionary:requestHeadersCopy];
}

- (id)marshalValue:(id)value {
    
    if ([value isKindOfClass:[NSDate class]]) {
        
        unsigned long long convertedValue = (unsigned long long)[value timeIntervalSince1970] * 1000;
        
        return [NSNumber numberWithUnsignedLongLong:convertedValue];
    }
    
    return value;
}

@end
