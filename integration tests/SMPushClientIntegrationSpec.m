/*
 * Copyright 2012-2013 StackMob
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

#import <Kiwi/Kiwi.h>
#import "SMIntegrationTestHelpers.h"
#import "StackMobPush.h"

SPEC_BEGIN(SMPushClientIntegrationSpec)

describe(@"SMPushClient", ^{

    __block NSString *token0 = @"0000000000000000000000000000000000000000000000000000000000000000";
    __block NSString *token1 = @"1111111111111111111111111111111111111111111111111111111111111111";
    __block NSString *token2 = @"2222222222222222222222222222222222222222222222222222222222222222";
    __block NSString *token3 = @"3333333333333333333333333333333333333333333333333333333333333333";
    __block SMPushClient *defaultClient = nil;
    beforeEach(^{
        // create object to login with, assumes user object name with username/password fields
        defaultClient = [SMIntegrationTestHelpers defaultPushClient];
        
        __block BOOL createSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [defaultClient registerDeviceToken:token0 withUser:@"bodie" onSuccess:^{
                createSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError) {
                createSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        [[theValue(createSuccess) should] beYes];
        
        createSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [defaultClient registerDeviceToken:token1 withUser:@"bodie" onSuccess:^{
                createSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError) {
                createSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        [[theValue(createSuccess) should] beYes];
        
        createSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [defaultClient registerDeviceToken:token2 withUser:@"nola" onSuccess:^{
                createSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError) {
                createSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        [[theValue(createSuccess) should] beYes];
        
    });
    afterEach(^{
        __block BOOL deleteSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [defaultClient deleteToken:token0 onSuccess:^{
                deleteSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError) {
                deleteSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(deleteSuccess) should] beYes];
        
        deleteSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [defaultClient deleteToken:token1 onSuccess:^{
                deleteSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError) {
                deleteSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(deleteSuccess) should] beYes];
        
        deleteSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [defaultClient deleteToken:token2 onSuccess:^{
                deleteSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError) {
                deleteSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(deleteSuccess) should] beYes];
    });
    describe(@"register/delete token", ^{
        it(@"should not register a duplicate token with overwrite flat set to NO", ^{
            __block BOOL failed = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient registerDeviceToken:token1 withUser:@"herc" overwrite:NO onSuccess:^{
                    failed = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    failed = YES;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(failed) should] beYes];
        });
        it(@"should not register an invalid token", ^{
            __block BOOL failed = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient registerDeviceToken:@"tooshort" withUser:@"herc" onSuccess:^{
                    failed = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    failed = YES;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(failed) should] beYes];
        });
        it(@"should register a duplicate token", ^{
            __block BOOL succeeded = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient registerDeviceToken:token1 withUser:@"herc" onSuccess:^{
                    succeeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
        });
        it(@"should register an SMPushToken and the overwrite flag", ^{
            __block BOOL succeeded = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                SMPushToken *token = [[SMPushToken alloc] initWithString:token1];
                [defaultClient registerDeviceToken:token withUser:@"herc" overwrite:YES onSuccess:^{
                    succeeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
        });
        it(@"should register and delete an SMPushToken", ^{
            __block BOOL succeeded = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                SMPushToken *token = [[SMPushToken alloc] initWithString:token3];
                [defaultClient registerDeviceToken:token withUser:@"herc" onSuccess:^{
                    succeeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            
            succeeded = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient deleteToken:token3 onSuccess:^{
                    succeeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = YES;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
        });
        it(@"should register and delete an Android token", ^{
            __block BOOL succeeded = NO;
            __block SMPushToken *token = [[SMPushToken alloc] initWithString:@"helloworld" type:TOKEN_TYPE_ANDROID_GCM];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {

                [defaultClient registerDeviceToken:token withUser:@"kodi" onSuccess:^{
                    succeeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            __block BOOL deleteSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient deleteToken:token onSuccess:^{
                    deleteSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    deleteSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(deleteSuccess) should] beYes];
        });
        pending(@"should not delete a nonexistent token", ^{
            __block BOOL failed;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient deleteToken:@"notatoken" onSuccess:^{
                    failed = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    failed = YES;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(failed) should] beYes];
        });
    });
    describe(@"get tokens for users", ^{
        it(@"should succeed with no results for an nonexistent user", ^{
            __block BOOL succeeded = NO;
            __block NSDictionary *result;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient getTokensForUsers:[NSArray arrayWithObject:@"herc"] onSuccess:^(NSDictionary * tokens){
                    succeeded = YES;
                    result = tokens;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            NSArray *tokenList = [result valueForKey:@"herc"];
            [[theValue([tokenList count]) should] equal:[NSNumber numberWithInt:0]];
        });
        it(@"should succeed for an existing user", ^{
            __block BOOL succeeded = NO;
            __block NSDictionary *result;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient getTokensForUsers:[NSArray arrayWithObject:@"nola"] onSuccess:^(NSDictionary * tokens){
                    succeeded = YES;
                    result = tokens;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            NSArray *tokenList = [result valueForKey:@"nola"];
            [[theValue([tokenList count]) should] equal:[NSNumber numberWithInt:1]];
            SMPushToken *token = [tokenList objectAtIndex:0];
            [[token.tokenString should] equal:token2];
            [[token.type should] equal:TOKEN_TYPE_IOS];
            [theValue(token.registrationTime) shouldNotBeNil];
        });
        it(@"should succeed for an existing user with multiple tokens", ^{
            __block BOOL succeeded = NO;
            __block NSDictionary *result;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient getTokensForUsers:[NSArray arrayWithObject:@"bodie"] onSuccess:^(NSDictionary * tokens){
                    succeeded = YES;
                    result = tokens;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            NSArray *tokenList = [result valueForKey:@"bodie"];
            [[theValue([tokenList count]) should] equal:[NSNumber numberWithInt:2]];
            SMPushToken *firstToken = [tokenList objectAtIndex:0];
            SMPushToken *secondToken = [tokenList objectAtIndex:1];
            if ([[firstToken tokenString] isEqualToString:token1]) {
                SMPushToken *tempToken = firstToken;
                firstToken = secondToken;
                secondToken = tempToken;
            }
            [[firstToken.tokenString should] equal:token0];
            [[firstToken.type should] equal:TOKEN_TYPE_IOS];
            [theValue(firstToken.registrationTime) shouldNotBeNil];
            [[secondToken.tokenString should] equal:token1];
            [[secondToken.type should] equal:TOKEN_TYPE_IOS];
            [theValue(secondToken.registrationTime) shouldNotBeNil];
        });
        
        it(@"should succeed for an android token", ^{
            
            __block BOOL succeeded = NO;
            __block SMPushToken *token = [[SMPushToken alloc] initWithString:@"helloworld" type:TOKEN_TYPE_ANDROID_GCM];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                
                [defaultClient registerDeviceToken:token withUser:@"kodi" onSuccess:^{
                    succeeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            succeeded = NO;
            __block NSDictionary *result;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient getTokensForUsers:[NSArray arrayWithObject:@"kodi"] onSuccess:^(NSDictionary * tokens){
                    succeeded = YES;
                    result = tokens;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
            NSArray *tokenList = [result valueForKey:@"kodi"];
            [[theValue([tokenList count]) should] equal:[NSNumber numberWithInt:1]];
            SMPushToken *firstToken = [tokenList objectAtIndex:0];
            [[firstToken.tokenString should] equal:[token tokenString]];
            [[firstToken.type should] equal:[token type]];
            [theValue(firstToken.registrationTime) shouldNotBeNil];
            
            __block BOOL deleteSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient deleteToken:token onSuccess:^{
                    deleteSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    deleteSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(deleteSuccess) should] beYes];
        });
    });
    /* need to get some realish tokens before enabling this
    describe(@"broadcast", ^{
        it(@"should succeed", ^{
            __block BOOL succeeded = NO;
            __block NSDictionary *result;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                NSMutableDictionary *args = [NSMutableDictionary dictionaryWithCapacity:3];
                [args setValue:@"my push message" forKey:@"alert"];
                [args setValue:[NSNumber numberWithInt:1] forKey:@"badge"];
                [defaultClient broadcastMessage:args onSuccess:^(NSDictionary * tokens){
                    succeeded = YES;
                    result = tokens;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    succeeded = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(succeeded) should] beYes];
        });
    });
     */
    describe(@"push to tokens", ^{
        /* need to get some realish tokens before enabling this
         it(@"should succeed", ^{
         __block BOOL succeeded = NO;
         __block NSDictionary *result;
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
         NSMutableDictionary *args = [NSMutableDictionary dictionaryWithCapacity:3];
         [args setValue:@"my push message" forKey:@"alert"];
         [args setValue:[NSNumber numberWithInt:1] forKey:@"badge"];
         [defaultClient sendMessage:args toTokens:[NSArray arrayWithObject:token0]  onSuccess:^(NSDictionary * tokens){
         succeeded = YES;
         result = tokens;
         syncReturn(semaphore);
         } onFailure:^(NSError *theError) {
         succeeded = NO;
         syncReturn(semaphore);
         }];
         });
         [[theValue(succeeded) should] beYes];
         });
         it(@"should succeed with SMPushToken", ^{
         __block BOOL succeeded = NO;
         __block NSDictionary *result;
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
         NSMutableDictionary *args = [NSMutableDictionary dictionaryWithCapacity:3];
         [args setValue:@"my push message" forKey:@"alert"];
         [args setValue:[NSNumber numberWithInt:1] forKey:@"badge"];
         SMPushToken * token = [[SMPushToken alloc] initWithString:token0];
         [defaultClient sendMessage:args toTokens:[NSArray arrayWithObject:token]  onSuccess:^(NSDictionary * tokens){
         succeeded = YES;
         result = tokens;
         syncReturn(semaphore);
         } onFailure:^(NSError *theError) {
         succeeded = NO;
         syncReturn(semaphore);
         }];
         });
         [[theValue(succeeded) should] beYes];
         });
         */
    });
    describe(@"push to users", ^{
        /* need to get some realish tokens before enabling this
         it(@"should succeed", ^{
         __block BOOL succeeded = NO;
         __block NSDictionary *result;
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
         NSMutableDictionary *args = [NSMutableDictionary dictionaryWithCapacity:3];
         [args setValue:@"my push message" forKey:@"alert"];
         [args setValue:[NSNumber numberWithInt:1] forKey:@"badge"];
         [defaultClient sendMessage:args toUsers:[NSArray arrayWithObject:@"bodie"] onSuccess:^(NSDictionary * tokens){
         succeeded = YES;
         result = tokens;
         syncReturn(semaphore);
         } onFailure:^(NSError *theError) {
         succeeded = NO;
         syncReturn(semaphore);
         }];
         });
         [[theValue(succeeded) should] beYes];
         });
         */
    });
 });


SPEC_END