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
#import <Kiwi/Kiwi.h>
#import "StackMob.h"
#import "SMTestProperties.h"
#import "Person.h"
#import "Superpower.h"

#define INSERTED @"inserted"
#define UPDATED @"updated"
#define DELETED @"deleted"

SPEC_BEGIN(OfflineLocalWriteCacheSpec)

describe(@"Basic insert when offline", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
    });
    afterEach(^{
        SM_CACHE_ENABLED = NO;
        //SM_CORE_DATA_DEBUG = NO;
    });
    it(@"A simple insert works", ^{
        // Make sure we are offline
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Object should be in the cache
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Check that dates were properly created
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        
        [[dqMapResults should] haveCountOf:3];
        [[[dqMapResults objectForKey:INSERTED] should] haveCountOf:1];
    });
    
    it(@"insert with a to-one relationship works", ^{
        // Make sure we are offline
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person assignObjectId];
        [person setPerson_id:objectID];
        [person setFirst_name:@"Bob"];
        
        // Add Superpower
        Superpower *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:testProperties.moc];
        objectID = [superpower assignObjectId];
        [superpower setSuperpower_id:objectID];
        [superpower setName:@"invisibility"];
        
        [person setSuperpower:superpower];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Person should be in the cache
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        
        [[results should] haveCountOf:1];
        Person *fetchedPerson = [results objectAtIndex:0];
        [[[fetchedPerson valueForKey:@"first_name"] should] equal:@"Bob"];
        Superpower *fetchedSuperpower = [fetchedPerson valueForKey:@"superpower"];
        [[[fetchedSuperpower valueForKey:@"name"] should] equal:@"invisibility"];
        
        // Inverse should also work
        fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"name == 'invisibility'"]];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        
        [[results should] haveCountOf:1];
        fetchedSuperpower = [results objectAtIndex:0];
        [[[fetchedSuperpower valueForKey:@"name"] should] equal:@"invisibility"];
        fetchedPerson = [fetchedSuperpower valueForKey:@"person"];
        [[[fetchedPerson valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[dqMapResults should] haveCountOf:3];
        [[[dqMapResults objectForKey:INSERTED] should] haveCountOf:2];
    });
    it(@"insert with a to-many relationship works", ^{
        // Make sure we are offline
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person assignObjectId];
        [person setPerson_id:objectID];
        [person setFirst_name:@"Bob"];
        
        // Add favorites
        NSManagedObject *favorite1 = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:testProperties.moc];
        [favorite1 setValue:[favorite1 assignObjectId] forKey:[favorite1 primaryKeyField]];
        [favorite1 setValue:@"fav1" forKey:@"genre"];
        
        NSManagedObject *favorite2 = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:testProperties.moc];
        [favorite2 setValue:[favorite2 assignObjectId] forKey:[favorite2 primaryKeyField]];
        [favorite2 setValue:@"fav2" forKey:@"genre"];
        
        [person setFavorites:[NSSet setWithObjects:favorite1, favorite2, nil]];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Person should be in the cache
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&error];
        
        [[results should] haveCountOf:1];
        Person *fetchedPerson = [results objectAtIndex:0];
        [[[fetchedPerson valueForKey:@"first_name"] should] equal:@"Bob"];
        NSSet *favorites = [fetchedPerson valueForKey:@"favorites"];
        [[favorites should] haveCountOf:2];
        
        // Inverse should also work
        NSFetchRequest *fav1Fetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        [fav1Fetch setPredicate:[NSPredicate predicateWithFormat:@"genre == 'fav1'"]];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fav1Fetch error:&error];
        
        [[results should] haveCountOf:1];
        NSManagedObject *fetchedFavorite = [results objectAtIndex:0];
        [[[fetchedFavorite valueForKey:@"genre"] should] equal:@"fav1"];
        NSArray *fetchedPersons = [[fetchedFavorite valueForKey:@"persons"] allObjects];
        [[fetchedPersons should] haveCountOf:1];
        [[[[fetchedPersons lastObject] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Second favorite
        NSFetchRequest *fav2Fetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        [fav2Fetch setPredicate:[NSPredicate predicateWithFormat:@"genre == 'fav2'"]];
        
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:fav2Fetch error:&error];
        
        [[results should] haveCountOf:1];
        fetchedFavorite = [results objectAtIndex:0];
        [[[fetchedFavorite valueForKey:@"genre"] should] equal:@"fav2"];
        fetchedPersons = [[fetchedFavorite valueForKey:@"persons"] allObjects];
        [[fetchedPersons should] haveCountOf:1];
        [[[[fetchedPersons lastObject] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[dqMapResults should] haveCountOf:3];
        
    });
});

// to do updates and deletes
describe(@"moving object from insert to update to delete - check dirty queue", ^{
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheOnly];
    });
    afterEach(^{
        SM_CACHE_ENABLED = NO;
        //SM_CORE_DATA_DEBUG = NO;
    });
    it(@"moves the primary key across the arrays in the dirty queue", ^{
        // Make sure we are offline
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[testProperties.client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:testProperties.moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:testProperties.client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[[dqMapResults objectForKey:INSERTED] should] haveCountOf:1];
        [[[dqMapResults objectForKey:UPDATED] should] haveCountOf:0];
        [[[dqMapResults objectForKey:DELETED] should] haveCountOf:0];
        
        // Update the person
        [person setValue:@"Jack" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Object is still considered inserted
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[[dqMapResults objectForKey:INSERTED] should] haveCountOf:1];
        [[[dqMapResults objectForKey:UPDATED] should] haveCountOf:0];
        [[[dqMapResults objectForKey:DELETED] should] haveCountOf:0];
        
        // Delete the object
        [testProperties.moc deleteObject:person];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        // Since you are offline, remove object when deleted completely
        [dqMapResults shouldNotBeNil];
        [[[dqMapResults objectForKey:INSERTED] should] haveCountOf:0];
        [[[dqMapResults objectForKey:UPDATED] should] haveCountOf:0];
        [[[dqMapResults objectForKey:DELETED] should] haveCountOf:0];
        
    });
    
});

SPEC_END