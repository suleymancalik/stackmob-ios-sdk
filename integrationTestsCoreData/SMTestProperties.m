/*
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

#import "SMTestProperties.h"

@implementation SMTestProperties
@synthesize client = _client;
@synthesize cds = _cds;
@synthesize moc = _moc;

- (id)init
{
    self = [super init];
    if (self) {
        // Client
        NSURL *credentialsURL = [[NSBundle bundleForClass:[self class]] URLForResource:@"StackMobCredentials" withExtension:@"plist"];
        NSDictionary *credentials = [NSDictionary dictionaryWithContentsOfURL:credentialsURL];
        NSString *publicKey = [credentials objectForKey:@"PublicKey"];
        self.client = [[SMClient alloc] initWithAPIVersion:SM_TEST_API_VERSION publicKey:publicKey];
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:@"api.stackmob.com"];
        [SMClient setDefaultClient:self.client];
        
        // CDS
        [SMCoreDataIntegrationTestHelpers removeSQLiteDatabaseAndMapsWithPublicKey:self.client.publicKey];
        NSBundle *classBundle = [NSBundle bundleForClass:[self class]];
        NSURL *modelURL = [classBundle URLForResource:@"SMCoreDataIntegrationTest" withExtension:@"momd"];
        NSManagedObjectModel *aModel = [[NSManagedObjectModel alloc] initWithContentsOfURL:modelURL];
        self.cds = [self.client coreDataStoreWithManagedObjectModel:aModel];
        
        // MOC
        self.moc = [self.cds contextForCurrentThread];
    }
    return self;
}

@end

