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
#import "Person.h"

SPEC_BEGIN(LocalWriteCacheSpec)

describe(@"Count query for network status", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
    });
    afterEach(^{
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:testProperties.moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:testProperties.moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [testProperties.moc deleteObject:obj];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }];
        SM_CACHE_ENABLED = NO;
    });
    it(@"A simple save works", ^{
      // Add another Matt
      Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
      NSString *objectID = [person assignObjectId];
      [person setValue:objectID forKey:[person primaryKeyField]];
      [person setValue:@"Bob" forKey:@"first_name"];
      
      // save them to the server
      [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
          [error shouldBeNil];
      }];
    });
});

describe(@"Write-through of successfully inserted objects, online", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
    });
    afterEach(^{
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:testProperties.moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:testProperties.moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [testProperties.moc deleteObject:obj];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }];
        SM_CACHE_ENABLED = NO;
    });
    it(@"A simple save works", ^{
        
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Cache should now contain object
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [cacheFetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:cacheFetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Server should have the same object
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [serverFetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:serverFetch error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Bob"];
        
    });
    it(@"update and save/write after having read the same object doesn't crash", ^{
        
        // Create bob object on the server
        NSDictionary *bobObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Bob", @"first_name", nil];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[testProperties.client dataStore] createObject:bobObject inSchema:@"person" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
            }];
        });
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        NSError *fetchError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&fetchError];
        [[results should] haveCountOf:1];
        NSManagedObject *bob = [results objectAtIndex:0];
        [bob setValue:@"Smith" forKey:@"last_name"];
        
        // Update
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:1];
        [[[[lcMapResults allValues] lastObject] should] haveCountOf:1];
        
        
        
    });
    it(@"create and save/write then deleting should empty the cache", ^{
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Should show up in cache
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:1];
        [[[[lcMapResults allValues] lastObject] should] haveCountOf:1];
        
        
        // Delete the object
        [testProperties.moc deleteObject:person];
        [[[testProperties.moc deletedObjects] should] haveCountOf:1];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Should be deleted from cache
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:0];
                
    });
});

describe(@"Write-through of successfully inserted objects, online, Part 2", ^{
    
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
    });
    afterEach(^{
        [testProperties.cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:testProperties.moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:testProperties.moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [testProperties.moc deleteObject:obj];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *fetchError = nil;
        NSArray *todoFetchResults = [testProperties.moc executeFetchRequestAndWait:fetch error:&fetchError];
        
        [fetchError shouldBeNil];
        [todoFetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        if ([testProperties.moc hasChanges]) {
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }
        SM_CACHE_ENABLED = NO;
    });
    it(@"Creating multiple objects works as well", ^{
        Person *person1 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person1 assignObjectId];
        [person1 setValue:objectID forKey:[person1 primaryKeyField]];
        [person1 setValue:@"Bob" forKey:@"first_name"];
        
        Person *person2 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        objectID = [person2 assignObjectId];
        [person2 setValue:objectID forKey:[person2 primaryKeyField]];
        [person2 setValue:@"Gob" forKey:@"first_name"];
        
        Person *person3 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        objectID = [person3 assignObjectId];
        [person3 setValue:objectID forKey:[person3 primaryKeyField]];
        [person3 setValue:@"Alex" forKey:@"first_name"];
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:1];
        [[[[lcMapResults allValues] lastObject] should] haveCountOf:3];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        objectID = [todo1 assignObjectId];
        [todo1 setValue:objectID forKey:[todo1 primaryKeyField]];
        [todo1 setValue:@"First" forKey:@"title"];
        
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        objectID = [todo2 assignObjectId];
        [todo2 setValue:objectID forKey:[todo2 primaryKeyField]];
        [todo2 setValue:@"Second" forKey:@"title"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        
        if ([[[lcMapResults allValues] objectAtIndex:0] count] == 2) {
            [[[[lcMapResults allValues] objectAtIndex:0] should] haveCountOf:2];
        } else {
            [[[[lcMapResults allValues] objectAtIndex:0] should] haveCountOf:3];
        }
        
        if ([[[lcMapResults allValues] objectAtIndex:1] count] == 2) {
            [[[[lcMapResults allValues] objectAtIndex:1] should] haveCountOf:2];
        } else {
            [[[[lcMapResults allValues] objectAtIndex:1] should] haveCountOf:3];
        }
        
        
    });
    
    it(@"Creating multiple objects and reading them, then deleting is smooth", ^{
        Person *person1 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person1 assignObjectId];
        [person1 setValue:objectID forKey:[person1 primaryKeyField]];
        [person1 setValue:@"Bob" forKey:@"first_name"];
        
        Person *person2 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        objectID = [person2 assignObjectId];
        [person2 setValue:objectID forKey:[person2 primaryKeyField]];
        [person2 setValue:@"Gob" forKey:@"first_name"];
        
        Person *person3 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        objectID = [person3 assignObjectId];
        [person3 setValue:objectID forKey:[person3 primaryKeyField]];
        [person3 setValue:@"Alex" forKey:@"first_name"];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        objectID = [todo1 assignObjectId];
        [todo1 setValue:objectID forKey:[todo1 primaryKeyField]];
        [todo1 setValue:@"First" forKey:@"title"];
        
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        objectID = [todo2 assignObjectId];
        [todo2 setValue:objectID forKey:[todo2 primaryKeyField]];
        [todo2 setValue:@"Second" forKey:@"title"];
        
        NSManagedObject *todo3 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:testProperties.moc];
        objectID = [todo3 assignObjectId];
        [todo3 setValue:objectID forKey:[todo3 primaryKeyField]];
        [todo3 setValue:@"Third" forKey:@"title"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:testProperties.client.publicKey];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[[lcMapResults allValues] objectAtIndex:0] should] haveCountOf:3];
        [[[[lcMapResults allValues] objectAtIndex:1] should] haveCountOf:3];
        
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        NSError *personFetchError = nil;
        NSArray *personFetchResults = [testProperties.moc executeFetchRequestAndWait:personFetch error:&personFetchError];
        [[personFetchResults should] haveCountOf:3];
        
        [personFetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *todoFetchError = nil;
        NSArray *todoFetchResults = [testProperties.moc executeFetchRequestAndWait:todoFetch error:&todoFetchError];
        [[todoFetchResults should] haveCountOf:3];
        
        [todoFetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:2];
        [[[[lcMapResults allValues] objectAtIndex:0] should] haveCountOf:3];
        [[[[lcMapResults allValues] objectAtIndex:1] should] haveCountOf:3];
        
        [[[testProperties.moc deletedObjects] should] haveCountOf:6];
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[lcMapResults should] haveCountOf:0];
        
    });
});



SPEC_END