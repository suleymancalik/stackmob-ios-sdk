//
//  NSManagedObjectContext+Concurrency.m
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 12/17/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import "NSManagedObjectContext+Concurrency.h"

@implementation NSManagedObjectContext (Concurrency)

- (void)saveContextOnSuccess:(void (^)())onSuccess onFailure:(void (^)(NSError *error))onFailure
{
    NSManagedObjectContext *mainContext = self;
    NSManagedObjectContext *privateContext = mainContext.parentContext;
    NSManagedObjectContext *temporaryContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    temporaryContext.parentContext = mainContext;
    
    [temporaryContext performBlock:^{
        // do something that takes some time asynchronously using the temp context
        
        __block NSError *saveError;
        // Save Temporary Context
        if (![temporaryContext save:&saveError]) {
            
            if (onFailure) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    onFailure(saveError);;
                });
            }
            
        } else {
            // Save Main Context
            [mainContext performBlock:^{
                
                if (![mainContext save:&saveError]) {
                    
                    if (onFailure) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                            onFailure(saveError);;
                        });
                    }
                    
                } else {
                    // Main Context should always have a private queue parent
                    if (privateContext) {
                        
                        // Save Private Context to disk
                        [privateContext performBlock:^{
                            
                            if (![privateContext save:&saveError]) {
                                
                                if (onFailure) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        onFailure(saveError);;
                                    });
                                }
                                
                            } else {
                                // Dispatch success block to main thread
                                if (onSuccess) {
                                    dispatch_async(dispatch_get_main_queue(), ^{
                                        onSuccess();
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



@end
