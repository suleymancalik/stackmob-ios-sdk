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

- (void)saveOnSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock;

- (void)saveWithSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock;

- (BOOL)saveAndWait:(NSError *__autoreleasing*)error;

- (NSArray *)executeFetchRequestAndWait:(NSFetchRequest *)request error:(NSError *__autoreleasing *)error;

- (void)executeFetchRequest:(NSFetchRequest *)request onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock;

- (void)executeFetchRequest:(NSFetchRequest *)request successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock;
@end
