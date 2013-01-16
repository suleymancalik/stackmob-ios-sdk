//
//  Animal.h
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 1/15/13.
//  Copyright (c) 2013 StackMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>

@class Capitaluser;

@interface Animal : NSManagedObject

@property (nonatomic, retain) NSString * animal_id;
@property (nonatomic, retain) NSString * theName;
@property (nonatomic, retain) NSString * theSpecies;
@property (nonatomic, retain) Capitaluser *capitalUser;

@end
