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

#import "SMDataStore.h"

extern NSString *const SMEnableCacheNotification;
extern NSString *const SMDisableCacheNotification;
extern NSString *const SMCacheWasEnabledNotification;
extern NSString *const SMCacheWasDisabledNotification;

@class SMIncrementalStore;

/**
 The `SMCoreDataStore` class provides all the necessary properties and methods to interact with StackMob's Core Data integration.
 
 ## Using SMCoreDataStore ##
 
 With your `SMCoreDataStore` object you can retrieve a managed object context configured with a `SMIncrementalStore` as it's persistent store to allow communication to StackMob from Core Data.  Obtain a managed object context for your thread using <contextForCurrentThread>.  You can obtain the managed object context for the main thread at any time with <mainThreadContext>.
 
 When saving or fetching from the context, use methods from the <NSManagedObjectContext+Concurrency> category to ensure proper asynchronous saving and fetching off of the main thread.
 
 If you want to do your own context creation, use the <persistentStoreCoordinator> property to ensure your objects are being saved to the StackMob server.
 
 The default merge policy set for all contexts created by this class is NSMergeByPropertyObjectTrumpMergePolicy.  Use <setDefaultMergePolicy:applyToMainThreadContextAndParent:> to change the default.
 
 @note You should not have to initialize an instance of this class directly.  Instead, initialize an instance of <SMClient> and use the method <coreDataStoreWithManagedObjectModel:> to retrieve an instance completely configured and ready to communicate to StackMob.
 */
@interface SMCoreDataStore : SMDataStore

///-------------------------------
/// @name Properties
///-------------------------------

/**
 An instance of `NSPersistentStoreCoordinator` with the `SMIncrementalStore` class as it's persistent store type.
 
 Uses the `NSManagedObjectModel` passed to the `coreDataStoreWithManagedObjectModel:` method in <SMClient>.
 */
@property(nonatomic, strong) NSPersistentStoreCoordinator *persistentStoreCoordinator;

/**
 An instance of `NSManagedObjectContext` set to use on the main thread.
 
 This managed object context has a private queue parent context set to ensure proper parent/child asynchronous saving.  The persistent store coordinator is set on the parent context. Merge policy is set to NSMergeByPropertyObjectTrumpMergePolicy.
 */
@property (nonatomic, strong) NSManagedObjectContext *mainThreadContext;

/**
 An instance of `NSManagedObjectContext` set to use on the main thread.
 
 This property is deprecated. Use <contextForCurrentThread> to obtain a properly initialized managed object context.
 */
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext __attribute__((deprecated));


///-------------------------------
/// @name Initialize
///-------------------------------

/**
 Initializes an `SMCoreDataStore`.
 
 @param apiVersion The API version of your StackMob application.
 @param session The session containing the credentials to use for requests made to StackMob by Core Data.
 @param managedObjectModel The managed object model to set to the persistent store coordinator.
 */
- (id)initWithAPIVersion:(NSString *)apiVersion session:(SMUserSession *)session managedObjectModel:(NSManagedObjectModel *)managedObjectModel;

///-------------------------------
/// @name Obtaining a Managed Object Context
///-------------------------------

/**
 Returns an initialized context for the current thread.
 
 Merge policy is set to NSMergeByPropertyObjectTrumpMergePolicy.
 
 If the current thread is the main thread, returns a context initialized with a NSMainQueueConcurrencyType.  Otherwise, returns a context initialized with a NSPrivateQueueConcurrencyType, with the mainThreadContext as its parent.
 
 */
- (NSManagedObjectContext *)contextForCurrentThread;

/**
 Sets the merge policy that is set by default to any context returned from <contextForCurrentThread>.
 
 If apply is YES, sets the merge policy of mainThreadContext and its private parent context to mergePolicy.
 
 @param mergePolicy The default merge policy to use going forward.
 @param apply Whether or not to set mergePolicy as the merge policy for the existing mainThreadContext and its private parent context.
 */
- (void)setDefaultMergePolicy:(id)mergePolicy applyToMainThreadContextAndParent:(BOOL)apply;

- (void)purgeCacheOfMangedObjectID:(NSManagedObjectID *)objectID onSuccess:(void (^)())successBlock onFailure:(void (^)())failureBlock;

- (void)purgeCacheOfManagedObjectsWithIDs:(NSArray *)managedObjectIDs onSuccess:(void (^)())successBlock onFailure:(void (^)())failureBlock;

- (void)purgeEntireCacheOnSuccess:(void (^)())successBlock onFailure:(void (^)())failureBlock;



@end
