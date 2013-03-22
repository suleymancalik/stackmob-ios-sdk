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
#import "Synchronization.h"
#import "SMIntegrationTestHelpers.h"
#import "StackMob.h"

SPEC_BEGIN(SMUserSessionIntegrationSpec)

describe(@"refresh token fail block", ^{
    __block SMDataStore *dataStore = nil;
    __block SMClient *client = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [SMClient setDefaultClient:client];
        dataStore = [client dataStore];
        
    });
    it(@"refresh token fail block should get called", ^{
        __block BOOL tokenFailure = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client setTokenRefreshFailureBlock:^(NSError *error, SMFailureBlock originalFailureBlock) {
                tokenFailure = YES;
                originalFailureBlock(error);
                syncReturn(semaphore);
            }];
            [[client.dataStore.session stubAndReturn:@"1234"] refreshToken];
            [[client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
            [client.dataStore createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"bob", @"title", nil] inSchema:@"todo" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                NSLog(@"Schema is %@", schema);
                NSLog(@"Failure with error: %@", theError);
            }];
        });
        
        [[theValue(tokenFailure) should] beYes];
    });
    it(@"refresh token fail block should get called during failure block from 401", ^{
        __block BOOL tokenFailure = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client setTokenRefreshFailureBlock:^(NSError *error, SMFailureBlock originalFailureBlock) {
                tokenFailure = YES;
                originalFailureBlock(error);
                syncReturn(semaphore);
            }];
            [[client.dataStore.session stubAndReturn:@"1234"] refreshToken];
            [[client.dataStore.session stubAndReturn:theValue(YES)] accessTokenHasExpired];
            [[client.dataStore.session stubAndReturn:theValue(NO)] eligibleForTokenRefresh:any()];
            [client.dataStore createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"bob", @"name", nil] inSchema:@"oauth2test" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                NSLog(@"Schema is %@", schema);
                NSLog(@"Failure with error: %@", theError);
            }];
        });
        
        [[theValue(tokenFailure) should] beYes];
    });
    it(@"block should get called when refresh token is nil", ^{
        __block BOOL tokenFailure = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client setTokenRefreshFailureBlock:^(NSError *error, SMFailureBlock originalFailureBlock) {
                tokenFailure = YES;
                originalFailureBlock(error);
                syncReturn(semaphore);
            }];
            [[client.dataStore.session stubAndReturn:theValue(YES)] eligibleForTokenRefresh:any()];
            [client.dataStore createObject:[NSDictionary dictionaryWithObjectsAndKeys:@"bob", @"title", nil] inSchema:@"todo" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                NSLog(@"Schema is %@", schema);
                NSLog(@"Failure with error: %@", theError);
            }];
        });
        
        [[theValue(tokenFailure) should] beYes];
    });
});


describe(@"basic auth", ^{
    __block SMDataStore *dataStore = nil;
    __block SMUserSession *userSession = nil;
    __block BOOL loginSuccess = NO;
    __block BOOL loginFailure = NO;
    __block SMClient *defaultClient = nil;
    beforeEach(^{
        // create object to login with, assumes user object name with username/password fields
        defaultClient = [SMIntegrationTestHelpers defaultClient];
        dataStore = [defaultClient dataStore];
        BOOL createSuccess = [SMIntegrationTestHelpers createUser:@"bob" password:@"1234" dataStore:dataStore];
        [[theValue(createSuccess) should] beYes];

    });
    afterEach(^{
        BOOL deleteSuccess = [SMIntegrationTestHelpers deleteUser:@"bob" dataStore:dataStore];
        [[theValue(deleteSuccess) should] beYes];
    });
    describe(@"being logged in", ^{
        __block NSDictionary *loginObj;
        beforeEach(^{
            loginSuccess = NO;
            userSession = [defaultClient session];
            [[userSession.tokenClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient loginWithUsername:@"bob" password:@"1234" onSuccess:^(NSDictionary *userObject) {
                    loginObj = userObject;
                    loginSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError * error) {
                    loginSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(loginSuccess) should] beYes];
            
        });
        
        afterEach(^{
            __block BOOL logoutSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient logoutOnSuccess:^(NSDictionary *result) {
                    logoutSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    logoutSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(logoutSuccess) should] beYes]; 
            
            
        });
        
        it(@"should return the whole user object", ^{
            [loginObj shouldNotBeNil];
            [[[loginObj valueForKey:@"username"] should] equal:@"bob"];
            
            [[loginObj valueForKey:@"password"] shouldBeNil];
            [[[loginObj valueForKey:@"sm_owner"] should] equal:@"user/bob"];
            [[[loginObj valueForKey:@"randomfield"] should] equal:@"value"];
            [[loginObj valueForKey:@"createddate"] shouldNotBeNil];
            [[loginObj valueForKey:@"lastmoddate"] shouldNotBeNil];  
        });
        it(@"should return yes to isLoggedIn", ^{
           [[theValue([defaultClient isLoggedIn]) should] beYes];
        });
        it(@"should return no to isLoggedOut", ^{
            [[theValue([defaultClient isLoggedOut]) should] beNo];
        });
        it(@"should allow posting/reading/deleting to a logged-in-user-only schema", ^{
            __block BOOL createSuccess = NO;
            __block NSString *objID;
            __block NSDictionary *createObjectDict = [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"foo", @"world", @"hello", nil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:createObjectDict inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    objID = [theObject valueForKey:@"restricted_id"];
                    createSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) { 
                    createSuccess = NO;
                    syncReturn(semaphore);
                }]; 
            });
            [[theValue(createSuccess) should] beYes];
            [objID shouldNotBeNil];
            
            __block BOOL readSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore readObjectWithId:objID inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    readSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSString *theObject, NSString *schema) {
                    readSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(readSuccess) should] beYes];
            
            __block BOOL deleteSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore deleteObjectId:objID inSchema:@"restricted" onSuccess:^(NSString *theObjectId, NSString *schema) {
                    deleteSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                    deleteSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(deleteSuccess) should] beYes];
 
        });
        
        it(@"should allow getLoggedInUser", ^{
            __block BOOL getDone = NO;
            __block NSDictionary *obj;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient getLoggedInUserOnSuccess:^(NSDictionary *userObject) {
                    getDone = YES;
                    obj = userObject;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(getDone) should] beYes];
            [obj shouldNotBeNil];
            [[[obj valueForKey:@"username"] should] equal:@"bob"];
    
            [[obj valueForKey:@"password"] shouldBeNil];
            [[[obj valueForKey:@"sm_owner"] should] equal:@"user/bob"];
            [[[obj valueForKey:@"randomfield"] should] equal:@"value"];
            [[obj valueForKey:@"createddate"] shouldNotBeNil];
            [[obj valueForKey:@"lastmoddate"] shouldNotBeNil];

        });
        
        it(@"should allow resetPassword", ^{
            __block BOOL resetDone = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient changeLoggedInUserPasswordFrom:@"1234" to:@"4321" onSuccess:^(NSDictionary *userObject) {
                    resetDone = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(resetDone) should] beYes];
            
            loginFailure = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient loginWithUsername:@"bob" password:@"1234" onSuccess:^(NSDictionary *userObject) {
                    loginFailure = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError * error) {
                    loginFailure = YES;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(loginFailure) should] beYes];
            
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient loginWithUsername:@"bob" password:@"4321" onSuccess:^(NSDictionary *userObject) {
                    loginSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError * error) {
                    loginSuccess = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(loginSuccess) should] beYes];
        });
        
        it(@"should allow refreshToken", ^{
            __block BOOL done = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient refreshLoginWithOnSuccess:^(NSDictionary *userObject) {
                    done = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    syncReturn(semaphore);
                }];
            });
                    
            [[theValue(done) should] beYes];
        });
        
        describe(@"when the session is expired", ^{
            __block NSString *oldToken = nil;
            beforeEach(^{
                userSession.expiration = [[NSDate date] dateByAddingTimeInterval:-60*5];
                oldToken = userSession.refreshToken;
            });
            it(@"should trigger a refreshToken call on requests", ^{
                __block BOOL createSuccess = NO;
                __block NSString *objID;
                NSDictionary *createObjectDict = [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"foo", @"world", @"hello", nil];
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore createObject:createObjectDict inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                        objID = [theObject valueForKey:@"restricted_id"];
                        createSuccess = YES;
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) { 
                        createSuccess = NO;
                        syncReturn(semaphore);
                    }];
                });
                
                [[theValue(createSuccess) should] beYes];
                [objID shouldNotBeNil];
                
                __block BOOL readSuccess = NO;
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore readObjectWithId:objID inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                        readSuccess = YES;
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSString *theObject, NSString *schema) {
                        readSuccess = NO;
                        syncReturn(semaphore);
                    }];
                });
                
                [[theValue(readSuccess) should] beYes];
                
                __block BOOL deleteSuccess = NO;
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore deleteObjectId:objID inSchema:@"restricted" onSuccess:^(NSString *theObjectId, NSString *schema) {
                        deleteSuccess = YES;
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                        deleteSuccess = NO;
                        syncReturn(semaphore);
                    }];
                });
                [[theValue(deleteSuccess) should] beYes];
                [[userSession.refreshToken shouldNot] equal:oldToken];
            });
            
        });
        describe(@"when the session is expired on the server", ^{
            __block NSString *oldToken;
            beforeEach(^{
                //Simulate the session being expired on the server
                userSession.regularOAuthClient.accessToken = @"notarealtoken";
                oldToken = userSession.refreshToken;
            });
            
            it(@"should trigger a refreshToken call on requests", ^{
                __block BOOL createSuccess = NO;
                __block NSString *objID;
                NSDictionary *createObjectDict = [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"foo", @"world", @"hello", nil];
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore createObject:createObjectDict inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                        objID = [theObject valueForKey:@"restricted_id"];
                        createSuccess = YES;
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) { 
                        createSuccess = NO;
                        syncReturn(semaphore);
                    }];
                });
                
                [[theValue(createSuccess) should] beYes];
                [objID shouldNotBeNil];
                
                __block BOOL readSuccess = NO;
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore readObjectWithId:objID inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                        readSuccess = YES;
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSString *theObject, NSString *schema) {
                        readSuccess = NO;
                        syncReturn(semaphore);
                    }];
                });
                
                [[theValue(readSuccess) should] beYes];
                
                __block BOOL deleteSuccess = NO;
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore deleteObjectId:objID inSchema:@"restricted" onSuccess:^(NSString *theObjectId, NSString *schema) {
                        deleteSuccess = YES;
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                        deleteSuccess = NO;
                        syncReturn(semaphore);
                    }];
                });
                
                [[theValue(deleteSuccess) should] beYes];
                [[userSession.refreshToken shouldNot] equal:oldToken];
            });
            
        });
    });
    
    describe(@"logging in and logging out", ^{
        
        beforeEach(^{
            loginSuccess = NO;
            userSession = [defaultClient session];
            [[userSession.tokenClient operationQueue] shouldNotBeNil];
            
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient loginWithUsername:@"bob" password:@"1234" onSuccess:^(NSDictionary *userObject) {
                    loginSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError * error) {
                    loginSuccess = NO;
                    syncReturn(semaphore);
                }];

            });
            
            [[theValue(loginSuccess) should] beYes];
            
        });
        
        it(@"should allow logging out", ^{
            __block BOOL logoutDone = NO;
            
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient logoutOnSuccess:^(NSDictionary *userObject) {
                    logoutDone = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(logoutDone) should] beYes];
            
            __block BOOL createFailed= NO;
            __block NSString *objID;
            NSDictionary *createObjectDict = [NSDictionary dictionaryWithObjectsAndKeys:@"bar", @"foo", @"world", @"hello", nil];
            
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:createObjectDict inSchema:@"restricted" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    objID = [theObject valueForKey:@"restricted_id"];
                    createFailed = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) { 
                    createFailed = YES;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(createFailed) should] beYes];
        }); 
    });
    describe(@"being logged out", ^{
        beforeEach(^{
            
            [[theValue([defaultClient isLoggedOut]) should] beYes];
            
            loginFailure = NO;
            userSession = [defaultClient session];
            [[userSession.tokenClient operationQueue] shouldNotBeNil];

            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient loginWithUsername:@"bob" password:@"12345" onSuccess:^(NSDictionary *userObject) {
                    loginFailure = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError * error) {
                    loginFailure = YES;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(loginFailure) should] beYes];
        });
        it(@"should call failure block", ^{
            [[theValue(loginFailure) should] beYes];
        });
        
        it(@"should return no to isLoggedIn", ^{
            [[theValue([defaultClient isLoggedIn]) should] beNo];
        });
        it(@"should return yes to isLoggedOut", ^{
            [[theValue([defaultClient isLoggedOut]) should] beYes];
        });
        
        
        it(@"should disallow getLoggedInUser", ^{
            __block BOOL getDone = NO;
            __block NSError *error;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient getLoggedInUserOnSuccess:^(NSDictionary *userObject) {
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    error = theError;
                    getDone = YES;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(getDone) should] beYes];
            [error shouldNotBeNil];
            [[theValue(error.code) should] equal:[NSNumber numberWithInt:SMErrorUnauthorized]];
        });
        
        it(@"should disallow resetPassword", ^{
            __block BOOL getDone = NO;
            __block NSError *error;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient changeLoggedInUserPasswordFrom:@"1234" to:@"4321" onSuccess:^(NSDictionary *userObject) {
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    error = theError;
                    getDone = YES;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(getDone) should] beYes];
            [error shouldNotBeNil];
            [[theValue(error.code) should] equal:[NSNumber numberWithInt:SMErrorUnauthorized]];
        });
        
        it(@"should disallow refreshToken", ^{
            __block BOOL done = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient refreshLoginWithOnSuccess:^(NSDictionary *userObject) {
                    done = NO;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    done = YES;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(done) should] beYes];
        });
        
        
        pending(@"logout should do nothing when logged out", ^{
            __block BOOL logoutDone = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [defaultClient logoutOnSuccess:^(NSDictionary *userObject) {
                    logoutDone = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError) {
                    logoutDone = NO;
                    syncReturn(semaphore);
                }];
            });
            
            [[theValue(logoutDone) should] beYes];
        });
    });
});

describe(@"forgotPassword", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        // create object to login with, assumes user object name with username/password fields
        client = [SMIntegrationTestHelpers defaultClient];
        
        __block BOOL createSuccess = [SMIntegrationTestHelpers createUser:@"bob" password:@"1234" dataStore:client.dataStore];
        
        [[theValue(createSuccess) should] beYes];
        
        createSuccess = NO;
        NSDictionary *createObjectDict = [NSDictionary dictionaryWithObjectsAndKeys:@"bob", @"username", @"1234", @"password", @"1234", @"email", nil];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] createObject:createObjectDict inSchema:@"cooluser" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                createSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                createSuccess = NO;
                //createSuccess = (theError.code == 409);
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(createSuccess) should] beYes];
        
        
    });
    afterEach(^{
        __block BOOL deleteSuccess = [SMIntegrationTestHelpers deleteUser:@"bob" dataStore:client.dataStore];
        
        [[theValue(deleteSuccess) should] beYes];
        
        deleteSuccess = NO;
        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:@"bob" inSchema:@"cooluser" onSuccess:^(NSString *theObjectId, NSString *schema) {
                deleteSuccess = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                deleteSuccess = NO;
                syncReturn(semaphore);
            }]; 
        });
        
        [[theValue(deleteSuccess) should] beYes];
        
        
    });
    it(@"should fail on a schema without a forgotPassword field value", ^{
        __block BOOL done = NO;
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client sendForgotPaswordEmailForUser:@"bob" onSuccess:^(NSDictionary *userObject) {
                syncReturn(semaphore);
            } onFailure:^(NSError * error) {
                done = YES;
                syncReturn(semaphore);
            }]; 
        });
        
        [[theValue(done) should] beYes];
        
    });
    it(@"should fail on a non-existent user", ^{
        __block BOOL done = NO;
        client.userSchema = @"cooluser";
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client sendForgotPaswordEmailForUser:@"bodie" onSuccess:^(NSDictionary *userObject) {
                syncReturn(semaphore);
            } onFailure:^(NSError * error) {
                done = YES;
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(done) should] beYes];
        
    });
    it(@"should success with a valid forgot password field and user", ^{
        __block BOOL done = NO;
        client.userSchema = @"cooluser";
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client sendForgotPaswordEmailForUser:@"bob" onSuccess:^(NSDictionary *userObject) {
                done = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError * error) {
                syncReturn(semaphore);
            }];
        });
        
        [[theValue(done) should] beYes];
        
    });
});

describe(@"authentication with permissions", ^{
    __block SMClient *client = nil;
    __block BOOL readSuccess = NO;
    beforeAll(^{
        client = [SMIntegrationTestHelpers defaultClient];
        readSuccess = NO;
        BOOL createSuccess = [SMIntegrationTestHelpers createUser:@"dude" password:@"sweet" dataStore:client.dataStore];
        [[theValue(createSuccess) should] beYes];        
        
    });
    afterAll(^{
        BOOL deleteSuccess = [SMIntegrationTestHelpers deleteUser:@"dude" dataStore:client.dataStore];
        [[theValue(deleteSuccess) should] beYes];
    });
    context(@"not logged in", ^{
        it(@"should not allow to read from a schema with permissions set", ^{
            readSuccess = NO;
            SMQuery *query = [[SMQuery alloc] initWithSchema:@"oauth2test"];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [[client dataStore] performQuery:query onSuccess:^(NSArray *results) {
                    NSLog(@"read success: %@", results);
                    readSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    NSLog(@"read failure: %@", error);
                    syncReturn(semaphore);
                }];
            });
            [[theValue(readSuccess) should] beNo];
        });
    });
    context(@"logged in", ^{
        beforeEach(^{
            readSuccess = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client loginWithUsername:@"dude" password:@"sweet" onSuccess:^(NSDictionary *result) {
                    NSLog(@"login success");
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    NSLog(@"login failure: %@", error);
                    [error shouldBeNil];
                    syncReturn(semaphore);
                }];
            });
        });
        afterEach(^{
            if (client.isLoggedIn) {
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [client logoutOnSuccess:^(NSDictionary *result) {
                        syncReturn(semaphore);
                    } onFailure:^(NSError *error) {
                        [error shouldBeNil];
                        syncReturn(semaphore);
                    }];
                });
            }
        });
        it(@"Should allow read from a schema with permissions set", ^{
            SMQuery *query = [[SMQuery alloc] initWithSchema:@"oauth2test"];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [[client dataStore] performQuery:query onSuccess:^(NSArray *results) {
                    NSLog(@"read success: %@", results);
                    readSuccess = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    NSLog(@"read failure: %@", error);
                    syncReturn(semaphore);
                }];
            });
            [[theValue(readSuccess) should] beYes];
        });
    });
});

describe(@"basic login/logout works as it should", ^{
    __block SMClient *client = nil;
    __block SMCoreDataStore *cds = nil;
    __block NSManagedObjectContext *moc = nil;
    
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        NSBundle *bundle = [NSBundle bundleForClass:[self class]];
        NSManagedObjectModel *mom = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:bundle]];
        cds = [client coreDataStoreWithManagedObjectModel:mom];
        moc = [cds contextForCurrentThread];
        // create object to login with, assumes user object name with username/password fields
        BOOL createSuccess = [SMIntegrationTestHelpers createUser:@"dude" password:@"sweet" dataStore:client.dataStore];
        [[theValue(createSuccess) should] beYes];
    });
    afterEach(^{
        BOOL deleteSuccess = [SMIntegrationTestHelpers deleteUser:@"dude" dataStore:client.dataStore];
        [[theValue(deleteSuccess) should] beYes];
    });
    it(@"login/logout", ^{
        // login
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client loginWithUsername:@"dude" password:@"sweet" onSuccess:^(NSDictionary *result) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // check values
        [[theValue([client isLoggedIn]) should] beYes];
        [[theValue([client isLoggedOut]) should] beNo];
        [[client.session refreshToken] shouldNotBeNil];
        
        // logout, if logged in
        if ([client isLoggedIn]) {
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [client logoutOnSuccess:^(NSDictionary *result) {
                    syncReturn(semaphore);
                } onFailure:^(NSError *error) {
                    [error shouldNotBeNil];
                    syncReturn(semaphore);
                }];
            });
        }
        
        // check values
        [[theValue([client isLoggedIn]) should] beNo];
        [[theValue([client isLoggedOut]) should] beYes];
        [[client.session refreshToken] shouldBeNil];
    });
});

SPEC_END
