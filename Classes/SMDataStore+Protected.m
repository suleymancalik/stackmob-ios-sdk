/*
 * Copyright 2012 StackMob
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

#import "SMDataStore+Protected.h"
#import "SMError.h"
#import "SMJSONRequestOperation.h"
#import "SMRequestOptions.h"
#import "SMNetworkReachability.h"

@implementation SMDataStore (SpecialCondition)

- (NSError *)errorFromResponse:(NSHTTPURLResponse *)response JSON:(id)JSON
{
    return [NSError errorWithDomain:HTTPErrorDomain code:response.statusCode userInfo:JSON];
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForSchema:(NSString *)schema withSuccessBlock:(SMDataStoreSuccessBlock)successBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(JSON, schema);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForObjectId:(NSString *)theObjectId ofSchema:(NSString *)schema withSuccessBlock:(SMDataStoreObjectIdSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(theObjectId, schema);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForSuccessBlock:(SMSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock();
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForResultSuccessBlock:(SMResultSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(JSON);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForResultsSuccessBlock:(SMResultsSuccessBlock)successBlock 
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock(JSON);
        }
    };
}

- (SMFullResponseSuccessBlock)SMFullResponseSuccessBlockForQuerySuccessBlock:(SMResultsSuccessBlock)successBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, id JSON)
    {
        if (successBlock) {
            successBlock((NSArray *)JSON);
        }
    };
}


- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForObject:(NSDictionary *)theObject ofSchema:(NSString *)schema withFailureBlock:(SMDataStoreFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(error, theObject, schema) : failureBlock([self errorFromResponse:response JSON:JSON], theObject, schema);
        }
    };
}

- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForObjectId:(NSString *)theObjectId ofSchema:(NSString *)schema withFailureBlock:(SMDataStoreObjectIdFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(error, theObjectId, schema) : failureBlock([self errorFromResponse:response JSON:JSON], theObjectId, schema);
        }
    };
}

- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForFailureBlock:(SMFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(error) : failureBlock([self errorFromResponse:response JSON:JSON]);
        }
    };
}

- (SMFullResponseFailureBlock)SMFullResponseFailureBlockForObject:(NSDictionary *)theObject options:(SMRequestOptions *)options originalSuccessBlock:(SMResultSuccessBlock)originalSuccessBlock coreDataSaveFailureBlock:(SMCoreDataSaveFailureBlock)failureBlock
{
    return ^void(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON)
    {
        if (failureBlock) {
            response == nil ? failureBlock(request, error, theObject, options, originalSuccessBlock) : failureBlock(request, [self errorFromResponse:response JSON:JSON], theObject, options, originalSuccessBlock);
        }
    };
}

- (int)countFromRangeHeader:(NSString *)rangeHeader results:(NSArray *)results
{
    if (rangeHeader == nil) {
        //No range header means we've got all the results right here (1 or 0)
        return [results count];
    } else {
        NSArray* parts = [rangeHeader componentsSeparatedByString: @"/"];
        if ([parts count] != 2) return -1;
        NSString *lastPart = [parts objectAtIndex: 1];
        if ([lastPart isEqualToString:@"*"]) return -2;
        if ([lastPart isEqualToString:@"0"]) return 0;
        int count = [lastPart intValue];
        if (count == 0) return -1; //real zero was filtered out above
        return count;
    } 
}

- (void)readObjectWithId:(NSString *)theObjectId inSchema:(NSString *)schema parameters:(NSDictionary *)parameters options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMDataStoreSuccessBlock)successBlock onFailure:(SMDataStoreObjectIdFailureBlock)failureBlock
{
    if (theObjectId == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(error, theObjectId, schema);
        }
    } else {
        NSString *path = [[schema lowercaseString] stringByAppendingPathComponent:[self URLEncodedStringFromValue:theObjectId]];
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"GET" path:path parameters:parameters];
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForSchema:schema withSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObjectId:theObjectId ofSchema:schema withFailureBlock:failureBlock];
        [self queueRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}

- (void)refreshAndRetry:(NSURLRequest *)request requestSuccessCallbackQueue:(dispatch_queue_t)successCallbackQueue requestFailureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMFullResponseSuccessBlock)successBlock onFailure:(SMFullResponseFailureBlock)failureBlock
{
    if (self.session.refreshing) {
        if (failureBlock) {
            dispatch_async(failureCallbackQueue, ^{
                NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenInProgress userInfo:nil];
                failureBlock(request, nil, error, nil);
            });
        }
    } else {
        __block SMRequestOptions *options = [SMRequestOptions options];
        [options setTryRefreshToken:NO];
        __block dispatch_queue_t newQueueForRefresh = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
        [self.session refreshTokenWithSuccessCallbackQueue:newQueueForRefresh failureCallbackQueue:newQueueForRefresh onSuccess:^(NSDictionary *userObject) {
            [self queueRequest:[self.session signRequest:request] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
        } onFailure:^(NSError *theError) {
            if (failureBlock) {
                __block NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenFailed userInfo:[NSDictionary dictionaryWithObjectsAndKeys:theError, @"RefreshErrorObject", nil]];
                dispatch_async(failureCallbackQueue, ^{
                    failureBlock(request, nil, error, nil);
                });
            }
        }];
    }
}

- (AFJSONRequestOperation *)newOperationForRequest:(NSURLRequest *)request options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMFullResponseSuccessBlock)successBlock onFailure:(SMFullResponseFailureBlock)failureBlock
{
    if (options.headers && [options.headers count] > 0) {
        // Enumerate through options and add them to the request header.
        NSMutableURLRequest *tempRequest = [request mutableCopy];
        [options.headers enumerateKeysAndObjectsUsingBlock:^(id headerField, id headerValue, BOOL *stop) {
            [tempRequest setValue:headerValue forHTTPHeaderField:headerField];
        }];
        request = tempRequest;
        
        // Set the headers dictionary to empty, to prevent unnecessary enumeration during recursion.
        options.headers = [NSDictionary dictionary];
    }
    
    SMFullResponseFailureBlock retryBlock = ^(NSURLRequest *originalRequest, NSHTTPURLResponse *response, NSError *error, id JSON) {
        if ([response statusCode] == SMErrorServiceUnavailable && options.numberOfRetries > 0) {
            NSString *retryAfter = [[response allHeaderFields] valueForKey:@"Retry-After"];
            if (retryAfter) {
                [options setNumberOfRetries:(options.numberOfRetries - 1)];
                double delayInSeconds = [retryAfter doubleValue];
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    if (options.retryBlock) {
                        options.retryBlock(originalRequest, response, error, JSON, options, successBlock, failureBlock);
                    } else {
                        [self queueRequest:[self.session signRequest:originalRequest] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:successBlock onFailure:failureBlock];
                    }
                });
            } else {
                if (failureBlock) {
                    failureBlock(originalRequest, response, error, JSON);
                }
            }
        } else if ([error domain] == NSURLErrorDomain && [error code] == -1009) {
            if (failureBlock) {
                NSError *networkNotReachableError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[error userInfo]];
                failureBlock(originalRequest, response, networkNotReachableError, JSON);
            }
        } else {
            if (failureBlock) {
                failureBlock(originalRequest, response, error, JSON);
            }
        }
    };
    
    AFJSONRequestOperation *op = [SMJSONRequestOperation JSONRequestOperationWithRequest:request success:successBlock failure:retryBlock];
    if (successCallbackQueue) {
        [op setSuccessCallbackQueue:successCallbackQueue];
    }
    if (failureCallbackQueue) {
        [op setFailureCallbackQueue:failureCallbackQueue];
    }
    
    return op;
    
}

- (void)queueRequest:(NSURLRequest *)request options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMFullResponseSuccessBlock)onSuccess onFailure:(SMFullResponseFailureBlock)onFailure
{
    if (options.headers && [options.headers count] > 0) {
        // Enumerate through options and add them to the request header.
        NSMutableURLRequest *tempRequest = [request mutableCopy];
        [options.headers enumerateKeysAndObjectsUsingBlock:^(id headerField, id headerValue, BOOL *stop) {
            [tempRequest setValue:headerValue forHTTPHeaderField:headerField];
        }];
        request = tempRequest;
        
        // Set the headers dictionary to empty, to prevent unnecessary enumeration during recursion.
        options.headers = [NSDictionary dictionary];
    }
    
    
    
    if (self.session.refreshToken != nil && options.tryRefreshToken && [self.session accessTokenHasExpired]) {
        [self refreshAndRetry:request requestSuccessCallbackQueue:successCallbackQueue requestFailureCallbackQueue:failureCallbackQueue onSuccess:onSuccess onFailure:onFailure];
    } 
    else {
        SMFullResponseFailureBlock retryBlock = ^(NSURLRequest *originalRequest, NSHTTPURLResponse *response, NSError *error, id JSON) {
            if ([response statusCode] == SMErrorUnauthorized && options.tryRefreshToken) {
                [self refreshAndRetry:originalRequest requestSuccessCallbackQueue:successCallbackQueue requestFailureCallbackQueue:failureCallbackQueue onSuccess:onSuccess onFailure:onFailure];
            } else if ([response statusCode] == SMErrorServiceUnavailable && options.numberOfRetries > 0) {
                NSString *retryAfter = [[response allHeaderFields] valueForKey:@"Retry-After"];
                if (retryAfter) {
                    [options setNumberOfRetries:(options.numberOfRetries - 1)];
                    double delayInSeconds = [retryAfter doubleValue];
                    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
                    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                        if (options.retryBlock) {
                            options.retryBlock(originalRequest, response, error, JSON, options, onSuccess, onFailure);
                        } else {
                            [self queueRequest:[self.session signRequest:originalRequest] options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:onSuccess onFailure:onFailure];
                        }
                    });
                } else {
                    if (onFailure) {
                        onFailure(originalRequest, response, error, JSON);
                    }
                }
            } else if ([error domain] == NSURLErrorDomain && [error code] == -1009) {
                if (onFailure) {
                    NSError *networkNotReachableError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[error userInfo]];
                    onFailure(originalRequest, response, networkNotReachableError, JSON);
                }
            } else {
                if (onFailure) {
                    onFailure(originalRequest, response, error, JSON);
                }
            }
        };
        
        AFJSONRequestOperation *op = [SMJSONRequestOperation JSONRequestOperationWithRequest:request success:onSuccess failure:retryBlock];
        if (successCallbackQueue) {
            [op setSuccessCallbackQueue:successCallbackQueue];
        }
        if (failureCallbackQueue) {
            [op setFailureCallbackQueue:failureCallbackQueue];
        }
        [[self.session oauthClientWithHTTPS:options.isSecure] enqueueHTTPRequestOperation:op];
    }
    
}

- (NSString *)URLEncodedStringFromValue:(NSString *)value
{
    static NSString * const kAFCharactersToBeEscaped = @":/.?&=;+!@#$()~[]";
    
	return (__bridge_transfer  NSString *)CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault, (__bridge CFStringRef)value, nil, (__bridge CFStringRef)kAFCharactersToBeEscaped, CFStringConvertNSStringEncodingToEncoding(NSUTF8StringEncoding));
}

// Operational methods

- (AFJSONRequestOperation *)postOperationForObject:(NSDictionary *)theObject inSchema:(NSString *)schema options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMCoreDataSaveFailureBlock)failureBlock
{
    
    if (theObject == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(nil, error, theObject, options, nil);
        }
        return nil;
    } else {
        NSString *theSchema = schema;
        if ([schema rangeOfCharacterFromSet:[NSCharacterSet characterSetWithCharactersInString:@"/"]].location == NSNotFound) {
            // lowercase the schema for StackMob
            theSchema = [theSchema lowercaseString];
        }
        
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"POST" path:theSchema parameters:theObject];
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForResultSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObject:theObject options:options originalSuccessBlock:successBlock coreDataSaveFailureBlock:failureBlock];
        return [self newOperationForRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}

- (AFJSONRequestOperation *)putOperationForObjectID:(NSString *)theObjectId inSchema:(NSString *)schema update:(NSDictionary *)updatedFields options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMCoreDataSaveFailureBlock)failureBlock
{
    if (theObjectId == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(nil, error, updatedFields, options, nil);
        }
        return nil;
    } else {
        NSString *path = [[schema lowercaseString] stringByAppendingPathComponent:[self URLEncodedStringFromValue:theObjectId]];
        
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"PUT" path:path parameters:updatedFields];
        
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForResultSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObject:updatedFields options:options originalSuccessBlock:successBlock coreDataSaveFailureBlock:failureBlock];
        return [self newOperationForRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}

- (AFJSONRequestOperation *)deleteOperationForObjectID:(NSString *)theObjectId inSchema:(NSString *)schema options:(SMRequestOptions *)options successCallbackQueue:(dispatch_queue_t)successCallbackQueue failureCallbackQueue:(dispatch_queue_t)failureCallbackQueue onSuccess:(SMResultSuccessBlock)successBlock onFailure:(SMCoreDataSaveFailureBlock)failureBlock
{
    if (theObjectId == nil || schema == nil) {
        if (failureBlock) {
            NSError *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:nil];
            failureBlock(nil, error, nil, options, nil);
        }
        return nil;
    } else {
        NSString *path = [[schema lowercaseString] stringByAppendingPathComponent:[self URLEncodedStringFromValue:theObjectId]];
        
        NSMutableURLRequest *request = [[self.session oauthClientWithHTTPS:options.isSecure] requestWithMethod:@"DELETE" path:path parameters:nil];
        SMFullResponseSuccessBlock urlSuccessBlock = [self SMFullResponseSuccessBlockForResultSuccessBlock:successBlock];
        SMFullResponseFailureBlock urlFailureBlock = [self SMFullResponseFailureBlockForObject:nil options:options originalSuccessBlock:successBlock coreDataSaveFailureBlock:failureBlock];
        return [self newOperationForRequest:request options:options successCallbackQueue:successCallbackQueue failureCallbackQueue:failureCallbackQueue onSuccess:urlSuccessBlock onFailure:urlFailureBlock];
    }
}



@end
