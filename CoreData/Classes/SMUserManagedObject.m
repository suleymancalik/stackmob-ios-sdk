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

#import "SMUserManagedObject.h"
#import "StackMob.h"
#import "KeychainWrapper.h"

@interface SMUserManagedObject ()

@property (nonatomic, readwrite) NSString *passwordIdentifier;
@end

@implementation SMUserManagedObject

@synthesize passwordIdentifier = _passwordIdentifier;

- (void)setPassword:(NSString *)value
{
    NSString *serviceName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleIdentifierKey];
    if (serviceName == nil) {
        serviceName = @"com.stackmob.passwordstore";
    }
    self.passwordIdentifier = [[serviceName stringByAppendingPathExtension:[NSString stringWithFormat:@"%d", arc4random() / 1000]] stringByAppendingPathExtension:@"password"];
    NSLog(@"passwordIdentifier is %@", self.passwordIdentifier);
    if (![KeychainWrapper createKeychainValue:value forIdentifier:self.passwordIdentifier]) {
        [NSException raise:@"SMKeychainSaveUnsuccessful" format:@"Password could not be saved to keychain"];
    }
}

- (NSString *)passwordIdentifier
{
    return _passwordIdentifier;
}



@end
