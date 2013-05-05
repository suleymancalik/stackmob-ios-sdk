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
#import "NSManagedObjectContext+Concurrency.h"
#import "StackMob.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "User3.h"
#import "Person.h"
#import "Superpower.h"

SPEC_BEGIN(NSManagedObjectContext_ConcurrencySpec)


describe(@"fetching runs in the background", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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
        __block dispatch_group_t group = dispatch_group_create();
        __block dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_group_enter(group);
        [moc executeFetchRequest:fetch returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results shouldNotBeNil];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    
    
});

describe(@"Returning managed object vs. ids", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSMutableArray *arrayOfObjects = nil;
    
    beforeAll(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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
    it(@"Properly returns managed objects, async method", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [moc executeFetchRequest:fetch returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[theValue([obj class] == [NSManagedObject class]) should] beYes];
            }];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_release(group);
        dispatch_release(queue);
        
    });
    it(@"Properly returns managed objects ids, async method", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [moc executeFetchRequest:fetch returnManagedObjectIDs:YES successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSArray *results) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [[theValue([obj isTemporaryID]) should] beNo];
                [[theValue([obj isKindOfClass:[NSManagedObjectID class]]) should] beYes];
            }];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_release(group);
        dispatch_release(queue);
        
    });
    it(@"Properly returns managed objects, sync method", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];

        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch returnManagedObjectIDs:NO error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [[theValue([obj class] == [NSManagedObject class]) should] beYes];
        }];
        
    });
    it(@"Properly returns managed objects ids, sync method", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch returnManagedObjectIDs:YES error:&error];
        [error shouldBeNil];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [[theValue([obj isTemporaryID]) should] beNo];
            [[theValue([obj isKindOfClass:[NSManagedObjectID class]]) should] beYes];
        }];
        
    });
});


describe(@"sending options with requests, saves", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeAll(^{
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
    });
    afterEach(^{
        NSArray *arrayOfSchemaObjectsToDelete = [NSArray arrayWithObjects:@"User3", @"Person", nil];
        __block NSFetchRequest *fetch = nil;
        __block NSError *error = nil;
        __block NSArray *results = nil;
        [arrayOfSchemaObjectsToDelete enumerateObjectsUsingBlock:^(id schemaName, NSUInteger idx, BOOL *stop) {
            
            fetch = [[NSFetchRequest alloc] initWithEntityName:schemaName];
            error = nil;
            results = [moc executeFetchRequestAndWait:fetch error:&error];
            if (!error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *innerstop) {
                    [moc deleteObject:obj];
                }];
            }
            
        }];
        
        error = nil;
        [moc saveAndWait:&error];
        
        
    });
    
    it(@"saveAndWait:options:, sending HTTPS", ^{
        
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         
         2 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
        
        //SM_CORE_DATA_DEBUG = YES;
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        if (!success) {
            NSLog(@"no success");
        }
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        error = nil;
        success = [moc saveAndWait:&error options:options];
        if (!success) {
            NSLog(@"no success");
        }
        
        //SM_CORE_DATA_DEBUG = NO;
    });
    it(@"saveAndWait:options:, not sending HTTPS", ^{
        
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock         
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        if (!success) {
            [error shouldBeNil];
        }
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        
        error = nil;
        success = [moc saveAndWait:&error options:options];
        if (!success) {
            [error shouldBeNil];
        }
    });
    
    it(@"saveOnSuccess, sending HTTPS", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         
         2 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveOnSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveWithSuccessCallbackQueue:dispatch_get_current_queue() failureCallbackQueue:dispatch_get_current_queue() options:options onSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
    });
    it(@"saveOnSuccess, not sending HTTPS", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock         
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveOnSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveWithSuccessCallbackQueue:dispatch_get_current_queue() failureCallbackQueue:dispatch_get_current_queue() options:options onSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
    });
    
});


describe(@"creating global request options, saves", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeAll(^{
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];;
        moc = [cds contextForCurrentThread];
    });
    afterEach(^{
        NSArray *arrayOfSchemaObjectsToDelete = [NSArray arrayWithObjects:@"User3", @"Person", nil];
        __block NSFetchRequest *fetch = nil;
        __block NSError *error = nil;
        __block NSArray *results = nil;
        [arrayOfSchemaObjectsToDelete enumerateObjectsUsingBlock:^(id schemaName, NSUInteger idx, BOOL *stop) {
            
            fetch = [[NSFetchRequest alloc] initWithEntityName:schemaName];
            error = nil;
            results = [moc executeFetchRequestAndWait:fetch error:&error];
            if (!error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *innerstop) {
                    [moc deleteObject:obj];
                }];
            }
            
        }];
        
        error = nil;
        [moc saveAndWait:&error];
        
        
    });
    
    it(@"saveAndWait:options:, global request options have HTTPS", ^{
        /*
         First save (global secure):
         Create person
         
         0 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         Network available
         
         3 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:3];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [cds setGlobalRequestOptions:[SMRequestOptions optionsWithHTTPS]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [error shouldBeNil];
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        error = nil;
        success = [moc saveAndWait:&error];
        [error shouldBeNil];
    });
    it(@"saveAndWait:options:, global request options regular", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [cds setGlobalRequestOptions:[SMRequestOptions options]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [error shouldBeNil];
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        error = nil;
        success = [moc saveAndWait:&error];
        [error shouldBeNil];
    });
    
    it(@"saveOnSuccess:options:, global request options have HTTPS", ^{
        /*
         First save (not secure):
         Create person
         
         0 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (secure):
         Get person - called twice
         Create user
         Upate person
         
         3 x secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:3];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [cds setGlobalRequestOptions:[SMRequestOptions optionsWithHTTPS]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveOnSuccess:^{
            
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveOnSuccess:^{
                
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    it(@"saveOnSuccess:options:, global request options regular", ^{
        /*
         First save (not secure):
         Create person
         
         1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         
         
         Second save (not secure):
         Get person - called twice
         Create user (secure)
         Upate person
         
         1 x secure + 1 x non-secure enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock
         2 x non-secure enqueueHTTPRequestOperation
         */
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:2];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [cds setGlobalRequestOptions:[SMRequestOptions options]];
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveOnSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        [person setValue:@"smith" forKey:@"last_name"];
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [moc saveOnSuccess:^{
                syncReturn(semaphore);
            } onFailure:^(NSError *asyncError) {
                [asyncError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    
});

describe(@"sending options with requests, fetches", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeAll(^{
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [client setUserSchema:@"User3"];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        User3 *user = [NSEntityDescription insertNewObjectForEntityForName:@"User3" inManagedObjectContext:moc];
        [user setUsername:[user assignObjectId]];
        [user setPassword:@"smith"];
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [[theValue(success) should] beYes];
    });
    afterAll(^{
        NSArray *arrayOfSchemaObjectsToDelete = [NSArray arrayWithObjects:@"User3", @"Person", nil];
        __block NSFetchRequest *fetch = nil;
        __block NSError *error = nil;
        __block NSArray *results = nil;
        [arrayOfSchemaObjectsToDelete enumerateObjectsUsingBlock:^(id schemaName, NSUInteger idx, BOOL *stop) {
            
            fetch = [[NSFetchRequest alloc] initWithEntityName:schemaName];
            error = nil;
            results = [moc executeFetchRequestAndWait:fetch error:&error];
            if (!error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger index, BOOL *innerstop) {
                    [moc deleteObject:obj];
                }];
            }
            
        }];
        
        error = nil;
        [moc saveAndWait:&error];
        [error shouldBeNil];
        
    });
    it(@"executeFetchRequestAndWait:error:, sending HTTPS", ^{
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetchRequest returnManagedObjectIDs:NO options:options error:&error];
        
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        
        
    });
    
    it(@"executeFetchRequestAndWait:error:, not sending HTTPS", ^{
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetchRequest returnManagedObjectIDs:NO options:options error:&error];
        
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        
    });
    
    it(@"executeFetchRequest:onSuccess, sending HTTPS", ^{
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        options.isSecure = YES;
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        
        dispatch_group_enter(group);
        [moc executeFetchRequest:fetchRequest returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue options:options onSuccess:^(NSArray *results) {
            [[theValue([results count]) should] equal:theValue(1)];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
    it(@"executeFetchRequest:onSuccess, not sending HTTPS", ^{
        
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Used to be 1, 3 because we added code to pull values on different threads
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:3];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:0];
        
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        
        SMRequestOptions *options = [SMRequestOptions optionsWithHeaders:[NSDictionary dictionaryWithObjectsAndKeys:@"random", @"header", nil]];
        
        dispatch_group_t group = dispatch_group_create();
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        
        __block NSManagedObjectID *objectID = nil;
        dispatch_group_enter(group);
        [moc executeFetchRequest:fetchRequest returnManagedObjectIDs:NO successCallbackQueue:queue failureCallbackQueue:queue options:options onSuccess:^(NSArray *results) {
            [[theValue([results count]) should] equal:theValue(1)];
            // Add code here to test threading
            
            NSManagedObject *object = [results objectAtIndex:0];
            NSString *first_name = [object valueForKey:@"first_name"];
            NSLog(@"first_name is %@", first_name);
            
            objectID = [object objectID];
            dispatch_group_leave(group);
        } onFailure:^(NSError *error) {
            [error shouldBeNil];
            dispatch_group_leave(group);
        }];
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        NSManagedObject *bob = [moc objectWithID:objectID];
        NSString *first_name = [bob valueForKey:@"first_name"];
        NSLog(@"outside of block, first_name is %@", first_name);
    });
});



/*
describe(@"testing getting 500s", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeAll(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"d87cee00-c574-437d-a4cb-ab841e263b52"];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
    });
    it(@"getting a 500:", ^{
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setPerson_id:[person assignObjectId]];
        [person setFirst_name:@"bob"];
        
        NSManagedObject *favorite = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
        [favorite setValue:[favorite assignObjectId] forKey:[favorite primaryKeyField]];
        [favorite setValue:@"fav" forKey:@"genre"];
        
        NSManagedObject *interest = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
        [interest setValue:[interest assignObjectId] forKey:[interest primaryKeyField]];
        [interest setValue:@"cool" forKey:@"name"];
        
        Superpower *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower setSuperpower_id:[superpower assignObjectId]];
        [superpower setName:@"super"];
        
        [person setInterests:[NSSet setWithObject:interest]];
        [person setFavorites:[NSSet setWithObject:favorite]];
        [person setSuperpower:superpower];
        
        [superpower setPerson:person];
        //[interest setValue:person forKey:@"person"];
        
        
        NSError *error = nil;
        BOOL success = [moc saveAndWait:&error];
        [error shouldBeNil];
        
    });
});
*/

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