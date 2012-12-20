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

- (void)performSaveOnSuccess:(void (^)())successBlock onFailure:(void (^)(NSError *error))failureBlock;
- (BOOL)performSaveAndWait:(NSError *__autoreleasing*)error;

@end
