//
//  User3.h
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 10/9/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "StackMob.h"
#import "SMModel.h"

@interface User3 : SMUserManagedObject <SMModel>

@property (nonatomic, retain) NSString * username;

@end
