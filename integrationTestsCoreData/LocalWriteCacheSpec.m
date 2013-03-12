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
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Person.h"

SPEC_BEGIN(LocalWriteCacheSpec)

describe(@"Count query for network status", ^{
    
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
    });
    afterEach(^{
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [moc deleteObject:obj];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }];
        SM_CACHE_ENABLED = NO;
    });
    it(@"A simple save works", ^{
      // Add another Matt
      Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
      NSString *objectID = [person assignObjectId];
      [person setValue:objectID forKey:[person primaryKeyField]];
      [person setValue:@"Bob" forKey:@"first_name"];
      
      // save them to the server
      [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
          [error shouldBeNil];
      }];
    });
});

describe(@"Write-through of successfully inserted objects, online", ^{
    
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
    });
    afterEach(^{
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [moc deleteObject:obj];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }];
        SM_CACHE_ENABLED = NO;
    });
    it(@"A simple save works", ^{
        
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Cache should now contain object
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        NSFetchRequest *cacheFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [cacheFetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:cacheFetch error:&error];
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Server should have the same object
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        NSFetchRequest *serverFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [serverFetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        error = nil;
        results = [moc executeFetchRequestAndWait:serverFetch error:&error];
        [error shouldBeNil];
        [[theValue([results count]) should] equal:theValue(1)];
        [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Bob"];
        
    });
    it(@"update and save/write after having read the same object doesn't crash", ^{
        
        // Create bob object on the server
        NSDictionary *bobObject = [NSDictionary dictionaryWithObjectsAndKeys:@"Bob", @"first_name", nil];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] createObject:bobObject inSchema:@"person" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
            }];
        });
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        NSError *fetchError = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&fetchError];
        [[theValue([results count]) should] equal:theValue(1)];
        NSManagedObject *bob = [results objectAtIndex:0];
        [bob setValue:@"Smith" forKey:@"last_name"];
        
        // Update
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(1)];
        
        
        
    });
    it(@"create and save/write then deleting should empty the cache", ^{
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Should show up in cache
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(1)];
        
        
        // Delete the object
        [moc deleteObject:person];
        
        [[theValue([[moc deletedObjects] count]) should] equal:theValue(1)];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Should be deleted from cache
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(0)];
                
    });
});

describe(@"Write-through of successfully inserted objects, online, Part 2", ^{
    
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
    });
    afterEach(^{
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [moc deleteObject:obj];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *fetchError = nil;
        NSArray *todoFetchResults = [moc executeFetchRequestAndWait:fetch error:&fetchError];
        
        [fetchError shouldBeNil];
        [todoFetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        
        if ([moc hasChanges]) {
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *saveError) {
                [saveError shouldBeNil];
            }];
        }
        SM_CACHE_ENABLED = NO;
    });
    it(@"Creating multiple objects works as well", ^{
        Person *person1 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person1 assignObjectId];
        [person1 setValue:objectID forKey:[person1 primaryKeyField]];
        [person1 setValue:@"Bob" forKey:@"first_name"];
        
        Person *person2 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        objectID = [person2 assignObjectId];
        [person2 setValue:objectID forKey:[person2 primaryKeyField]];
        [person2 setValue:@"Gob" forKey:@"first_name"];
        
        Person *person3 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        objectID = [person3 assignObjectId];
        [person3 setValue:objectID forKey:[person3 primaryKeyField]];
        [person3 setValue:@"Alex" forKey:@"first_name"];
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(3)];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        objectID = [todo1 assignObjectId];
        [todo1 setValue:objectID forKey:[todo1 primaryKeyField]];
        [todo1 setValue:@"First" forKey:@"title"];
        
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        objectID = [todo2 assignObjectId];
        [todo2 setValue:objectID forKey:[todo2 primaryKeyField]];
        [todo2 setValue:@"Second" forKey:@"title"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(2)];
        
        if ([[[lcMapResults allValues] objectAtIndex:0] count] == 2) {
            [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(2)];
        } else {
            [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(3)];
        }
        
        if ([[[lcMapResults allValues] objectAtIndex:1] count] == 2) {
            [[theValue([[[lcMapResults allValues] objectAtIndex:1] count]) should] equal:theValue(2)];
        } else {
            [[theValue([[[lcMapResults allValues] objectAtIndex:1] count]) should] equal:theValue(3)];
        }
        
        
    });
    
    it(@"Creating multiple objects and reading them, then deleting is smooth", ^{
        Person *person1 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person1 assignObjectId];
        [person1 setValue:objectID forKey:[person1 primaryKeyField]];
        [person1 setValue:@"Bob" forKey:@"first_name"];
        
        Person *person2 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        objectID = [person2 assignObjectId];
        [person2 setValue:objectID forKey:[person2 primaryKeyField]];
        [person2 setValue:@"Gob" forKey:@"first_name"];
        
        Person *person3 = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        objectID = [person3 assignObjectId];
        [person3 setValue:objectID forKey:[person3 primaryKeyField]];
        [person3 setValue:@"Alex" forKey:@"first_name"];
        
        NSManagedObject *todo1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        objectID = [todo1 assignObjectId];
        [todo1 setValue:objectID forKey:[todo1 primaryKeyField]];
        [todo1 setValue:@"First" forKey:@"title"];
        
        NSManagedObject *todo2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        objectID = [todo2 assignObjectId];
        [todo2 setValue:objectID forKey:[todo2 primaryKeyField]];
        [todo2 setValue:@"Second" forKey:@"title"];
        
        NSManagedObject *todo3 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        objectID = [todo3 assignObjectId];
        [todo3 setValue:objectID forKey:[todo3 primaryKeyField]];
        [todo3 setValue:@"Third" forKey:@"title"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(2)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(3)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:1] count]) should] equal:theValue(3)];
        
        NSFetchRequest *personFetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        NSError *personFetchError = nil;
        NSArray *personFetchResults = [moc executeFetchRequestAndWait:personFetch error:&personFetchError];
        [[theValue([personFetchResults count]) should] equal:theValue(3)];
        
        [personFetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        
        NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        NSError *todoFetchError = nil;
        NSArray *todoFetchResults = [moc executeFetchRequestAndWait:todoFetch error:&todoFetchError];
        [[theValue([todoFetchResults count]) should] equal:theValue(3)];
        
        [todoFetchResults enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(2)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(3)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:1] count]) should] equal:theValue(3)];
        
        [[theValue([[moc deletedObjects] count]) should] equal:theValue(6)];
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(0)];
        
    });
});



SPEC_END