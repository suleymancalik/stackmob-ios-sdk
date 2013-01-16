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
#import "SMClient.h"
#import "SMDataStore+Protected.h"

SPEC_BEGIN(SMDataStore_CompletionBlocksSpec)

describe(@"SMFullResponseSuccessBlockForSchema:withSuccessBlock:", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        SMClient *client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]];
    });
    it(@"returns a block which calls the success block with appropriate arguments", ^{
        NSDictionary *responseObject = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"The Great American Novel", @"name", 
                                        @"Yours Truely", @"author",
                                        @"1234", @"book_id", 
                                        nil];
        NSURL *url = [NSURL URLWithString:@"http://mob1.stackmob.com/books/1234"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
        
        __block BOOL completionBlockDidExecute = NO;
        SMDataStoreSuccessBlock successBlock = ^(NSDictionary* theObject, NSString *schema) {
            [[schema should] equal:@"book"];
            [[theObject should] equal:responseObject];
            completionBlockDidExecute = YES;
        };
        
        SMFullResponseSuccessBlock success = [dataStore SMFullResponseSuccessBlockForSchema:@"book" withSuccessBlock:successBlock];
        success(request, response, responseObject);
        
        [[theValue(completionBlockDidExecute) should] beYes];
    });
});

describe(@"-SMFullResponseFailureBlockForObject:ofSchema:withFailureBlock:", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        SMClient *client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]];
    });
    it(@"returns a block which calls the failure block with appropriate arguments", ^{
        NSDictionary *requestObject = [NSDictionary dictionaryWithObjectsAndKeys:
                                        @"1234", @"book_id", 
                                        nil];
        NSURL *url = [NSURL URLWithString:@"http://mob1.stackmob.com/books/1234"];
        NSURLRequest *request = [NSURLRequest requestWithURL:url];
        NSHTTPURLResponse *response = [[NSHTTPURLResponse alloc] initWithURL:url statusCode:200 HTTPVersion:@"1.1" headerFields:nil];
        
        __block BOOL completionBlockDidExecute = NO;
        SMDataStoreFailureBlock failureBlock = ^(NSError *theError, NSDictionary* theObject, NSString *schema) {
            [[schema should] equal:@"book"];
            [[theObject should] equal:requestObject];
            completionBlockDidExecute = YES;
        };
        
        SMFullResponseFailureBlock failure = [dataStore SMFullResponseFailureBlockForObject:requestObject ofSchema:@"book" withFailureBlock:failureBlock];
        NSError *error = [NSError errorWithDomain:@"com.stackmob" code:0 userInfo:nil];
        failure(request, response, error, nil);
        
        [[theValue(completionBlockDidExecute) should] beYes];
    });
});

describe(@"countFromRangeHeader", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        SMClient *client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]];
    });
    it(@"should return 0 given a nil rangeHeader and an empty array", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:nil results:[NSArray array]]] should] equal:[NSNumber numberWithInt:0]];
    });
    it(@"should return 1 given a nil rangeHeader and an array of size 1", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:nil results:[NSArray arrayWithObject:@"foo"]]] should] equal:[NSNumber numberWithInt:1]];
    });
    it(@"should return 3 given a nil rangeHeader and an array of size 3", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:nil results:[NSArray arrayWithObjects:@"foo", @"bar", @"baz", nil]]] should] equal:[NSNumber numberWithInt:3]];
    });
    it(@"should return -1 given a gibberish rangeHeader", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"xfkvhf89olhlwa3s3nku921k," results:nil]] should] equal:[NSNumber numberWithInt:-1]];
    });
    it(@"should return -1 given a rangeHeader with too many bits", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"1-1/5/4," results:nil]] should] equal:[NSNumber numberWithInt:-1]];
    });
    it(@"should return -2 given a rangeHeader with a star", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"1-1/*," results:nil]] should] equal:[NSNumber numberWithInt:-1]];
    });
    it(@"should return 637 given a rangeHeader with that number in the count position", ^{
        [[[NSNumber numberWithInt:[dataStore countFromRangeHeader:@"1-1/637," results:nil]] should] equal:[NSNumber numberWithInt:637]];
    });
});

describe(@"lowercase schema tests", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        SMClient *client = [[SMClient alloc] initWithAPIVersion:@"0" publicKey:@"XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX"];
        dataStore = [[SMDataStore alloc] initWithAPIVersion:@"0" session:[client session]];
    });
    afterEach(^{
        SM_LOWERCASE_SCHEMA_NAMES = YES;
    });
    it(@"post operation", ^{
        AFJSONRequestOperation *op = [dataStore postOperationForObject:[NSDictionary dictionary] inSchema:@"Schema" options:nil successCallbackQueue:nil failureCallbackQueue:nil onSuccess:nil onFailure:nil];
        [[[[[op request] URL] path] should] equal:@"/schema"];
        
        SM_LOWERCASE_SCHEMA_NAMES = NO;
        
        op = [dataStore postOperationForObject:[NSDictionary dictionary] inSchema:@"Schema" options:nil successCallbackQueue:nil failureCallbackQueue:nil onSuccess:nil onFailure:nil];
        [[[[[op request] URL] path] should] equal:@"/Schema"];
    });
    it(@"put operation", ^{
        AFJSONRequestOperation *op = [dataStore putOperationForObjectID:@"1234" inSchema:@"Schema" update:[NSDictionary dictionary] options:nil successCallbackQueue:nil failureCallbackQueue:nil onSuccess:nil onFailure:nil];
        [[[[[op request] URL] path] should] equal:@"/schema/1234"];
        
        SM_LOWERCASE_SCHEMA_NAMES = NO;
        
        op = [dataStore putOperationForObjectID:@"1234" inSchema:@"Schema" update:[NSDictionary dictionary] options:nil successCallbackQueue:nil failureCallbackQueue:nil onSuccess:nil onFailure:nil];
        [[[[[op request] URL] path] should] equal:@"/Schema/1234"];
    });
    it(@"delete operation", ^{
        AFJSONRequestOperation *op = [dataStore deleteOperationForObjectID:@"1234" inSchema:@"Schema" options:nil successCallbackQueue:nil failureCallbackQueue:nil onSuccess:nil onFailure:nil];
        [[[[[op request] URL] path] should] equal:@"/schema/1234"];
        
        SM_LOWERCASE_SCHEMA_NAMES = NO;
        
        op = [dataStore deleteOperationForObjectID:@"1234" inSchema:@"Schema" options:nil successCallbackQueue:nil failureCallbackQueue:nil onSuccess:nil onFailure:nil];
        [[[[[op request] URL] path] should] equal:@"/Schema/1234"];
    });
});

SPEC_END
