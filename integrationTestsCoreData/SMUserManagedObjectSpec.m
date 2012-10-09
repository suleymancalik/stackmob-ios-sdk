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
#import "SMUserManagedObject.h"
#import "User3.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "KeychainWrapper.h"

SPEC_BEGIN(SMUserManagedObjectSpec)

describe(@"SMUserManagedObject", ^{
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *person = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client session] setUserSchema:@"user3"];
        moc = [SMCoreDataIntegrationTestHelpers moc];
        // tests save here
        person = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person setUsername:@"bob"];
        [person setPassword:@"1234"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    afterEach(^{
        [moc deleteObject:person];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    describe(@"Should save a person with a SMUserManagedObject subclass without a password attribute in Core Data", ^{
        it(@"should have deleted the entry from the keychain", ^{
            NSString *serviceName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleIdentifierKey];
            if (serviceName == nil) {
                serviceName = @"com.stackmob.passwordstore";
            }
            NSString *passwordIdentifier = [serviceName stringByAppendingPathComponent:@"password"];
            
            NSString *result = [KeychainWrapper keychainStringFromMatchingIdentifier:passwordIdentifier];
            [result shouldBeNil];
        });
        it(@"we can login successfully", ^{
            __block BOOL loginSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client loginWithUsername:@"bob" password:@"1234" onSuccess:^(NSDictionary *result) {
                    loginSuccess = YES;
                    NSLog(@"you have logged in");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    NSLog(@"error is %@", error);
                    syncReturn(semaphore);
                }];
            });
            [[theValue(loginSuccess) should] beYes];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client logoutOnSuccess:^(NSDictionary *result) {
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