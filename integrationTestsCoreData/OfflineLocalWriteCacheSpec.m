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
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Person.h"
#import "Superpower.h"

SPEC_BEGIN(OfflineLocalWriteCacheSpec)

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
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
    });
    afterEach(^{
        SM_CACHE_ENABLED = NO;
        SM_CORE_DATA_DEBUG = NO;
    });
    it(@"A simple insert works", ^{
        // Make sure we are offline
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person assignObjectId];
        [person setValue:objectID forKey:[person primaryKeyField]];
        [person setValue:@"Bob" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Object should be in the cache
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
        
        [[theValue([results count]) should] equal:theValue(1)];
        [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Check that dates were properly created
        NSDAte *createddate = [[results objectAtIndex:0] valueForKey:@"createddate"];
        [createddate shouldNotBeNil];
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[theValue([dqMapResults count]) should] equal:theValue(1)];
    });
    /*
    it(@"insert with a to-one relationship works", ^{
        // Make sure we are offline
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person assignObjectId];
        [person setPerson_id:objectID];
        [person setFirst_name:@"Bob"];
        
        // Add Superpower
        Superpower *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        objectID = [superpower assignObjectId];
        [superpower setSuperpower_id:objectID];
        [superpower setName:@"invisibility"];
        
        [person setSuperpower:superpower];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Person should be in the cache
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
        
        [[theValue([results count]) should] equal:theValue(1)];
        Person *fetchedPerson = [results objectAtIndex:0];
        [[[fetchedPerson valueForKey:@"first_name"] should] equal:@"Bob"];
        Superpower *fetchedSuperpower = [fetchedPerson valueForKey:@"superpower"];
        [[[fetchedSuperpower valueForKey:@"name"] should] equal:@"invisibility"];
        
        // Inverse should also work
        fetch = [[NSFetchRequest alloc] initWithEntityName:@"Superpower"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"name == 'invisibility'"]];
        
        error = nil;
        results = [moc executeFetchRequestAndWait:fetch error:&error];
        
        [[theValue([results count]) should] equal:theValue(1)];
        fetchedSuperpower = [results objectAtIndex:0];
        [[[fetchedSuperpower valueForKey:@"name"] should] equal:@"invisibility"];
        fetchedPerson = [fetchedSuperpower valueForKey:@"person"];
        [[[fetchedPerson valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[theValue([dqMapResults count]) should] equal:theValue(2)];
    });
    it(@"insert with a to-many relationship works", ^{
        // Make sure we are offline
        [[[client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        [[[client.session oauthClientWithHTTPS:YES] should] receive:@selector(enqueueBatchOfHTTPRequestOperations:completionBlockQueue:progressBlock:completionBlock:) withCount:0];
        
        // Add person
        Person *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *objectID = [person assignObjectId];
        [person setPerson_id:objectID];
        [person setFirst_name:@"Bob"];
        
        // Add favorites
        NSManagedObject *favorite1 = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
        [favorite1 setValue:[favorite1 assignObjectId] forKey:[favorite1 primaryKeyField]];
        [favorite1 setValue:@"fav1" forKey:@"genre"];
        
        NSManagedObject *favorite2 = [NSEntityDescription insertNewObjectForEntityForName:@"Favorite" inManagedObjectContext:moc];
        [favorite2 setValue:[favorite2 assignObjectId] forKey:[favorite2 primaryKeyField]];
        [favorite2 setValue:@"fav2" forKey:@"genre"];
        
        [person setFavorites:[NSSet setWithObjects:favorite1, favorite2, nil]];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Person should be in the cache
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
        
        [[theValue([results count]) should] equal:theValue(1)];
        Person *fetchedPerson = [results objectAtIndex:0];
        [[[fetchedPerson valueForKey:@"first_name"] should] equal:@"Bob"];
        NSSet *favorites = [fetchedPerson valueForKey:@"favorites"];
        [[theValue([favorites count]) should] equal:theValue(2)];
        
        // Inverse should also work
        NSFetchRequest *fav1Fetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        [fav1Fetch setPredicate:[NSPredicate predicateWithFormat:@"genre == 'fav1'"]];
        
        error = nil;
        results = [moc executeFetchRequestAndWait:fav1Fetch error:&error];
        
        [[theValue([results count]) should] equal:theValue(1)];
        NSManagedObject *fetchedFavorite = [results objectAtIndex:0];
        [[[fetchedFavorite valueForKey:@"genre"] should] equal:@"fav1"];
        NSArray *fetchedPersons = [[fetchedFavorite valueForKey:@"persons"] allObjects];
        [[theValue([fetchedPersons count]) should] equal:theValue(1)];
        [[[[fetchedPersons lastObject] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Second favorite
        NSFetchRequest *fav2Fetch = [[NSFetchRequest alloc] initWithEntityName:@"Favorite"];
        [fav2Fetch setPredicate:[NSPredicate predicateWithFormat:@"genre == 'fav2'"]];
        
        error = nil;
        results = [moc executeFetchRequestAndWait:fav2Fetch error:&error];
        
        [[theValue([results count]) should] equal:theValue(1)];
        fetchedFavorite = [results objectAtIndex:0];
        [[[fetchedFavorite valueForKey:@"genre"] should] equal:@"fav2"];
        fetchedPersons = [[fetchedFavorite valueForKey:@"persons"] allObjects];
        [[theValue([fetchedPersons count]) should] equal:theValue(1)];
        [[[[fetchedPersons lastObject] valueForKey:@"first_name"] should] equal:@"Bob"];
        
        // Check dirty queue
        __block NSDictionary *dqMapResults = nil;
        NSURL *dirtyQueueURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForDirtyQueueTableWithPublicKey:client.publicKey];
        dqMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[dirtyQueueURL path]];
        
        [dqMapResults shouldNotBeNil];
        [[theValue([dqMapResults count]) should] equal:theValue(3)];
        
    });
     */
});

// to do updates and deletes

SPEC_END