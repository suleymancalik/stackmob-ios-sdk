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

/*
 NOTE: Most of the comments on this page reference Apple's NSIncrementalStore Class Reference.
 */

#import "SMIncrementalStore.h"
#import "StackMob.h"
#import "KeychainWrapper.h"
#import "SMDataStore+Protected.h"
#import "AFHTTPClient.h"

#define DLog(fmt, ...) NSLog((@"Performing %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

NSString *const SMIncrementalStoreType = @"SMIncrementalStore";
NSString *const SM_DataStoreKey = @"SM_DataStoreKey";
NSString *const StackMobRelationsKey = @"X-StackMob-Relations";
NSString *const SerializedDictKey = @"SerializedDict";

NSString *const SMInsertedObjectFailures = @"SMInsertedObjectFailures";
NSString *const SMUpdatedObjectFailures = @"SMUpdatedObjectFailures";
NSString *const SMDeletedObjectFailures = @"SMDeletedObjectFailures";

NSString *const SMFailedManagedObjectID = @"SMFailedManagedObjectID";
NSString *const SMFailedManagedObjectError = @"SMFailedManagedObjectError";

// Internal

NSString *const SMFailedRequestError = @"SMFailedRequestError";
NSString *const SMFailedRequestObjectPrimaryKey = @"SMFailedRequestObjectPrimaryKey";
NSString *const SMFailedRequestObjectEntity = @"SMFailedRequestObjectEntity";
NSString *const SMFailedRequest = @"SMFailedRequest";
NSString *const SMFailedRequestOptions = @"SMFailedRequestOptions";
NSString *const SMFailedRequestSuccessBlock = @"SMFailedRequestSuccessBlock";
NSString *const SMFailedRequestFailureBlock = @"SMFailedRequestFailureBlock";
NSString *const SMFailedRequestOriginalSuccessBlock = @"SMFailedRequestOriginalSuccessBlock";


BOOL SM_CORE_DATA_DEBUG = NO;
unsigned int SM_MAX_LOG_LENGTH = 10000;

NSString* truncateOutputIfExceedsMaxLogLength(id objectToCheck) {
    return [[NSString stringWithFormat:@"%@", objectToCheck] length] > SM_MAX_LOG_LENGTH ? [[[NSString stringWithFormat:@"%@", objectToCheck] substringToIndex:SM_MAX_LOG_LENGTH] stringByAppendingString:@" <MAX_LOG_LENGTH_REACHED>"] : objectToCheck;
}

@interface SMIncrementalStore () {
    
}

@property (nonatomic, strong) SMDataStore *smDataStore;
@property (nonatomic) dispatch_queue_t callbackQueue;
@property (nonatomic, strong) SMRequestOptions *globalOptions;

- (id)handleSaveRequest:(NSPersistentStoreRequest *)request 
            withContext:(NSManagedObjectContext *)context 
                  error:(NSError *__autoreleasing *)error;

- (id)handleFetchRequest:(NSPersistentStoreRequest *)request 
             withContext:(NSManagedObjectContext *)context 
                   error:(NSError *__autoreleasing *)error;

- (NSDictionary *)sm_responseSerializationForDictionary:(NSDictionary *)theObject schemaEntityDescription:(NSEntityDescription *)entityDescription managedObjectContext:(NSManagedObjectContext *)context;

- (void)SM_enqueueOperations:(NSArray *)ops dispatchGroup:(dispatch_group_t)group completionBlockQueue:(dispatch_queue_t)queue secure:(BOOL)isSecure;

- (BOOL)SM_setErrorAndUserInfoWithFailedOperations:(NSMutableArray *)failedOperations errorCode:(int)errorCode error:(NSError *__autoreleasing*)error;

- (void)SM_waitForRefreshingWithTimeout:(int)timeout;

- (BOOL)SM_doTokenRefreshIfNeededWithGroup:(dispatch_group_t)group queue:(dispatch_queue_t)queue error:(NSError *__autoreleasing*)error;

@end

@implementation SMIncrementalStore

@synthesize smDataStore = _smDataStore;
@synthesize callbackQueue = _callbackQueue;
@synthesize globalOptions = _globalOptions;

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)root configurationName:(NSString *)name URL:(NSURL *)url options:(NSDictionary *)options {
    
    self = [super initWithPersistentStoreCoordinator:root configurationName:name URL:url options:options];
    if (self) {
        _smDataStore = [options objectForKey:SM_DataStoreKey];
        _callbackQueue = dispatch_queue_create("Queue For Incremental Store Request Callbacks", NULL);
        _globalOptions = [SMRequestOptions options];
    }
    return self;
}

/*
Once a store has been created, the persistent store coordinator invokes loadMetadata: on it. In your implementation, if all goes well you should typically load the store metadata, call setMetadata: to store the metadata, and return YES. If an error occurs, however (if the store is invalid for some reason—for example, if the store URL is invalid, or the user doesn’t have read permission for the store URL), create an NSError object that describes the problem, assign it to the error parameter passed into the method, and return NO.

In the specific case where the store is new, you may choose not to generate metadata in loadMetadata:, but instead allow it to be automatically generated. In this case, the call to setMetadata: is not necessary.

If the metadata is generated automatically, the store identifier will set to a generated UUID. To override this automatic UUID generation, override identifierForNewStoreAtURL: to return an appropriate value. Store identifiers should either be persisted as part of the store metadata, or uniquely derivable in some way such that a given store will have the same identifier even if added to multiple persistent store coordinators. The identifier may be any type of object, although if you want object IDs created by your store to respond to URIRepresentation or for managedObjectIDForURIRepresentation: to be able to parse the generated URI representation, it should be an instance of NSString.
 
 Note: loadMetadata: should ignore any potential skew between the store and the model in use by the coordinator; this will bee handled automatically by the persistent store coordinator later. It is sufficient to return the version hashes that were saved in the store metadata the last time the store was saved (if the store is new the version hashes for the current model in use should be returned).
 
 In your implementation of this method, you must validate that the URL used to create the store is usable (the location exists and if necessary is writable, the schema is compatible, and so on) and return an error if there is an issue.
 
*/
- (BOOL)loadMetadata:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    NSString* uuid = [[NSProcessInfo processInfo] globallyUniqueString];
    [self setMetadata:[NSDictionary dictionaryWithObjectsAndKeys:
                       SMIncrementalStoreType, NSStoreTypeKey, 
                       uuid, NSStoreUUIDKey, 
                       @"Something user defined", @"Some user defined key",
                       nil]];
    return YES;
}

/*
Return Value
A value as appropriate for request, or nil if the request cannot be completed

Discussion
The value to return depends on the result type (see resultType) of request:

You should implement this method conservatively, and expect that unknown request types may at some point be passed to the method. The correct behavior in these cases is to return nil and an error.
*/

- (id)executeRequest:(NSPersistentStoreRequest *)request 
         withContext:(NSManagedObjectContext *)context 
               error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    id result = nil;
    switch (request.requestType) {
        case NSSaveRequestType:
            result = [self handleSaveRequest:request withContext:context error:error];
            break;
        case NSFetchRequestType:
            result = [self handleFetchRequest:request withContext:context error:error];
            break;
        default:
            [NSException raise:SMExceptionIncompatibleObject format:@"Unknown request type."];
            break;
    }
    
    //
    // Workaround for gnarly bug.
    //
    // I believe the issue is in NSManagedObjectContext -executeFetchRequest:error:, which seems to be releasing the error object.
    // We work around by manually incrementing the object's retain count.
    //
    // For details, see:
    //
    //   https://devforums.apple.com/message/560644#560644
    //   http://clang.llvm.org/docs/AutomaticReferenceCounting.html#objects.operands.casts
    //   http://developer.apple.com/library/ios/#releasenotes/ObjectiveC/RN-TransitioningToARC
    //
    
    if (result == nil) {
        *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
    }
    
    return result;
}

/*
 If the request is a save request, you record the changes provided in the request’s insertedObjects, updatedObjects, and deletedObjects collections. Note there is also a lockedObjects collection; this collection contains objects which were marked as being tracked for optimistic locking (through the detectConflictsForObject:: method); you may choose to respect this or not.
 In the case of a save request containing objects which are to be inserted, executeRequest:withContext:error: is preceded by a call to obtainPermanentIDsForObjects:error:; Core Data will assign the results of this call as the objectIDs for the objects which are to be inserted. Once these IDs have been assigned, they cannot change. 
 
 Note that if an empty save request is received by the store, this must be treated as an explicit request to save the metadata, but that store metadata should always be saved if it has been changed since the store was loaded.

 If the request is a save request, the method should return an empty array.
 If the save request contains nil values for the inserted/updated/deleted/locked collections; you should treat it as a request to save the store metadata.
 
 @note: We are *IGNORING* locked objects. We are also not handling the metadata save requests, because AFAIK we don't need to generate any.
 */
- (id)handleSaveRequest:(NSPersistentStoreRequest *)request 
            withContext:(NSManagedObjectContext *)context 
                  error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    
    // Reset options and failed operations queue
    [self.globalOptions setTryRefreshToken:YES];
    
    NSSaveChangesRequest *saveRequest = [[NSSaveChangesRequest alloc] initWithInsertedObjects:[context insertedObjects] updatedObjects:[context updatedObjects] deletedObjects:[context deletedObjects] lockedObjects:nil];
    
    NSSet *insertedObjects = [saveRequest insertedObjects];
    if ([insertedObjects count] > 0) {
        BOOL insertSuccess = [self handleInsertedObjects:insertedObjects inContext:context error:error];
        if (!insertSuccess) {
            return nil;
        }
    }
    NSSet *updatedObjects = [saveRequest updatedObjects];
    if ([updatedObjects count] > 0) {
        BOOL updateSuccess = [self handleUpdatedObjects:updatedObjects inContext:context error:error];
        if (!updateSuccess) {
            return nil;
        }
    }
    NSSet *deletedObjects = [saveRequest deletedObjects];
    if ([deletedObjects count] > 0) {
        BOOL deleteSuccess = [self handleDeletedObjects:deletedObjects inContext:context error:error];
        if (!deleteSuccess) {
            return nil;
        }
    }
    
    return [NSArray array];
}

- (BOOL)handleInsertedObjects:(NSSet *)insertedObjects inContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    if (SM_CORE_DATA_DEBUG) { DLog(@"objects to be inserted are %@", truncateOutputIfExceedsMaxLogLength(insertedObjects))}
    
    __block BOOL success = YES;
    
    // create a group dispatch and queue
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_group_t group = dispatch_group_create();
    
    __block NSMutableArray *secureOperations = [NSMutableArray array];
    __block NSMutableArray *regularOperations = [NSMutableArray array];
    __block NSMutableArray *failedRequests = [NSMutableArray array];
    __block NSMutableArray *failedRequestsWithUnauthorizedResponse = [NSMutableArray array];
    
    [insertedObjects enumerateObjectsUsingBlock:^(id managedObject, BOOL *stop) {
        
        // Create operation for inserted object
        
        NSDictionary *serializedObjDict = [managedObject sm_dictionarySerialization];
        NSString *schemaName = [managedObject sm_schema];
        __block NSString *insertedObjectID = [managedObject sm_objectId];
        
        SMRequestOptions *options = [SMRequestOptions options];
        // If superclass is SMUserNSManagedObject, add password
        if ([managedObject isKindOfClass:[SMUserManagedObject class]]) {
            BOOL addPasswordSuccess = [self addPasswordToSerializedDictionary:&serializedObjDict originalObject:managedObject];
            if (!addPasswordSuccess)
            {
                *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorPasswordForUserObjectNotFound userInfo:nil];
                *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
                *stop = YES;
            }
            options.isSecure = YES;
        }
        
        if (!*stop) {
            if (SM_CORE_DATA_DEBUG) { DLog(@"Serialized object dictionary: %@", truncateOutputIfExceedsMaxLogLength(serializedObjDict)) }
            // add relationship headers if needed
            NSMutableDictionary *headerDict = [NSMutableDictionary dictionary];
            if ([serializedObjDict objectForKey:StackMobRelationsKey]) {
                [headerDict setObject:[serializedObjDict objectForKey:StackMobRelationsKey] forKey:StackMobRelationsKey];
                [options setHeaders:headerDict];
            }
            
            SMResultSuccessBlock operationSuccesBlock = ^(NSDictionary *theObject){
                if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore inserted object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject) , schemaName); }
                if ([managedObject isKindOfClass:[SMUserManagedObject class]]) {
                    [managedObject removePassword];
                }

            };
            
            SMCoreDataSaveFailureBlock operationFailureBlock = ^(NSURLRequest *theRequest, NSError *theError, NSDictionary *theObject, SMRequestOptions *theOptions, SMResultSuccessBlock originalSuccessBlock){
                
                if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore failed to insert object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject), schemaName); }
                if (SM_CORE_DATA_DEBUG) { DLog(@"the error userInfo is %@", [theError userInfo]); }
                
                NSDictionary *failedRequestDict = [NSDictionary dictionaryWithObjectsAndKeys:theRequest, SMFailedRequest, theError, SMFailedRequestError, insertedObjectID, SMFailedRequestObjectPrimaryKey, [managedObject entity], SMFailedRequestObjectEntity, theOptions, SMFailedRequestOptions, originalSuccessBlock, SMFailedRequestOriginalSuccessBlock, nil];
                
                // Add failed request to correct array
                if ([theError code] == SMErrorUnauthorized) {
                    [failedRequestsWithUnauthorizedResponse addObject:failedRequestDict];
                } else {
                    [failedRequests addObject:failedRequestDict];
                }
                
            };
            
            AFJSONRequestOperation *op = [[self smDataStore] postOperationForObject:[serializedObjDict objectForKey:SerializedDictKey] inSchema:schemaName options:options successCallbackQueue:queue failureCallbackQueue:queue onSuccess:operationSuccesBlock onFailure:operationFailureBlock];
        
            options.isSecure ? [secureOperations addObject:op] : [regularOperations addObject:op];
            
        } else {
            success = NO;
        }
        
    }];
    
    
    // Refresh access token if needed before initial enqueue of operations
    success = [self SM_doTokenRefreshIfNeededWithGroup:group queue:queue error:error];
    
    if (success) {
        [self SM_enqueueOperations:secureOperations  dispatchGroup:group completionBlockQueue:queue secure:YES];
        [self SM_enqueueOperations:regularOperations dispatchGroup:group completionBlockQueue:queue secure:NO];
        
        dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        
        // If there were 401s, refresh token is valid, refresh token is present and token has expired, attempt refresh and reprocess
        if ([failedRequestsWithUnauthorizedResponse count] > 0) {
            
            if ([self.smDataStore.session eligibleForTokenRefresh:self.globalOptions]) {
                
                // If we are refreshing, wait for refresh with 5 sec timeout
                __block BOOL refreshSuccess = NO;
                
                if (self.smDataStore.session.refreshing) {
                    
                    [self SM_waitForRefreshingWithTimeout:5];
                    
                } else {
                    
                    [self.globalOptions setTryRefreshToken:NO];
                    dispatch_group_enter(group);
                    self.smDataStore.session.refreshing = YES;//Don't ever trigger two refreshToken calls
                    [self.smDataStore.session doTokenRequestWithEndpoint:@"refreshToken" credentials:[NSDictionary dictionaryWithObjectsAndKeys:self.smDataStore.session.refreshToken, @"refresh_token", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *userObject) {
                        refreshSuccess = YES;
                        dispatch_group_leave(group);
                    } onFailure:^(NSError *theError) {
                        refreshSuccess = NO;
                        success = NO;
                        [failedRequests addObjectsFromArray:failedRequestsWithUnauthorizedResponse];
                        [self SM_setErrorAndUserInfoWithFailedOperations:failedRequests errorCode:SMErrorRefreshTokenFailed error:error];
                        dispatch_group_leave(group);
                    }];
                    
                    
                    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
                }
                
                if (self.smDataStore.session.refreshing) {
                    
                    refreshSuccess = NO;
                    success = NO;
                    [failedRequests addObjectsFromArray:failedRequestsWithUnauthorizedResponse];
                    [self SM_setErrorAndUserInfoWithFailedOperations:failedRequests errorCode:SMErrorRefreshTokenInProgress error:error];
                    
                } else {
                    refreshSuccess = YES;
                }
                
                if (refreshSuccess) {
                    
                    // Retry Failed Requests
                    
                    [secureOperations removeAllObjects];
                    [regularOperations removeAllObjects];
                    
                    [failedRequestsWithUnauthorizedResponse enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
                        SMRequestOptions *retryOptions = [obj objectForKey:SMFailedRequestOptions];
                        
                        SMFullResponseSuccessBlock retrySuccessBlock = [self.smDataStore SMFullResponseSuccessBlockForResultSuccessBlock:[obj objectForKey:SMFailedRequestOriginalSuccessBlock]];
                        
                        SMFullResponseFailureBlock retryFailureBlock = ^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *retryError, id JSON) {
                            
                            NSDictionary *failedRequestDict = [NSDictionary dictionaryWithObjectsAndKeys:[self.smDataStore errorFromResponse:response JSON:JSON], SMFailedRequestError, [obj objectForKey:SMFailedRequestObjectPrimaryKey], SMFailedRequestObjectPrimaryKey, [obj objectForKey:SMFailedRequestObjectEntity], SMFailedRequestObjectEntity, nil];
                            [failedRequests addObject:failedRequestDict];
                            
                        };
                        
                        AFJSONRequestOperation *op = [self.smDataStore newOperationForRequest:[obj objectForKey:SMFailedRequest] options:[obj objectForKey:SMFailedRequestOptions] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:retrySuccessBlock onFailure:retryFailureBlock];
                        
                        retryOptions.isSecure ? [secureOperations addObject:op] : [regularOperations addObject:op];
                    }];
                    
                    [self SM_enqueueOperations:secureOperations  dispatchGroup:group completionBlockQueue:queue secure:YES];
                    [self SM_enqueueOperations:regularOperations dispatchGroup:group completionBlockQueue:queue secure:NO];
                    
                    dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
                    
                }
                
            } else {
                [failedRequests addObjectsFromArray:failedRequestsWithUnauthorizedResponse];
            }
        }
        
        // Error if any failed requests have made it to this point
        if ([failedRequests count] > 0) {
            success = NO;
            [self SM_setErrorAndUserInfoWithFailedOperations:failedRequests errorCode:SMErrorCoreDataSave error:error];
        }
    }
    
    dispatch_release(group);
    dispatch_release(queue);
    return success;
    
}

- (BOOL)SM_setErrorAndUserInfoWithFailedOperations:(NSMutableArray *)failedOperations errorCode:(int)errorCode error:(NSError *__autoreleasing*)error
{
    if (error != NULL) {
        __block NSMutableArray *failedInsertedObjects = [NSMutableArray array];
        [failedOperations enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSManagedObjectID *oid = [self newObjectIDForEntity:[obj objectForKey:SMFailedRequestObjectEntity] referenceObject:[obj objectForKey:SMFailedRequestObjectPrimaryKey]];
            NSDictionary *failedObject = [NSDictionary dictionaryWithObjectsAndKeys:oid, SMFailedManagedObjectID, [obj objectForKey:SMFailedRequestError], SMFailedManagedObjectError, nil];
            [failedInsertedObjects addObject:failedObject];
        }];
        NSError *refreshError = [[NSError alloc] initWithDomain:SMErrorDomain code:errorCode userInfo:[NSDictionary dictionaryWithObjectsAndKeys:failedInsertedObjects, SMInsertedObjectFailures, nil]];
        *error = (__bridge id)(__bridge_retained CFTypeRef)refreshError;
    }
    [failedOperations removeAllObjects];
    return YES;
}

- (void)SM_waitForRefreshingWithTimeout:(int)timeout
{
    if (timeout == 0 || !self.smDataStore.session.refreshing) {
        return;
    }
    
    sleep(1);
    
    [self SM_waitForRefreshingWithTimeout:(timeout - 1)];
    
}

- (void)SM_enqueueOperations:(NSArray *)ops dispatchGroup:(dispatch_group_t)group completionBlockQueue:(dispatch_queue_t)queue secure:(BOOL)isSecure
{
    if ([ops count] > 0) {
        dispatch_group_enter(group);
        [[[self.smDataStore session] oauthClientWithHTTPS:isSecure] enqueueBatchOfHTTPRequestOperations:ops completionBlockQueue:queue progressBlock:^(NSUInteger numberOfFinishedOperations, NSUInteger totalNumberOfOperations) {
            
        } completionBlock:^(NSArray *operations) {
            dispatch_group_leave(group);
        }];
    }
}

- (BOOL)SM_doTokenRefreshIfNeededWithGroup:(dispatch_group_t)group queue:(dispatch_queue_t)queue error:(NSError *__autoreleasing*)error
{
    __block BOOL success = YES;
    if ([self.smDataStore.session eligibleForTokenRefresh:self.globalOptions]) {
        
        if (self.smDataStore.session.refreshing) {
            
            [self SM_waitForRefreshingWithTimeout:5];
            
        } else {
            
            [self.globalOptions setTryRefreshToken:NO];
            dispatch_group_enter(group);
            self.smDataStore.session.refreshing = YES;//Don't ever trigger two refreshToken calls
            [self.smDataStore.session doTokenRequestWithEndpoint:@"refreshToken" credentials:[NSDictionary dictionaryWithObjectsAndKeys:self.smDataStore.session.refreshToken, @"refresh_token", nil] options:[SMRequestOptions options] successCallbackQueue:queue failureCallbackQueue:queue onSuccess:^(NSDictionary *userObject) {
                dispatch_group_leave(group);
            } onFailure:^(NSError *theError) {
                success = NO;
                if (error != NULL) {
                    NSError *refreshError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenFailed userInfo:nil];
                    *error = (__bridge id)(__bridge_retained CFTypeRef)refreshError;
                }
                dispatch_group_leave(group);
            }];
            
            
            dispatch_group_wait(group, DISPATCH_TIME_FOREVER);
        }
        
        if (self.smDataStore.session.refreshing) {
            
            success = NO;
            if (error != NULL) {
                NSError *refreshError = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorRefreshTokenInProgress userInfo:nil];
                *error = (__bridge id)(__bridge_retained CFTypeRef)refreshError;
            }
            
        }
        
    }
    
    return success;
}

- (BOOL)handleUpdatedObjects:(NSSet *)updatedObjects inContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    __block BOOL success = NO;
    if (SM_CORE_DATA_DEBUG) { DLog(@"objects to be updated are %@", truncateOutputIfExceedsMaxLogLength(updatedObjects)); }
    [updatedObjects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            
            NSDictionary *serializedObjDict = [obj sm_dictionarySerialization];
            NSString *schemaName = [obj sm_schema];
            if (SM_CORE_DATA_DEBUG) { DLog(@"serialized object is %@", truncateOutputIfExceedsMaxLogLength(serializedObjDict)); }
            // if there are relationships present in the update, send as a POST
            if ([serializedObjDict objectForKey:StackMobRelationsKey]) {
                NSDictionary *headerDict = [NSDictionary dictionaryWithObject:[serializedObjDict objectForKey:StackMobRelationsKey] forKey:StackMobRelationsKey];
                [self.smDataStore createObject:[serializedObjDict objectForKey:SerializedDictKey] inSchema:schemaName options:[SMRequestOptions optionsWithHeaders:headerDict] onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore inserted object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject), schema); }
                    success = YES;
                    // TO-DO OFFLINE-SUPPORT
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore failed to insert object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject), schema); }
                    if (SM_CORE_DATA_DEBUG) { DLog(@"the error userInfo is %@", [theError userInfo]); }
                    success = NO;
                    *error = (__bridge id)(__bridge_retained CFTypeRef)theError;
                    syncReturn(semaphore);
                }];
            } else {
                [self.smDataStore updateObjectWithId:[obj sm_objectId] inSchema:schemaName update:[serializedObjDict objectForKey:SerializedDictKey] onSuccess:^(NSDictionary *theObject, NSString *schema) {
                    if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore updated object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject), schema); }
                    success = YES;
                    // TO-DO OFFLINE-SUPPORT
                    syncReturn(semaphore);
                } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                    if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore failed to update object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject), schema); }
                    if (SM_CORE_DATA_DEBUG) { DLog(@"the error userInfo is %@", [theError userInfo]); }
                    success = NO;
                    *error = (__bridge id)(__bridge_retained CFTypeRef)theError;
                    syncReturn(semaphore);
                }];
            }
            
        });
        if (success == NO)
            *stop = YES;
    }];
    return success;
}

- (BOOL)handleDeletedObjects:(NSSet *)deletedObjects inContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    __block BOOL success = NO;
        if (SM_CORE_DATA_DEBUG) { DLog(@"objects to be deleted are %@", truncateOutputIfExceedsMaxLogLength(deletedObjects)); }
    [deletedObjects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {        
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSString *schemaName = [obj sm_schema];
            NSString *uuid = [obj sm_objectId];
            [self.smDataStore deleteObjectId:uuid inSchema:schemaName onSuccess:^(NSString *theObjectId, NSString *schema) {
                if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore deleted object with id %@ on schema %@", theObjectId, schema); }
                success = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
                if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore failed to delete object with id %@ on schema %@", theObjectId, schema); }
                    if (SM_CORE_DATA_DEBUG) { DLog(@"the error userInfo is %@", [theError userInfo]); }
                success = NO;
                *error = (__bridge id)(__bridge_retained CFTypeRef)theError;
                syncReturn(semaphore);
            }];
            if (success) {
                // TO-DO OFFLINE-SUPPORT
            }
        });
        if (success == NO)
            *stop = YES;
    }];
    return success;
}

/*
 If it is NSCountResultType, the method should return an array containing an NSNumber whose value is the count of of all objects in the store matching the request.
 
 You must support the following properties of NSFetchRequest: entity, predicate, sortDescriptors, fetchLimit, resultType, includesSubentities, returnsDistinctResults (in the case of NSDictionaryResultType), propertiesToFetch (in the case of NSDictionaryResultType), fetchOffset, fetchBatchSize, shouldRefreshFetchedObjects, propertiesToGroupBy, and havingPredicate. If a store does not have underlying support for a feature (propertiesToGroupBy, havingPredicate), it should either emulate the feature in memory or return an error. Note that these are the properties that directly affect the contents of the array to be returned.
 
 You may optionally ignore the following properties of NSFetchRequest: includesPropertyValues, returnsObjectsAsFaults, relationshipKeyPathsForPrefetching, and includesPendingChanges (this is handled by the managed object context). (These are properties that allow for optimization of I/O and do not affect the results array contents directly.)
*/
- (id)handleFetchRequest:(NSPersistentStoreRequest *)request 
             withContext:(NSManagedObjectContext *)context 
                   error:(NSError * __autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    NSFetchRequest *fetchRequest = (NSFetchRequest *)request;
    switch (fetchRequest.resultType) {
        case NSManagedObjectResultType:
            return [self fetchObjects:fetchRequest withContext:context error:error];
            break;
        case NSManagedObjectIDResultType:
            return [self fetchObjectIDs:fetchRequest withContext:context error:error];
            break;
        case NSDictionaryResultType:
            [NSException raise:SMExceptionIncompatibleObject format:@"Unimplemented result type requested."];
            break;
        case NSCountResultType:
            [NSException raise:SMExceptionIncompatibleObject format:@"Unimplemented result type requested."];
            break;
        default:
            [NSException raise:SMExceptionIncompatibleObject format:@"Unknown result type requested."];
            break;
    }
    return nil;
}

// Returns NSArray<NSManagedObject>

- (id)fetchObjects:(NSFetchRequest *)fetchRequest withContext:(NSManagedObjectContext *)context error:(NSError * __autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    
    SMQuery *query = [SMIncrementalStore queryForFetchRequest:fetchRequest error:error];

    if (query == nil) {
        return nil;
    }
    
    __block id resultsWithoutOID;
    synchronousQuery(self.smDataStore, query, ^(NSArray *results) {
        resultsWithoutOID = results;
    }, ^(NSError *theError) {
        *error = (__bridge id)(__bridge_retained CFTypeRef)theError;
    });

    return [resultsWithoutOID map:^(id item) {
        NSString *primaryKeyField = nil;
        @try {
            primaryKeyField = [fetchRequest.entity sm_fieldNameForProperty:[[fetchRequest.entity propertiesByName] objectForKey:[fetchRequest.entity primaryKeyField]]];
        }
        @catch (NSException *exception) {
            primaryKeyField = [self.smDataStore.session userPrimaryKeyField];
        }
        id remoteID = [item objectForKey:primaryKeyField];
        if (!remoteID) {
            [NSException raise:SMExceptionIncompatibleObject format:@"No key for supposed primary key field %@ for item %@", primaryKeyField, item];
        }
        NSManagedObjectID *oid = [self newObjectIDForEntity:fetchRequest.entity referenceObject:remoteID];
        NSManagedObject *object = [context objectWithID:oid];
        
        
        // Populate the attributes of the object with the fetch data
        [self populateManagedObject:object withItem:item fetchRequest:fetchRequest context:context];
        
        return object;
        
    }];
}

// Returns NSArray<NSManagedObjectID>

- (id)fetchObjectIDs:(NSFetchRequest *)fetchRequest withContext:(NSManagedObjectContext *)context error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(); }
    
    NSArray *objects = [self fetchObjects:fetchRequest withContext:context error:error];
    return [objects map:^(id item) {
        return [item objectID];
    }];
}

/*
 Returns an incremental store node encapsulating the persistent external values of the object with a given object ID.
 Return Value
   An incremental store node encapsulating the persistent external values of the object with object ID objectID, or nil if the corresponding object cannot be found.
 
 Discussion
 The returned node should include all attributes values and may include to-one relationship values as instances of NSManagedObjectID.
 
 If an object with object ID objectID cannot be found, the method should return nil and—if error is not NULL—create and return an appropriate error object in error.
 */

/*
 * Returns an incremental store node encapsulating the persistent external values of the object with a given object ID.
 The returned node should include all attributes values and may include to-one relationship values as instances of NSManagedObjectID.
    
 */
- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context 
                                               error:(NSError *__autoreleasing *)error {
    
    if (SM_CORE_DATA_DEBUG) { DLog(@"new values for object with id %@", [context objectWithID:objectID]); }
    
    // Make a GET call to SM and return the properties for the entity
    __block NSManagedObject *theObj = [context objectWithID:objectID];
    __block NSEntityDescription *objEntity = [theObj entity];
    __block NSString *schemaName = [[objEntity name] lowercaseString];
    __block NSString *objStringId = [self referenceObjectForObjectID:objectID];
    __block BOOL success = NO;
    __block NSDictionary *objectFields;
    
    
    
    syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
        [self.smDataStore readObjectWithId:objStringId inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
            objectFields = [self sm_responseSerializationForDictionary:theObject schemaEntityDescription:objEntity managedObjectContext:context];
            success = YES;
            syncReturn(semaphore);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            if (SM_CORE_DATA_DEBUG) { DLog(@"Could not read the object with objectId %@ and error userInfo %@", theObjectId, [theError userInfo]); }
            success = NO;
            if (NULL != error) {
                // TO DO provide sm specific error
                *error = [[NSError alloc] initWithDomain:[theError domain] code:[theError code] userInfo:[theError userInfo]];
                *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
            }
            syncReturn(semaphore);
        }];
    });
    
    if (!success) {
        return nil;
    }

    NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:objectFields version:1];
    
    return node;
}

/*
 Return Value
 The value of the relationship specified relationship of the object with object ID objectID, or nil if an error occurs.
 
 Discussion
 If the relationship is a to-one, the method should return an NSManagedObjectID instance that identifies the destination, or an instance of NSNull if the relationship value is nil.
 
 If the relationship is a to-many, the method should return a collection object containing NSManagedObjectID instances to identify the related objects. Using an NSArray instance is preferred because it will be the most efficient. A store may also return an instance of NSSet or NSOrderedSet; an instance of NSDictionary is not acceptable.
 
 If an object with object ID objectID cannot be found, the method should return nil and—if error is not NULL—create and return an appropriate error object in error.
 */
- (id)newValueForRelationship:(NSRelationshipDescription *)relationship
              forObjectWithID:(NSManagedObjectID *)objectID 
                  withContext:(NSManagedObjectContext *)context 
                        error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(@"new value for relationship %@ for object with id %@", relationship, objectID); }
    
    __block NSManagedObject *theObj = [context objectWithID:objectID];
    __block NSEntityDescription *objEntity = [theObj entity];
    __block NSString *schemaName = [[objEntity name] lowercaseString];
    __block NSString *objStringId = [self referenceObjectForObjectID:objectID];
    __block BOOL success = NO;
    __block NSDictionary *objDict;

    syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
        [self.smDataStore readObjectWithId:objStringId inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
            objDict = theObject;
            success = YES;
            syncReturn(semaphore);
        } onFailure:^(NSError *theError, NSString *theObjectId, NSString *schema) {
            if (SM_CORE_DATA_DEBUG) { DLog(@"Could not read the object with objectId %@ and error userInfo %@", theObjectId, [theError userInfo]); }
            success = NO;
            if (NULL != error) {
                // TO DO provide sm specific error
                *error = [[NSError alloc] initWithDomain:[theError domain] code:[theError code] userInfo:[theError userInfo]];
                *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
                
            }
            syncReturn(semaphore);
        }];
    });
    
    if (!success) {
        return nil;
    }
    
    id relationshipContents = [objDict valueForKey:[objEntity sm_fieldNameForProperty:relationship]];
    
    if ([relationship isToMany]) {
        if (relationshipContents) {
            if (![relationshipContents isKindOfClass:[NSArray class]]) {
                [NSException raise:SMExceptionIncompatibleObject format:@"Relationship contents should be an array for a to-many relationship. The relationship passed has contents that are of class type %@. Confirm that this relationship was meant to be to-many.", [relationshipContents class]];
            }
            NSMutableArray *arrayToReturn = [NSMutableArray array];
            [(NSSet *)relationshipContents enumerateObjectsUsingBlock:^(id stringIdReference, BOOL *stop) {
                NSManagedObjectID *relationshipObjectID = [self newObjectIDForEntity:[relationship destinationEntity] referenceObject:stringIdReference];
                [arrayToReturn addObject:relationshipObjectID];
            }];
            return arrayToReturn;
        } else {
            return [NSArray array];
        }
    } else {
        if (relationshipContents) {
            if (![relationshipContents isKindOfClass:[NSString class]]) {
                [NSException raise:SMExceptionIncompatibleObject format:@"Relationship contents should be a string for a to-one relationship. The relationship passed has contents that are of class type %@. Confirm that this relationship was meant to be to-one.", [relationshipContents class]];
            }
            NSManagedObjectID *relationshipObjectID = [self newObjectIDForEntity:[relationship destinationEntity] referenceObject:relationshipContents];
            return relationshipObjectID;
        } else {
            return [NSNull null];
        }
    }

}

/*
 Returns an array containing the object IDs for a given array of newly-inserted objects.
 This method is called before executeRequest:withContext:error: with a save request, to assign permanent IDs to newly-inserted objects.
 */
- (NSArray *)obtainPermanentIDsForObjects:(NSArray *)array 
                                    error:(NSError *__autoreleasing *)error {
    if (SM_CORE_DATA_DEBUG) { DLog(@"obtain permanent ids for objects: %@", truncateOutputIfExceedsMaxLogLength(array)); }
    // check if array is null, return empty array if so
    if (array == nil) {
        return [NSArray array];
    }
    
    if (*error) { 
        if (SM_CORE_DATA_DEBUG) { DLog(@"error with obtaining perm ids is %@", *error); }
        *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
    }
    
    return [array map:^id(id item) {
        NSString *itemId = [item sm_objectId];
        if (!itemId) {
            [NSException raise:SMExceptionIncompatibleObject format:@"Item not previously assigned an object ID for it's primary key field, which is used to obtain a permanent ID for the Core Data object.  Before a call to save on the managedObjectContext, be sure to assign an object ID.  This looks something like [newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]].  The item in question is %@", item];
        } 
        
        NSManagedObjectID *returnId = [self newObjectIDForEntity:[item entity] referenceObject:itemId];
        if (SM_CORE_DATA_DEBUG) { DLog(@"Permanent ID assigned is %@", returnId); }
        
        return returnId;
    }];
}
     
#pragma mark - Object store
- (NSString *)remoteKeyForEntityName:(NSString *)entityName {
    return [[entityName lowercaseString] stringByAppendingString:@"_id"];
}

/*
 Returns a dictionary that has extra fields from StackMob that aren't present as attributes or relationships in the Core Data representation stripped out.  Examples may be StackMob added createddate or lastmoddate.
 
 Used for newValuesForObjectWithID:.
 */
- (NSDictionary *)sm_responseSerializationForDictionary:(NSDictionary *)theObject schemaEntityDescription:(NSEntityDescription *)entityDescription managedObjectContext:(NSManagedObjectContext *)context
{
    __block NSMutableDictionary *serializedDictionary = [NSMutableDictionary dictionary];
    
    [entityDescription.propertiesByName enumerateKeysAndObjectsUsingBlock:^(id propertyName, id property, BOOL *stop) {
        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *attributeDescription = (NSAttributeDescription *)property;
            if (attributeDescription.attributeType != NSUndefinedAttributeType) {
                id value = [theObject valueForKey:[entityDescription sm_fieldNameForProperty:attributeDescription]];
                if (value != nil) {
                    if (attributeDescription.attributeType == NSDateAttributeType) {
                        NSDate *convertedDate = [NSDate dateWithTimeIntervalSince1970:[value doubleValue]];
                        [serializedDictionary setObject:convertedDate forKey:propertyName];
                    } else {
                        [serializedDictionary setObject:value forKey:propertyName];
                    }
                }
            }
        }
        else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *relationshipDescription = (NSRelationshipDescription *)property;
            // get the relationship contents for the property
            id relationshipContents = [theObject valueForKey:[entityDescription sm_fieldNameForProperty:relationshipDescription]];
            if (relationshipContents) {
                if (![relationshipDescription isToMany]) {
                    NSEntityDescription *entityDescriptionForRelationship = [NSEntityDescription entityForName:[[property destinationEntity] name] inManagedObjectContext:context];
                    if ([relationshipContents isKindOfClass:[NSString class]]) {
                        NSManagedObjectID *relationshipObjectID = [self newObjectIDForEntity:entityDescriptionForRelationship referenceObject:relationshipContents];
                        [serializedDictionary setObject:relationshipObjectID forKey:propertyName];
                    }
                }
            }
            
        }       
    }];
    
    return serializedDictionary;
}

/*
 Temporary method which replaces internal data of fetched objects with any changes made to objects on the server
 */
- (void)populateManagedObject:(NSManagedObject *)object withItem:(NSDictionary *)item fetchRequest:(NSFetchRequest *)fetchRequest context:(NSManagedObjectContext *)context
{
    NSDictionary *serializedDict = [self sm_responseSerializationForDictionary:item schemaEntityDescription:fetchRequest.entity managedObjectContext:context];
    for (NSString *field in [serializedDict allKeys]) {
        if ([[[fetchRequest.entity attributesByName] allKeys] indexOfObject:field] != NSNotFound) {
            [object setPrimitiveValue:serializedDict[field] forKey:field];
        } else if ([[[fetchRequest.entity relationshipsByName] allKeys] indexOfObject:field] != NSNotFound) {
            NSRelationshipDescription *relationshipDescription = (NSRelationshipDescription *)[[fetchRequest.entity relationshipsByName] objectForKey:field];
            // handle to-many
            if ([relationshipDescription isToMany]) {
                // let fault for now
            } else {
                // handle to-one
                [object setPrimitiveValue:[context objectWithID:serializedDict[field]]  forKey:field];
            }
            
        }
    }
}

- (BOOL)addPasswordToSerializedDictionary:(NSDictionary **)originalDictionary originalObject:(SMUserManagedObject *)object
{
    NSMutableDictionary *dictionaryToReturn = [*originalDictionary mutableCopy];
    
    NSMutableDictionary *serializedDictCopy = [[*originalDictionary objectForKey:SerializedDictKey] mutableCopy];
    
    NSString *passwordIdentifier = [object passwordIdentifier];
    NSString *thePassword = [KeychainWrapper keychainStringFromMatchingIdentifier:passwordIdentifier];
    
    if (!thePassword) {
        return NO;
    }
    
    [serializedDictCopy setObject:thePassword forKey:[[[self smDataStore] session] userPasswordField]];
    
    [dictionaryToReturn setObject:serializedDictCopy forKey:SerializedDictKey];
    
    *originalDictionary = dictionaryToReturn;
    
    return YES;
}

@end
