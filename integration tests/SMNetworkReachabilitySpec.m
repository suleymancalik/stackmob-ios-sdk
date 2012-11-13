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
#import "SMNetworkReachability.h"
#import "SMNetworkReachabilityHelper.h"
#import "SMIntegrationTestHelpers.h"

SPEC_BEGIN(SMNetworkReachabilitySpec)

describe(@"SMNetworkReachability", ^{
    __block SMClient *client = nil;
    __block SMNetworkReachabilityHelper *helper = nil;
    beforeEach(^{
        helper = [[SMNetworkReachabilityHelper alloc] init];
        client = helper.client;
        [client.session.networkMonitor setNetworkStatusChangeBlock:^(SMNetworkStatus status) {
            NSLog(@"block is getting called with status %d", status);
        }];
        if ([client.session.networkMonitor currentNetworkStatus] == Reachable) {
            NSLog(@"We are reachable");
        }
        switch ([client.session.networkMonitor currentNetworkStatus]) {
            case  Reachable:
                NSLog(@"Reachable via switch statement");
                break;
            case NotReachable:
                NSLog(@"Not reachable");
                break;
            case Unknown:
                NSLog(@"Unknowwn");
                break;
            default:
                break;
        }
    });
    afterEach(^{
        [[NSNotificationCenter defaultCenter] removeObserver:helper];
    });
    it(@"can make a call when we are online", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            double delayInSeconds = 2.0;
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_current_queue(), ^{
                SMQuery *query = [[SMQuery alloc] initWithSchema:@"blog"];
                [[client dataStore] performQuery:query onSuccess:^(NSArray *results) {
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
        });
    });
});

SPEC_END