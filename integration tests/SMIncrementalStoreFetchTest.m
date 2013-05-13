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
#import "User3.h"
#import "SMTestProperties.h"

SPEC_BEGIN(SMIncrementalStoreFetchTest)

describe(@"with fixtures", ^{
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    
    __block NSManagedObjectContext *moc;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSPredicate *predicate;
    //[SMCoreDataIntegrationTestHelpers registerForMOCNotificationsWithContext:[SMCoreDataIntegrationTestHelpers moc]];
    
    beforeEach(^{
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    
    afterEach(^{
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
    });
    describe(@"compound predicates", ^{
        describe(@"AND predicate", ^{
            beforeEach(^{
                predicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                             [NSArray arrayWithObjects:
                              [NSPredicate predicateWithFormat:@"company == %@", @"Carbon Five"],
                              [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"], 
                              nil]];
            });
            it(@"works correctly", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jonah"];  
                }];
            });
        });
        describe(@"NOT predicate", ^{
            beforeEach(^{
                predicate = [NSCompoundPredicate notPredicateWithSubpredicate:
                             [NSPredicate predicateWithFormat:@"last_name == %@", @"Vaznaian"]];
            });
            it(@"returns an error", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [[error should] beNonNil];
                }];
            });    
        });
        describe(@"OR predicate", ^{
            beforeEach(^{
                predicate = [NSCompoundPredicate orPredicateWithSubpredicates:
                             [NSArray arrayWithObjects:
                              [NSPredicate predicateWithFormat:@"company == %@", @"Carbon Five"],
                              [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"], 
                              nil]];
            });
            it(@"works correctly", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
                [request setPredicate:predicate];
                NSError *error = nil;
                NSArray *results = [moc executeFetchRequestAndWait:request error:&error];
                [error shouldBeNil];
                [[results should] haveCountOf:2];
                if ([results count] == 2) {
                    NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
                    [[array should] contain:@"Jon"];
                    [[array should] contain:@"Jonah"];
                }
            });
        });
    });
    describe(@"Advanced OR", ^{
        it(@"single or", ^{
            // Person where:
            // armor_class = 17 || first_name == "Jonah"
            // Should return Matt and Jonah
            NSPredicate *allOrs = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"armor_class == %@", [NSNumber numberWithInt:17]], [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"], nil]];
            
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
            [request setPredicate:allOrs];
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequestAndWait:request error:&error];
            [error shouldBeNil];
            [[results should] haveCountOf:2];
            if ([results count] == 2) {
                NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
                [[array should] contain:@"Matt"];
                [[array should] contain:@"Jonah"];
            }
        });
        it(@"multiple ors", ^{
            // Person where:
            // armor_class < 17 && ((first_name == "Jonah" && last_name == "Williams) || first_name == "Jon" || company == "Carbon Five")
            // Should return Jon and Jonah
            
            NSPredicate *firstAnd = [NSCompoundPredicate andPredicateWithSubpredicates:
                                     [NSArray arrayWithObjects:
                                      [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"],
                                      [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"],
                                      nil]];
            
            NSPredicate *secondAnd = [NSPredicate predicateWithFormat:@"first_name == %@", @"Jon"];
                                      
            NSPredicate *thirdAnd = [NSPredicate predicateWithFormat:@"company == %@", @"Carbon Five"];
            NSPredicate *allOrs = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:firstAnd, secondAnd, thirdAnd, nil]];
            
            NSPredicate *predicateForFetch = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"armor_class < %@", [NSNumber numberWithInt:17]], allOrs, nil]];
            
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
            [request setPredicate:predicateForFetch];
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequestAndWait:request error:&error];
            [error shouldBeNil];
            [[results should] haveCountOf:2];
            if ([results count] == 2) {
                NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
                [[array should] contain:@"Jon"];
                [[array should] contain:@"Jonah"];
            }
            
        });
        it(@"multiple ands in or", ^{
            // Person where:
            // armor_class < 17 && ((first_name == "Jonah" && last_name == "Williams) || (first_name == "Jon" && last_name == "Cooper") || company == "Carbon Five")
            // Should return Jon and Jonah
            
            NSPredicate *firstAnd = [NSCompoundPredicate andPredicateWithSubpredicates:
                                     [NSArray arrayWithObjects:
                                      [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"],
                                      [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"],
                                      nil]];
            
            NSPredicate *secondAnd = [NSCompoundPredicate andPredicateWithSubpredicates:
                                      [NSArray arrayWithObjects:
                                       [NSPredicate predicateWithFormat:@"first_name == %@", @"Jon"],
                                       [NSPredicate predicateWithFormat:@"last_name == %@", @"Cooper"],
                                       nil]];
            NSPredicate *thirdAnd = [NSPredicate predicateWithFormat:@"company == %@", @"Carbon Five"];
            
            NSPredicate *allOrs = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:firstAnd, secondAnd, thirdAnd, nil]];
            
            NSPredicate *predicateForFetch = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"armor_class < %@", [NSNumber numberWithInt:17]], allOrs, nil]];
            
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
            [request setPredicate:predicateForFetch];
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequestAndWait:request error:&error];
            [error shouldBeNil];
            [[results should] haveCountOf:2];
            if ([results count] == 2) {
                NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
                [[array should] contain:@"Jon"];
                [[array should] contain:@"Jonah"];
            }
        });
    });
    
    describe(@"Advanced AND", ^{
        it(@"works", ^{
            NSPredicate *andPredicate = [NSCompoundPredicate andPredicateWithSubpredicates:
                                         [NSArray arrayWithObjects:
                                          [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"],
                                          [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"],
                                          [NSPredicate predicateWithFormat:@"armor_class == %@", [NSNumber numberWithInt:15]],
                                          nil]];
            
            NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
            [request setPredicate:andPredicate];
            NSError *error = nil;
            NSArray *results = [moc executeFetchRequestAndWait:request error:&error];
            [error shouldBeNil];
            [[results should] haveCountOf:1];
            if ([results count] == 1) {
                [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jonah"];
            }
        });
    });
    describe(@"sorting", ^{
        __block NSFetchRequest *fetchRequest;
        __block NSArray *sortDescriptors;
        __block NSSortDescriptor *firstNameSD;
        __block NSSortDescriptor *companyNameSD;
        __block NSSortDescriptor *armorClassSD;
        beforeEach(^{
            firstNameSD = [NSSortDescriptor sortDescriptorWithKey:@"first_name" ascending:NO];
            companyNameSD = [NSSortDescriptor sortDescriptorWithKey:@"company" ascending:NO];
            armorClassSD = [NSSortDescriptor sortDescriptorWithKey:@"armor_class" ascending:YES];
        });
        it(@"applies one sort descriptor correctly", ^{
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            sortDescriptors = [NSArray arrayWithObject:firstNameSD];
            fetchRequest = [SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc];
            [fetchRequest setSortDescriptors:sortDescriptors];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                [error shouldBeNil];
                [[[results objectAtIndex:0] should] haveValue:@"Matt" forKey:@"first_name"];
                [[[results objectAtIndex:1] should] haveValue:@"Jonah" forKey:@"first_name"];
                [[[results objectAtIndex:2] should] haveValue:@"Jon" forKey:@"first_name"];
            }];
        });
        it(@"applies multiple sort descriptors correctly", ^{
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            sortDescriptors = [NSArray arrayWithObjects:companyNameSD, armorClassSD, nil];
            fetchRequest = [SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc];
            [fetchRequest setSortDescriptors:sortDescriptors];
            [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                [error shouldBeNil];
                [[[results objectAtIndex:0] should] haveValue:@"Vaznaian" forKey:@"last_name"];
                [[[results objectAtIndex:1] should] haveValue:@"Cooper" forKey:@"last_name"];
                [[[results objectAtIndex:2] should] haveValue:@"Williams" forKey:@"last_name"]; 
            }];
        });
    });
    
    describe(@"pagination / limiting", ^{
        __block NSFetchRequest *fetchRequest;
        describe(@"fetchLimit", ^{
            beforeEach(^{
                fetchRequest = [SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc];
                [fetchRequest setFetchLimit:1];
            });
            it(@"returns the expected results", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[results objectAtIndex:0] should] haveValue:@"Cooper" forKey:@"last_name"];
                }];
            });
        });
        
        describe(@"fetchOffset", ^{
            beforeEach(^{
                fetchRequest = [SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc];
                [fetchRequest setFetchOffset:1];
            });
            it(@"returns the expected results", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[results objectAtIndex:0] should] haveValue:@"Vaznaian" forKey:@"last_name"];
                    [[[results objectAtIndex:1] should] haveValue:@"Williams" forKey:@"last_name"];
                }];
            });            
        });
        
        describe(@"fetchBatchSize", ^{
            beforeEach(^{
                fetchRequest = [SMCoreDataIntegrationTestHelpers makePersonFetchRequest:nil context:moc];
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
    
    //describe(@"NSIncrementalStore implementation guide says we must implement", ^{
        //pending(@"shouldRefreshFetchedObjects", nil);
        //pending(@"propertiesToGroupBy", nil);
        //pending(@"havingPredicate", nil);
    //});
    
    describe(@"queries", ^{
        describe(@"error handling", ^{
            describe(@"when the left-hand side is not a keypath", ^{
                beforeEach(^{
                    predicate = [NSPredicate predicateWithFormat:@"%@ == last_name", @"Vaznaian"];
                });
                it(@"returns an error", ^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                        [[error should] beNonNil];
                        [results shouldBeNil];
                    }];
                });
            });
            describe(@"when the right-hand side is not a constant", ^{
                beforeEach(^{
                    predicate = [NSPredicate predicateWithFormat:@"%@ == %@", @"last_name", @"Vaznaian"];
                });
                it(@"returns an error", ^{
                    [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                    [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                        [[error should] beNonNil];
                        [results shouldBeNil];  
                    }];
                    
                });    
            });
        });
        describe(@"==", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"last_name == %@", @"Cooper"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                }];
            });
        });
        describe(@"=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"last_name = %@", @"Cooper"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                }];
            });
        });
        describe(@"!=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"last_name != %@", @"Williams"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Matt"];                  
                }];
            });
        });
        describe(@"<>", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"last_name <> %@", @"Williams"];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Matt"];                  
                }];
            });   
        });
        describe(@"<", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class < %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];
                }];
            });        
        });
        describe(@">", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class > %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:1];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Matt"];                    
                }];
            });        
        });
        describe(@"<=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class <= %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@"=<", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class =< %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Jonah"];
                }];
            });
        });
        describe(@">=", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class >= %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Matt"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Jonah"];
                }];
            });       
        });
        describe(@"=>", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"armor_class => %@", [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Matt"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Jonah"];
                }];
            });        
        });
        
        describe(@"BETWEEN", ^{
            beforeEach(^{
                predicate = [NSPredicate predicateWithFormat:@"(armor_class >= %@) AND (armor_class <= %@)", [NSNumber numberWithInt:12], [NSNumber numberWithInt:15]];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[results should] haveCountOf:2];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Jon"];   
                    [[[[results objectAtIndex:1] valueForKey:@"first_name"] should] equal:@"Jonah"];
                }];
            });
        });
        
        describe(@"IN", ^{
            __block NSArray *first_names;
            beforeEach(^{
                first_names = [NSArray arrayWithObjects:@"Aaron", @"Bob", @"Clyde", @"Ducksworth", @"Elliott", @"Matt", nil];
                predicate = [NSPredicate predicateWithFormat:@"first_name IN %@", first_names];
            });
            it(@"works", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[[[results objectAtIndex:0] valueForKey:@"first_name"] should] equal:@"Matt"];   
                }];
            });
        });
    });
});



describe(@"OR query from network should return same as cache", ^{
    __block User3 *user1 = nil;
    __block User3 *user2 = nil;
    __block User3 *user3 = nil;
    __block NSString *user1ID = nil;
    __block NSString *user2ID = nil;
    __block NSString *user3ID = nil;
    __block SMTestProperties *testProperties = nil;
    beforeEach(^{
        // create a bunch of users
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        [testProperties.client setUserSchema:@"User3"];
        //[[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
        
        user1 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc] insertIntoManagedObjectContext:testProperties.moc];
        user1ID = [NSString stringWithFormat:@"matt%d", arc4random() / 10000];
        [user1 setUsername:user1ID];
        [user1 setEmail:@"matt@matt.com"];
        [user1 setPassword:@"1234"];
        
        user2 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc] insertIntoManagedObjectContext:testProperties.moc];
        user2ID = [NSString stringWithFormat:@"matt%d", arc4random() / 10000];
        [user2 setUsername:user2ID];
        [user2 setEmail:@"bob@bob.com"];
        [user2 setPassword:@"1234"];
        
        user3 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc] insertIntoManagedObjectContext:testProperties.moc];
        user3ID = [NSString stringWithFormat:@"matt%d", arc4random() / 10000];
        [user3 setUsername:user3ID];
        [user3 setEmail:@"kat@kat.com"];
        [user3 setPassword:@"1234"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    afterEach(^{
        //[[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSError *fetchError = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:fetch error:&fetchError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [testProperties.moc deleteObject:obj];
        }];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:testProperties.moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        SM_CACHE_ENABLED = NO;
    });
    it(@"simple query", ^{
        [testProperties.client.coreDataStore setCachePolicy:SMCachePolicyTryNetworkOnly];
        // Should only call the network once
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:testProperties.moc];
        [fetchRequest setEntity:entity];
        
        NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"username == %@", user1ID], [NSPredicate predicateWithFormat:@"email == %@", @"bob@bob.com"], nil]];
        [fetchRequest setPredicate:predicate];
        NSError *anError = nil;
        NSArray *theResults = [testProperties.moc executeFetchRequestAndWait:fetchRequest error:&anError];
        [anError shouldBeNil];
        [[theResults should] haveCountOf:2];
        if ([theResults count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[theResults objectAtIndex:0] valueForKey:@"username"], [[theResults objectAtIndex:1] valueForKey:@"username"], nil];
            [[array should] contain:user1ID];
            [[array should] contain:user2ID];
        }
        
        [testProperties.client.coreDataStore setCachePolicy:SMCachePolicyTryCacheOnly];
        // Second fetch from cache should yeild same results
        NSFetchRequest *secondFetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        [secondFetch setPredicate:predicate];
        anError = nil;
        theResults = [testProperties.moc executeFetchRequestAndWait:secondFetch error:&anError];
        [anError shouldBeNil];
        [[theResults should] haveCountOf:2];
        if ([theResults count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[theResults objectAtIndex:0] valueForKey:@"username"], [[theResults objectAtIndex:1] valueForKey:@"username"], nil];
            [[array should] contain:user1ID];
            [[array should] contain:user2ID];
        }
    });
});
describe(@"Advanced OR from network should yeild same results as cache", ^{
    __block NSArray *fixturesToLoad;
    __block NSDictionary *fixtures;
    
    __block SMTestProperties *testProperties = nil;
    //[SMCoreDataIntegrationTestHelpers registerForMOCNotificationsWithContext:[SMCoreDataIntegrationTestHelpers moc]];
    
    beforeEach(^{
        SM_CACHE_ENABLED = YES;
        testProperties = [[SMTestProperties alloc] init];
        fixturesToLoad = [NSArray arrayWithObjects:@"person", nil];
        fixtures = [SMIntegrationTestHelpers loadFixturesNamed:fixturesToLoad];
        [[testProperties.client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [testProperties.cds setCachePolicy:SMCachePolicyTryCacheElseNetwork];
    });
    
    afterEach(^{
        [SMIntegrationTestHelpers destroyAllForFixturesNamed:fixturesToLoad];
        SM_CACHE_ENABLED = NO;
    });
    it(@"single or", ^{
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        // Person where:
        // armor_class = 17 || first_name == "Jonah"
        // Should return Matt and Jonah
        NSPredicate *allOrs = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"armor_class == %@", [NSNumber numberWithInt:17]], [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"], nil]];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [request setPredicate:allOrs];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:2];
        if ([results count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
            [[array should] contain:@"Matt"];
            [[array should] contain:@"Jonah"];
        }
        
        // Check cache
        NSFetchRequest *request2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [request2 setPredicate:allOrs];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:2];
        if ([results count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
            [[array should] contain:@"Matt"];
            [[array should] contain:@"Jonah"];
        }
    });
    it(@"multiple ors", ^{
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        // Person where:
        // armor_class < 17 && ((first_name == "Jonah" && last_name == "Williams) || first_name == "Jon" || company == "Carbon Five")
        // Should return Jon and Jonah
        
        NSPredicate *firstAnd = [NSCompoundPredicate andPredicateWithSubpredicates:
                                 [NSArray arrayWithObjects:
                                  [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"],
                                  [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"],
                                  nil]];
        
        NSPredicate *secondAnd = [NSPredicate predicateWithFormat:@"first_name == %@", @"Jon"];
        
        NSPredicate *thirdAnd = [NSPredicate predicateWithFormat:@"company == %@", @"Carbon Five"];
        
        NSPredicate *allOrs = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:firstAnd, secondAnd, thirdAnd, nil]];
        
        NSPredicate *predicateForFetch = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"armor_class < %@", [NSNumber numberWithInt:17]], allOrs, nil]];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [request setPredicate:predicateForFetch];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:2];
        if ([results count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
            [[array should] contain:@"Jon"];
            [[array should] contain:@"Jonah"];
        }
        
        // Cache
        NSFetchRequest *request2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [request2 setPredicate:predicateForFetch];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:2];
        if ([results count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
            [[array should] contain:@"Jon"];
            [[array should] contain:@"Jonah"];
        }
        
    });
    it(@"multiple ands in or", ^{
        [[[testProperties.client.session oauthClientWithHTTPS:NO] should] receive:@selector(enqueueHTTPRequestOperation:) withCount:1];
        // Person where:
        // armor_class < 17 && ((first_name == "Jonah" && last_name == "Williams) || (first_name == "Jon" && last_name == "Cooper") || company == "Carbon Five")
        // Should return Jon and Jonah
        
        NSPredicate *firstAnd = [NSCompoundPredicate andPredicateWithSubpredicates:
                                 [NSArray arrayWithObjects:
                                  [NSPredicate predicateWithFormat:@"first_name == %@", @"Jonah"],
                                  [NSPredicate predicateWithFormat:@"last_name == %@", @"Williams"],
                                  nil]];
        
        NSPredicate *secondAnd = [NSCompoundPredicate andPredicateWithSubpredicates:
                                  [NSArray arrayWithObjects:
                                   [NSPredicate predicateWithFormat:@"first_name == %@", @"Jon"],
                                   [NSPredicate predicateWithFormat:@"last_name == %@", @"Cooper"],
                                   nil]];
        NSPredicate *thirdAnd = [NSPredicate predicateWithFormat:@"company == %@", @"Carbon Five"];
        
        NSPredicate *allOrs = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:firstAnd, secondAnd, thirdAnd, nil]];
        
        NSPredicate *predicateForFetch = [NSCompoundPredicate andPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"armor_class < %@", [NSNumber numberWithInt:17]], allOrs, nil]];
        
        NSFetchRequest *request = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [request setPredicate:predicateForFetch];
        NSError *error = nil;
        NSArray *results = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:2];
        if ([results count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
            [[array should] contain:@"Jon"];
            [[array should] contain:@"Jonah"];
        }
        
        // Cache
        NSFetchRequest *request2 = [[NSFetchRequest alloc] initWithEntityName:@"Person"];
        [request2 setPredicate:predicateForFetch];
        error = nil;
        results = [testProperties.moc executeFetchRequestAndWait:request error:&error];
        [error shouldBeNil];
        [[results should] haveCountOf:2];
        if ([results count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[results objectAtIndex:0] valueForKey:@"first_name"], [[results objectAtIndex:1] valueForKey:@"first_name"], nil];
            [[array should] contain:@"Jon"];
            [[array should] contain:@"Jonah"];
        }
    });
});

describe(@"Fetch request on User which inherits from the SMUserManagedObject", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block User3 *user1 = nil;
    __block User3 *user2 = nil;
    __block User3 *user3 = nil;
    __block NSString *user1ID = nil;
    __block NSString *user2ID = nil;
    __block NSString *user3ID = nil;
    beforeEach(^{
        // create a bunch of users
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [client setUserSchema:@"User3"];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        user1 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        user1ID = [NSString stringWithFormat:@"matt%d", arc4random() / 10000];
        [user1 setUsername:user1ID];
        [user1 setEmail:@"matt@matt.com"];
        [user1 setPassword:@"1234"];
        
        user2 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        user2ID = [NSString stringWithFormat:@"matt%d", arc4random() / 10000];
        [user2 setUsername:user2ID];
        [user2 setEmail:@"bob@bob.com"];
        [user2 setPassword:@"1234"];
        
        user3 = [[User3 alloc] initWithEntity:[NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc] insertIntoManagedObjectContext:moc];
        user3ID = [NSString stringWithFormat:@"matt%d", arc4random() / 10000];
        [user3 setUsername:user3ID];
        [user3 setEmail:@"kat@kat.com"];
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
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"User3"];
        NSError *fetchError = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&fetchError];
        [results enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            [moc deleteObject:obj];
        }];
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
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];
        NSError *anError = nil;
        NSArray *theResults = [moc executeFetchRequestAndWait:fetchRequest error:&anError];
        [anError shouldBeNil];
        [[theValue([theResults count]) should] equal:theValue(3)];
    });
    it(@"works with or", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"User3" inManagedObjectContext:moc];
        [fetchRequest setEntity:entity];
        
        NSPredicate *predicate = [NSCompoundPredicate orPredicateWithSubpredicates:[NSArray arrayWithObjects:[NSPredicate predicateWithFormat:@"username == %@", user1ID], [NSPredicate predicateWithFormat:@"email == %@", @"bob@bob.com"], nil]];
        [fetchRequest setPredicate:predicate];
        NSError *anError = nil;
        NSArray *theResults = [moc executeFetchRequestAndWait:fetchRequest error:&anError];
        [anError shouldBeNil];
        [[theValue([theResults count]) should] equal:theValue(2)];
        if ([theResults count] == 2) {
            NSArray *array = [NSArray arrayWithObjects:[[theResults objectAtIndex:0] valueForKey:@"username"], [[theResults objectAtIndex:1] valueForKey:@"username"], nil];
            [[array should] contain:user1ID];
            [[array should] contain:user2ID];
        }
    });
    
});

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
        [client setUserSchema:@"User3"];
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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


describe(@"empty string", ^{
    __block NSManagedObjectContext *moc = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObject *todoObject1 = nil;
    __block NSManagedObject *todoObject2 = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        // Create todos
        todoObject1 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todoObject1 setValue:@"1234" forKey:@"todoId"];
        [todoObject1 setValue:@"" forKey:@"title"];
        
        todoObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Todo" inManagedObjectContext:moc];
        [todoObject2 setValue:@"5678" forKey:@"todoId"];
        [todoObject2 setValue:@"full" forKey:@"title"];
    });
    afterEach(^{
        [moc deleteObject:todoObject1];
        [moc deleteObject:todoObject2];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    it(@"equal to empty string", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title == ''"]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
        
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        if ([results count] == 1) {
            [[[[results objectAtIndex:0] valueForKey:@"todoId"] should] equal:@"1234"];
        }
        
    });
    it(@"equal to empty string", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
        
        NSFetchRequest *fetch = [[NSFetchRequest alloc] initWithEntityName:@"Todo"];
        [fetch setPredicate:[NSPredicate predicateWithFormat:@"title != ''"]];
        
        NSError *error = nil;
        NSArray *results = [moc executeFetchRequestAndWait:fetch error:&error];
        
        [error shouldBeNil];
        [[results should] haveCountOf:1];
        [[[[results objectAtIndex:0] valueForKey:@"todoId"] should] equal:@"5678"];
        
    });
});


SPEC_END
