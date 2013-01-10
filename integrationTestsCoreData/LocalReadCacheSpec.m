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
        
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];

    });
});

describe(@"CoreDataFetchRequest", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    beforeEach(^{
        
        NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
        NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
        NSString *defaultName = @"CoreDataStore.sqlite";
        NSURL *sqliteDBURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
        NSFileManager *fileManager = [NSFileManager defaultManager];
        
        NSError *sqliteDeleteError = nil;
        BOOL sqliteDelete = [fileManager removeItemAtURL:sqliteDBURL error:&sqliteDeleteError];
        [[theValue(sqliteDelete) should] beYes];
        
        SM_CORE_DATA_DEBUG = YES;
        
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        client = [SMIntegrationTestHelpers defaultClient];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
    });
    afterEach(^{
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        
    });
    
    describe(@"General Fetch Flow", ^{
        it(@"returned objects are saved into local cache without error", ^{
            __block NSArray *smResults = nil;
            __block NSArray *lcResults = nil;
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                smResults = results;
            }];
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
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
                smResults = results;
            }];
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
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
            
            [object setValue:@"Ty" forKey:@"first_name"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
            // Should then be able to fetch updated object, go offline and fetch updated again
            NSPredicate *tyPredicate = [NSPredicate predicateWithFormat:@"first_name == 'Ty'"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:tyPredicate] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:tyPredicate] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                NSManagedObject *tyObject = [results objectAtIndex:0];
                [[[tyObject valueForKey:@"first_name"] should] equal:@"Ty"];
            }];
            
        });
    });
     
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
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    [theError shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
            
            
            __block NSString *smFirstName = nil;
            
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            // fetch object from stackmob
            __block NSManagedObject *object = nil;
            __block NSManagedObjectContext *mocToCompare = moc;
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Bob'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                object = [results objectAtIndex:0];
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
     
    
    describe(@"newValuesForRelationship offline testing, To-One", ^{
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
        
        it(@"to-one relationship fault fill without internet when related object has NOT been previously fetched remains a fault", ^{
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
            [moc.parentContext reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            NSString *name = [jonObject valueForKey:@"first_name"];
            [[name should] equal:@"Jon"];
            NSError *anError = nil;
            NSManagedObject *jonSuperpower = [jonObject valueForRelationshipKey:@"superpower" error:&anError];
            
            [anError shouldNotBeNil];
            [[theValue([anError code]) should] equal:theValue(SMErrorCouldNotFillRelationshipFault)];
            [jonSuperpower shouldNotBeNil];
            
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
    
    describe(@"newValuesForRelationship offline testing, To-Many", ^{
        
        it(@"to-many null relationship returns empty set", ^{
            __block NSManagedObject *jonObject = nil;
            
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
                NSSet *interestsSet = [jonObject valueForKey:@"interests"];
                [interestsSet shouldNotBeNil];
                [[theValue([interestsSet count]) should] equal:theValue(0)];
            }];
        });
         
        
        it(@"To-Many relationship fault fill without internet when related object has NOT been previously fetched remains a fault", ^{
            __block NSManagedObject *jonObject = nil;
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
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
            NSError *anError = nil;
            NSString *jonName = [jonObject valueForKey:@"first_name"];
            [[jonName should] equal:@"Jon"];
            NSSet *jonInterests = [jonObject valueForRelationshipKey:@"interests" error:&anError];
            [[theValue([jonInterests isKindOfClass:[NSSet class]]) should] equal:theValue(1)];
            [anError shouldNotBeNil];
            [[theValue([jonObject hasFaultForRelationshipNamed:@"interests"]) should] beYes];
            [[theValue([anError code]) should] equal:theValue(SMErrorCouldNotFillRelationshipFault)];
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
     
        it(@"To-Many relationship fault fill without internet when related object has been previously fetched returns properly", ^{
            __block NSManagedObject *jonObject = nil;
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
            
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            
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
            
            
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeInterestFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
                [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                    [moc deleteObject:obj];
                }];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
     
        
        it(@"To-Many relationship fault fill with internet returns related object and caches correctly", ^{
            __block NSManagedObject *jonObject = nil;
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
            
            NSArray *jonInterests = [[jonObject valueForKey:@"interests"] allObjects];
            
            // should be able to fetch jonSuperpower after moc was reset
            NSString *interestName = [[jonInterests objectAtIndex:0] valueForKey:@"name"];
            NSArray *interestsArray = [NSArray arrayWithObjects:@"interest1", @"interest2", nil];
            [[interestsArray should] contain:interestName];
            
            // We can then clear the moc, go offline and fetch both items
            [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
            [moc reset];
            
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:[NSPredicate predicateWithFormat:@"first_name == 'Jon'"]] andBlock:^(NSArray *results, NSError *error) {
                [[theValue([results count]) should] equal:theValue(1)];
                jonObject = [results objectAtIndex:0];
            }];
            
            jonInterests = [[jonObject valueForKey:@"interests"] allObjects];
            
            // should be able to fetch jonSuperpower after moc was reset
            interestName = [[jonInterests objectAtIndex:0] valueForKey:@"name"];
            interestsArray = [NSArray arrayWithObjects:@"interest1", @"interest2", nil];
            [[interestsArray should] contain:interestName];
            
            
            // delete objects
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
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
     
});

*/


describe(@"purging the cache when objects are deleted", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    beforeEach(^{
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMaps];
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
    });
    it(@"Should clear the cache of the object", ^{
        [cds enableCache];
        [[theValue([cds cacheIsEnabled]) should] beYes];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [moc deleteObject:obj];
            }];
        }];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        // Go offline
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [[theValue([results count]) should] equal:theValue(0)];
        }];
        
        
    });
    
    it(@"Should clear the mapping table of the object reference", ^{
        [cds enableCache];
        [[theValue([cds cacheIsEnabled]) should] beYes];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        __block NSMutableArray *array = [NSMutableArray array];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
            [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                [array addObject:[obj valueForKey:@"person_id"]];
                [moc deleteObject:obj];
            }];
        }];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        NSString *errorDesc = nil;
        NSPropertyListFormat format;
        NSURL *mapPath = nil;
        NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
        NSString *applicationDocumentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
        NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
        
        NSString *defaultName = @"CacheMap.plist";
        
        NSArray *paths = [NSArray arrayWithObjects:applicationDocumentsDirectory, applicationStorageDirectory, nil];
        
        NSFileManager *fm = [[NSFileManager alloc] init];
        
        for (NSString *path in paths)
        {
            NSString *filepath = [path stringByAppendingPathComponent:defaultName];
            if ([fm fileExistsAtPath:filepath])
            {
                mapPath =  [NSURL fileURLWithPath:filepath];
            }
            
        }
        
        mapPath = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
        
        [[theValue([[NSFileManager defaultManager] fileExistsAtPath:[mapPath path]]) should] beYes];
        
        NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:[mapPath path]];
        NSDictionary *temp = (NSDictionary *)[NSPropertyListSerialization
                                              propertyListFromData:plistXML
                                              mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                              format:&format
                                              errorDescription:&errorDesc];
        
        [array enumerateObjectsUsingBlock:^(id personID, NSUInteger idx, BOOL *stop) {
            [[temp objectForKey:personID] shouldBeNil];
        }];
        
        // Go offline
        [[client.session.networkMonitor stubAndReturn:theValue(0)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil] andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            [[theValue([results count]) should] equal:theValue(0)];
        }];
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


SPEC_END