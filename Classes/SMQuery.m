/*
 * Copyright 2012 StackMob
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
#import "SMClient.h"

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
    
    NSString *schemaName = SM_LOWERCASE_SCHEMA_NAMES ? [[entity name] lowercaseString] : [entity name];
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
        _schemaName = SM_LOWERCASE_SCHEMA_NAMES ? [schema lowercaseString] : schema;
        _requestParameters = [NSMutableDictionary dictionaryWithCapacity:1];
        _requestHeaders = [NSMutableDictionary dictionaryWithCapacity:1];
    }
    return self;
}

- (void)where:(NSString *)field isEqualTo:(id)value
{
    if(value == nil) {
        [self.requestParameters setValue:@"true"
                                  forKey:CONCAT(field, @"[null]")];
    } else {
        [self.requestParameters setValue:value 
                                  forKey:field];
    }
}

- (void)where:(NSString *)field isNotEqualTo:(id)value
{
    if(value == nil) {
        [self.requestParameters setValue:@"false"
                                  forKey:CONCAT(field, @"[null]")];
    } else {
        [self.requestParameters setValue:value
                                  forKey:CONCAT(field, @"[ne]")];
    }
}

- (void)where:(NSString *)field isLessThan:(id)value
{
    [self.requestParameters setValue:value
                              forKey:CONCAT(field, @"[lt]")];
}

- (void)where:(NSString *)field isLessThanOrEqualTo:(id)value
{
    [self.requestParameters setValue:value
                              forKey:CONCAT(field, @"[lte]")];
}

- (void)where:(NSString *)field isGreaterThan:(id)value
{
    [self.requestParameters setValue:value
                              forKey:CONCAT(field, @"[gt]")];
}

- (void)where:(NSString *)field isGreaterThanOrEqualTo:(id)value
{
    [self.requestParameters setValue:value
                              forKey:CONCAT(field, @"[gte]")];
}

- (void)where:(NSString *)field isIn:(NSArray *)valuesArray
{
    NSString *possibleValues = [valuesArray componentsJoinedByString:@","];
    [self.requestParameters setValue:possibleValues
                              forKey:CONCAT(field, @"[in]")];
}

- (void)where:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point
{
    double radius = miles / EARTH_RADIAN_MILES;
    NSString *withinParam = [NSString stringWithFormat:@"%.6f,%.6f,%.6f",
                             point.latitude, 
                             point.longitude, 
                             radius];
    
    [self.requestParameters setValue:withinParam
                              forKey:CONCAT(field, @"[within]")];
}

- (void)where:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point
{
    double radius = kilometers / EARTH_RADIAN_KM;
    NSString *withinParam = [NSString stringWithFormat:@"%.6f,%.6f,%.6f",
                             point.latitude, 
                             point.longitude, 
                             radius];
    [self.requestParameters setValue:withinParam
                              forKey:CONCAT(field, @"[within]")];
}

- (void)where:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne
{
    NSString *withinParam = [NSString stringWithFormat:@"%.6f,%.6f,%.6f,%.6f",
                             sw.latitude, 
                             sw.longitude,
                             ne.latitude,
                             ne.longitude];                            
    [self.requestParameters setValue:withinParam
                              forKey:CONCAT(field, @"[within]")];
}

// TODO: how do we highlight to the user that this is going to add a 'distance' field and will ignore order by criteria
- (void)where:(NSString *)field near:(CLLocationCoordinate2D)point {
    NSString *nearParam = [NSString stringWithFormat:@"%f,%f",
                           point.latitude, point.longitude];
    
    [self.requestParameters setValue:nearParam 
                              forKey:CONCAT(field, @"[near]")];
}

- (void)fromIndex:(NSUInteger)start toIndex:(NSUInteger)end
{
    NSString *rangeHeader = [NSString stringWithFormat:@"objects=%i-%i", (int)start, (int)end];
    [self.requestHeaders setValue:rangeHeader forKey:@"Range"];
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
    [self.requestHeaders setValue:orderByHeader forKey:@"X-StackMob-OrderBy"];
}

@end
