//
//  SMPredicate.h
//  stackmob-ios-sdk
//
//  Created by Carl Atupem on 1/30/13.
//  Copyright (c) 2013 StackMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

#define GEOQUERY_WITHIN_MILES @"withinMiles"
#define GEOQUERY_WITHIN_KILOMETERS @"withinKilometers"
#define GEOQUERY_WITHIN_BOUNDS @"withinBounds"
#define GEOQUERY_NEAR @"near"

@interface SMPredicate : NSPredicate

@property (strong, nonatomic) NSDictionary *predicateDictionary;

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)miles milesOf:(CLLocationCoordinate2D)point;

+(SMPredicate *)predicateWhere:(NSString *)field isWithin:(CLLocationDistance)kilometers kilometersOf:(CLLocationCoordinate2D)point;

+(SMPredicate *)predicateWhere:(NSString *)field isWithinBoundsWithSWCorner:(CLLocationCoordinate2D)sw andNECorner:(CLLocationCoordinate2D)ne;

+(SMPredicate *)predicateWhere:(NSString *)field near:(CLLocationCoordinate2D)point;

@end
