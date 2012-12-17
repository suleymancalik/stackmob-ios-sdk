//
//  NSManagedObjectContext+Concurrency.h
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 12/17/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import <CoreData/CoreData.h>
#import "StackMob.h"

@interface NSManagedObjectContext (Concurrency)

//- (void)save:(NSError *__autoreleasing *)error onSuccess:(void(^)())onSuccess onFailure:(SMFailureBlock)onFailure;
- (void)saveContextOnSuccess:(void (^)())onSuccess onFailure:(void (^)(NSError *error))onFailure;

@end
