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
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"

SPEC_BEGIN(SMCoreDataStoreTest)

describe(@"create an instance of SMCoreDataStore from SMClient", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *coreDataStore = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        coreDataStore = [client coreDataStoreWithManagedObjectModel:aModel];
        
    });
    describe(@"obtaining a managedObjectContext hooked to SM", ^{
        beforeEach(^{
            moc = [coreDataStore contextForCurrentThread];
        });
        it(@"is not nil", ^{
            [moc shouldNotBeNil];
        });
    });
    describe(@"with a managedObjectContext from SMCoreDataStore", ^{
        beforeEach(^{
            moc = [coreDataStore contextForCurrentThread];
            [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        });
        
        describe(@"inserting an object", ^{
            __block NSManagedObject *aPerson = nil;
            beforeEach(^{
                aPerson = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
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
            it(@"reads the object", ^{
                [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
                NSPredicate *predicate = [NSPredicate predicateWithFormat:@"last_name = 'dude'"];
                [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:[SMCoreDataIntegrationTestHelpers makePersonFetchRequest:predicate context:moc] andBlock:^(NSArray *results, NSError *error) {
                    [error shouldBeNil];
                    [[theValue([results count]) should] equal:theValue(1)];
                    NSManagedObject *theDude = [results objectAtIndex:0];
                    [[[theDude valueForKey:@"first_name"] should] equal:@"the"];
                }];
            });
            
            it(@"updates the object", ^{
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
                    theRequest = [SMCoreDataIntegrationTestHelpers makeFavoriteFetchRequest:predicate context:moc];
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
