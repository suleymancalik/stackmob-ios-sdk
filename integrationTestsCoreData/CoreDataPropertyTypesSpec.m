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
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
            [[theValue([[[results objectAtIndex:0] valueForKey:@"time"] timeIntervalSinceDate:date]) should] beLessThan:theValue(1)];
        }];
    });
    it(@"Will successfully read with NSDate in the predicate", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        [fetchRequest setPredicate:[NSPredicate predicateWithFormat:@"time == %@", date]];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            [[theValue([results count]) should] equal:theValue(1)];
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
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
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
/*
describe(@"Testing CRUD on an Entity with a Boolean attribute set to True", ^{
    __block NSManagedObjectContext *moc = nil;
    __block Random *booleanObject = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
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
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
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
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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
     NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
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
     
         NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
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

describe(@"Testing CRUD on an Entity with a GeoPoint attribute", ^{
    __block NSManagedObjectContext *moc = nil;
    __block NSManagedObject *geoObject = nil;
    __block NSManagedObject *geoObject2 = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSDictionary *location = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
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
        
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:geoObject];
        [moc deleteObject:geoObject2];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will successfully read", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(2)];
        }];
    });
    it(@"Will successfully read with miles query", ^{
        
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
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
    });
    
    it(@"Will successfully read with kilometers query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.810317;
        coordinate.longitude = -122.418167;
        
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithin:5.0 kilometersOf:coordinate];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
    });
    
    it(@"Will successfully read with bounds query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Twin Peaks
        CLLocationCoordinate2D swCoordinate;
        swCoordinate.latitude = 37.755245;
        swCoordinate.longitude = -122.447741;
        
        // Fisherman's Wharf
        CLLocationCoordinate2D neCoordinate;
        neCoordinate.latitude = 37.810317;
        neCoordinate.longitude = -122.418167;
        
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithinBoundsWithSWCorner:swCoordinate andNECorner:neCoordinate];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(0)];
        }];
    });
    
    it(@"Will successfully read with near query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Twin Peaks
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.755245;
        coordinate.longitude = -122.447741;
        
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" near:coordinate];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(2)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
    });

    it(@"Will successfully read using an NSPredicate instance method", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        SMPredicate *predicate = (SMPredicate *)[SMPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
    });
    it(@"Will successfully read with an NSPredicate", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        SMPredicate *predicate = (SMPredicate *)[NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
    });
    it(@"Will successfully read with compound query", ^{
        
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
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:location];
        }];
        
    });
    
    it(@"Will save and read without error after update", ^{
        
        // Fisherman's Wharf
        NSNumber *lat = [NSNumber numberWithDouble:37.810317];
        NSNumber *lon = [NSNumber numberWithDouble:-122.418167];
        
        NSDictionary *newLocation = [NSDictionary dictionaryWithObjectsAndKeys:
                    lat
                    ,@"lat"
                    ,lon
                    ,@"lon", nil];
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:newLocation];
        
        [geoObject setValue:data forKey:@"geopoint"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            NSDictionary *comparisonDictionary = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonDictionary should] equal:newLocation];
            
        }];
    });
    
});

describe(@"Testing CRUD on an Entity with a SMGeoPoint attribute", ^{
    __block NSManagedObjectContext *moc = nil;
    __block NSManagedObject *geoObject = nil;
    __block NSManagedObject *geoObject2 = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block SMGeoPoint *location = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        cds = [client coreDataStoreWithManagedObjectModel:aModel];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        
        geoObject = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        
        NSNumber *lat = [NSNumber numberWithDouble:37.77215879638275];
        NSNumber *lon = [NSNumber numberWithDouble:-122.4064476357965];
        
        location = [SMGeoPoint geoPointWithLatitude:lat longitude:lon];
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:location];
        
        [geoObject setValue:data forKey:@"geopoint"];
        [geoObject setValue:@"StackMob" forKey:@"name"];
        [geoObject setValue:[geoObject assignObjectId] forKey:[geoObject primaryKeyField]];
        
        geoObject2 = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
        NSNumber *lat2 = [NSNumber numberWithDouble:42.280373];
        NSNumber *lon2 = [NSNumber numberWithDouble:-71.416669];
        
        SMGeoPoint *location2 = [SMGeoPoint geoPointWithLatitude:lat2 longitude:lon2];
        
        NSData *data2 = [NSKeyedArchiver archivedDataWithRootObject:location2];
        [geoObject2 setValue:data2 forKey:@"geopoint"];
        [geoObject2 setValue:@"Framingahm" forKey:@"name"];
        [geoObject2 setValue:[geoObject2 assignObjectId] forKey:[geoObject2 primaryKeyField]];
        
        
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:geoObject];
        [moc deleteObject:geoObject2];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
    });
    it(@"Will successfully read", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(2)];
        }];
    });
    it(@"Will successfully read with miles query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.810317;
        coordinate.longitude = -122.418167;
        
        SMGeoPoint *geoPoint = [SMGeoPoint geoPointWithCoordinate:coordinate];
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithin:3.5 milesOfGeoPoint:geoPoint];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            SMGeoPoint *comparisonGeoPoint = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonGeoPoint should] equal:location];
        }];
    });
    
    it(@"Will successfully read with kilometers query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.810317;
        coordinate.longitude = -122.418167;
        
        SMGeoPoint *geoPoint = [SMGeoPoint geoPointWithCoordinate:coordinate];
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithin:5.0 kilometersOfGeoPoint:geoPoint];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            SMGeoPoint *comparisonGeoPoint = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonGeoPoint should] equal:location];
        }];
    });
    
    it(@"Will successfully read with bounds query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Twin Peaks
        CLLocationCoordinate2D swCoordinate;
        swCoordinate.latitude = 37.755245;
        swCoordinate.longitude = -122.447741;
        
        SMGeoPoint *swGeoPoint = [SMGeoPoint geoPointWithCoordinate:swCoordinate];
        
        // Fisherman's Wharf
        CLLocationCoordinate2D neCoordinate;
        neCoordinate.latitude = 37.810317;
        neCoordinate.longitude = -122.418167;
        
        SMGeoPoint *neGeoPoint = [SMGeoPoint geoPointWithCoordinate:neCoordinate];
    
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" isWithinBoundsWithSWGeoPoint:swGeoPoint andNEGeoPoint:neGeoPoint];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(0)];
        }];
    });
    
    it(@"Will successfully read with near query", ^{
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        // Twin Peaks
        CLLocationCoordinate2D coordinate;
        coordinate.latitude = 37.755245;
        coordinate.longitude = -122.447741;
        
        SMGeoPoint *geoPoint = [SMGeoPoint geoPointWithCoordinate:coordinate];
        
        SMPredicate *predicate = [SMPredicate predicateWhere:@"geopoint" nearGeoPoint:geoPoint];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(2)];
            
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            SMGeoPoint *comparisonGeoPoint = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonGeoPoint should] equal:location];
        }];
        
    });
    
    it(@"Will save and read without error after update", ^{
        
        // Fisherman's Wharf
        NSNumber *lat = [NSNumber numberWithDouble:37.810317];
        NSNumber *lon = [NSNumber numberWithDouble:-122.418167];
        
        SMGeoPoint *newLocation = [SMGeoPoint geoPointWithLatitude:lat longitude:lon];
        
        NSData *data = [NSKeyedArchiver archivedDataWithRootObject:newLocation];
        
        [geoObject setValue:data forKey:@"geopoint"];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
        }];
        
        NSEntityDescription *entity = [NSEntityDescription entityForName:@"Random" inManagedObjectContext:moc];
        NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
        [fetchRequest setEntity:entity];
        
        NSPredicate *predicate = [NSPredicate predicateWithFormat:@"name == %@", @"StackMob"];
        [fetchRequest setPredicate:predicate];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            if (error != nil) {
                DLog(@"Error userInfo is %@", [error userInfo]);
                [error shouldBeNil];
            }
            NSLog(@"results is %@", results);
            [[theValue([results count]) should] equal:theValue(1)];
            
            NSData *comparisonData = [[results objectAtIndex:0] valueForKey:@"geopoint"];
            SMGeoPoint *comparisonGeoPoint = [NSKeyedUnarchiver unarchiveObjectWithData:comparisonData];
            
            [[comparisonGeoPoint should] equal:newLocation];
            
        }];
    });
    
});
*/

SPEC_END