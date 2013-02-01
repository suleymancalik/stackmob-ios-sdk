//
//  SMPredicate.m
//  stackmob-ios-sdk
//
//  Created by Carl Atupem on 1/30/13.
//  Copyright (c) 2013 StackMob. All rights reserved.
//

#import "SMPredicate.h"

@implementation SMPredicate 

- (id)init {
    
    if (!(self = [super init]))
        return nil;
    
    return self;
}

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point {

    SMPredicate *predicate = [[SMPredicate alloc] init];
    
    NSNumber *latitude = [NSNumber numberWithDouble:point.latitude];
    NSNumber *longitude = [NSNumber numberWithDouble:point.longitude];
    
    NSDictionary *coordinate = [NSDictionary dictionaryWithObjectsAndKeys:latitude, @"latitude", longitude, @"longitude", nil];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [dictionary setValue:GEOQUERY_WITHIN_KILOMETERS forKey:@"predicate"];
    [dictionary setValue:field forKey:@"field"];
    [dictionary setValue:[NSNumber numberWithDouble:kilometers] forKey:@"kilometers"];
    [dictionary setValue:coordinate forKey:@"point"];
    
    predicate.predicateDictionary = [NSDictionary dictionaryWithDictionary:dictionary];
    
    return predicate;
}

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point {
   
    SMPredicate *predicate = [[SMPredicate alloc] init];
    
    NSNumber *latitude = [NSNumber numberWithDouble:point.latitude];
    NSNumber *longitude = [NSNumber numberWithDouble:point.longitude];
    
    NSDictionary *coordinate = [NSDictionary dictionaryWithObjectsAndKeys:latitude, @"latitude", longitude, @"longitude", nil];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [dictionary setValue:GEOQUERY_WITHIN_MILES forKey:@"predicate"];
    [dictionary setValue:field forKey:@"field"];
    [dictionary setValue:[NSNumber numberWithDouble:miles] forKey:@"miles"];
    [dictionary setValue:coordinate forKey:@"point"];
    
    
    predicate.predicateDictionary = [NSDictionary dictionaryWithDictionary:dictionary];
    return predicate;
}

+(SMPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne {
    
    SMPredicate *predicate = [[SMPredicate alloc] init];
    
    NSNumber *swLatitude = [NSNumber numberWithDouble:sw.latitude];
    NSNumber *swLongitude = [NSNumber numberWithDouble:sw.longitude];
    NSDictionary *swCoordinate = [NSDictionary dictionaryWithObjectsAndKeys:swLatitude, @"latitude", swLongitude, @"longitude", nil];
    
    NSNumber *neLatitude = [NSNumber numberWithDouble:ne.latitude];
    NSNumber *neLongitude = [NSNumber numberWithDouble:ne.longitude];
    NSDictionary *neCoordinate = [NSDictionary dictionaryWithObjectsAndKeys:neLatitude, @"latitude", neLongitude, @"longitude", nil];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [dictionary setValue:GEOQUERY_WITHIN_BOUNDS forKey:@"predicate"];
    [dictionary setValue:field forKey:@"field"];
    [dictionary setValue:swCoordinate forKey:@"sw"];
    [dictionary setValue:neCoordinate forKey:@"ne"];
    
    predicate.predicateDictionary = [NSDictionary dictionaryWithDictionary:dictionary];
    
    return predicate;
}

+(SMPredicate *)predicateWhere:(NSString *)field near:(CLLocationCoordinate2D)point {
    
    SMPredicate *predicate = [[SMPredicate alloc] init];
    
    NSNumber *latitude = [NSNumber numberWithDouble:point.latitude];
    NSNumber *longitude = [NSNumber numberWithDouble:point.longitude];
    
    NSDictionary *coordinate = [NSDictionary dictionaryWithObjectsAndKeys:latitude, @"latitude", longitude, @"longitude", nil];
    
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithCapacity:1];
    [dictionary setValue:GEOQUERY_NEAR forKey:@"predicate"];
    
    predicate.predicateDictionary = [NSDictionary dictionaryWithObjectsAndKeys:GEOQUERY_NEAR, @"predicate", field, @"field", point, @"point", nil];
    
    return predicate;
}

@end
