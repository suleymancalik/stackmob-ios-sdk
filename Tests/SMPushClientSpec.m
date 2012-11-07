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

#import <Kiwi/Kiwi.h>
#import "SMPushClient.h"

SPEC_BEGIN(SMPushClientSpec)

describe(@"+defaultClient", ^{
    context(@"when the default client has not been set", ^{
        beforeEach(^{
            [SMPushClient setDefaultClient:nil];
        });
        context(@"creating a new client instance", ^{
            __block SMPushClient *client = nil;
            beforeEach(^{
                client = [[SMPushClient alloc] initWithAPIVersion:@"1" publicKey:@"public" privateKey:@"private"];
            });
            it(@"should set the default client", ^{
                [[[SMPushClient defaultClient] should] equal:client];
            });
        });
    });
    context(@"when the default client has been set", ^{
        __block SMPushClient *originalDefaultClient = nil;
        beforeEach(^{
            originalDefaultClient = [SMPushClient mock];
            [SMPushClient setDefaultClient:originalDefaultClient];
        });
        context(@"setting the default client", ^{
            __block SMPushClient *client = nil;
            beforeEach(^{
                client = [[SMPushClient alloc] initWithAPIVersion:@"1" publicKey:@"public" privateKey:@"private"];
                [SMPushClient setDefaultClient:client];
            });
            it(@"should update the default client", ^{
                [[[SMPushClient defaultClient] should] equal:client];
            });
        });
        context(@"creating a new client instance", ^{
            __block SMPushClient *client = nil;
            beforeEach(^{
                client = [[SMPushClient alloc] initWithAPIVersion:@"1" publicKey:@"public" privateKey:@"private"];
            });
            it(@"should not change the default client", ^{
                [[[SMPushClient defaultClient] should] equal:originalDefaultClient];
            });
        });
    });
});

describe(@"configuration", ^{
    __block SMPushClient *client = nil;
    __block NSString *publicKey = nil;
    __block NSString *privateKey = nil;
    beforeEach(^{
        publicKey = @"public";
        privateKey = @"private";
        client = [[SMPushClient alloc] initWithAPIVersion:@"0" publicKey:publicKey privateKey:privateKey];
    });
    
    describe(@"oauth credentials", ^{
        it(@"should set the client public key", ^{
            [[client.publicKey should] equal:publicKey];
        });
        it(@"should set the client private key", ^{
            [[client.privateKey should] equal:privateKey];
        });
    });

    
    describe(@"host", ^{
        it(@"should default to stackmob.com", ^{
            [[[client host] should] equal:@"push.stackmob.com"];
        });
    });
    
    describe(@"appAPIVersion", ^{
        it(@"should support version 0", ^{
            [[[client appAPIVersion] should] equal:@"0"];
        });
    });
});

SPEC_END