//
//  Capitaluser.h
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 1/15/13.
//  Copyright (c) 2013 StackMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "SMUserManagedObject.h"

@class Animal;

@interface Capitaluser : SMUserManagedObject

@property (nonatomic, retain) NSString * userName;
@property (nonatomic, retain) Animal *animal;

@end
