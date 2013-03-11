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
#import "StackMob.h"
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Person.h"

SPEC_BEGIN(LocalReadCacheSpec)


pending_(@"fetch request that errors returns properly", ^{
    
});
pending_(@"changing the default expand depth on queries", ^{
    
});
pending_(@"sending request options that overwrite the cache policy", ^{
    
});
pending_(@"sending request options that overwrite the expand depth", ^{
    
});
pending_(@"completion block when purging is sucessful", ^{
    
});

describe(@"LocalReadCacheInitialization", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        //SM_CORE_DATA_DEBUG = YES;
        SM_CACHE_ENABLED = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
    });
    it(@"Initializes the sqlite database", ^{
        
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];

    });
});


describe(@"Successful fetching replaces equivalent results of fetching from cache", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
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
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        SM_CACHE_ENABLED = NO;
    });
    it(@"works", ^{
        // Add another Matt
        Person *anotherMatt = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        NSString *mattObjectID = [anotherMatt assignObjectId];
        [anotherMatt setValue:mattObjectID forKey:[anotherMatt primaryKeyField]];
        [anotherMatt setValue:@"Matt" forKey:@"first_name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Matt'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(2)];
            [error shouldBeNil];
        }];
        
        // The Number of things cached should be 2
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(2)];
        
        // Delete a Matt from the server
        __block BOOL deleteSuccess = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:mattObjectID inSchema:@"person" onSuccess:^(NSString *theObjectId, NSString *schema) {
                deleteSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                deleteSuccess = NO;
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(deleteSuccess) should] beYes];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Matt'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(1)];
            [error shouldBeNil];
        }];
        
        // The Number of things cached should be 1
        lcMapResults = nil;
        cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(1)];
        
        
    });
});

describe(@"Fetch with Cache", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
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
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        SM_CACHE_ENABLED = NO;
    });
    describe(@"Cache else network logic", ^{
        it(@"behaves properly", ^{
            __block NSArray *fetchResults = nil;
            [cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
            
            [[cds should] receive:@selector(performQuery:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:) withCount:1];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                fetchResults = results;
                [error shouldBeNil];
            }];
            
            [[theValue([fetchResults count]) should] equal:theValue(3)];
            
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                fetchResults = results;
                [error shouldBeNil];
            }];
            
            [[theValue([fetchResults count]) should] equal:theValue(3)];
            
            
        });
    });
    describe(@"General Fetch Flow", ^{
        it(@"cache enabled, returned objects are saved into local cache without error", ^{
            __block NSArray *smResults = nil;
            __block NSArray *lcResults = nil;
            __block NSDictionary *lcMapResults = nil;
            
            [[theValue([cds cachePolicy]) should] equal:theValue(SMCachePolicyTryNetworkOnly)];
            
            [cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                smResults = results;
                [error shouldBeNil];
            }];
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                smResults = results;
                [error shouldBeNil];
            }];
            
            // Cache should have three entries
            NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
            lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
            
            [lcMapResults shouldNotBeNil];
            [[theValue([lcMapResults count]) should] equal:theValue(1)];
            [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(3)];
            
            // let's try again to see that fetching same objects multiple times is smooth
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                smResults = results;
            }];
            
            lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
            
            [lcMapResults shouldNotBeNil];
            [[theValue([lcMapResults count]) should] equal:theValue(1)];
            [[theValue([[[lcMapResults allValues] lastObject] count]) should] equal:theValue(3)];
            
            // Let's 100% check
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                lcResults = results;
            }];
            
            [lcResults enumerateObjectsUsingBlock:^(id managedObjectID, NSUInteger idx, BOOL *stop) {
                [[theValue([smResults indexOfObject:managedObjectID] != NSNotFound) should] beYes];
            }];
            
            // TODO Add in here to compare fields
            
            
            // Should also give us the same results
            [cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                lcResults = results;
            }];
            
            [lcResults enumerateObjectsUsingBlock:^(id managedObjectID, NSUInteger idx, BOOL *stop) {
                [[theValue([smResults indexOfObject:managedObjectID] != NSNotFound) should] beYes];
            }];
            
        });
        
    });
    
    describe(@"when in memory differs from lc", ^{
        it(@"handles correctly", ^{
            __block NSString *firstName = nil;
            __block NSString *personId = nil;
            [[theValue([cds cachePolicy]) should] equal:theValue(SMCachePolicyTryNetworkOnly)];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                // grab its values into memory
                firstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
                personId = [[results objectAtIndex:0] valueForKey:@"person_id"];
            }];
            
            // update object on the server
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"Bob", @"first_name", nil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [[client dataStore] updateObjectWithId:personId inSchema:@"person" update:dict onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    [theError shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
            
            
            __block NSString *smFirstName = nil;
            
            // fetch object from stackmob
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                
                // this should be the in memory value
                smFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
            }];
            
            // reset memory
            [moc reset];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            // fetch from LC
            __block NSString *lcFirstName = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                lcFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
            }];
            
            [[smFirstName should] equal:lcFirstName];
            
        });
    });
    
    describe(@"relationships and in memory", ^{
        it(@"should handle correctly for relationships as well", ^{
            __block NSString *firstName = nil;
            __block NSString *personId = nil;
            __block NSManagedObject *jonObject = nil;
            __block NSString *superpowerId = nil;
            
            [[theValue([cds cachePolicy]) should] equal:theValue(SMCachePolicyTryNetworkOnly)];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                // grab its values into memory
                jonObject = [results objectAtIndex:0];
                firstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
                personId = [[results objectAtIndex:0] valueForKey:@"person_id"];
            }];
            
            // add some related objects
            NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
            superpowerId = [superpower assignObjectId];
            [superpower setValue:superpowerId forKey:[superpower primaryKeyField]];
            [superpower setValue:@"superpower" forKey:@"name"];
            
            
            NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
            [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
            [interest1 setValue:@"interest1" forKey:@"name"];
            
            NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
            [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
            [interest2 setValue:@"interest2" forKey:@"name"];
            
            
            // save them to the server
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // relate and save
            [jonObject setValue:superpower forKey:@"superpower"];
            [jonObject setValue:[NSSet setWithObjects:interest1, interest2, nil] forKey:@"interests"];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // fetch all that stuff
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                // grab its values into memory
                firstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
                personId = [[results objectAtIndex:0] valueForKey:@"person_id"];
            }];
            
            
            // update object on the server
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"Bob", @"first_name", nil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [[client dataStore] updateObjectWithId:personId inSchema:@"person" update:dict onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    [theError shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
            
            
            __block NSString *smFirstName = nil;
            
            // fetch object from stackmob
            __block NSManagedObject *object = nil;
            __block NSManagedObjectContext *mocToCompare = moc;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                object = [results objectAtIndex:0];
            }];
        
            // this should be the in memory value
            smFirstName = [object valueForKey:@"first_name"];
            NSManagedObject *superpowerFromPerson = [object valueForKey:@"superpower"];
            NSString *spID = [superpowerFromPerson valueForKey:@"superpower_id"];
            [[spID should] equal:superpowerId];
            NSSet *interestSet = [object valueForKey:@"interests"];
            NSManagedObject *firstInterest = [interestSet anyObject];
            NSManagedObjectContext *interestMOC = [firstInterest managedObjectContext];
            [[interestMOC should] equal:mocToCompare];
            
            // reset memory
            [moc reset];
            [[moc parentContext] reset];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            // fetch from LC
            __block NSString *lcFirstName = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                lcFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
            }];
            
            [[smFirstName should] equal:lcFirstName];
            
            // delete objects
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
        });
    });
    
    describe(@"same tests pass when moc is reset each time", ^{
        it(@"returned objects are saved into local cache without error", ^{
            __block NSArray *smResults = nil;
            __block NSArray *lcResults = nil;
            [[theValue([cds cachePolicy]) should] equal:theValue(SMCachePolicyTryNetworkOnly)];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                smResults = results;
            }];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                lcResults = results;
            }];
            [[theValue([smResults count]) should] equal:theValue([lcResults count])];
            
            // make sure the results match
            [smResults enumerateObjectsUsingBlock:^(id smResultObj, NSUInteger smResultIdx, BOOL *stop) {
                for (NSString *key in [[[NSEntityDescription entityForName:@"Person" inManagedObjectContext:moc] attributesByName] allKeys]) {
                    NSManagedObject *smObj = [smResultObj valueForKey:key];
                    NSManagedObject *lcObj = [[lcResults objectAtIndex:smResultIdx] valueForKey:key];
                    [[smObj should] equal:lcObj];
                }
                [[[NSEntityDescription entityForName:@"Person" inManagedObjectContext:moc] relationshipsByName] enumerateKeysAndObjectsUsingBlock:^(id relationshipName, id relationshipDescription, BOOL *stopWithRelationships) {
                    if ([relationshipDescription isToMany]) {
                        if ([smResultObj valueForKey:relationshipName] == nil) {
                            [[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName] shouldBeNil];
                        } else {
                            [[theValue([[smResultObj valueForKey:relationshipName] count]) should] equal:theValue([[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName] count])];
                        }
                    } else {
                        if ([smResultObj valueForKey:relationshipName] == nil) {
                            [[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName] shouldBeNil];
                        } else {
                            [[[smResultObj valueForKey:relationshipName] should] equal:[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName]];
                        }
                    }
                }];
            }];
            
            // let's try again to see that fetching same objects multiple times is smooth
            [moc reset];
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                smResults = results;
            }];
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                lcResults = results;
            }];
            [[theValue([smResults count]) should] equal:theValue([lcResults count])];
            
            // make sure the results match
            [smResults enumerateObjectsUsingBlock:^(id smResultObj, NSUInteger smResultIdx, BOOL *stop) {
                for (NSString *key in [[[NSEntityDescription entityForName:@"Person" inManagedObjectContext:moc] attributesByName] allKeys]) {
                    NSManagedObject *smObj = [smResultObj valueForKey:key];
                    NSManagedObject *lcObj = [[lcResults objectAtIndex:smResultIdx] valueForKey:key];
                    [[smObj should] equal:lcObj];
                }
                [[[NSEntityDescription entityForName:@"Person" inManagedObjectContext:moc] relationshipsByName] enumerateKeysAndObjectsUsingBlock:^(id relationshipName, id relationshipDescription, BOOL *stopWithRelationships) {
                    if ([relationshipDescription isToMany]) {
                        if ([smResultObj valueForKey:relationshipName] == nil) {
                            [[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName] shouldBeNil];
                        } else {
                            [[theValue([[smResultObj valueForKey:relationshipName] count]) should] equal:theValue([[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName] count])];
                        }
                    } else {
                        if ([smResultObj valueForKey:relationshipName] == nil) {
                            [[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName] shouldBeNil];
                        } else {
                            [[[smResultObj valueForKey:relationshipName] should] equal:[[lcResults objectAtIndex:smResultIdx] valueForKey:relationshipName]];
                        }
                    }
                }];
            }];
            
            [moc reset];
            
            // update to object will work on correct MOC
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            NSPredicate *jonPredicate = [NSPredicate predicateWithFormat:@"first_name == 'Jon'"];
            __block NSArray *jonFetchResults = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:jonPredicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonFetchResults = results;
            }];
            NSManagedObject *object = [jonFetchResults objectAtIndex:0];
            [[[object valueForKey:@"first_name"] should] equal:@"Jon"];
            
            [object setValue:@"Ty" forKey:@"first_name"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // Should then be able to fetch updated object, go offline and fetch updated again
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Ty'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
            
            [moc reset];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Ty'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
        });
    });
    
    describe(@"newValuesForRelationship offline testing, To-One", ^{
        it(@"to-one null relationship returns null", ^{
            __block NSManagedObject *jonObject = nil;
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];
        });
        
        it(@"to-one relationship fault fill without internet when related object has NOT been previously fetched remains a fault", ^{
            __block NSManagedObject *jonObject = nil;
            __block NSString *superpowerId = nil;
            // go online
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];

            // add some related objects
            NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
            superpowerId = [superpower assignObjectId];
            [superpower setValue:superpowerId forKey:[superpower primaryKeyField]];
            [superpower setValue:@"superpower" forKey:@"name"];
            
            // save them to the server
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // relate and save
            [jonObject setValue:superpower forKey:@"superpower"];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            [moc reset];
            [moc.parentContext reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            NSString *name = [jonObject valueForKey:@"first_name"];
            [[name should] equal:@"Jon"];
            NSError *anError = nil;
            NSManagedObject *jonSuperpower = [jonObject valueForRelationshipKey:@"superpower" error:&anError];
            
            NSString *jonSuperpowerName = [jonSuperpower valueForKey:@"name"];
            [[jonSuperpowerName should] equal:@"superpower"];
            
            // delete objects
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
        
        it(@"to-one relationship fault fill without internet when related object has been previously fetched returns properly", ^{
            __block NSManagedObject *jonObject = nil;
            __block NSString *superpowerId = nil;
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];
            
            // add some related objects
            NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
            superpowerId = [superpower assignObjectId];
            [superpower setValue:superpowerId forKey:[superpower primaryKeyField]];
            [superpower setValue:@"superpower" forKey:@"name"];
            
            // save them to the server
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // relate and save
            [jonObject setValue:superpower forKey:@"superpower"];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:[NSPredicate predicateWithFormat:@"name == 'superpower'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
            }];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            NSManagedObject *jonSuperpower = nil;
            @try {
                jonSuperpower = [jonObject valueForKey:@"superpower"];
            }
            @catch (NSException *exception) {
                [exception shouldBeNil];
            }
            
            [jonSuperpower shouldNotBeNil];
            [[[jonSuperpower valueForKey:@"name"] should] equal:@"superpower"];
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
        
        it(@"to-one relationship fault fill with internet returns related object and caches correctly", ^{
            __block NSManagedObject *jonObject = nil;
            __block NSString *superpowerId = nil;
           [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];
            
            // add some related objects
            NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
            superpowerId = [superpower assignObjectId];
            [superpower setValue:superpowerId forKey:[superpower primaryKeyField]];
            [superpower setValue:@"superpower" forKey:@"name"];
            
            // save them to the server
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // relate and save
            [jonObject setValue:superpower forKey:@"superpower"];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            NSManagedObject *jonSuperpower = [jonObject valueForKey:@"superpower"];

            [jonSuperpower shouldNotBeNil];
            
            // should be able to fetch jonSuperpower after moc was reset
            NSString *superpowerName = [[jonObject valueForKey:@"superpower"] valueForKey:@"name"];
            [[superpowerName should] equal:@"superpower"];
            
            // We can then clear the moc, go offline and fetch both items
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            jonSuperpower = [jonObject valueForKey:@"superpower"];
            
            [jonSuperpower shouldNotBeNil];
            
            // should be able to fetch jonSuperpower after moc is reset
            superpowerName = [[jonObject valueForKey:@"superpower"] valueForKey:@"name"];
            [[superpowerName should] equal:@"superpower"];
            
            
            // delete objects
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
         
    });
    
    describe(@"newValuesForRelationship offline testing, To-Many", ^{
        
        it(@"to-many null relationship returns empty set", ^{
            __block NSManagedObject *jonObject = nil;
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSSet *interestsSet = [jonObject valueForKey:@"interests"];
                [interestsSet shouldNotBeNil];
                [[theValue([interestsSet count]) should] equal:theValue(0)];
            }];
        });
         
        
        it(@"To-Many relationship fault fill without internet when related object has NOT been previously fetched remains a fault", ^{
            __block NSManagedObjectContext *testContext = moc;
            __block Person *jonObject = nil;
            //SM_CORE_DATA_DEBUG = YES;
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:testContext withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:testContext] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];
            
            // add some related objects
            NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:testContext];
            [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
            [interest1 setValue:@"interest1" forKey:@"name"];
            
            NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:testContext];
            [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
            [interest2 setValue:@"interest2" forKey:@"name"];
            
            // save them to the server
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testContext withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // relate and save
            [jonObject addInterests:[NSSet setWithObjects:interest1, interest2, nil]];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testContext withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            [testContext reset];
            [[testContext parentContext] reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:testContext withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:testContext] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            
            NSString *jonName = [jonObject valueForKey:@"first_name"];
            [[jonName should] equal:@"Jon"];
            NSSet *jonInterests = [jonObject valueForKey:@"interests"];
            [jonInterests enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
                NSString *interestName = [obj valueForKey:@"name"];
                if ([interestName isEqualToString:@"interest1"]) {
                    [[interestName should] equal:@"interest1"];
                } else {
                    [[interestName should] equal:@"interest2"];
                }
            }];
            
            // delete objects
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:testContext withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil context:testContext] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [testContext deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testContext withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
        
        it(@"To-Many relationship fault fill with internet returns related object and caches correctly", ^{
            __block Person *jonObject = nil;
            
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];
            
            // add some related objects
            NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
            [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
            [interest1 setValue:@"interest1" forKey:@"name"];
            
            NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
            [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
            [interest2 setValue:@"interest2" forKey:@"name"];
            
            // save them to the server
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // relate and save
            [jonObject addInterests:[NSSet setWithObjects:interest1, interest2, nil]];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            NSArray *jonInterests = [[jonObject valueForKey:@"interests"] allObjects];
            
            // should be able to fetch jonSuperpower after moc was reset
            NSString *interestName = [[jonInterests objectAtIndex:0] valueForKey:@"name"];
            NSArray *interestsArray = [NSArray arrayWithObjects:@"interest1", @"interest2", nil];
            [[interestsArray should] contain:interestName];
            
            // We can then clear the moc, go offline and fetch both items
            [cds setCachePolicy:SMCachePolicyTryCacheOnly];
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"] context:moc] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            jonInterests = [[jonObject valueForKey:@"interests"] allObjects];
            
            // should be able to fetch jonSuperpower after moc was reset
            interestName = [[jonInterests objectAtIndex:0] valueForKey:@"name"];
            interestsArray = [NSArray arrayWithObjects:@"interest1", @"interest2", nil];
            [[interestsArray should] contain:interestName];
            
            
            // delete objects
            [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
     
    });

});


describe(@"Purging the Cache", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
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
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
    });
    afterEach(^{
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        SM_CACHE_ENABLED = NO;
    });
    it(@"Should clear the cache of objects that are deleted", ^{
        __block NSArray *resultfOfFetch = nil;
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultfOfFetch = results;
        }];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(3)];
        
        [resultfOfFetch enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        lcMapResults = nil;
        cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(0)];
        
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [[theValue([results count]) should] equal:theValue(0)];
        }];
        
    });
    
    it(@"interface for purging the cache of an object", ^{
        __block NSArray *resultfOfFetch = nil;
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultfOfFetch = results;
        }];
        
        NSManagedObject *anItem = [resultfOfFetch objectAtIndex:0];
        
        [cds purgeCacheOfMangedObjectID:[anItem objectID]];
        
        sleep(5);
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(2)];
        
        // TODO grab actual objects and test with cache objects
        
    });
    it(@"resetting the cache", ^{
        __block NSArray *resultfOfFetch = nil;
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultfOfFetch = results;
        }];
        
        [[theValue([resultfOfFetch count]) should] equal:theValue(3)];
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(3)];
        
        [cds resetCache];
        
        sleep(5);
        
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultfOfFetch = results;
        }];
        
        [[theValue([resultfOfFetch count]) should] equal:theValue(0)];
        
        lcMapResults = nil;
        cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(0)];
    });
});

describe(@"purging cache of multiple objects at a time", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
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
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
    });
    afterEach(^{
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        SM_CACHE_ENABLED = NO;
    });
    it(@"interface for purging the cache of objects", ^{
        __block NSArray *resultfOfFetch = nil;
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultfOfFetch = results;
        }];
        
        [cds purgeCacheOfMangedObjects:resultfOfFetch];
        
        sleep(5);
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(0)];
        
        // deleting the objects through CD shouldn't break
        [resultfOfFetch enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
    });
    it(@"interface for purging the cache of objects by entity name", ^{
        __block NSArray *resultfOfFetch = nil;
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultfOfFetch = results;
        }];
        
        [cds purgeCacheOfObjectsWithEntityName:@"Todo"];
        
        sleep(5);
        
        __block NSDictionary *lcMapResults = nil;
        NSURL *cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(1)];
        [[theValue([[[lcMapResults allValues] objectAtIndex:0] count]) should] equal:theValue(3)];
        
        [cds purgeCacheOfObjectsWithEntityName:@"Person"];
        
        sleep(5);
        
        lcMapResults = nil;
        cacheMapURL = [SMCoreDataIntegrationTestHelpers SM_getStoreURLForCacheMapTableWithPublicKey:client.publicKey];
        lcMapResults = [SMCoreDataIntegrationTestHelpers getContentsOfFileAtPath:[cacheMapURL path]];
        
        [lcMapResults shouldNotBeNil];
        [[theValue([lcMapResults count]) should] equal:theValue(0)];
        
        // deleting the objects through CD shouldn't break
        [resultfOfFetch enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
    });
});

describe(@"cache references should not be returned during fetches", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
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
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        
        // Fetch all persons
        __block NSArray *resultsOfFetch = nil;
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            resultsOfFetch = results;
        }];
        
        // Make a relationship
        // add some related objects
        NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
        [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
        [interest1 setValue:@"interest1" forKey:@"name"];
        
        NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
        [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
        [interest2 setValue:@"interest2" forKey:@"name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        [[resultsOfFetch objectAtIndex:0] addInterests:[NSSet setWithObjects:interest1, interest2, nil]];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Fetch all persons again to create nil references
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            resultsOfFetch = results;
        }];
    });
    afterEach(^{
        // delete
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [moc deleteObject:obj];
            }];
        }];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        SM_CACHE_ENABLED = NO;
    });
    it(@"works", ^{
        
        [cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
        
        [[cds should] receive:@selector(performQuery:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:) withCount:1];
        
        // Fetch that entity, should not throw an exception
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil context:moc] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [[theValue([results count]) should] equal:theValue(2)];
        }];
    });
});

describe(@"Testing cache using Entity with a GeoPoint attribute", ^{
    __block NSManagedObjectContext *moc = nil;
    __block NSManagedObject *geoObject = nil;
    __block NSManagedObject *geoObject2 = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSDictionary *location = nil;
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        //SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient: client];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        geoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        
        NSNumber *lat = [NSNumber numberWithDouble:37.77215879638275];
        NSNumber *lon = [NSNumber numberWithDouble:-122.4064476357965];
        
        location = [NSDictionary dictionaryWithObjectsAndKeys:
                    lat
                    ,@"lat"
                    ,lon
                    ,@"lon", nil];
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:location];
        
        [geoObject setValue:data forKey:@"geopoint"];
        [geoObject setValue:@"StackMob" forKey:@"name"];
        [geoObject setValue:[geoObject assignObjectId] forKey:[geoObject primaryKeyField]];
        
        geoObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        NSNumber *lat2 = [NSNumber numberWithDouble:42.280373];
        NSNumber *lon2 = [NSNumber numberWithDouble:-71.416669];
        
        NSDictionary *location2 = [NSDictionary dictionaryWithObjectsAndKeys:
                                   lat2
                                   ,@"lat"
                                   ,lon2
                                   ,@"lon", nil];
        
        NSData *data2 = [NSKeyedArchiver archivedDataWithRootObject:location2];
        [geoObject2 setValue:data2 forKey:@"geopoint"];
        [geoObject2 setValue:@"Framingahm" forKey:@"name"];
        [geoObject2 setValue:[geoObject2 assignObjectId] forKey:[geoObject2 primaryKeyField]];
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    afterEach(^{
        [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:geoObject];
        [moc deleteObject:geoObject2];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        SM_CACHE_ENABLED = NO;
    });
    it(@"Will prevent SMPredicate query on read cache", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.810317;
        coordinate.longitude = -122.418167;
        
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithin:3.5
                                                     milesOf:coordinate];
        [fetchRequest setPredicate:predicate];
        
        
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }            
            [[theValue([results count]) should] equal:theValue(0)];
        }];
    });
    it(@"Will successfully read with an NSPredicate on read cache", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        SMPredicate *predicate = (SMPredicate *)[NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
    });
    it(@"Will prevent compound query with SMPredicate on read cache", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.810317;
        coordinate.longitude = -122.418167;
        
        SMPredicate *geoPredicate = [SMPredicate predicateWhere:@"geopoint" isWithin:1000
                                                        milesOf:coordinate];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        NSArray *predicates = [NSArray arrayWithObjects:geoPredicate, predicate, nil];
        
        NSPredicate *compoundPredicate =[NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        [fetchRequest setPredicate:compoundPredicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }            
            [[theValue([results count]) should] equal:theValue(0)];
        }];
    });
    
    it(@"Will prevent compound query with SMPredicate (embedded two levels deep) on read cache", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.810317;
        coordinate.longitude = -122.418167;
        
        SMPredicate *geoPredicate = [SMPredicate predicateWhere:@"geopoint" isWithin:1000
                                                        milesOf:coordinate];
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        NSArray *predicates = [NSArray arrayWithObjects:geoPredicate, predicate, nil];
        
        NSPredicate *compoundPredicate =[NSCompoundPredicate andPredicateWithSubpredicates:predicates];
        
        NSPredicate *predicate2 = [NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        NSArray *predicates2 = [NSArray arrayWithObjects:predicate2, compoundPredicate, nil];
        
        NSPredicate *compoundPredicate2 =[NSCompoundPredicate andPredicateWithSubpredicates:predicates2];
        [fetchRequest setPredicate:compoundPredicate2];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
        [cds setCachePolicy:SMCachePolicyTryCacheOnly];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(0)];
        }];
    });
});




// MISC TESTS

/*
 describe(@"testing", ^{
 __block SMClient *client = nil;
 __block SMCoreDataStore *cds = nil;
 __block NSManagedObjectContext *moc = nil;
 __block NSArray *fixturesToLoad;
 __block NSDictionary *fixtures;
 beforeEach(^{
 SM_CACHE_ENABLED = YES;
 //SM_CORE_DATA_DEBUG = YES;
 
 //fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
 //fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
 client = [SMIntegrationTestHelpers defaultClient];
 [SMClient setDefaultClient:client];
 [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
 NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
 NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
 NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
 cds = [client coreDataStoreWithManagedObjectModel:aModel];
 moc = [cds contextForCurrentThread];
 
 // create an object
 NSDictionary *dictionary = [NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"todo_id", @"new todo", @"title", nil];
 syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
 [[client dataStore] createObject:dictionary inSchema:@"todo" onSuccess:^(NSDictionary *theObject, NSString *schema) {
 NSLog(@"successful create");
 syncReturn(semaphore);
 } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
 NSLog(@"failure creating: %@", theError);
 syncReturn(semaphore);
 }];
 });
 
 });
 afterEach(^{
 [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
 syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
 [[client dataStore] deleteObjectId:@"1234" inSchema:@"todo" onSuccess:^(NSString *theObjectId, NSString *schema) {
 NSLog(@"successful delete");
 syncReturn(semaphore);
 } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
 NSLog(@"error deleting: %@", theError);
 syncReturn(semaphore);
 }];
 });
 //[SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
 SM_CACHE_ENABLED = NO;
 });
 it(@"tests", ^{
 NSPredicate *pred = [NSPredicate predicateWithFormat:@"todoId == '1234'"];
 NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
 [fetch setPredicate:pred];
 NSError *error = nil;
 NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
 NSLog(@"results are %@", results);
 [error shouldBeNil];
 
 error = nil;
 results = [moc executeFetchRequestAndWait:fetch error:&error];
 NSLog(@"results are %@", results);
 [error shouldBeNil];
 });
 });
 */

/*
 describe(@"testing2", ^{
 __block SMClient *client = nil;
 __block SMCoreDataStore *cds = nil;
 __block NSManagedObjectContext *moc = nil;
 beforeEach(^{
 SM_CACHE_ENABLED = YES;
 SM_CORE_DATA_DEBUG = YES;
 
 client = [SMIntegrationTestHelpers defaultClient];
 [SMClient setDefaultClient:client];
 [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
 NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
 NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
 NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
 cds = [client coreDataStoreWithManagedObjectModel:aModel];
 moc = [cds contextForCurrentThread];
 
 NSManagedObject *todo = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
 [todo setValue:@"bob" forKey:@"title"];
 [todo setValue:@"1234" forKey:[todo primaryKeyField]];
 
 NSManagedObject *category = [NSEntityDescription insertNewObjectForEntityForName:@"Category" inManagedObjectContext:moc];
 [category setValue:@"new" forKey:@"name"];
 [category setValue:@"primarykey" forKey:[category primaryKeyField]];
 
 [todo setValue:category forKey:@"category"];
 
 NSError *error = nil;
 BOOL success = [moc saveAndWait:&error];
 [[theValue(success) should] beYes];
 
 });
 afterEach(^{
 [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
 NSFetchRequest *todoFetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
 [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:todoFetch andBlock:^(NSArray *results, NSError *error) {
 [error shouldBeNil];
 [moc deleteObject:[results objectAtIndex:0]];
 }];
 NSFetchRequest *categoryFetch = [[NSFetchRequest alloc] initWithEntityName:@"Category"];
 [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:categoryFetch andBlock:^(NSArray *results, NSError *error) {
 [error shouldBeNil];
 [moc deleteObject:[results objectAtIndex:0]];
 }];
 
 NSError *error = nil;
 BOOL success = [moc saveAndWait:&error];
 [[theValue(success) should] beYes];
 
 SM_CACHE_ENABLED = NO;
 });
 it(@"tests", ^{
 [moc reset];
 
 NSPredicate *pred = [NSPredicate predicateWithFormat:@"todoId == '1234'"];
 NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
 [fetch setPredicate:pred];
 NSError *error = nil;
 NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
 NSLog(@"results are %@", results);
 [error shouldBeNil];
 
 NSManagedObject *todo = [results objectAtIndex:0];
 
 NSManagedObject *category = [todo valueForKey:@"category"];
 NSLog(@"category is %@", category);
 NSString *categoryTitle = [category valueForKey:@"name"];
 NSLog(@"title is %@", categoryTitle);
 });
 });
 */


/*
describe(@"calls to save when not online", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
    });
    it(@"should fail with appropriate error during insert", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        
        NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower setValue:[superpower assignObjectId] forKey:[superpower primaryKeyField]];
        [superpower setValue:@"superpower" forKey:@"name"];
        
        // save them to the server
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorNetworkNotReachable)];
        }];
        
        
    });
    it(@"should fail with appropriate error during update", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower setValue:[superpower assignObjectId] forKey:[superpower primaryKeyField]];
        [superpower setValue:@"superpower" forKey:@"name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        
        [superpower setValue:@"new name" forKey:@"name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorNetworkNotReachable)];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        [moc deleteObject:superpower];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    
    it(@"should fail with appropriate error during update with to-one", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower setValue:[superpower assignObjectId] forKey:[superpower primaryKeyField]];
        [superpower setValue:@"superpower" forKey:@"name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        
        [person setValue:superpower forKey:@"superpower"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorNetworkNotReachable)];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        [moc deleteObject:person];
        [moc deleteObject:superpower];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    
    it(@"should fail with appropriate error during update with to-many", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
        [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
        [interest1 setValue:@"interest1" forKey:@"name"];
        
        NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
        [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
        [interest2 setValue:@"interest2" forKey:@"name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        
        [person setValue:[NSSet setWithObjects:interest1, interest2, nil] forKey:@"interests"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorNetworkNotReachable)];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        [moc deleteObject:person];
        [moc deleteObject:interest1];
        [moc deleteObject:interest2];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    it(@"should fail with appropriate error during delete", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
        [superpower setValue:[superpower assignObjectId] forKey:[superpower primaryKeyField]];
        [superpower setValue:@"superpower" forKey:@"name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        
        [moc deleteObject:superpower];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldNotBeNil];
            [[theValue([error code]) should] equal:theValue(SMErrorNetworkNotReachable)];
        }];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
     
});


describe(@"returning proper errors from reads", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
    });
    it(@"new values for object on save with a 401", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        NSManagedObject *newMO = [NSEntityDescription insertNewObjectForEntityForName:@"Getpermission" inManagedObjectContext:moc];
        [newMO setValue:[newMO assignObjectId] forKey:[newMO primaryKeyField]];
        [newMO setValue:@"bob" forKey:@"name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        [newMO setValue:@"jack" forKey:@"name"];
        
        __block NSError *anError = nil;
        [moc performBlockAndWait:^{
            BOOL savesuccess = [moc save:&anError];
            if (!savesuccess) {
                NSLog(@"error is %@", anError);
            }
        }];
        
        [moc deleteObject:newMO];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
    });
});
 */
/*
describe(@"cache enabling and disabling", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMaps];
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
    });
    afterEach(^{
        [cds enableCache];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block NSManagedObject *fetchedPerson = nil;
        // Fetch person
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'bob'"]] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(1)];
            
            fetchedPerson = [results objectAtIndex:0];
            
        }];
        
        [moc deleteObject:fetchedPerson];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
    });
    it(@"cache should not be on by default", ^{
        
        [[theValue([cds cacheIsEnabled]) should] beNo];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // Create person
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        __block NSManagedObject *fetchedPerson = nil;
        // Fetch person
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'bob'"]] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(1)];
            
            fetchedPerson = [results objectAtIndex:0];
            
        }];
        
        // fetchedPerson should be a fault
        [[theValue([fetchedPerson isFault]) should] beYes];
        
        // being online, fault fill should cause a network call
        [[cds should] receive:@selector(readObjectWithId:inSchema:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:) withCount:1];
        NSString *name = [fetchedPerson valueForKey:@"first_name"];
        [[name should] equal:@"bob"];
        
        
    });
    it(@"can turn the cache on", ^{
        
        [[theValue([cds cacheIsEnabled]) should] beNo];
        
        [cds enableCache];
        
        [[theValue([cds cacheIsEnabled])  should] beYes];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // Create person
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        __block NSManagedObject *fetchedPerson = nil;
        // Fetch person
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'bob'"]] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(1)];
            
            fetchedPerson = [results objectAtIndex:0];
            
        }];
        
        // fetchedPerson should be a fault
        [[theValue([fetchedPerson isFault]) should] beYes];
        
        // being online, fault fill should cause a network call
        [[cds should] receive:@selector(readObjectWithId:inSchema:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:) withCount:0];
        NSString *name = [fetchedPerson valueForKey:@"first_name"];
        [[name should] equal:@"bob"];
        
        
    });

    it(@"can turn the cache on and off", ^{
        
        [[theValue([cds cacheIsEnabled]) should] beNo];
        
        [cds enableCache];
        
        [[theValue([cds cacheIsEnabled])  should] beYes];
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        // Create person
        NSManagedObject *person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        [person setValue:@"bob" forKey:@"first_name"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        __block NSManagedObject *fetchedPerson = nil;
        // Fetch person
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'bob'"]] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(1)];
            
            fetchedPerson = [results objectAtIndex:0];
            
        }];
        
        // fetchedPerson should be a fault
        [[theValue([fetchedPerson isFault]) should] beYes];
        
        // being online, fault fill should cause a network call
        NSString *name = [fetchedPerson valueForKey:@"first_name"];
        [[name should] equal:@"bob"];
        
        // DISABLE CACHE
        [moc reset];
        [moc.parentContext reset];
        [cds disableCache];
        
        [[theValue([cds cacheIsEnabled])  should] beNo];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'bob'"]] andBlock:^(NSArray *results, NSError *error) {
            [[theValue([results count]) should] equal:theValue(1)];
            
            fetchedPerson = [results objectAtIndex:0];
            
        }];
        
        // fetchedPerson should be a fault
        [[theValue([fetchedPerson isFault]) should] beYes];
        
        // being online, fault fill should cause a network call
        [[cds should] receive:@selector(readObjectWithId:inSchema:options:successCallbackQueue:failureCallbackQueue:onSuccess:onFailure:) withCount:1];
        name = [fetchedPerson valueForKey:@"first_name"];
        
        [[name should] equal:@"bob"];
        
    });
    
});
*/

// extra

/*
 it(@"To-Many relationship fault fill without internet when related object has been previously fetched returns properly", ^{
 __block NSManagedObject *jonObject = nil;
 
 [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
 
 // fetch new object, which will fault
 [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
 [[theValue([results count]) should] equal:theValue(1)];
 jonObject = [results objectAtIndex:0];
 NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
 [nullSuperpower shouldBeNil];
 }];
 
 // add some related objects
 NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
 [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
 [interest1 setValue:@"interest1" forKey:@"name"];
 
 NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
 [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
 [interest2 setValue:@"interest2" forKey:@"name"];
 
 // save them to the server
 [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
 [error shouldBeNil];
 }];
 
 // relate and save
 [jonObject setValue:[NSSet setWithObjects:interest1, interest2, nil] forKey:@"interests"];
 
 [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
 [error shouldBeNil];
 }];
 
 [moc reset];
 
 [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
 [[theValue([results count]) should] equal:theValue(1)];
 jonObject = [results objectAtIndex:0];
 }];
 
 [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
 [[theValue([results count]) should] equal:theValue(2)];
 }];
 
 [cds setCachePolicy:SMCachePolicyTryCacheOnly];
 
 NSArray *jonInterests = nil;
 @try {
 jonInterests = [[jonObject valueForKey:@"interests"] allObjects];
 }
 @catch (NSException *exception) {
 [exception shouldBeNil];
 }
 
 [jonInterests shouldNotBeNil];
 [[theValue([jonInterests count]) should] equal:theValue(2)];
 NSString *interestName = [[jonInterests objectAtIndex:0] valueForKey:@"name"];
 NSArray *interestsArray = [NSArray arrayWithObjects:@"interest1", @"interest2", nil];
 [[interestsArray should] contain:interestName];
 
 
 [cds setCachePolicy:SMCachePolicyTryNetworkOnly];
 [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
 [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
 [moc deleteObject:obj];
 }];
 }];
 [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
 [error shouldBeNil];
 }];
 });
 */

SPEC_END