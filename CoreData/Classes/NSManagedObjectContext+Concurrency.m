//
//  NSManagedObjectContext+Concurrency.m
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 12/17/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import "NSManagedObjectContext+Concurrency.h"

@implementation NSManagedObjectContext (Concurrency)

- (void)saveOnSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self saveWithSuccessCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)saveWithSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    NSManagedObjectContext *mainContext = nil;
    NSManagedObjectContext *temporaryContext = nil;
    if ([self concurrencyType] == NSMainQueueConcurrencyType) {
        mainContext = self;
        temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        temporaryContext.parentContext = mainContext;
    } else {
        temporaryContext = self;
        mainContext = temporaryContext.parentContext;
    }
    
    
    NSManagedObjectContext *privateContext = mainContext.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should be of type NSMainQueueConcurrencyType"];
    } else if (!privateContext) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should have parent with set persistent store coordinator"];
    }
    
    [temporaryContext performBlock:^{
        
        __block NSError *saveError;
        // Save Temporary Context
        if (![temporaryContext save:&saveError]) {
            
            if (failureBlock) {
                dispatch_async(failureCallbackQueue, ^{
                    failureBlock(saveError);
                });
            }
            
        } else {
            // Save Main Context
            [mainContext performBlock:^{
                
                if (![mainContext save:&saveError]) {
                    
                    if (failureBlock) {
                        dispatch_async(failureCallbackQueue, ^{
                            failureBlock(saveError);
                        });
                    }
                    
                } else {
                    // Main Context should always have a private queue parent
                    if (privateContext) {
                        
                        // Save Private Context to disk
                        [privateContext performBlock:^{
                            
                            if (![privateContext save:&saveError]) {
                                
                                if (failureBlock) {
                                    dispatch_async(failureCallbackQueue, ^{
                                        failureBlock(saveError);
                                    });
                                }
                                
                            } else {
                                // Dispatch success block to main thread
                                if (successBlock) {
                                    dispatch_async(successCallbackQueue, ^{
                                        successBlock();
                                    });
                                }
                                
                            }
                            
                        }];
                        
                    }
                }
                
            }];
            
        }
        
    }];
}



- (BOOL)saveAndWait:(NSError *__autoreleasing*)error
{
    NSManagedObjectContext *mainContext = nil;
    NSManagedObjectContext *temporaryContext = nil;
    if ([self concurrencyType] == NSMainQueueConcurrencyType) {
        mainContext = self;
        temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        temporaryContext.parentContext = mainContext;
    } else {
        temporaryContext = self;
        mainContext = temporaryContext.parentContext;
    }
    
    
    NSManagedObjectContext *privateContext = mainContext.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should be of type NSMainQueueConcurrencyType"];
    } else if (!privateContext) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should have parent with set persistent store coordinator"];
    }
    
    __block BOOL success = NO;
    __block NSError *saveError = nil;
    [temporaryContext performBlockAndWait:^{
        
        // Save Temporary Context
        if ([temporaryContext save:&saveError]) {
            
            // Save Main Context
            [mainContext performBlockAndWait:^{
                
                if ([mainContext save:&saveError]) {
                    
                    // Save Private Context to disk
                    [privateContext performBlockAndWait:^{
                        
                        if ([privateContext save:&saveError]) {
                            
                            success = YES;
                        }
                        
                    }];
                    
                }
                
            }];
            
        }
        
    }];
    
    if (saveError != nil && error != NULL) {
        *error = saveError;
    }
    
    return success;
}

- (void)executeFetchRequest:(NSFetchRequest *)request onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    [self executeFetchRequest:request successCallbackQueue:dispatch_get_main_queue() failureCallbackQueue:dispatch_get_main_queue() onSuccess:successBlock onFailure:failureBlock];
}

- (void)executeFetchRequest:(NSFetchRequest *)request successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultsSuccessBlock)successBlock onFailure:(SMFailureBlock)failureBlock
{
    dispatch_queue_t aQueue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    __block NSManagedObjectContext *mainContext = [self concurrencyType] == NSMainQueueConcurrencyType ? self : self.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should be of type NSMainQueueConcurrencyType"];
    }
    
    dispatch_async(aQueue, ^{
        NSError *fetchError = nil;
        NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [backgroundContext setPersistentStoreCoordinator:mainContext.parentContext.persistentStoreCoordinator];
        [backgroundContext setMergePolicy:[mainContext mergePolicy]];
        NSFetchRequest *fetchCopy = [request copy];
        [fetchCopy setResultType:NSManagedObjectIDResultType];
        
        NSArray *resultsOfFetch = [backgroundContext executeFetchRequest:fetchCopy error:&fetchError];
        if (fetchError) {
            if (failureBlock) {
                dispatch_async(failureCallbackQueue, ^{
                    failureBlock(fetchError);
                });
            }
        } else {
            if (successBlock) {
                dispatch_async(successCallbackQueue, ^{
                    successBlock(resultsOfFetch);
                });
            }
        }
    });
    
}

- (NSArray *)executeFetchRequestAndWait:(NSFetchRequest *)request error:(NSError *__autoreleasing *)error
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    __block NSManagedObjectContext *mainContext = [self concurrencyType] == NSMainQueueConcurrencyType ? self : self.parentContext;
    
    // Error checks
    if ([mainContext concurrencyType] != NSMainQueueConcurrencyType) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Method saveAndWait: main context should be of type NSMainQueueConcurrencyType"];
    }
    
    __block NSArray *resultsOfFetch = nil;
    __block NSError *fetchError = nil;
    
    dispatch_sync(queue, ^{
        NSManagedObjectContext *backgroundContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [backgroundContext setPersistentStoreCoordinator:mainContext.parentContext.persistentStoreCoordinator];
        [backgroundContext setMergePolicy:[mainContext mergePolicy]];
        NSFetchRequest *fetchCopy = [request copy];
        [fetchCopy setResultType:NSManagedObjectIDResultType];
        
        resultsOfFetch = [backgroundContext executeFetchRequest:fetchCopy error:&fetchError];
    });
    
    if (fetchError && error != NULL) {
        *error = fetchError;
    }

    dispatch_release(queue);
    
    return resultsOfFetch;
    
}



@end
