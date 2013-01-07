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
#import "StackMob.h"
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"

SPEC_BEGIN(IncrementalStoreBatchOperationsSpec)


describe(@"Inserting/Updating/Deleting many objects works fine", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
    });
    afterAll(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *fetchError = nil;
        NSArray *resultsArray = [moc executeFetchRequest:fetch error:&fetchError];
        for (NSManagedObject *obj in resultsArray) {
            [moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        
    });
    it(@"inserts and updates without error", ^{
        arrayOfObjects = [NSMutableArray array];
        for (int i=0; i < 30; i++) {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
            [newManagedObject setValue:@"bob" forKey:@"title"];
            [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
            
            [arrayOfObjects addObject:newManagedObject];
        }
        
        __block BOOL saveSuccess = NO;
        __block NSError *error = nil;
        
        saveSuccess = [moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        
        for (unsigned int i=0; i < [arrayOfObjects count]; i++) {
            if ([[arrayOfObjects objectAtIndex:i] isFault]) {
                NSLog(@"isFault");
            }
            [[arrayOfObjects objectAtIndex:i] setValue:@"jack" forKey:@"title"];
        }
        
        saveSuccess = [moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];


        
    });
});

describe(@"fetching runs in the background", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        arrayOfObjects = [NSMutableArray array];
        for (int i=0; i < 30; i++) {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
            [newManagedObject setValue:@"bob" forKey:@"title"];
            [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
            
            [arrayOfObjects addObject:newManagedObject];
        }
        __block BOOL saveSuccess = NO;
        __block NSError *error = nil;
        
        saveSuccess = [moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
    });
    afterAll(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        for (NSManagedObject *obj in arrayOfObjects) {
            [moc deleteObject:obj];
        }
        __block NSError *error = nil;
        BOOL saveSuccess = [moc saveAndWait:&error];
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
        
    });
    it(@"fetches, sync method", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSError *error = nil;
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
        [results shouldNotBeNil];
        [error shouldBeNil];
        
    });
    it(@"fetches, async method", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_group_enter(group);
        [moc executeFetchRequest:fetch successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results shouldNotBeNil];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
     

});

describe(@"With a non-401 error", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        
        if ([client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:@"primarykey" inSchema:@"todo" onSuccess:^(NSString *theObjectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    it(@"General Error should return", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [newManagedObject setValue:@"bob" forKey:@"title"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [[theValue(success) should] beYes];
        
        // Produce a 409
        NSManagedObject *secondManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [secondManagedObject setValue:@"bob" forKey:@"title"];
        [secondManagedObject setValue:@"primarykey" forKey:[secondManagedObject primaryKeyField]];
        
        success = [moc saveAndWait:&error];
        [[theValue(success) should] beNo];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        
        [failedInsertedObjects shouldNotBeNil];
        [[theValue([failedInsertedObjects count]) should] equal:theValue(1)];
        NSDictionary *dict = [failedInsertedObjects objectAtIndex:0];
        NSError *failedError = [dict objectForKey:SMFailedManagedObjectError];
        [[theValue([failedError code]) should] equal:theValue(SMErrorConflict)];
        NSLog(@"Error is %@", [error userInfo]);
        
    });

    
});



describe(@"With 401s", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        
        if ([client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
    });
    afterEach(^{
        
    });
    
    it(@"Not logged in, 401 should get added to failed operations and show up in error", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        [[client.dataStore.session.regularOAuthClient should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [[theValue([error code]) should] equal:theValue(SMErrorCoreDataSave)];
        [failedInsertedObjects shouldNotBeNil];
        [[theValue([failedInsertedObjects count]) should] equal:theValue(1)];
        NSDictionary *dict = [failedInsertedObjects objectAtIndex:0];
        NSError *failedError = [dict objectForKey:SMFailedManagedObjectError];
        [[theValue([failedError code]) should] equal:theValue(SMErrorUnauthorized)];
        
    });
    
    it(@"Failed refresh before requests are attemtped should error appropriately", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        NSError *error = nil;
        
        [[client.dataStore.session stubAndReturn:@"1234"] refreshToken];
        [[client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[client.dataStore.session stubAndReturn:theValue(NO)] refreshing];
        
        BOOL success = [moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(SMErrorRefreshTokenFailed)];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [failedInsertedObjects shouldBeNil];
    });
        
});


describe(@"401s requiring logins", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client loginWithUsername:@"dude" password:@"sweet" onSuccess:^(NSDictionary *result) {
                NSLog(@"logged in, %@", result);
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldNotBeNil];
                syncReturn(semaphore);
            }];
        });
        
        
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        if ([client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
    });
    it(@"After successful refresh, should send out requests again", ^{
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        [[client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[client.dataStore.session stubAndReturn:theValue(NO)] refreshing];
        [[client.dataStore.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
        
        [[client.dataStore.session should] receive:@selector(doTokenRequestWithEndpoint:credentials:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:)  withCount:2 arguments:@"refreshToken", any(), any(), any(), any(), any(), any()];
        
        [[client.dataStore.session.regularOAuthClient should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(SMErrorCoreDataSave)];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [[theValue([failedInsertedObjects count] ) should] equal:theValue(1)];
        NSDictionary *dictionary = [failedInsertedObjects objectAtIndex:0];
        [[dictionary objectForKey:SMFailedManagedObjectError] shouldNotBeNil];
        [[dictionary objectForKey:SMFailedManagedObjectID] shouldNotBeNil];
    });

});



describe(@"timeouts with refreshing", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        
        
    });
    it(@"waits 5 seconds and fails", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        [[client.dataStore.session stubAndReturn:@"1234"] refreshToken];
        [[client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[client.dataStore.session stubAndReturn:theValue(YES)] refreshing];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        
        [[theValue(success) should] beNo];
        [[theValue([error code]) should] equal:theValue(SMErrorRefreshTokenInProgress)];
        
    });
    
});


describe(@"With 401s and other errors", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client loginWithUsername:@"dude" password:@"sweet" onSuccess:^(NSDictionary *result) {
                NSLog(@"logged in, %@", result);
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldNotBeNil];
                syncReturn(semaphore);
            }];
        });
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:@"bob" forKey:@"title"];
        [todo setValue:@"primarykey" forKey:[todo primaryKeyField]];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [[theValue(success) should] beYes];
        
        
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:@"primarykey" inSchema:@"todo" onSuccess:^(NSString *theObjectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        if ([client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client logoutOnSuccess:^(NSDictionary *result) {
                    NSLog(@"Logged out");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
        
    });
    it(@"Only 401s should be refreshed if possible", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // Set up scenario
        [[client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
        [[client.dataStore.session stubAndReturn:theValue(NO)] refreshing];
        [[client.dataStore.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
        
        // Add objects for 401 and 409
        NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:moc];
        [newManagedObject setValue:@"bob" forKey:@"name"];
        [newManagedObject setValue:@"primarykey" forKey:[newManagedObject primaryKeyField]];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todo setValue:@"bob" forKey:@"title"];
        [todo setValue:@"primarykey" forKey:[todo primaryKeyField]];
        
        // Should create total of 3 operations, one for the 409 and 2 for the 401 (first time and retry)
        [[client.dataStore.session.regularOAuthClient should] receive:@selector(enqueueHTTPRequestOperation:) withCount:3];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [[theValue(success) should] beNo];
        
        // Test failure
        [[theValue([error code]) should] equal:theValue(SMErrorCoreDataSave)];
        NSArray *failedInsertedObjects = [[error userInfo] objectForKey:SMInsertedObjectFailures];
        [[theValue([failedInsertedObjects count] ) should] equal:theValue(2)];
        NSDictionary *dictionary = [failedInsertedObjects objectAtIndex:0];
        [[dictionary objectForKey:SMFailedManagedObjectError] shouldNotBeNil];
        [[dictionary objectForKey:SMFailedManagedObjectID] shouldNotBeNil];
        dictionary = [failedInsertedObjects objectAtIndex:1];
        [[dictionary objectForKey:SMFailedManagedObjectError] shouldNotBeNil];
        [[dictionary objectForKey:SMFailedManagedObjectID] shouldNotBeNil];
        
        
    });
    
});

/*
describe(@"async save method tests", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        client = [SMIntegrationTestHelpers defaultClient];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        arrayOfObjects = [NSMutableArray array];
        for (int i=0; i < 30; i++) {
            NSManagedObject *newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
            [newManagedObject setValue:@"bob" forKey:@"title"];
            [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
            
            [arrayOfObjects addObject:newManagedObject];
        }
    });
    
    afterAll(^{
        __block BOOL saveSucess = NO;
        NSMutableArray *objectIDS = [NSMutableArray array];
        for (NSManagedObject *obj in arrayOfObjects) {
            [objectIDS addObject:[obj valueForKey:@"todoId"]];
        }
        
        for (NSString *objID in objectIDS) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client.dataStore deleteObjectId:objID inSchema:@"todo" onSuccess:^(NSString *theObjectId, NSString *schema) {
                    saveSucess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                    saveSucess = NO;
                    syncReturn(semaphore);
                }];
            });
            [[theValue(saveSucess) should] beYes];
        }
        
        
        for (NSManagedObject *obj in arrayOfObjects) {
            [moc deleteObject:obj];
        }
        __block BOOL saveSuccess = NO;
        dispatch_group_enter(group);
        [moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
            saveSuccess = YES;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
         
        [[theValue(saveSuccess) should] beYes];
        [arrayOfObjects removeAllObjects];
         
        
    });
    it(@"inserts without error", ^{
        __block BOOL saveSuccess = NO;
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
            saveSuccess = YES;
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            dispatch_group_leave(group);
        }];
        
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveWithSuccessCallbackQueue:queue failureCallbackQueue:queue onSuccess:^{
                saveSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                syncReturn(semaphore);
            }];
        });
        
                
        [[theValue(saveSuccess) should] beYes];
    });

});
*/

SPEC_END