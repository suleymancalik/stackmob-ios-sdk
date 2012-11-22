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

describe(@"CoreDataFetchRequest", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    beforeEach(^{
        SM_CORE_DATA_DEBUG = YES;
        client = [SMIntegrationTestHelpers defaultClient];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds managedObjectContext];
    });
    describe(@"When we are online", ^{
        pending(@"places returned objects into local cache without error", ^{
        
        });
    });
});
    

SPEC_END