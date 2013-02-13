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
#import "SMIntegrationTestHelpers.h"

SPEC_BEGIN(CRUDTests)

describe(@"CRUD", ^{
    __block SMDataStore *dataStore = nil;
    beforeEach(^{
        dataStore = [SMIntegrationTestHelpers dataStore];
        [NSURLRequest setAllowsAnyHTTPSCertificate:YES forHost:@"api.stackmob.com"];
    });
    it(@"should successfully create a Datastore", ^{
        [dataStore shouldNotBeNil];
    });
    
    context(@"creating a new book object", ^{
        __block NSDictionary *newBook = nil;
        __block NSString *newBookTitle = nil;
        beforeEach(^{
            newBookTitle = [NSString stringWithFormat:@"Twilight part %ld", random() % 10000];
            NSDictionary *book = [NSDictionary dictionaryWithObjectsAndKeys:
                                  newBookTitle, @"title",
                                  @"Rabid Fan", @"author",
                                  nil];
            
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:book inSchema:@"book" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    newBook = theObject;
                    syncReturn(semaphore);
                    NSLog(@"Created %@", theObject);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    NSLog(@"Failed to create a new %@: %@", schema, theError);
                    syncReturn(semaphore);
                }];
            });
            
            [newBook shouldNotBeNil];
        });
        afterEach(^{
            [dataStore deleteObjectId:[newBook objectForKey:@"book_id"] inSchema:@"book" onSuccess:^(NSString *theObjectId, NSString *schema) {
                NSLog(@"Deleted %@", theObjectId);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                NSLog(@"Failed to delete %@", [newBook objectForKey:@"book_id"]);
            }];
            newBook = nil;
        });
        it(@"creates a new book object", ^{
            [newBook shouldNotBeNil];
            [[[newBook objectForKey:@"title"] should] equal:newBookTitle];
            [[newBook objectForKey:@"book_id"] shouldNotBeNil];
            [[newBook objectForKey:@"lastmoddate"] shouldNotBeNil];
            [[newBook objectForKey:@"createddate"] shouldNotBeNil];
        });
        context(@"when reading the new book object", ^{
            __block NSDictionary *readBook = nil;
            beforeEach(^{
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore readObjectWithId:[newBook objectForKey:@"book_id"] inSchema:@"book" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                        readBook = theObject;
                        NSLog(@"Read %@", theObject);
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                        NSLog(@"failed to read the object with error: %@", theError);
                        syncReturn(semaphore);
                    }]; 
                });
            });
            
            [readBook shouldNotBeNil];
            
            it(@"returns the object's attributes", ^{
                [[readBook should] equal:newBook]; 
            });
        });
        context(@"updating the new object", ^{
            __block NSDictionary *updatedBook = nil;
            __block NSDictionary *updatedFields = nil;
            beforeEach(^{
                updatedFields = [NSDictionary dictionaryWithObjectsAndKeys:@"Coolest Author Ever", @"author", nil];
                syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                    [dataStore updateObjectWithId:[newBook objectForKey:@"book_id"] inSchema:@"book" update:updatedFields onSuccess:^(NSDictionary *theObject, NSString *schema) {
                        updatedBook = theObject;
                        NSLog(@"updated %@", theObject);
                        syncReturn(semaphore);
                    } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                        NSLog(@"failed to update the object with error: %@", theError);
                        syncReturn(semaphore);
                    }]; 
                });
                
                [updatedBook shouldNotBeNil];
                
                 
            });
            it(@"updates the object's attributes", ^{
                [[[updatedBook objectForKey:@"book_id"] should] equal:[newBook objectForKey:@"book_id"]];
                [[[updatedBook objectForKey:@"author"] should] equal:@"Coolest Author Ever"];
            });
        });
    });
    context(@"deleting the new book", ^{
        __block NSDictionary *newBook = nil;
        __block NSString *newBookTitle = nil;
        beforeEach(^{
            newBookTitle = [NSString stringWithFormat:@"Twilight part %ld", random() % 10000];
            NSDictionary *book = [NSDictionary dictionaryWithObjectsAndKeys:
                                  newBookTitle, @"title",
                                  @"Rabid Fan", @"author",
                                  nil];
            
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:book inSchema:@"book" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    newBook = theObject;
                    syncReturn(semaphore);
                    NSLog(@"Created %@", theObject);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    NSLog(@"Failed to create a new %@: %@", schema, theError);
                    syncReturn(semaphore);
                }];
            });
            
            [newBook shouldNotBeNil];
        });
        
        __block BOOL deleteSucceeded = NO;
        it(@"deletes the object", ^{
            deleteSucceeded = NO;
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore deleteObjectId:[newBook objectForKey:@"book_id"] inSchema:@"book" onSuccess:^(NSString *theObjectId, NSString *schema) {
                    NSLog(@"deleted %@", theObjectId);
                    deleteSucceeded = YES;
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                    NSLog(@"failed to delete the object with error: %@", theError);
                    syncReturn(semaphore);
                }];
            });
            
            [theValue(deleteSucceeded) shouldNotBeNil];
            [[theValue(deleteSucceeded) should] beYes];
        });
    });
    context(@"CRUD with non-lowercase schema name", ^{
        __block NSDictionary *newBook = nil;
        __block NSString *newBookTitle = nil;
        __block NSDictionary *book = nil;
        __block NSString *returnedSchema = nil;
        __block NSString *objectId;
        beforeEach(^{
            newBookTitle = [NSString stringWithFormat:@"Twilight part %ld", random() % 10000];
            returnedSchema = nil;
            newBook = nil;
        });
        it(@"Should create given non-lowercase schema name", ^{
            book = [NSDictionary dictionaryWithObjectsAndKeys:
                    newBookTitle, @"title",
                    @"Rabid Fan", @"author",
                    nil];
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore createObject:book inSchema:@"Book" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    newBook = theObject;
                    returnedSchema = schema;
                    objectId = [theObject objectForKey:@"book_id"];
                    NSLog(@"Created %@", theObject);
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    NSLog(@"Failed to create a new %@: %@", schema, theError);
                    newBook = nil;
                    syncReturn(semaphore);
                }];
            });
            [newBook shouldNotBeNil];
            [[returnedSchema should] equal:@"Book"];
        });
        it(@"Should read given non-lowercase schema name", ^{
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore readObjectWithId:objectId inSchema:@"Book" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    newBook = theObject;
                    returnedSchema = schema;
                    NSLog(@"Read %@", theObject);
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                    NSLog(@"Failed to read %@: %@", theObjectId, theError);
                    newBook = nil;
                    syncReturn(semaphore);
                }];
            });
            [newBook shouldNotBeNil];
            [[returnedSchema should] equal:@"Book"];
        });
        it(@"Should update given non-lowercase schema name", ^{
            book = [NSDictionary dictionaryWithObjectsAndKeys:
                    newBookTitle, @"title",
                    @"Rabid Fan Not", @"author",
                    nil];
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore updateObjectWithId:objectId inSchema:@"Book" update:book onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    newBook = theObject;
                    returnedSchema = schema;
                    NSLog(@"Updated %@", theObject);
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    NSLog(@"Failed to update %@: %@", schema, theError);
                    newBook = nil;
                    syncReturn(semaphore);
                }];
            });
            [newBook shouldNotBeNil];
            [[returnedSchema should] equal:@"Book"];
        });
        it(@"Should delete given non-lowercase schema name", ^{
            [[dataStore.session.regularOAuthClient operationQueue] shouldNotBeNil];
            syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
                [dataStore deleteObjectId:objectId inSchema:@"Book" onSuccess:^(NSString *theObjectId, NSString *schema) {
                    returnedSchema = schema;
                    NSLog(@"Deleted %@", theObjectId);
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                    NSLog(@"Failed to delete %@: %@", schema, theError);
                    syncReturn(semaphore);
                }];
            });
            [[returnedSchema should] equal:@"Book"];
        });

    });
});

describe(@"read value containing special chartacters", ^{
    __block SMClient *client = nil;
    __block NSString *objectId = @"matt+matt@matt.com";
    __block NSString *primaryKey = @"blog_id";
    __block NSString *schemaName = @"blog";
    __block NSString *fieldKey = @"blogname";
    __block NSString *fieldValue = @"coolblog";
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *createDict = [NSDictionary dictionaryWithObjectsAndKeys:objectId, primaryKey, fieldValue, fieldKey, nil];
            [[client dataStore] createObject:createDict inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
                [[[theObject objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    afterEach(^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:objectId inSchema:schemaName onSuccess:^(NSString *theObjectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    it(@"reads and updates the value with special characters", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] readObjectWithId:objectId inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
                [[[theObject objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *updateDict = [NSDictionary dictionaryWithObjectsAndKeys:@"c*oo^l$blog", fieldKey, nil];
            [[client dataStore] updateObjectWithId:objectId inSchema:schemaName update:updateDict onSuccess:^(NSDictionary *theObject, NSString *schema) {
                [[[theObject objectForKey:fieldKey] should] equal:@"c*oo^l$blog"];
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    
});

describe(@"read value containing special chartacters in schema with permissions", ^{
    __block SMClient *client = nil;
    __block NSString *objectId = @"matt+mat@matt.com";
    __block NSString *primaryKey = @"blog2_id";
    __block NSString *schemaName = @"blog2";
    __block NSString *fieldKey = @"blogname";
    __block NSString *fieldValue = @"coolblog";
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
        [client setUserSchema:@"user3"];
        // create user 3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *userDict = [NSDictionary dictionaryWithObjectsAndKeys:objectId, @"username", @"1234", @"password", nil];
            [[client dataStore] createObject:userDict inSchema:@"user3" onSuccess:^(NSDictionary *theObject, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // login user3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client loginWithUsername:objectId password:@"1234" onSuccess:^(NSDictionary *result) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // create blog2
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *createDict = [NSDictionary dictionaryWithObjectsAndKeys:objectId, primaryKey, fieldValue, fieldKey, nil];
            [[client dataStore] createObject:createDict inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
                [[[theObject objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    afterEach(^{
        
        // logout user3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [client logoutOnSuccess:^(NSDictionary *result) {
                syncReturn(semaphore);
            } onFailure:^(NSError *error) {
                [error shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // delete blog2
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:objectId inSchema:schemaName onSuccess:^(NSString *theObjectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        
        // delete user3
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] deleteObjectId:objectId inSchema:@"user3" onSuccess:^(NSString *theObjectId, NSString *schema) {
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    it(@"reads and updates the value with special characters", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            [[client dataStore] readObjectWithId:objectId inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
                [[[theObject objectForKey:fieldKey] should] equal:fieldValue];
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *updateDict = [NSDictionary dictionaryWithObjectsAndKeys:@"c*ool$blog", fieldKey, nil];
            [[client dataStore] updateObjectWithId:objectId inSchema:schemaName update:updateDict onSuccess:^(NSDictionary *theObject, NSString *schema) {
                [[[theObject objectForKey:fieldKey] should] equal:@"c*ool$blog"];
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                [theError shouldBeNil];
                syncReturn(semaphore);
            }];
        });
    });
    
});

describe(@"setExpandDepth", ^{
    __block SMClient *client = nil;
    beforeEach(^{
        client = [SMIntegrationTestHelpers defaultClient];
    });
    it(@"Works with 1-1 read", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
            [[client dataStore] readObjectWithId:@"1234" inSchema:@"expanddepthtest" options:options onSuccess:^(NSDictionary *theObject, NSString *schema)
             {
                 [[theValue([[[theObject objectForKey:@"child"] class] isSubclassOfClass:[NSDictionary class]]) should] beYes];
                 [[[[theObject objectForKey:@"child"] objectForKey:@"name"] should] equal:@"bob"];
                 syncReturn(semaphore);
             } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                 [theError shouldBeNil];
                 syncReturn(semaphore);
             }];
        });
    });
    
     it(@"Works with 1-many read", ^{
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
             SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
             [[client dataStore] readObjectWithId:@"5678" inSchema:@"expanddepthtest" options:options onSuccess:^(NSDictionary *theObject, NSString *schema)
             {
                NSLog(@"the object is %@", theObject);
                 [[theValue([[theObject objectForKey:@"children"] count]) should] equal:theValue(3)];
                 [[theValue([[[theObject objectForKey:@"children"] class] isSubclassOfClass:[NSArray class]]) should] beYes];
                 [[theValue([[[[theObject objectForKey:@"children"] objectAtIndex:0] class] isSubclassOfClass:[NSDictionary class]]) should] beYes];
                 syncReturn(semaphore);
             } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                 [theError shouldBeNil];
                 syncReturn(semaphore);
             }];
         });
     });
     
    
     it(@"Works with 1-1 and 1-many general queries", ^{
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
             SMQuery *query = [[SMQuery alloc] initWithSchema:@"expanddepthtest"];
             SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
             [[client dataStore] performQuery:query options:options onSuccess:^(NSArray *results)
             {
                 for(NSDictionary *dictionary in results) {
                     if([dictionary objectForKey:@"child"]){
                         [[theValue([[[dictionary objectForKey:@"child"] class] isSubclassOfClass:[NSDictionary class]]) should] beYes];
                         [[[[dictionary objectForKey:@"child"] objectForKey:@"name"] should] equal:@"bob"];
                         
                     }
                     else if ([dictionary objectForKey:@"children"]){
                         [[theValue([[dictionary objectForKey:@"children"] count]) should] equal:theValue(3)];
                         [[theValue([[[dictionary objectForKey:@"children"] class] isSubclassOfClass:[NSArray class]]) should] beYes];
                         [[theValue([[[[dictionary objectForKey:@"children"] objectAtIndex:0] class] isSubclassOfClass:[NSDictionary class]]) should] beYes];
                     }
                 }
                  syncReturn(semaphore);
             } onFailure:^(NSError *error) {
                 
                  [error shouldBeNil];
                  syncReturn(semaphore);
             }];
         });
     });
     it(@"Works with 1-1 query", ^{
         syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
             SMQuery *query = [[SMQuery alloc] initWithSchema:@"expanddepthtest"];
             [query where:@"expanddepthtest_id" isEqualTo:@"1234"];
             SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
             [[client dataStore] performQuery:query options:options onSuccess:^(NSArray *results)
              {
                  NSDictionary *dictionary = [results objectAtIndex:0];
                  [[theValue([[[dictionary objectForKey:@"child"] class] isSubclassOfClass:[NSDictionary class]]) should] beYes];
                  [[[[dictionary objectForKey:@"child"] objectForKey:@"name"] should] equal:@"bob"];
                  syncReturn(semaphore);
              } onFailure:^(NSError *error) {
                  
                  [error shouldBeNil];
                  syncReturn(semaphore);
              }];
         });
     });
    it(@"Works with 1-many query", ^{
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            SMQuery *query = [[SMQuery alloc] initWithSchema:@"expanddepthtest"];
            [query where:@"expanddepthtest_id" isEqualTo:@"5678"];
            SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
            [[client dataStore] performQuery:query options:options onSuccess:^(NSArray *results)
             {
                 NSDictionary *dictionary = [results objectAtIndex:0];
                 [[theValue([[dictionary objectForKey:@"children"] count]) should] equal:theValue(3)];
                 [[theValue([[[dictionary objectForKey:@"children"] class] isSubclassOfClass:[NSArray class]]) should] beYes];
                 [[theValue([[[[dictionary objectForKey:@"children"] objectAtIndex:0] class] isSubclassOfClass:[NSDictionary class]]) should] beYes];
                 syncReturn(semaphore);
             } onFailure:^(NSError *error) {
                 
                 [error shouldBeNil];
                 syncReturn(semaphore);
             }];
        });
    });
    it(@"throws an exception when attempting post method", ^{
        SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
        NSDictionary *toCreate = [NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"expanddepthtest_id", nil];
        [[theBlock(^{
            [[client dataStore] createObject:toCreate inSchema:@"expanddepthtest" options:options onSuccess:^(NSDictionary *theObject, NSString *schema)
             {
                 // Doesn't matter
             } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                 [theError shouldNotBeNil];
                 [[theValue([theError code]) should] equal:theValue(SMErrorInvalidArguments)];
             }];
        }) should] raiseWithReason:@"Expand depth is not supported for creates or updates.  Please check your requests and edit accordingly."];
        
    });
    
    it(@"throws an exception when attempting post method", ^{
        SMRequestOptions *options = [SMRequestOptions optionsWithExpandDepth:1];
        NSDictionary *toCreate = [NSDictionary dictionaryWithObjectsAndKeys:@"1234", @"expanddepthtest_id", nil];
        [[theBlock(^{
            [[client dataStore] updateObjectWithId:@"1234" inSchema:@"expanddepthtest" update:toCreate options:options onSuccess:^(NSDictionary *theObject, NSString *schema)
             {
                 // Doesn't matter
             } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                 [theError shouldNotBeNil];
                 [[theValue([theError code]) should] equal:theValue(SMErrorInvalidArguments)];
             }];
        }) should] raiseWithReason:@"Expand depth is not supported for creates or updates.  Please check your requests and edit accordingly."];
    });
    
    
});

SPEC_END
