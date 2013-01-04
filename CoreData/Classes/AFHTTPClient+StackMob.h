//
//  AFHTTPClient+StackMob.h
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 12/18/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import "AFHTTPClient.h"

@interface AFHTTPClient (StackMob)

- (void)enqueueBatchOfHTTPRequestOperations:(NSArray *)operations
                       completionBlockQueue:(dispatch_queue_t)queue
                              progressBlock:(void (^)(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations))progressBlock
                            completionBlock:(void (^)(NSArray *operations))completionBlock;

@end
