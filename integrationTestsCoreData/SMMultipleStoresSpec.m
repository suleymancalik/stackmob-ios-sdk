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
#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIntegrationTestHelpers.h"
#import "StackMob.h"

SPEC_BEGIN(SMMultipleStoresSpec)

describe(@"LocalCacheTests", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        NSURL *credentialsURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"StackMobCredentials" withExtension:@"plist"];
        NSDictionary *credentials = [NSDictionary dictionaryWithContentsOfURL:credentialsURL];
        NSString *publicKey = [credentials objectForKey:@"PublicKey"];
        client = [[SMClient alloc] initWithAPIVersion:SM_TEST_API_VERSION publicKey:publicKey];
        moc = [SMCoreDataIntegrationTestHelpers moc];
    });
    it(@"let's try a simple read call", ^{
        
        NSFetchRequest *fetchRequest = [NSFetchRequest fetchRequestWithEntityName:@"Random"];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousFetch:moc withRequest:fetchRequest andBlock:^(NSArray *results, NSError *error) {
            [error shouldBeNil];
            NSLog(@"results are %@", results);
        }];
        
    });
    
    
    /*
    it(@"initializes the cds successfully", ^{
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds managedObjectContext];
    });
    describe(@"save workflow when online", ^{
        __block NSManagedObject *random = nil;
        beforeEach(^{
            cds.tempNetworkStatus = YES;
            random = [NSEntityDescription insertNewObjectForEntityForName:@"Random" inManagedObjectContext:moc];
            [random setValue:[random assignObjectId] forKey:[random primaryKeyField]];
            
        });
        it(@"queues request, request is processed immediately, in success block saves to local cache", ^{
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            
        });
        it(@"can refresh the object to get updated values", ^{
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
            NSLog(@"person is %@", random);
            [moc refreshObject:random mergeChanges:YES];
            NSLog(@"person is now %@", random);
        });
    });
    */
    
    
  
});

SPEC_END