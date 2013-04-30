/*
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
#import "StackMob.h"
#import "SMTestProperties.h"
#import "User3.h"

SPEC_BEGIN(SMMergePolicySpec)

//////////////////////////////
/////////INSERTS///////////
//////////////////////////////

describe(@"Insert 1 Offline, should send as an insert no merge, NO CONFLICT", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Should send object as an update, no merge policy should get called", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline insert"];
        
        // TODO better testing that merge policy never gets called
        
    });
    
});

describe(@"Insert 1 Offline at T1, Insert 1 Offline at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as an update", ^{
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Insert 1 online
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
    });
    
    it(@"Last Mod Wins MP, Should merge server object with cache", ^{
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Insert 1 online
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
    });
    
    it(@"Server Mod Wins MP, Should merge server object with cache", ^{
        
        // Insert 1 offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Insert 1 online
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
          
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
    });

    
});

describe(@"While offline, Insert 1 Online at T1, Insert 1 Offline at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as an update", ^{
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Insert 1 offline
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Sync
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
          
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
    });
    
    it(@"Last Mod Wins MP, Should send object as an update", ^{
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Insert 1 offline
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Sync
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
           
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client insert"];
        
    });
    
    it(@"Server Mod Wins MP, Should merge server object with cache", ^{
        
        // Insert 1 online
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"online server insert", @"title", @"1234", @"todo_id", nil] inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Insert 1 offline
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"offline client insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        // Sync
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server insert"];
        
    });
    
    
});


//////////////////////////////
/////////UPDATES///////////
//////////////////////////////

describe(@"Insert 1 Online, Update 1 Offline, NO CONFLICT", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
 
    
    it(@"Should send object as an update, no merge policy should get called", ^{
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline update"];
        
        // TODO better testing that merge policy never gets called
        
    });
     
});

describe(@"Insert 1 Online, Update 1 Offline at T1, Update 1 Online at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as an update", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update server at T2
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
           
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
    
    
    it(@"Last Mod Wins MP, Should update cache with server values", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [testProperties.moc refreshObject:todo mergeChanges:YES];
        NSLog(@"After online client save, todo is %@ with lastmoddate %f", todo, [[todo valueForKey:SMLastModDateKey] timeIntervalSince1970]);
        
        // Update offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        [testProperties.moc refreshObject:todo mergeChanges:YES];
        NSLog(@"After offline client update, todo is %@ with lastmoddate %f", todo, [[todo valueForKey:SMLastModDateKey] timeIntervalSince1970]);
        sleep(3);
        // Update server at T2
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
    });
    
    
    it(@"Server Mod Wins MP, Should update cache with server values", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update server at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
    });
     
});

describe(@"Insert 1 Online, Update Online at T1, Update Offline at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as an update", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Syn with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
     
    it(@"Last Mod Wins MP, Should send object as an update", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Syn with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
    
    it(@"Server Mod Wins MP, Should update cache with server values", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        [testProperties.moc refreshObject:todo mergeChanges:YES];
        __block NSDate *serverBase = [todo valueForKey:SMLastModDateKey];
        NSLog(@"todo lastmoddate is %@", serverBase);
        
        // Update online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            NSLog(@"the object is %@", theObject);
            long double convertedValue = [[theObject valueForKey:SMLastModDateKey] doubleValue] / 1000.0000;
            NSDate *convertedDate = [NSDate dateWithTimeIntervalSince1970:convertedValue];
            NSLog(@"converted date is %@", convertedDate);
            double interval = [serverBase timeIntervalSinceDate:convertedDate];
            NSLog(@"interval is %.4f", interval);
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Syn with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
    });
    
});

describe(@"Insert 1 Online, Update Offline at T1, Delete Online at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as an insert", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete online at T2
        sleep(3);
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
    
    it(@"Last Mod Wins MP, Should send object as an insert", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete online at T2
        sleep(3);
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
    
    it(@"Server Mod Wins MP, Should delete cached object", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete online at T2
        sleep(3);
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
    
});

describe(@"Insert 1 Online, Delete Online at T1, Update Offline at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as an insert", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
    
    it(@"Last Mod Wins MP, Should send object as an insert", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"offline client update"];
        
    });
    
    it(@"Server Mod Wins MP, Should delete cached object", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [todo setValue:@"offline client update" forKey:@"title"];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
    
});

describe(@"Insert 5 Online, Go offline and update 5, T2 update 2 Online", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should update server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
    });
    
    it(@"Last Mod wins, 3 should update server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        
    });

});

describe(@"Insert 5 Online, T1 update 2 Online, Go offline and update 5,", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should update server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
    });
    
    it(@"Last Mod wins, 5 should update server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
        
    });
    
});

describe(@"Insert 5 Online, Go offline and update 5, T2 delete 2 Online", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should update server, 2 should delete from cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:3];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:3];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
    });
    
    it(@"Last Mod wins, delete time not known, 5 should update server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
        
    });
    
});

describe(@"Insert 5 Online, Delete 2 online at T1, Go offline and update 5 at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should update server, 2 should delete from cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:3];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:3];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
    });
    
    it(@"Last Mod wins, delete time not known, 5 should update server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
    });
    
});

describe(@"Insert 5 Online, Go offline and update 5, T2 update 1 and delete 1 Online", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should update server, 1 should update cache, 1 should delete from cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // update 1 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // delete 1 Online at T2
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:4];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(1)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:4];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(1)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
    });
    
    it(@"Last Mod wins, delete time not known, 4 should update server, 1 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // update 1 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // delete 1 Online at T2
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(1)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(4)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(1)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(4)];
        
        
    });
    
});

describe(@"Insert 5 Online, Delete 1 online at T1, update 1 at T1, Go offline and update 5 at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should update server, 1 should update cache, 1 should delete from cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // update 1 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // delete 1 Online at T1
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:4];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(1)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:4];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(1)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(3)];
        
    });
    
    it(@"Last Mod wins, delete time not known, 5 should update server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // update 1 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // delete 1 Online at T1
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"5678" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Update 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [todo setValue:@"offline client update" forKey:@"title"];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(5)];
        
    });
    
});

//////////////////////////////
/////////DELETES///////////
//////////////////////////////
/*
describe(@"Insert 1 Online, Delete 1 Offline, NO CONFLICT", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    
    it(@"Should send object as an update, no merge policy should get called", ^{
        
        // Online insert
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Offline delete
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // TODO better testing that merge policy never gets called
        
    });
    
});

describe(@"Insert 1 Online, Delete Offline at T1, Update Online at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as a delete", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Update online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
    
    it(@"Last Mod Wins MP, Should update cache with server object", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Update online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
    });
    
    it(@"Server Wins MP, Should update cache with server object", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        
        // Update online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
    });
    
});

describe(@"Insert 1 Online, Update Online at T1, Delete Offline at T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    it(@"Client Wins MP, Should send object as a delete", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Delete offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
    
    it(@"Last Mod Wins MP, Should send object as a delete", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Delete offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
    
    it(@"Server Wins MP, Should update cache with server object", ^{
        // Insert online
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"online server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Delete offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
 
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"online server update"];
        
    });
    
});

describe(@"Insert 1 Online, Delete 1 Offline at T1, Delete 1 Online at T2, NO CONFLICT", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    
    it(@"No action is taken, no merge policy should get called", ^{
        
        // Online insert
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Offline delete at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        // Online delete at T2
        sleep(3);
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // TODO better testing that merge policy never gets called
        
    });
    
});

describe(@"Insert 1 Online, Delete 1 Online at T1, Delete 1 Offline at T2, NO CONFLICT", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    
    
    it(@"No action is taken, no merge policy should get called", ^{
        
        // Online insert
        NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo setValue:@"1234" forKey:[todo primaryKeyField]];
        [todo setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        // Online delete at T1
        dispatch_group_enter(group);
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"todo" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Offline delete at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:todo];
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // TODO better testing that merge policy never gets called
        
    });
    
});

describe(@"Sync Errors, Inserting offline to a forbidden schema with POST perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        
    });
    it(@"Error callback should get called", ^{
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermspost" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermspostId"];
        [object setValue:@"post perms" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setMergeCallbackForFailedInserts:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            // Check server
            [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});
 
describe(@"Sync Errors, Inserting offline to a forbidden schema with GET perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        
    });
    it(@"Error callback should get called", ^{
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermsget" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermsgetId"];
        [object setValue:@"get perms" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setMergeCallbackForFailedInserts:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            // Check server
            [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            dispatch_group_leave(group);
            
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});


describe(@"Insert 5 Online, Go offline and delete 5, T2 update 2 Online", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should delete from server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Delete 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
    });
    
    it(@"Last Mod wins, 3 should delete from server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
    it(@"Client wins, 5 should delete from server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 5 offline at T1
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T2
        sleep(3);
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
});

describe(@"Insert 5 Online, Update 2 Online T1, Go offline and delete 5 T2", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
    it(@"Server Mod wins, 3 should delete from server, 2 should update cache", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Delete 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:2];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(2)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
    });
    
    it(@"Last Mod wins, should delete 5 from the server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Delete 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];

        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyLastModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
    it(@"Client wins, 5 should delete from server", ^{
        
        // Insert 5 online
        for (int i=0; i < 3; i++) {
            NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
            [todo setValue:[todo assignObjectId] forKey:[todo primaryKeyField]];
            [todo setValue:@"online insert" forKey:@"title"];
        }
        NSManagedObject *todo1234 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo1234 setValue:@"1234" forKey:[todo1234 primaryKeyField]];
        [todo1234 setValue:@"online insert" forKey:@"title"];
        
        NSManagedObject *todo5678 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [todo5678 setValue:@"5678" forKey:[todo5678 primaryKeyField]];
        [todo5678 setValue:@"online insert" forKey:@"title"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update 2 Online at T1
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"1234" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_group_enter(group);
        [testProperties.cds updateObjectWithId:@"5678" inSchema:@"todo" update:[NSDictionary dictionaryWithObjectsAndKeys:@"T2 server update", @"title", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *theObject, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
            [theError shouldBeNil];
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Delete 5 offline at T2
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&saveError];
        [[results should] haveCountOf:5];
        
        [results enumerateObjectsUsingBlock:^(id todo, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:todo];
        }];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];

        
        // Sync with server
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        __block int t2OnlineServerUpdateTitles = 0;
        __block int offlineClientUpdateTitles = 0;
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        t2OnlineServerUpdateTitles = 0;
        offlineClientUpdateTitles = 0;
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *title = [obj valueForKey:@"title"];
            if ([title isEqualToString:@"T2 server update"]) {
                t2OnlineServerUpdateTitles++;
            } else {
                offlineClientUpdateTitles++;
            }
        }];
        
        [[theValue(t2OnlineServerUpdateTitles) should] equal:theValue(0)];
        [[theValue(offlineClientUpdateTitles) should] equal:theValue(0)];
        
        
    });
    
});




describe(@"Sync Errors, Updating offline to a forbidden schema with PUT perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
    });
    it(@"Error callback should get called", ^{
        // Insert online
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermsput" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermsputId"];
        [object setValue:@"original title" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [object setValue:@"put perms" forKey:@"title"];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setMergeCallbackForFailedUpdates:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            // Check server
            [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
            [[results should] haveCountOf:1];
            if ([results count] == 1) {
                [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"original title"];
            }
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch2 = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsput"];
            saveError = nil;
            results = [testProperties.moc executeFetchRequestAndWait:cacheFetch2 error:&saveError];
            [[results should] haveCountOf:1];
            if ([results count] == 1) {
                [[[[results objectAtIndex:0] valueForKey:@"title"] should] equal:@"original title"];
            }
            
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});
describe(@"Sync Errors, Updating offline to a forbidden schema with GET perms", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        
    });
    afterEach(^{
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        dispatch_group_enter(group);
        
        [testProperties.cds deleteObjectId:@"1234" inSchema:@"offlinepermsget" options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        SM_CACHE_ENABLED = NO;
    });
    it(@"Error callback should get called", ^{
        // Insert online
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Offlinepermsget" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"offlinepermsgetId"];
        [object setValue:@"original title" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Update offline
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [object setValue:@"get perms" forKey:@"title"];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        // Sync
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        __block SMCoreDataStore *blockCoreDataStore = testProperties.cds;
        [testProperties.cds setMergeCallbackForFailedUpdates:^(NSArray *objects) {
            [[objects should] haveCountOf:1];
            [blockCoreDataStore markArrayOfFailedObjectsAsSynced:objects purgeFromCache:YES];
        }];
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        dispatch_queue_t newQueue = dispatch_queue_create("newQueue", NULL);
        
        dispatch_group_enter(group);
        
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 5 * NSEC_PER_SEC), newQueue, ^{
            
            // Check cache
            [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
            NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Offlinepermsget"];
            saveError = nil;
            NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
            [[results should] haveCountOf:0];
            
            dispatch_group_leave(group);
        });
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
    });
});

describe(@"Sync Global request options with HTTPS", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
    });
    afterEach(^{
        
    });
    it(@"Only makes HTTPS calls", ^{
        
        testProperties.cds.globalRequestOptions = [SMRequestOptions optionsWithHTTPS];
        
        [[testProperties.cds.session.regularOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) withCount:0];
        [[testProperties.cds.session.secureOAuthClient should] receive:@selector(requestWithMethod:path:parameters:) withCount:5];
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSManagedObject *object = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        [object setValue:@"1234" forKey:@"todoId"];
        [object setValue:@"only https" forKey:@"title"];
        
        __block NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyClientWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
        
    });
});


describe(@"Syncing with user objects, Inserts", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
    });
    it(@"Succeeds without error", ^{
        
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        User3 *user = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:testProperties.moc];
        [user setUsername:@"Bob"];
        [user setPassword:@"1234"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"username"] should] equal:@"Bob"];
        }
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"username"] should] equal:@"Bob"];
        }
    });
});

describe(@"Syncing with user objects, Updates", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSError *saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&saveError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        saveError = nil;
        BOOL success = [testProperties.moc saveAndWait:&saveError];
        [[theValue(success) should] beYes];
        SM_CACHE_ENABLED = NO;
    });
    it(@"Succeeds without error", ^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        User3 *user = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:testProperties.moc];
        [user setUsername:@"Bob"];
        [user setPassword:@"1234"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [user setEmail:@"bob@bob.com"];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"email"] should] equal:@"bob@bob.com"];
        }
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"email"] should] equal:@"bob@bob.com"];
        }
    });
});

describe(@"Syncing with user objects, Deletes", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
    });
    afterEach(^{
        SM_CACHE_ENABLED = NO;
    });
    it(@"Succeeds without error", ^{
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        User3 *user = [[User3 alloc] initWithEntity:entity insertIntoManagedObjectContext:testProperties.moc];
        [user setUsername:@"Bob"];
        [user setPassword:@"1234"];
        
        NSError *saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        sleep(3);
        NSArray *persistentStores = [testProperties.cds.persistentStoreCoordinator persistentStores];
        SMIncrementalStore *store = [persistentStores lastObject];
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(NO)];
        
        [testProperties.moc deleteObject:user];
        
        saveError = nil;
        [testProperties.moc saveAndWait:&saveError];
        [saveError shouldBeNil];
        
        [store stub:@selector(SM_checkNetworkAvailability) andReturn:theValue(YES)];
        
        dispatch_queue_t queue = dispatch_queue_create("queue", NULL);
        dispatch_group_t group = dispatch_group_create();
        
        [testProperties.cds setMergeCallbackQueue:queue];
        [testProperties.cds setDefaultSMMergePolicy:SMMergePolicyServerModifiedWins];
        [testProperties.cds setSyncCompletionCallback:^(NSArray *objects) {
            dispatch_group_leave(group);
        }];
        
        dispatch_group_enter(group);
        
        [testProperties.cds syncWithServer];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // Check cache
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&saveError];
        [[results should] haveCountOf:0];
        
        // Check server
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        saveError = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&saveError];
        [[results should] haveCountOf:0];
        
    });
});
*/

SPEC_END