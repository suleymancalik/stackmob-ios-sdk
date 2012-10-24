/**
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
#import "SMRequestOptions.h"

SPEC_BEGIN(SMRequestOptionsSpec)

describe(@"SMRequestOptions", ^{
    
    it(@"+options", ^{
        SMRequestOptions *options = [SMRequestOptions options];
        [options.headers shouldBeNil];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"+optionsWithHeaders", ^{
        NSDictionary *headersDict = [NSDictionary dictionaryWithObjectsAndKeys:@"headerValue", @"header", nil];
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:headersDict];
        [[options.headers should] equal:headersDict];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"+optionsWithHTTPS", ^{
        SMRequestOptions *options = [SMRequestOptions optionsWithHTTPS];
        [options.headers shouldBeNil];
        [[theValue(options.isSecure) should] equal:theValue(YES)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"+optionsoptionsWithExpandDepth", ^{
        SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:2];
        NSDictionary *expandDepthHeadersDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%d", 2], @"X-StackMob-Expand", nil];
        [[options.headers should] equal:expandDepthHeadersDict];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"+optionsWithReturnedFieldsRestrictedTo", ^{
        NSArray *restrictArray = [NSArray arrayWithObjects:@"name", @"age", @"year", nil];
        SMRequestOptions *options = [SMRequestOptions optionsWithReturnedFieldsRestrictedTo:restrictArray];
        NSDictionary *restrictHeadersDict = [NSDictionary dictionaryWithObjectsAndKeys:[restrictArray componentsJoinedByString:@","], @"X-StackMob-Select", nil];
        [[options.headers should] equal:restrictHeadersDict];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"can use properties to set headers", ^{
        SMRequestOptions *options = [SMRequestOptions options];
        NSDictionary *headersDict = [NSDictionary dictionaryWithObjectsAndKeys:@"headerValue", @"header", nil];
        options.headers = headersDict;
        [[options.headers should] equal:headersDict];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"can use properties to set security", ^{
        SMRequestOptions *options = [SMRequestOptions options];
        options.isSecure = YES;
        [options.headers shouldBeNil];
        [[theValue(options.isSecure) should] equal:theValue(YES)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"-setExapandDepth", ^{
        SMRequestOptions *options = [SMRequestOptions options];
        [options setExpandDepth:2];
        NSDictionary *expandDepthHeadersDict = [NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"%d", 2], @"X-StackMob-Expand", nil];
        [[options.headers should] equal:expandDepthHeadersDict];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
    it(@"add 503 error block", ^{
        SMRequestOptions *myOptions = [SMRequestOptions options];
        SMFailureRetryBlock myRetryBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error, id JSON, SMRequestOptions *options, SMFullResponseSuccessBlock successBlock, SMFullResponseFailureBlock failureBlock) {
            NSLog(@"do something");
        };
        [myOptions setRetryBlock:myRetryBlock];
        [myOptions.headers shouldBeNil];
        [[theValue(myOptions.isSecure) should] equal:theValue(NO)];
        [[theValue(myOptions.numberOfRetries) should] equal:theValue(3)];
        [[theValue(myOptions.tryRefreshToken) should] equal:theValue(YES)];
        [[myOptions.retryBlock should] equal:myRetryBlock];
    });
    it(@"restrict returned fields method", ^{
        NSArray *restrictArray = [NSArray arrayWithObjects:@"name", @"age", @"year", nil];
        SMRequestOptions *options = [SMRequestOptions options];
        [options restrictReturnedFieldsTo:restrictArray];
        NSDictionary *restrictHeadersDict = [NSDictionary dictionaryWithObjectsAndKeys:[restrictArray componentsJoinedByString:@","], @"X-StackMob-Select", nil];
        [[options.headers should] equal:restrictHeadersDict];
        [[theValue(options.isSecure) should] equal:theValue(NO)];
        [[theValue(options.numberOfRetries) should] equal:theValue(3)];
        [[theValue(options.tryRefreshToken) should] equal:theValue(YES)];
        [options.retryBlock shouldBeNil];
    });
});

SPEC_END