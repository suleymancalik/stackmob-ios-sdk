/*
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
#import "SMClient.h"
#import "SMCoreDataStore.h"
#import "SMIntegrationTestHelpers.h"
#import "SMCoreDataIntegrationTestHelpers.h"
#import "Superpower.h"
#import "SMBinaryDataConversion.h"

SPEC_BEGIN(SMBinDataConvertCDIntegrationSpec)

describe(@"SMBinDataConvertCDIntegration", ^{
    __block NSManagedObjectContext *moc = nil;
    __block Superpower *superpower = nil;
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        [client setUserSchema:@"user3"];
        cds = [client coreDataStoreWithManagedObjectModel:[NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]]];
        moc = [cds contextForCurrentThread];
        [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
    });
    describe(@"should successfully set binary data when translated to string", ^{
        __block NSString *dataString = nil;
        beforeEach(^{
             [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            superpower = [NSEntityDescription insertNewObjectForEntityForName:@"Superpower" inManagedObjectContext:moc];
            NSError *error = nil;
            NSBundle *bundle = [NSBundle bundleForClass:[self class]];
            NSString* pathToImageFile = [bundle pathForResource:@"goatPic" ofType:@"jpeg"];
            NSData *theData = [NSData dataWithContentsOfFile:pathToImageFile options:NSDataReadingMappedIfSafe error:&error];
            [error shouldBeNil];
            dataString = [SMBinaryDataConversion stringForBinaryData:theData name:@"whatever" contentType:@"image/jpeg"];
            [dataString shouldNotBeNil];
            [superpower setName:@"cool"];
            [superpower setValue:dataString forKey:@"pic"];
            [superpower setSuperpower_id:[superpower assignObjectId]];
        });
        it(@"should persist to StackMob and update after a refresh call", ^{
             [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
                [moc refreshObject:superpower mergeChanges:YES];
                NSString *picString = [superpower valueForKey:@"pic"];
                [[[picString substringToIndex:4] should] equal:@"http"];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousDelete:moc withObject:[superpower objectID] andBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
        it(@"should update the object successfully without overwriting the data", ^{
             [[client.session.networkMonitor stubAndReturn:theValue(1)] currentNetworkStatus];
            __block NSString *picURL = nil;
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
                [moc refreshObject:superpower mergeChanges:YES];
                picURL = [superpower valueForKey:@"pic"];
            }];
            [superpower setName:@"the coolest"];
            [SMCoreDataIntegrationTestHelpers executeSynchronousSave:moc withBlock:^(NSError *error) {
                [error shouldBeNil];
                NSString *picString = [superpower valueForKey:@"pic"];
                [[picString should] equal:picURL];
            }];
            [SMCoreDataIntegrationTestHelpers executeSynchronousDelete:moc withObject:[superpower objectID] andBlock:^(NSError *error) {
                [error shouldBeNil];
            }];
        });
    });
});

SPEC_END
