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
    beforeEach(^{
        moc = [SMCoreDataIntegrationTestHelpers moc];
        date = [NSDate date];
        camelCaseObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [camelCaseObject setValue:@"new" forKey:@"name"];
        [camelCaseObject setValue:date forKey:@"time"];
        [camelCaseObject setValue:[camelCaseObject assignObjectId] forKey:[camelCaseObject primaryKeyField]];
    });
    afterEach(^{
        [moc deleteObject:camelCaseObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will save without error after creation", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    it(@"Will successfully read", ^{
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
            [[[[results objectAtIndex:0] valueForKey:@"time"] should] equal:date];
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
            [[[[results objectAtIndex:0] valueForKey:@"time"] should] equal:newDate];
        }];
        
    });
     
     
});

describe(@"Testing CRUD on an Entity with a Boolean attribute set to True", ^{
    __block NSManagedObjectContext *moc = nil;
    __block Random *booleanObject = nil;
    beforeEach(^{
        moc = [SMCoreDataIntegrationTestHelpers moc];
        booleanObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [booleanObject setValue:@"TRUUUUUUUUU" forKey:@"name"];
        [booleanObject setValue:[NSNumber numberWithBool:YES] forKey:@"done"];
        [booleanObject setValue:[booleanObject assignObjectId] forKey:[booleanObject primaryKeyField]];
    });
    afterEach(^{
        [moc deleteObject:booleanObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will save without error after creation", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    it(@"Will successfully read", ^{
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
    beforeEach(^{
        moc = [SMCoreDataIntegrationTestHelpers moc];
        booleanObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        [booleanObject setValue:@"Should be False" forKey:@"name"];
        [booleanObject setValue:[NSNumber numberWithBool:NO] forKey:@"done"];
        [booleanObject setValue:[booleanObject assignObjectId] forKey:[booleanObject primaryKeyField]];
    });
    afterEach(^{
        [moc deleteObject:booleanObject];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will save without error after creation", ^{
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    
    
     
     it(@"Will successfully read", ^{
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