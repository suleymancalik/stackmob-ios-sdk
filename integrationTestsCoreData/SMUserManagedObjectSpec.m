/**
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
#import "SMUserManagedObject.h"
#import "User3.h"
#import "User4.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "KeychainWrapper.h"
#import "StackMob.h"

SPEC_BEGIN(SMUserManagedObjectSpec)

describe(@"SMUserManagedObject", ^{
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *person = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSString *passwordID = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        
        [client setUserSchema:@"user3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:person];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"should have deleted the entry from the keychain", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // tests save here
        NSEntityDescription *desc = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc];
        person = [[User3 alloc] initWithEntity:desc client:client insertIntoManagedObjectContext:moc];
        [person setUsername:@"bob"];
        [person setPassword:@"1234"];
        passwordID = [client.session.userIdentifierMap objectForKey:[person valueForKey:[person primaryKeyField]]];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        NSString *passwordIDFromMap = [client.session.userIdentifierMap objectForKey:[person valueForKey:[person primaryKeyField]]];
        [passwordIDFromMap shouldBeNil];
        NSString *result = [KeychainWrapper keychainStringFromMatchingIdentifier:passwordID];
        [result shouldBeNil];
    });
    
    it(@"we can login successfully", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // tests save here
        NSEntityDescription *desc = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc];
        person = [[User3 alloc] initWithEntity:desc client:client insertIntoManagedObjectContext:moc];
        [person setUsername:@"bob"];
        [person setPassword:@"1234"];
        passwordID = [client.session.userIdentifierMap objectForKey:[person valueForKey:[person primaryKeyField]]];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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

describe(@"can set a client with different password field name and everything still works", ^{
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User4 *person = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:person];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"works", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [client setUserSchema:@"User4"];
        [client setUserPrimaryKeyField:@"theuser"];
        [client setUserPasswordField:@"thepassword"];
        // tests save here
        NSEntityDescription *desc = [NSEntityDescription entityForName:@"User4" inManagedObjectContext:moc];
        person = [[User4 alloc] initWithEntity:desc client:client insertIntoManagedObjectContext:moc];
        [person setTheuser:@"bob"];
        [person setPassword:@"1234"];
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
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // tests save here
        person1 = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person1 setUsername:@"bob"];
        [person1 setPassword:@"1234"];
        
        person2 = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person2 setUsername:@"adam"];
        [person2 setPassword:@"4321"];
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
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // tests save here
        person = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [person setUsername:@"bob"];
        [person setPassword:@"1234"];
        
        todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
        [todo setValue:@"related to user3" forKey:@"title"];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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

describe(@"userPrimaryKeyField works", ^{
    
    __block SMClient *client = nil;
    __block NSManagedObjectContext *moc = nil;
    __block User3 *user3 = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
                NSString *passwordIdentifier = [client.session.userIdentifierMap objectForKey:[failObject valueForKey:[failObject primaryKeyField]]];
                NSLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldNotBeNil];
                NSString *result = [KeychainWrapper keychainStringFromMatchingIdentifier:passwordIdentifier];
                [result shouldNotBeNil];
                [failObject removePassword];
                result = [KeychainWrapper keychainStringFromMatchingIdentifier:passwordIdentifier];
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