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
#import "Animal.h"
#import "Capitaluser.h"

SPEC_BEGIN(ConvertPropertiesSwitchSpec)

describe(@"with fixtures", ^{
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    
    __block NSManagedObjectContext *moc;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSPredicate *predicate;
    [SMCoreDataIntegrationTestHelpers registerForMOCNotificationsWithContext:[SMCoreDataIntegrationTestHelpers moc]];
    
    beforeEach(^{
        SM_CONVERT_PROPERTIES = NO;
        SM_LOWERCASE_SCHEMA_NAMES = NO;
        fixturesToLoad = [NSArray arrayWithObjects:@"Animal", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    
    afterEach(^{
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        SM_CONVERT_PROPERTIES = YES;
        SM_LOWERCASE_SCHEMA_NAMES = YES;
    });
    
    describe(@"compound predicates", ^{
        describe(@"AND predicate", ^{
            beforeEach(^{
                predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                             [NSArray arrayWithObjects:
                              [NSPredicate predicateWithFormat:@"theName = %@", @"Jonah"],
                              [NSPredicate predicateWithFormat:@"theSpecies = %@", @"Williams"],
                              nil]];
            });
            it(@"works correctly", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@"NOT predicate", ^{
            beforeEach(^{
                predicate = [NSCompoundPredicate notPredicateWithSubpredicate:
                             [NSPredicate predicateWithFormat:@"theSpecies = %@", @"Vaznaian"]];
            });
            it(@"returns an error", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [[error should] beNonNil];
                }];
            });
        });
        describe(@"OR predicate", ^{
            beforeEach(^{
                predicate = [NSCompoundPredicate orPredicateWithSubpredicates:
                             [NSArray arrayWithObjects:
                              [NSPredicate predicateWithFormat:@"theName = %@", @"Jonah"],
                              [NSPredicate predicateWithFormat:@"theSpecies = %@", @"Williams"],
                              nil]];
            });
            it(@"returns an error", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [[error should] beNonNil];
                }];
            });
        });
    });
    describe(@"sorting", ^{
        __block NSFetchRequest *fetchRequest;
        __block NSArray *sortDescriptors;
        __block NSSortDescriptor *firstNameSD;
        __block NSSortDescriptor *companyNameSD;
        __block NSSortDescriptor *armorClassSD;
        beforeEach(^{
            firstNameSD = [NSSortDescriptor sortDescriptorWithKey:@"theName" ascending:NO];
            companyNameSD = [NSSortDescriptor sortDescriptorWithKey:@"company" ascending:NO];
            armorClassSD = [NSSortDescriptor sortDescriptorWithKey:@"armor_class" ascending:YES];
        });
        /*
        it(@"applies one sort descriptor correctly", ^{
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            sortDescriptors = [NSArray arrayWithObject:firstNameSD];
            fetchRequest = [SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:nil];
            [fetchRequest setSortDescriptors:sortDescriptors];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                [error shouldBeNil];
                [[[results objectAtIndex:0] should] haveValue:@"Matt" forKey:@"theName"];
                [[[results objectAtIndex:1] should] haveValue:@"Jonah" forKey:@"theName"];
                [[[results objectAtIndex:2] should] haveValue:@"Jon" forKey:@"theName"];
            }];
        });
         */
        it(@"applies multiple sort descriptors correctly", ^{
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            sortDescriptors = [NSArray arrayWithObjects:companyNameSD, armorClassSD, nil];
            fetchRequest = [SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:nil];
            [fetchRequest setSortDescriptors:sortDescriptors];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                [error shouldBeNil];
                [[[results objectAtIndex:0] should] haveValue:@"Vaznaian" forKey:@"theSpecies"];
                [[[results objectAtIndex:1] should] haveValue:@"Cooper" forKey:@"theSpecies"];
                [[[results objectAtIndex:2] should] haveValue:@"Williams" forKey:@"theSpecies"];
            }];
        });
    });
    describe(@"pagination / limiting", ^{
        __block NSFetchRequest *fetchRequest;
        describe(@"fetchLimit", ^{
            beforeEach(^{
                fetchRequest = [SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:nil];
                [fetchRequest setFetchLimit:1];
            });
            it(@"returns the expected results", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                }];
            });
        });
        
        describe(@"fetchOffset", ^{
            beforeEach(^{
                fetchRequest = [SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:nil];
                [fetchRequest setFetchOffset:1];
            });
            /*
            it(@"returns the expected results", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[results objectAtIndex:0] should] haveValue:@"Vaznaian" forKey:@"theSpecies"];
                    [[[results objectAtIndex:1] should] haveValue:@"Williams" forKey:@"theSpecies"];
                }];
            });
             */
        });
        
        describe(@"fetchBatchSize", ^{
            beforeEach(^{
                fetchRequest = [SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:nil];
                [fetchRequest setFetchBatchSize:1];
                [fetchRequest setFetchLimit:1];
                [fetchRequest setFetchOffset:1];
            });
            it(@"returns an error", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                    [error shouldNotBeNil];
                }];
            });
        });
    });
    
    describe(@"NSIncrementalStore implementation guide says we must implement", ^{
        pending(@"shouldRefreshFetchedObjects", nil);
        pending(@"propertiesToGroupBy", nil);
        pending(@"havingPredicate", nil);
    });
    
    describe(@"queries", ^{
        describe(@"error handling", ^{
            describe(@"when the left-hand side is not a keypath", ^{
                beforeEach(^{
                    predicate = [NSPredicate predicateWithFormat:@"%@ == theSpecies", @"Vaznaian"];
                });
                it(@"returns an error", ^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                        [[error should] beNonNil];
                        [results shouldBeNil];
                    }];
                });
            });
            describe(@"when the right-hand side is not a constant", ^{
                beforeEach(^{
                    predicate = [NSPredicate predicateWithFormat:@"%@ == %@", @"theSpecies", @"Vaznaian"];
                });
                it(@"returns an error", ^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                        [[error should] beNonNil];
                        [results shouldBeNil];
                    }];
                    
                });
            });
        });
        describe(@"==", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"theSpecies == %@", @"Cooper"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                }];
            });
        });
        describe(@"=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"theSpecies = %@", @"Cooper"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                }];
            });
        });
        /*
        describe(@"!=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"theSpecies != %@", @"Williams"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Matt"];
                }];
            });
        });
        describe(@"<>", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"theSpecies <> %@", @"Williams"];
            });
            
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Matt"];
                }];
            });
            
        });
        describe(@"<", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class < %@", [NSNumber numberWithInt:15]];
            });
            
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                }];
            });
            
        });
        describe(@">", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class > %@", [NSNumber numberWithInt:15]];
            });
            
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Matt"];
                }];
            });
             
        });
        describe(@"<=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class <= %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@"=<", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class =< %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@">=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class >= %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Matt"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@"=>", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class => %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Matt"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@"BETWEEN", ^{
            beforeEach(^{
                NSArray *range = [NSArray arrayWithObjects:
                                  [NSNumber numberWithInt:12],
                                  [NSNumber numberWithInt:15],
                                  nil];
                predicate = [NSPredicate predicateWithFormat:@"armor_class BETWEEN %@", range];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Jon"];
                    [[[[results objectAtIndex:1] valueForKey:@"theName"] should] equal:@"Jonah"];
                }];
            });
        });
         */
        describe(@"IN", ^{
            __block NSArray *first_names;
            beforeEach(^{
                first_names = [NSArray arrayWithObjects:@"Aaron", @"Bob", @"Clyde", @"Ducksworth", @"Elliott", @"Matt", nil];
                predicate = [NSPredicate predicateWithFormat:@"theName IN %@", first_names];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makeAnimalFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[[[results objectAtIndex:0] valueForKey:@"theName"] should] equal:@"Matt"];
                }];
            });
        });
    });
    
});


describe(@"Fetch request on User which inherits from the SMUserManagedObject", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block Capitaluser *user1 = nil;
    __block Capitaluser *user2 = nil;
    __block Capitaluser *user3 = nil;
    beforeEach(^{
        SM_CONVERT_PROPERTIES = NO;
        SM_LOWERCASE_SCHEMA_NAMES = NO;
        SM_CORE_DATA_DEBUG = YES;
        // create a bunch of users
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"Capitaluser"];
        [client setUserPrimaryKeyField:@"userName"];
        [SMClient setDefaultClient:client];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        user1 = [[Capitaluser alloc] initWithEntity:[NSEntityDescription entityForName:@"Capitaluser" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        [user1 setUserName:[NSString stringWithFormat:@"matt%d", arc4random() / 10000]];
        [user1 setPassword:@"1234"];
        
        user2 = [[Capitaluser alloc] initWithEntity:[NSEntityDescription entityForName:@"Capitaluser" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        [user2 setUserName:[NSString stringWithFormat:@"matt%d", arc4random() / 10000]];
        [user2 setPassword:@"1234"];
        
        user3 = [[Capitaluser alloc] initWithEntity:[NSEntityDescription entityForName:@"Capitaluser" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        [user3 setUserName:[NSString stringWithFormat:@"matt%d", arc4random() / 10000]];
        [user3 setPassword:@"1234"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:user1];
        [moc deleteObject:user2];
        [moc deleteObject:user3];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        SM_CONVERT_PROPERTIES = YES;
        SM_LOWERCASE_SCHEMA_NAMES = YES;
        SM_CORE_DATA_DEBUG = NO;
    });
    it(@"Should correctly fetch", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Capitaluser" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];
        NSError *anError = nil;
        NSArray *theResults = [moc executeFetchRequestAndWait:fetchRequest error:&anError];
        [anError shouldBeNil];
        [[theValue([theResults count]) should] equal:theValue(3)];
    });
    
});
/*
describe(@"fetch requests for managed objects", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block User3 *user1 = nil;
    __block NSManagedObject *todoObject = nil;
    beforeEach(^{
        // create a bunch of users
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        user1 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        [user1 setUsername:@"matt1234"];
        [user1 setPassword:@"1234"];
        
        todoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todoObject setValue:[todoObject assignObjectId] forKey:[todoObject primaryKeyField]];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        [todoObject setValue:user1 forKey:@"user3"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:user1];
        [moc deleteObject:todoObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Should correctly fetch", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Todo" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"user3 == %@", user1]];
        NSError *anError = nil;
        NSArray *theResults = [moc executeFetchRequestAndWait:fetchRequest error:&anError];
        [anError shouldBeNil];
        [[theValue([theResults count]) should] equal:theValue(1)];
    });
});
*/

describe(@"create an instance of SMCoreDataStore from SMClient", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *coreDataStore = nil;
    __block NSManagedObjectModel *mom = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        mom = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        coreDataStore = [client coreDataStoreWithManagedObjectModel:mom];
        
    });
    describe(@"with a managedObjectContext from SMCoreDataStore", ^{
        beforeEach(^{
            moc = [coreDataStore contextForCurrentThread];
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        });
        describe(@"inserting an object", ^{
            __block NSManagedObject *aPerson = nil;
            beforeEach(^{
                aPerson = [NSEntityDescription insertNewObjectForEntityForName:@"Animal" inManagedObjectContext:moc];
                [aPerson setValue:@"the" forKey:@"first_name"];
                [aPerson setValue:@"dude" forKey:@"last_name"];
                [aPerson setValue:[aPerson assignObjectId] forKey:[aPerson primaryKeyField]];
            });
            afterEach(^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [moc deleteObject:aPerson];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    [error shouldBeNil];
                }];
            });
            it(@"the context should have inserted objects", ^{
                [[theValue([[moc insertedObjects] count]) should] beGreaterThan:theValue(0)];
            });
            it(@"a call to save should not fail", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    [error shouldBeNil];
                    [[theValue([[moc insertedObjects] count]) should] equal:theValue(0)];
                }];
            });
        });
        describe(@"inserting a user object", ^{
            
        });
        describe(@"read, update", ^{
            __block NSManagedObject *aPerson = nil;
            beforeEach(^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                aPerson = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
                [aPerson setValue:@"the" forKey:@"first_name"];
                [aPerson setValue:@"dude" forKey:@"last_name"];
                [aPerson setValue:[aPerson assignObjectId] forKey:[aPerson primaryKeyField]];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    [error shouldBeNil];
                }];
            });
            afterEach(^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [moc deleteObject:aPerson];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    [error shouldBeNil];
                }];
            });
            describe(@"reads the object", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"last_name = 'dude'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[theValue([results count]) should] equal:theValue(1)];
                    NSManagedObject *theDude = [results objectAtIndex:0];
                    [[theValue([theDude valueForKey:@"first_name"]) should] equal:theValue(@"the")];
                }];
            });
            describe(@"updates the object", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [aPerson setValue:@"matt" forKey:@"first_name"];
                [aPerson setValue:@"StackMob" forKey:@"company"];
                [[theValue([[moc updatedObjects] count]) should] beGreaterThan:theValue(0)];
                [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                    [error shouldBeNil];
                }];
            });
            describe(@"after sending a request for a field that doesn't exist", ^{
                __block NSFetchRequest *theRequest = nil;
                beforeEach(^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    NSPredicate *predicate = [NSPredicate predicateWithFormat:@"not_a_field = 'hello'"];
                    theRequest = [SMCoreDataIntegrationTestHelpers makeFavoriteFetchRequest:predicate];
                });
                it(@"the fetch request should fail, and the error should contain the info", ^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    __block NSArray *results = nil;
                    [moc performBlockAndWait:^{
                        NSError *__autoreleasing error = nil;
                        results = [moc executeFetchRequest:theRequest error:&error];
                        [error shouldNotBeNil];
                    }];
                    [results shouldBeNil];
                });
            });
            describe(@"after trying inserting an object to a schema with permission Allow any logged in user when we are not logged in", ^{
                __block NSManagedObject *newManagedObject = nil;
                beforeEach(^{
                    newManagedObject = [NSEntityDescription insertNewObjectForEntityForName:@"Oauth2test" inManagedObjectContext:moc];
                    [newManagedObject setValue:@"fail" forKey:@"name"];
                    [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
                });
                it(@"a call to save: should fail, and the error should contain the info", ^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    __block BOOL saveSuccess = NO;
                    
                    NSError *anError = nil;
                    saveSuccess = [moc saveAndWait:&anError];
                    [anError shouldNotBeNil];
                    [[theValue(saveSuccess) should] beNo];
                });
            });
        });
    });
});

SPEC_END