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

SPEC_BEGIN(SMUpdateObjectsOptimizationSpec)

describe(@"updating an object only persists changed fields", ^{
    __block NSManagedObjectContext *moc = nil;
    __block Person *person = nil;
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
        person = [NSEntityDescription insertNewObjectForEntityForName:@"Person" inManagedObjectContext:moc];
        [person setValue:@"bob" forKey:@"first_name"];
        [person setValue:@"jean" forKey:@"first_name"];
        [person setValue:[person assignObjectId] forKey:[person primaryKeyField]];
        NSDictionary *personDict = [person SMDictionarySerialization];
        [[theValue([[[personDict objectForKey:@"SerializedDict"] allKeys] count]) should] equal:theValue(2)];
        
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    afterEach(^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [moc deleteObject:person];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    it(@"should only persist the updated fields", ^{
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
        [person setValue:@"joe" forKey:@"first_name"];
        NSDictionary *personDict = [person SMDictionarySerialization];
        [[[personDict objectForKey:@"SerializedDict"] objectForKey:@"first_name"] shouldNotBeNil];
        [[[personDict objectForKey:@"SerializedDict"] objectForKey:@"person_id"] shouldNotBeNil];
        [[theValue([[[personDict objectForKey:@"SerializedDict"] allKeys] count]) should] equal:theValue(2)];
        [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
            [error shouldBeNil];
        }];
    });
    
});

SPEC_END