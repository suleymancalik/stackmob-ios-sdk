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

#import "SMNetworkReachabilityHelper.h"

@implementation SMNetworkReachabilityHelper

@synthesize client = _client;

- (id)init
{
    self = [super init];
    if (self) {
        NSURL *credentialsURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"StackMobCredentials" withExtension:@"plist"];
        NSDictionary *credentials = [NSDictionary dictionaryWithContentsOfURL:credentialsURL];
        NSString *publicKey = [credentials objectForKey:@"PublicKey"];
        self.client =  [[SMClient alloc] initWithAPIVersion:@"0" publicKey:publicKey];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(networkDidChange:) name:SMNetworkStatusDidChangeNotification object:nil];
    }
    
    return self;
}

- (void)networkDidChange:(NSNotification *)notification
{
    NSLog(@"user info is %@", [notification userInfo]);
    if ([[[notification userInfo] objectForKey:SMCurrentNetworkStatusKey] intValue] == Reachable) {
        NSLog(@"Reachable");
    }
    switch ([[[notification userInfo] objectForKey:SMCurrentNetworkStatusKey] intValue]) {
        case  Reachable:
            NSLog(@"Reachable via switch statement");
            break;
        default:
            break;
    }
}

@end
