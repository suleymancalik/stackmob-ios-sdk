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
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "Random.h"

SPEC_BEGIN(CoreDataPropertyTypesSpec)

describe(@"Testing CRUD on an Entity with an NSDate attribute", ^{
    __block NSManagedObjectContext *moc = nil;
    __block NSManagedObject *camelCaseObject = nil;
    __block NSDate *date = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        date = [NSDate date];
        camelCaseObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [camelCaseObject setValue:@"new" forKey:@"name"];
        [camelCaseObject setValue:date forKey:@"time"];
        [camelCaseObject setValue:[camelCaseObject assignObjectId] forKey:[camelCaseObject primaryKeyField]];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:camelCaseObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    it(@"Will save without error after creation", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    it(@"Will successfully read", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        NSEntityDescription *entity = [SMCoreDataIntegrationTestHelpers entityForName:@"Random"];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            NSDate *firstDate = [[results objectAtIndex:0] valueForKey:@"time"];
            NSDate *secondDate = date;
            [firstDate isEqualToDate:secondDate] ? NSLog(@"dates are equal") : NSLog(@"dates are not equal");
            [firstDate timeIntervalSince1970] == [secondDate timeIntervalSince1970] ? NSLog(@"dates intervals are equal") : NSLog(@"dates intervals are not equal");
            if ([[[results objectAtIndex:0] valueForKey:@"time"] isEqualToDate:date]) {
                NSLog(@"dates are equal");
            }
            [[theValue([[[results objectAtIndex:0] valueForKey:@"time"] timeIntervalSinceDate:date]) should] beLessThan:theValue(1)];
        }];
    });
    it(@"Will save and read without error after update", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        __block NSDate *newDate = [NSDate date];
        [camelCaseObject setValue:newDate forKey:@"time"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        NSEntityDescription *entity = [SMCoreDataIntegrationTestHelpers entityForName:@"Random"];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            [[theValue((int)[[[results objectAtIndex:0] valueForKey:@"time"] timeIntervalSince1970]) should] equal:theValue((int)[newDate timeIntervalSince1970])];
        }];
        
    });
     
     
});

describe(@"Testing CRUD on an Entity with a Boolean attribute set to True", ^{
    __block NSManagedObjectContext *moc = nil;
    __block Random *booleanObject = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        booleanObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [booleanObject setValue:@"TRUUUUUUUUU" forKey:@"name"];
        [booleanObject setValue:[NSNumber numberWithBool:YES] forKey:@"done"];
        [booleanObject setValue:[booleanObject assignObjectId] forKey:[booleanObject primaryKeyField]];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:booleanObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will save without error after creation", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    it(@"Will successfully read", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        NSEntityDescription *entity = [SMCoreDataIntegrationTestHelpers entityForName:@"Random"];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:[NSNumber numberWithBool:YES]];
        }];
    });
    
    it(@"Will save and read without error after update", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        [booleanObject setValue:[NSNumber numberWithBool:NO] forKey:@"done"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        NSEntityDescription *entity = [SMCoreDataIntegrationTestHelpers entityForName:@"Random"];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:[NSNumber numberWithBool:NO]];
        }];
        
    });
 
 
});

describe(@"Testing CRUD on an Entity with a Boolean attribute set to false", ^{
    __block NSManagedObjectContext *moc = nil;
    __block NSManagedObject *booleanObject = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        booleanObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [booleanObject setValue:@"Should be False" forKey:@"name"];
        [booleanObject setValue:[NSNumber numberWithBool:NO] forKey:@"done"];
        [booleanObject setValue:[booleanObject assignObjectId] forKey:[booleanObject primaryKeyField]];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:booleanObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will save without error after creation", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    
     
     it(@"Will successfully read", ^{
         [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
         [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
             if (error != nil) {
                 DLog(@"Error userInfo is %@", [error userInfo]);
                 [error shouldBeNil];
             }
         }];
     NSEntityDescription *entity = [SMCoreDataIntegrationTestHelpers entityForName:@"Random"];
     NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
     [fetchRequest setEntity:entity];
     [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
         if (error != nil) {
             DLog(@"Error userInfo is %@", [error userInfo]);
             [error shouldBeNil];
         }
         NSLog(@"results is %@", results);
         [[theValue([results count]) should] equal:theValue(1)];
         [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:[NSNumber numberWithBool:NO]];
        }];
     });
    
    
     it(@"Will save and read without error after update", ^{
         [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
         [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
             if (error != nil) {
                 DLog(@"Error userInfo is %@", [error userInfo]);
                 [error shouldBeNil];
             }
         }];
         [booleanObject setValue:[NSNumber numberWithBool:YES] forKey:@"done"];
         [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
             if (error != nil) {
                 DLog(@"Error userInfo is %@", [error userInfo]);
                 [error shouldBeNil];
             }
         }];
     
         NSEntityDescription *entity = [SMCoreDataIntegrationTestHelpers entityForName:@"Random"];
         NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
         [fetchRequest setEntity:entity];
         [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
             if (error != nil) {
                 DLog(@"Error userInfo is %@", [error userInfo]);
                 [error shouldBeNil];
             }
             NSLog(@"results is %@", results);
             [[theValue([results count]) should] equal:theValue(1)];
             [[[[results objectAtIndex:0] valueForKey:@"done"] should] equal:[NSNumber numberWithBool:YES]];
         }];
     
    });
     
});

SPEC_END