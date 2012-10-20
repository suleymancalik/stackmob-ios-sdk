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
#import "User4.h"
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
        [client setUserSchema:@"user3"];
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
            NSString *passwordIdentifier = [person passwordIdentifier];
            
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

describe(@"can set a client with different password field name and everything still works", ^{
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User4 *person = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"User4"];
        [client setPrimaryKeyFieldName:@"theuser"];
        [client setPasswordFieldName:@"thepassword"];
        moc = [SMCoreDataIntegrationTestHelpers moc];
        // tests save here
        person = [NSEntityDescription insertNewObjectForEntityForName:@"User4" inManagedObjectContext:moc];
        [person setTheuser:@"bob"];
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
    
});

describe(@"creating and saving two users should not conflict with each other", ^{
    
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *person1 = nil;
    __block User3 *person2 = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"User3"];
        moc = [SMCoreDataIntegrationTestHelpers moc];
        // tests save here
        person1 = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person1 setUsername:@"bob"];
        [person1 setPassword:@"1234"];
        
        person2 = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person2 setPassword:@"4321"];
        [person2 setUsername:@"adam"];
    });
    afterEach(^{
        [moc deleteObject:person1];
        [moc deleteObject:person2];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"should save successfully and we can log in person1", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
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
    it(@"should save successfully and we can log in person2", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        __block BOOL loginSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client loginWithUsername:@"adam" password:@"4321" onSuccess:^(NSDictionary *result) {
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

describe(@"should be able to create a user, relate to other object, and save everything without reset password errors", ^{
    
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *person = nil;
    __block NSManagedObject *todo = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"User3"];
        moc = [SMCoreDataIntegrationTestHelpers moc];
        // tests save here
        person = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person setUsername:@"bob"];
        [person setPassword:@"1234"];
        
        todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
        [todo setValue:@"related to user3" forKey:@"title"];
    });
    afterEach(^{
        [moc deleteObject:person];
        [moc deleteObject:todo];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"should save before and after relation", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];

        [todo setValue:person forKey:@"user3"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];

        
        
    });
    
});
 
describe(@"primaryKeyFieldName works", ^{
    
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *user3 = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"User3"];
        moc = [SMCoreDataIntegrationTestHelpers moc];
    });
    afterEach(^{
        [moc deleteObject:user3];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"saves correctly when using default client", ^{
        // tests save here
        user3 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        [user3 setValue:[user3 assignObjectId] forKey:[user3 primaryKeyField]];
        [user3 setPassword:@"1234"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"saves correctly when specifying client", ^{
        // tests save here
        user3 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc] client:client insertIntoManagedObjectContext:moc];
        [user3 setValue:[user3 assignObjectId] forKey:[user3 primaryKeyField]];
        [user3 setPassword:@"1234"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });

    
});

describe(@"testing someting", ^{
    
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *ardoObject = nil;
    __block User3 *failObject = nil;
    __block User3 *successObject = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"User3"];
        moc = [SMCoreDataIntegrationTestHelpers moc];
    });
    afterEach(^{
        [moc deleteObject:ardoObject];
        [moc deleteObject:successObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });

    it(@"should save", ^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc];
        ardoObject = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:moc];
        [ardoObject setUsername:@"ardo"];
        [ardoObject setPassword:@"1234"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        failObject = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:moc];
        [failObject setUsername:@"ardo"];
        [failObject setPassword:@"1234"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldNotBeNil];
                NSString *result = [KeychainWrapper keychainStringFromMatchingIdentifier:[failObject passwordIdentifier]];
                [result shouldNotBeNil];
                [failObject removePassword];
                result = [KeychainWrapper keychainStringFromMatchingIdentifier:[failObject passwordIdentifier]];
                [result shouldBeNil];
                [moc deleteObject:failObject];
            }
        }];
        
        successObject = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:moc];
        [successObject setUsername:@"james"];
        [successObject setPassword:@"1234"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
    });
    
});

SPEC_END