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

SPEC_BEGIN(LocalReadCacheSpec)

/*
describe(@"LocalReadCacheInitialization", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
    });
    it(@"Initializes the sqlite database", ^{
        
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds managedObjectContext];

    });
});
 */

describe(@"CoreDataFetchRequest", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        // delete sqlite db for fresh restart
        NSURL *sqliteDBURL = [NSURL URLWithString:@"file://localhost/Users/mattvaz/Library/Application%20Support/iPhone%20Simulator/6.0/Library/Application%20Support/CoreDataStore.sqlite"];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *sqliteDeleteError = nil;
        BOOL sqliteDelete = [fileManager removeItemAtURL:sqliteDBURL error:&sqliteDeleteError];
        [[theValue(sqliteDelete) should] beYes];
        
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        client = [SMIntegrationTestHelpers defaultClient];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds managedObjectContext];
    });
    afterEach(^{
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        
    });
    /*
    describe(@"General Fetch Flow", ^{
        it(@"returned objects are saved into local cache without error", ^{
            __block NSArray *smResults = nil;
            __block NSArray *lcResults = nil;
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                smResults = results;
            }];
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
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
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                smResults = results;
            }];
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
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
            
            // update to object will work on correct MOC
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            NSManagedObject *object = [lcResults objectAtIndex:0];
            
            // TODO get rid of log statements
            NSLog(@"object moc is %@", [object managedObjectContext]);
            NSLog(@"moc is %@", moc);
            [object setValue:@"Ty" forKey:@"first_name"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // Should then be able to fetch updated object, go offline and fetch updated again
            NSPredicate *tyPredicate = [NSPredicate predicateWithFormat:@"first_name == 'Ty'"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:tyPredicate] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:tyPredicate] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
            
        });
    });
    */
    /*
    describe(@"when in memory differs from lc", ^{
        it(@"handles correctly", ^{
            __block NSString *firstName = nil;
            __block NSString *personId = nil;
            // go online
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                // grab its values into memory
                firstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
                personId = [[results objectAtIndex:0] valueForKey:@"person_id"];
            }];
            
            // update object on the server
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"Bob", @"first_name", nil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [[client dataStore] updateObjectWithId:personId inSchema:@"person" update:dict onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    NSLog(@"results: %@", theObject);
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    [theError shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
            
            
            __block NSString *smFirstName = nil;
            
            // fetch object from stackmob
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                
                // this should be the in memory value
                smFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
            }];
            
            // reset memory
            [moc reset];
            // go offline
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            // fetch from LC
            __block NSString *lcFirstName = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                lcFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
            }];
            
            [[smFirstName should] equal:lcFirstName];
            
        });
    });
    */
    /*
    describe(@"relationships and in memory", ^{
        it(@"should handle correctly for relationships as well", ^{
            
            NSURL *sqliteDBURL = [NSURL URLWithString:@"file://localhost/Users/mattvaz/Library/Application%20Support/iPhone%20Simulator/6.0/Library/Application%20Support/CoreDataStore.sqlite"];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSError *sqliteDeleteError = nil;
            BOOL sqliteDelete = [fileManager removeItemAtURL:sqliteDBURL error:&sqliteDeleteError];
            [[theValue(sqliteDelete) should] beYes];
            
            __block NSString *firstName = nil;
            __block NSString *personId = nil;
            __block NSManagedObject *jonObject = nil;
            __block NSString *superpowerId = nil;
            // go online
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
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
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                // grab its values into memory
                firstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
                personId = [[results objectAtIndex:0] valueForKey:@"person_id"];
            }];
            
            
            // update object on the server
            NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:@"Bob", @"first_name", nil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [[client dataStore] updateObjectWithId:personId inSchema:@"person" update:dict onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    NSLog(@"results: %@", theObject);
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    [theError shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
            
            
            __block NSString *smFirstName = nil;
            
            // fetch object from stackmob
            __block NSManagedObjectContext *mocToCompare = moc;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                
                // this should be the in memory value
                smFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
                NSManagedObject *superpowerFromPerson = [[results objectAtIndex:0] valueForKey:@"superpower"];
                NSString *spID = [superpowerFromPerson valueForKey:@"superpower_id"];
                [[spID should] equal:superpowerId];
                NSSet *interestSet = [[results objectAtIndex:0] valueForKey:@"interests"];
                NSManagedObject *firstInterest = [interestSet anyObject];
                NSLog(@"firstInterest is %@", firstInterest);
                NSManagedObjectContext *interestMOC = [firstInterest managedObjectContext];
                [[interestMOC should] equal:mocToCompare];
            }];
            
            // reset memory
            [moc reset];
            // go offline
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            // fetch from LC
            __block NSString *lcFirstName = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                lcFirstName = [[results objectAtIndex:0] valueForKey:@"first_name"];
            }];
            
            [[smFirstName should] equal:lcFirstName];
            
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
        });
    });
    */

    /*
    describe(@"same tests pass when moc is reset each time", ^{
        it(@"returned objects are saved into local cache without error", ^{
            __block NSArray *smResults = nil;
            __block NSArray *lcResults = nil;
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                smResults = results;
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
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
            
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                smResults = results;
            }];
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
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
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            NSPredicate *jonPredicate = [NSPredicate predicateWithFormat:@"first_name == 'Jon'"];
            __block NSArray *jonFetchResults = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:jonPredicate] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                [[theValue([results count]) should] equal:theValue(1)];
                jonFetchResults = results;
            }];
            NSManagedObject *object = [jonFetchResults objectAtIndex:0];
            [[[object valueForKey:@"first_name"] should] equal:@"Jon"];
            
            // TODO get rid of log statements
            NSLog(@"object moc is %@", [object managedObjectContext]);
            NSLog(@"moc is %@", moc);
            [object setValue:@"Ty" forKey:@"first_name"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // Should then be able to fetch updated object, go offline and fetch updated again
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Ty'"]] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
            
            [moc reset];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Ty'"]] andBlock:^(NSArray *results, NSError *error) {
                NSLog(@"results are %@", results);
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
        });
    });
     */
    describe(@"newValuesForRelationship offline testing", ^{
        /*
        beforeEach(^{
            NSURL *sqliteDBURL = [NSURL URLWithString:@"file://localhost/Users/mattvaz/Library/Application%20Support/iPhone%20Simulator/6.0/Library/Application%20Support/CoreDataStore.sqlite"];
            NSFileManager *fileManager = [NSFileManager defaultManager];
            
            NSError *sqliteDeleteError = nil;
            BOOL sqliteDelete = [fileManager removeItemAtURL:sqliteDBURL error:&sqliteDeleteError];
            [[theValue(sqliteDelete) should] beYes];
        });
         */
        /*
        it(@"to-one null relationship returns null", ^{
            __block NSManagedObject *jonObject = nil;
            
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSManagedObject *nullSuperpower = [jonObject valueForKey:@"superpower"];
                [nullSuperpower shouldBeNil];
            }];
        });
         */
        it(@"to-one relationship fault fill without internet when related object has NOT been previously fetched returns exception", ^{
            __block NSManagedObject *jonObject = nil;
            __block NSString *superpowerId = nil;
            // go online
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
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
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            NSManagedObject *jonSuperpower = nil;
            @try {
                jonSuperpower = [jonObject valueForKey:@"superpower"];
            }
            @catch (NSException *exception) {
                [[[exception name] should] equal:SMExceptionCannotFillRelationshipFault];
            }
            
            [jonSuperpower shouldBeNil];
            
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
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
            // go online
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
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
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:[NSPredicate predicateWithFormat:@"name == 'superpower'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            NSManagedObject *jonSuperpower = nil;
            @try {
                jonSuperpower = [jonObject valueForKey:@"superpower"];
            }
            @catch (NSException *exception) {
                [exception shouldBeNil];
            }
            
            [jonSuperpower shouldNotBeNil];
            [[[jonSuperpower valueForKey:@"name"] should] equal:@"superpower"];
            
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
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
            // go online
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            // fetch new object, which will fault
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
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
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            NSManagedObject *jonSuperpower = [jonObject valueForKey:@"superpower"];

            [jonSuperpower shouldNotBeNil];
            
            // should be able to fetch jonSuperpower after moc was reset
            NSString *superpowerName = [[jonObject valueForKey:@"superpower"] valueForKey:@"name"];
            [[superpowerName should] equal:@"superpower"];
            
            // We can then clear the moc, go offline and fetch both items
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            jonSuperpower = [jonObject valueForKey:@"superpower"];
            
            [jonSuperpower shouldNotBeNil];
            
            // should be able to fetch jonSuperpower after moc is reset
            superpowerName = [[jonObject valueForKey:@"superpower"] valueForKey:@"name"];
            [[superpowerName should] equal:@"superpower"];
            
            
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeSuperpowerFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
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

/*
describe(@"calls to save when not online", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds managedObjectContext];
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
 */

/*
 NSManagedObject *interest1 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
 [interest1 setValue:[interest1 assignObjectId] forKey:[interest1 primaryKeyField]];
 [interest1 setValue:@"interest1" forKey:@"name"];
 
 NSManagedObject *interest2 = [NSEntityDescription insertNewObjectForEntityForName:@"Interest" inManagedObjectContext:moc];
 [interest2 setValue:[interest2 assignObjectId] forKey:[interest2 primaryKeyField]];
 [interest2 setValue:@"interest2" forKey:@"name"];
 */
//[jonObject setValue:[NSSet setWithObjects:interest1, interest2, nil] forKey:@"interests"];


SPEC_END