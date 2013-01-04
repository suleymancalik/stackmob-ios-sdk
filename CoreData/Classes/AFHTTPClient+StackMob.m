//
//  AFHTTPClient+StackMob.m
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 12/18/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import "AFHTTPClient+StackMob.h"
#import "AFHTTPRequestOperation.h"

typedef void (^AFCompletionBlock)(void);

@implementation AFHTTPClient (StackMob)

- (void)enqueueBatchOfHTTPRequestOperations:(NSArray *)operations
                       completionBlockQueue:(dispatch_queue_t)completionBlockQueue
                              progressBlock:(void (^)(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations))progressBlock
                            completionBlock:(void (^)(NSArray *operations))completionBlock
{
    __block dispatch_group_t dispatchGroup = dispatch_group_create();
    NSBlockOperation *batchedOperation = [NSBlockOperation blockOperationWithBlock:^{
        dispatch_queue_t theCompletionBlockQueue = completionBlockQueue ? completionBlockQueue : dispatch_get_main_queue();
        dispatch_group_notify(dispatchGroup, theCompletionBlockQueue, ^{
            if (completionBlock) {
                completionBlock(operations);
            }
        });
        
#if !OS_OBJECT_USE_OBJC
        dispatch_release(dispatchGroup);
#endif
    }];
    
    for (AFHTTPRequestOperation *operation in operations) {
        AFCompletionBlock originalCompletionBlock = [operation.completionBlock copy];
        operation.completionBlock = ^{
            dispatch_queue_t queue = operation.successCallbackQueue ?: dispatch_get_main_queue();
            dispatch_group_async(dispatchGroup, queue, ^{
                if (originalCompletionBlock) {
                    originalCompletionBlock();
                }
                
                __block NSUInteger numberOfFinishedOperations = 0;
                [operations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    if ([(NSOperation *)obj isFinished]) {
                        numberOfFinishedOperations++;
                    }
                }];
                
                if (progressBlock) {
                    progressBlock(numberOfFinishedOperations, [operations count]);
                }
                
                dispatch_group_leave(dispatchGroup);
            });
        };
        
        dispatch_group_enter(dispatchGroup);
        [batchedOperation addDependency:operation];
        
        [self enqueueHTTPRequestOperation:operation];
    }
    [self.operationQueue addOperation:batchedOperation];
}


@end
