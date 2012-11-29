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

#define DLog(fmt, ...) NSLog((@"Performing %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

NSString *const SMIncrementalStoreType = @"SMIncrementalStore";
NSString *const SM_DataStoreKey = @"SM_DataStoreKey";
NSString *const StackMobRelationsKey = @"X-StackMob-Relations";
NSString *const SerializedDictKey = @"SerializedDict";

BOOL SM_CORE_DATA_DEBUG = NO;
unsigned int SM_MAX_LOG_LENGTH = 10000;

NSString* truncateOutputIfExceedsMaxLogLength(id objectToCheck) {
    return [[NSString stringWithFormat:@"%@", objectToCheck] length] > SM_MAX_LOG_LENGTH ? [[[NSString stringWithFormat:@"%@", objectToCheck] substringToIndex:SM_MAX_LOG_LENGTH] stringByAppendingString:@" <MAX_LOG_LENGTH_REACHED>"] : objectToCheck;
}

@interface SMIncrementalStore () {
    
}

@property (nonatomic, strong) SMDataStore *smDataStore;
@property (nonatomic, strong) NSManagedObjectContext *localManagedObjectContext;
@property (nonatomic, strong) NSPersistentStoreCoordinator *localPersistentStoreCoordinator;
@property (nonatomic, strong) NSManagedObjectModel *localManagedObjectModel;

- (id)handleSaveRequest:(NSPersistentStoreRequest *)request 
            withContext:(NSManagedObjectContext *)context 
                  error:(NSError *__autoreleasing *)error;

- (id)handleFetchRequest:(NSPersistentStoreRequest *)request 
             withContext:(NSManagedObjectContext *)context 
                   error:(NSError *__autoreleasing *)error;

- (NSDictionary *)sm_responseSerializationForDictionary:(NSDictionary *)theObject schemaEntityDescription:(NSEntityDescription *)entityDescription managedObjectContext:(NSManagedObjectContext *)context forFetchRequest:(BOOL)forFetchRequest;

- (void)configureCache;
- (NSURL *)getStoreURL;
- (void)createStoreURLPathIfNeeded:(NSURL *)storeURL;

@end

@implementation SMIncrementalStore

@synthesize smDataStore = _smDataStore;
@synthesize localManagedObjectModel = _localManagedObjectModel;
@synthesize localManagedObjectContext = _localManagedObjectContext;
@synthesize localPersistentStoreCoordinator = _localPersistentStoreCoordinator;

- (id)initWithPersistentStoreCoordinator:(NSPersistentStoreCoordinator *)root configurationName:(NSString *)name URL:(NSURL *)url options:(NSDictionary *)options {
    
    self = [super initWithPersistentStoreCoordinator:root configurationName:name URL:url options:options];
    if (self) {
        _smDataStore = [options objectForKey:SM_DataStoreKey];
        [self configureCache];
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
    
    // If network is not reachable, error and return
    if ([self.smDataStore.session.networkMonitor currentNetworkStatus] != Reachable) {
        if (NULL != error) {
            *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The network is not reachable", NSLocalizedDescriptionKey, nil]];
            *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
        }
        return nil;
    }
    
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

    __block BOOL success = NO;
    
    [insertedObjects enumerateObjectsUsingBlock:^(id obj, BOOL *stop) {
        syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
            NSDictionary *serializedObjDict = [obj sm_dictionarySerialization];
            NSString *schemaName = [obj sm_schema];
            
            SMRequestOptions *options = [SMRequestOptions options];
            // If superclass is SMUserNSManagedObject, add password
            if ([obj isKindOfClass:[SMUserManagedObject class]]) {
                BOOL addPasswordSuccess = [self addPasswordToSerializedDictionary:&serializedObjDict originalObject:obj];
                if (!addPasswordSuccess)
                {
                    *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorPasswordForUserObjectNotFound userInfo:nil];
                    *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
                    *stop = YES;
                }
                options.isSecure = YES;
            }
            if (SM_CORE_DATA_DEBUG) { DLog(@"Serialized object dictionary: %@", truncateOutputIfExceedsMaxLogLength(serializedObjDict)) }
            // add relationship headers if needed
            NSMutableDictionary *headerDict = [NSMutableDictionary dictionary];
            if ([serializedObjDict objectForKey:StackMobRelationsKey]) {
                [headerDict setObject:[serializedObjDict objectForKey:StackMobRelationsKey] forKey:StackMobRelationsKey];
                [options setHeaders:headerDict];
            }
            
            [self.smDataStore createObject:[serializedObjDict objectForKey:SerializedDictKey] inSchema:schemaName options:options onSuccess:^(NSDictionary *theObject, NSString *schema) {
                if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore inserted object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject) , schema); }
                if ([obj isKindOfClass:[SMUserManagedObject class]]) {
                    [obj removePassword];
                }
                success = YES;
                syncReturn(semaphore);
            } onFailure:^(NSError *theError, NSDictionary *theObject, NSString *schema) {
                if (SM_CORE_DATA_DEBUG) { DLog(@"SMIncrementalStore failed to insert object %@ on schema %@", truncateOutputIfExceedsMaxLogLength(theObject), schema); }
                if (SM_CORE_DATA_DEBUG) { DLog(@"the error userInfo is %@", [theError userInfo]); }
                success = NO;
                *error = (__bridge id)(__bridge_retained CFTypeRef)theError;
                syncReturn(semaphore);
            }];
            
        });
        if (success == NO)
            *stop = YES;
    }];
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
    
    // if we are online
    if ([self.smDataStore.session.networkMonitor currentNetworkStatus] == Reachable) {
        
        // build query for StackMob
        SMQuery *query = [SMIncrementalStore queryForFetchRequest:fetchRequest error:error];
        
        if (query == nil) {
            return nil;
        }
        
        __block NSArray *resultsWithoutOID;
        // execute query on StackMob
        synchronousQuery(self.smDataStore, query, ^(NSArray *results) {
            resultsWithoutOID = results;
        }, ^(NSError *theError) {
            if (NULL != error) {
                *error = [[NSError alloc] initWithDomain:[theError domain] code:[theError code] userInfo:[theError userInfo]];
                *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
            }
        });
        
        if (*error != nil) {
            return nil;
        }
        
        // For each result of the fetch
        NSArray *results = [resultsWithoutOID map:^(id item) {
            // Find the primary key and grab the object from the current context
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
            //NSManagedObject *object = [context objectRegisteredForID:oid];
            
            // if the object does not previously exist it will be marked faulted
            NSDictionary *serializedDict = [self sm_responseSerializationForDictionary:item schemaEntityDescription:fetchRequest.entity managedObjectContext:context forFetchRequest:YES];
            if (![object isFault]) {
                // enumerate through properties
                // change them in memory
                [serializedDict enumerateKeysAndObjectsUsingBlock:^(id propertyName, id propertyValue, BOOL *stop) {
                    NSPropertyDescription *propertyDescription = [[fetchRequest.entity propertiesByName] objectForKey:propertyName];
                    if ([propertyDescription isKindOfClass:[NSAttributeDescription class]]) {
                        [object setPrimitiveValue:serializedDict[propertyName] forKey:propertyName];
                    } else if (![object hasFaultForRelationshipNamed:propertyName]) {
                        NSRelationshipDescription *relationshipDescription = (NSRelationshipDescription *)propertyDescription;
                        if ([relationshipDescription isToMany]) {
                            NSMutableSet *relatedObjects = [[object primitiveValueForKey:propertyName] mutableCopy];
                            if (relatedObjects != nil) {
                                [relatedObjects removeAllObjects];
                                NSSet *serializedDictSet = serializedDict[propertyName];
                                // create objects from managed object ids
                                [serializedDictSet enumerateObjectsUsingBlock:^(id managedObjectID, BOOL *stopEnum) {
                                    [relatedObjects addObject:[context objectWithID:managedObjectID]];
                                }];
                                [object setPrimitiveValue:relatedObjects forKey:propertyName];
                            }
                        } else {
                            // handle to-one
                            NSManagedObject *toOneObject = [context objectWithID:serializedDict[propertyName]];
                            [object setPrimitiveValue:toOneObject forKey:propertyName];
                        }
                    }
                }];
            }
            
            // see if the object already exists in LC, otherwise add it
            
            // TODO do not use user defaults... store in a document or something
            
            NSManagedObject *cacheObject = [self getCacheObjectForRemoteID:remoteID entityName:[[object entity] name]];
            
            
            [[fetchRequest.entity propertiesByName] enumerateKeysAndObjectsUsingBlock:^(id propertyName, id property, BOOL *stop) {
                id propertyValueFromSerializedDict = [serializedDict objectForKey:propertyName];
                if (propertyValueFromSerializedDict) {
                    if ([property isKindOfClass:[NSAttributeDescription class]]) {
                        [cacheObject setValue:propertyValueFromSerializedDict forKey:propertyName];
                    } else if ([(NSRelationshipDescription *)property isToMany]) {
                        // to-many
                        NSMutableArray *array = [NSMutableArray array];
                        [(NSSet *)propertyValueFromSerializedDict enumerateObjectsUsingBlock:^(id obj, BOOL *stopEnum) {
                            [array addObject:[self getCacheObjectForRemoteID:[self referenceObjectForObjectID:obj] entityName:[[property destinationEntity] name]]];
                        }];
                        [cacheObject setValue:[NSSet setWithArray:array] forKey:propertyName];
                    } else {
                        // to-one
                        // translate smid to cache id and store
                        NSManagedObject *setObject = [self getCacheObjectForRemoteID:[self referenceObjectForObjectID:propertyValueFromSerializedDict] entityName:[[property destinationEntity] name]];
                        //[setObject setValue:[self referenceObjectForObjectID:propertyValueFromSerializedDict] forKey:[setObject primaryKeyField]];
                        [cacheObject setValue:setObject forKey:propertyName];
                    }
                } else {
                    [cacheObject setValue:nil forKey:propertyName];
                }
                
            }];
            
            return object;
            
        }];
        
        // Save LC if has changes
        NSError *cacheError = nil;
        if ([self.localManagedObjectContext hasChanges]) {
            BOOL localCacheSaveSuccess = [self.localManagedObjectContext save:&cacheError];
            if (!localCacheSaveSuccess) {
                *error = (__bridge id)(__bridge_retained CFTypeRef)cacheError;
                return nil;
            }
        }
        
        return results;
        
    } else {
        // if we are offline,
        
        //perform fetch request on LC,
        NSArray *localCacheResults = [self.localManagedObjectContext executeFetchRequest:fetchRequest error:error];
       
        //transfer results to current context,
        NSString *primaryKeyField = nil;
        @try {
            primaryKeyField = [fetchRequest.entity primaryKeyField];
        }
        @catch (NSException *exception) {
            primaryKeyField = [self.smDataStore.session userPrimaryKeyField];
        }
        
        NSArray *results = [localCacheResults map:^id(id item) {
            id remoteID = [item valueForKey:primaryKeyField];
            if (!remoteID) {
                [NSException raise:SMExceptionIncompatibleObject format:@"No key for supposed primary key field %@ for item %@", primaryKeyField, item];
            }
            NSManagedObjectID *oid = [self newObjectIDForEntity:fetchRequest.entity referenceObject:remoteID];
            
            // Allows us to always return object, faulted or not
            NSManagedObject *object = [context objectWithID:oid];
            
            return object;
        }];
        
        //return
        return results;
        
    }
}

- (NSManagedObject *)getCacheObjectForRemoteID:(NSString *)remoteID entityName:(NSString *)entityName {
    
    NSManagedObject *cacheObject = nil;
    NSString *cacheReferenceId = [[NSUserDefaults standardUserDefaults] objectForKey:remoteID];
    if (cacheReferenceId) {
        NSManagedObjectID *cacheObjectId = [[self localPersistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:cacheReferenceId]];
        // consider registeredWithId?
        cacheObject = [self.localManagedObjectContext objectWithID:cacheObjectId];
    } else {
        cacheObject = [NSEntityDescription insertNewObjectForEntityForName:entityName inManagedObjectContext:self.localManagedObjectContext];
        NSError *idError = nil;
        [self.localManagedObjectContext obtainPermanentIDsForObjects:[NSArray arrayWithObject:cacheObject] error:&idError];
        // TODO an error check for obtainID
        
        [[NSUserDefaults standardUserDefaults] setObject:[[[cacheObject objectID] URIRepresentation] absoluteString] forKey:remoteID];
    }

    return cacheObject;
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
 
 This method is used in 2 scenarios: When an object is fulfilling a fault, and before a save on updated objects to grab a copy from the server for merge conflict purposes.
 */
- (NSIncrementalStoreNode *)newValuesForObjectWithID:(NSManagedObjectID *)objectID
                                         withContext:(NSManagedObjectContext *)context 
                                               error:(NSError *__autoreleasing *)error {
    
    if (SM_CORE_DATA_DEBUG) { DLog(@"new values for object with id %@", [context objectWithID:objectID]); }
    
    __block NSManagedObject *theObj = [context objectWithID:objectID];
    __block NSString *objStringId = [self referenceObjectForObjectID:objectID];
    
    // Is the object is fulfilling a fault, it has been fetched an placed in the local cache - grab values from there
    if ([theObj isFault]) {
        NSString *cacheReferenceId = [[NSUserDefaults standardUserDefaults] objectForKey:objStringId];
        NSManagedObjectID *cacheObjectId = [[self localPersistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:cacheReferenceId]];
    
        if (!cacheObjectId) {
            if (NULL != error) {
                *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorCacheIDNotFound userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"No cache ID was found for the provided object ID: %@", objectID], NSLocalizedDescriptionKey, nil]];
                *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
            }
            return nil;
        }
        
        // Pull object from cache
        NSManagedObject *objectFromCache = [self.localManagedObjectContext objectRegisteredForID:cacheObjectId];
        
        if (!objectFromCache) {
            
        }
        
        // Create dictionary of keys and values for incremental store node
        NSMutableDictionary *dictionaryOfObject = [NSMutableDictionary dictionary];
        
        [[objectFromCache dictionaryWithValuesForKeys:[[[objectFromCache entity] attributesByName] allKeys]] enumerateKeysAndObjectsUsingBlock:^(id attributeName, id attributeValue, BOOL *stop) {
            if (attributeValue != [NSNull null]) {
                [dictionaryOfObject setObject:attributeValue forKey:attributeName];
            }
        }];
        
        NSIncrementalStoreNode *node = [[NSIncrementalStoreNode alloc] initWithObjectID:objectID withValues:dictionaryOfObject version:1];
        
        return node;
    }
    
    // If the object is not faulted, a call to save has been made and we need to retreive an up-to-date copy from the server.
    
    // If the network is not reachable, error and return
    if ([self.smDataStore.session.networkMonitor currentNetworkStatus] != Reachable) {
        if (NULL != error) {
            *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The network is not reachable", NSLocalizedDescriptionKey, nil]];
            *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
        }
        return nil;
    }
    
    __block NSEntityDescription *objEntity = [theObj entity];
    __block NSString *schemaName = [[objEntity name] lowercaseString];
    __block BOOL success = NO;
    __block NSDictionary *objectFields;
    
    syncWithSemaphore(^(dispatch_semaphore_t semaphore) {
        [self.smDataStore readObjectWithId:objStringId inSchema:schemaName onSuccess:^(NSDictionary *theObject, NSString *schema) {
            objectFields = [self sm_responseSerializationForDictionary:theObject schemaEntityDescription:objEntity managedObjectContext:context forFetchRequest:NO];
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
    __block NSString *objStringId = [self referenceObjectForObjectID:objectID];
    
    // Is the object is fulfilling a fault, it has been fetched an placed in the local cache - grab values from there
    if ([theObj isFault]) {
        NSString *cacheReferenceId = [[NSUserDefaults standardUserDefaults] objectForKey:objStringId];
        NSManagedObjectID *cacheObjectId = [[self localPersistentStoreCoordinator] managedObjectIDForURIRepresentation:[NSURL URLWithString:cacheReferenceId]];
        
        if (!cacheObjectId) {
            if (NULL != error) {
                *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorCacheIDNotFound userInfo:[NSDictionary dictionaryWithObjectsAndKeys:[NSString stringWithFormat:@"No cache ID was found for the provided object ID: %@", objectID], NSLocalizedDescriptionKey, nil]];
                *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
            }
            return nil;
        }
        
        // Pull object from cache
        NSManagedObject *objectFromCache = [self.localManagedObjectContext objectWithID:cacheObjectId];
        
        // Get primary key field of relationship
        NSString *primaryKeyField = nil;
        @try {
            primaryKeyField = [[relationship destinationEntity] primaryKeyField];
        }
        @catch (NSException *exception) {
            primaryKeyField = [self.smDataStore.session userPrimaryKeyField];
        }
        
        if ([relationship isToMany]) {
            
        } else {
            // to-one: pull related object from cache
            // relationship value should be the cache object reference for the related objecdt
            NSManagedObject *relationshipValue = [objectFromCache valueForKey:[relationship name]];
            if (!relationshipValue) {
                return [NSNull null];
            } else {
                // get remoteID for object in context
                id relatedObjectRemoteID = [relationshipValue valueForKey:primaryKeyField];
                
                // TODO if there is no primary key id, this was just a reference and we need to retreive online, if possible
                if (!relatedObjectRemoteID) {
                    NSLog(@"fix this");
                }
                
                // TODO otherwise, use relatedObjectRemoteID to create MOID return it
                NSManagedObjectID *oid = [self newObjectIDForEntity:[relationship destinationEntity] referenceObject:relatedObjectRemoteID];
                
                // TODO investigate object that is returned, possibly use objectREgistered and error is object is nil
                NSManagedObject *object = [context objectWithID:oid];
                NSLog(@"object is %@", object);
                
                
                return oid;
            }
        }
    }
    
    // If the object is not faulted, a call to save has been made and we need to retreive an up-to-date copy from the server.
    
    // If the network is not reachable, error and return
    if ([self.smDataStore.session.networkMonitor currentNetworkStatus] != Reachable) {
        if (NULL != error) {
            *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorNetworkNotReachable userInfo:[NSDictionary dictionaryWithObjectsAndKeys:@"The network is not reachable", NSLocalizedDescriptionKey, nil]];
            *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
        }
        return nil;
    }
    
    
    __block NSEntityDescription *objEntity = [theObj entity];
    __block NSString *schemaName = [[objEntity name] lowercaseString];
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

#pragma mark - Local Cache

- (void)configureCache
{
    _localManagedObjectModel = self.localManagedObjectModel;
    _localManagedObjectContext = self.localManagedObjectContext;
    _localPersistentStoreCoordinator = self.localPersistentStoreCoordinator;
    
}

- (NSManagedObjectModel *)localManagedObjectModel
{
    if (_localManagedObjectModel == nil) {
        _localManagedObjectModel = self.persistentStoreCoordinator.managedObjectModel;
    }
    
    return _localManagedObjectModel;
}

- (NSManagedObjectContext *)localManagedObjectContext
{
    if (_localManagedObjectContext == nil) {
        _localManagedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_localManagedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_localManagedObjectContext setPersistentStoreCoordinator:self.localPersistentStoreCoordinator];
    }
    
    return _localManagedObjectContext;
    
}

- (NSPersistentStoreCoordinator *)localPersistentStoreCoordinator
{
    if (_localPersistentStoreCoordinator == nil) {
        
        _localPersistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.localManagedObjectModel];
        
        NSURL *storeURL = [self getStoreURL];
        [self createStoreURLPathIfNeeded:storeURL];
        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
        
        NSError *error = nil;
        [_localPersistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType configuration:nil URL:storeURL options:options error:&error];
        
        if (error != nil) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating sqlite persistent store: %@", error];
        }
        
    }
    
    return _localPersistentStoreCoordinator;
}

- (NSURL *)getStoreURL
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *applicationDocumentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
    
    NSString *defaultName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(id)kCFBundleNameKey];
    if (defaultName == nil)
    {
        defaultName = @"CoreDataStore";
    }
    if (![defaultName hasSuffix:@"sqlite"])
    {
        defaultName = [defaultName stringByAppendingPathExtension:@"sqlite"];
    }
    
    NSArray *paths = [NSArray arrayWithObjects:applicationDocumentsDirectory, applicationStorageDirectory, nil];
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    
    for (NSString *path in paths)
    {
        NSString *filepath = [path stringByAppendingPathComponent:defaultName];
        if ([fm fileExistsAtPath:filepath])
        {
            return [NSURL fileURLWithPath:filepath];
        }
        
    }
    
    return [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
}

- (void)createStoreURLPathIfNeeded:(NSURL *)storeURL
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    NSURL *pathToStore = [storeURL URLByDeletingLastPathComponent];
    
    NSError *error = nil;
    BOOL pathWasCreated = [fileManager createDirectoryAtPath:[pathToStore path] withIntermediateDirectories:YES attributes:nil error:&error];
    
    if (!pathWasCreated) {
        [NSException raise:SMExceptionAddPersistentStore format:@"Error creating sqlite persistent store: %@", error];
    }
    
}

#pragma mark - Internal Methods

/*
 Returns a dictionary that has extra fields from StackMob that aren't present as attributes or relationships in the Core Data representation stripped out.  Examples may be StackMob added createddate or lastmoddate.
 
 Used for newValuesForObjectWithID:.
 */
- (NSDictionary *)sm_responseSerializationForDictionary:(NSDictionary *)theObject schemaEntityDescription:(NSEntityDescription *)entityDescription managedObjectContext:(NSManagedObjectContext *)context forFetchRequest:(BOOL)forFetchRequest
{
    if (SM_CORE_DATA_DEBUG) {DLog()};
    
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
                } else if (forFetchRequest && [relationshipDescription isToMany]) {
                    // to many relationship
                    if (![relationshipContents isKindOfClass:[NSArray class]]) {
                        [NSException raise:SMExceptionIncompatibleObject format:@"Relationship contents should be an array for a to-many relationship. The relationship passed has contents that are of class type %@. Confirm that this relationship was meant to be to-many.", [relationshipContents class]];
                    }
                    NSMutableArray *relatedObjects = [NSMutableArray array];
                    [(NSSet *)relationshipContents enumerateObjectsUsingBlock:^(id stringIdReference, BOOL *stopEnumOfRelatedObjects) {
                        NSManagedObjectID *relationshipObjectID = [self newObjectIDForEntity:[relationshipDescription destinationEntity] referenceObject:stringIdReference];
                        [relatedObjects addObject:relationshipObjectID];
                    }];
                    [serializedDictionary setObject:[NSSet setWithArray:relatedObjects] forKey:propertyName];
                }
            }
        }       
    }];
    
    return serializedDictionary;
}

- (void)populateCacheManagedObject:(NSManagedObject **)object withItem:(NSDictionary *)item fetchRequest:(NSFetchRequest *)fetchRequest context:(NSManagedObjectContext *)context
{
    if (SM_CORE_DATA_DEBUG) {DLog()};
    
    NSDictionary *serializedDict = [self sm_responseSerializationForDictionary:item schemaEntityDescription:fetchRequest.entity managedObjectContext:context forFetchRequest:YES];
    [[fetchRequest.entity propertiesByName] enumerateKeysAndObjectsUsingBlock:^(id propertyName, id property, BOOL *stop) {
        id propertyValueFromSerializedDict = [serializedDict objectForKey:propertyName];
        if (propertyValueFromSerializedDict) {
            [*object setValue:propertyValueFromSerializedDict forKey:propertyName];
        } else {
            if ([property isKindOfClass:[NSRelationshipDescription class]] && [(NSRelationshipDescription *)property isToMany]) {
                [*object setValue:[NSSet set] forKey:propertyName];
            } else {
                [*object setValue:nil forKey:propertyName];
            }
        }
    }];
}


/*
 Temporary method which replaces internal data of fetched objects with any changes made to objects on the server
 */
- (void)populateManagedObject:(NSManagedObject *)object withItem:(NSDictionary *)item fetchRequest:(NSFetchRequest *)fetchRequest context:(NSManagedObjectContext *)context
{
    if (SM_CORE_DATA_DEBUG) {DLog()};
    
    NSDictionary *serializedDict = [self sm_responseSerializationForDictionary:item schemaEntityDescription:fetchRequest.entity managedObjectContext:context forFetchRequest:YES];
    for (NSString *field in [serializedDict allKeys]) {
        if ([[[fetchRequest.entity attributesByName] allKeys] indexOfObject:field] != NSNotFound) {
            [object setPrimitiveValue:serializedDict[field] forKey:field];
        } else if ([[[fetchRequest.entity relationshipsByName] allKeys] indexOfObject:field] != NSNotFound) {
            NSRelationshipDescription *relationshipDescription = (NSRelationshipDescription *)[[fetchRequest.entity relationshipsByName] objectForKey:field];
            // handle to-many
            if ([relationshipDescription isToMany]) {
                NSMutableSet *relatedObjects = [[object primitiveValueForKey:field] mutableCopy];
                if (relatedObjects != nil) {
                    [relatedObjects removeAllObjects];
                    [object setPrimitiveValue:serializedDict[field] forKey:field];
                }
            } else {
                // handle to-one
                [object setPrimitiveValue:[context objectWithID:serializedDict[field]]  forKey:field];
            }
            
        }
    }
}

- (BOOL)addPasswordToSerializedDictionary:(NSDictionary **)originalDictionary originalObject:(SMUserManagedObject *)object
{
    if (SM_CORE_DATA_DEBUG) {DLog()};
    
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
