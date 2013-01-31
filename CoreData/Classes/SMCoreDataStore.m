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

#import "SMCoreDataStore.h"
#import "SMIncrementalStore.h"
#import "SMError.h"
#import "NSManagedObjectContext+Concurrency.h"

#define DLog(fmt, ...) NSLog((@"Performing %s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__);

static NSString *const SM_ManagedObjectContextKey = @"SM_ManagedObjectContextKey";
NSString *const SMSetCachePolicyNotification = @"SMSetCachePolicyNotification";
BOOL SM_CACHE_ENABLED = NO;

@interface SMCoreDataStore ()

@property(nonatomic, readwrite, strong)NSManagedObjectModel *managedObjectModel;
@property (nonatomic, strong) NSManagedObjectContext *privateContext;
@property (nonatomic, strong) id defaultMergePolicy;
@property (nonatomic) dispatch_queue_t cachePurgeQueue;

- (NSManagedObjectContext *)SM_newPrivateQueueContextWithParent:(NSManagedObjectContext *)parent;
- (void)SM_didReceiveSetCachePolicyNotification:(NSNotification *)notification;

@end

@implementation SMCoreDataStore

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;
@synthesize mainThreadContext = _mainThreadContext;
@synthesize privateContext = _privateContext;
@synthesize defaultMergePolicy = _defaultMergePolicy;
@synthesize cachePurgeQueue = _cachePurgeQueue;
@synthesize cachePolicy = _cachePolicy;

- (id)initWithAPIVersion:(NSString *)apiVersion session:(SMUserSession *)session managedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
    self = [super initWithAPIVersion:apiVersion session:session];
    if (self) {
        _managedObjectModel = managedObjectModel;
        _defaultMergePolicy = NSMergeByPropertyObjectTrumpMergePolicy;
        self.cachePurgeQueue = dispatch_queue_create("Purge Cache Of Object Queue", NULL);
        [self setCachePolicy:SMCachePolicyTryNetworkOnly];
        
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(SM_didReceiveSetCachePolicyNotification:) name:SMSetCachePolicyNotification object:self.session.networkMonitor];
    }
    
    return self;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator == nil) {
        [NSPersistentStoreCoordinator registerStoreClass:[SMIncrementalStore class] forStoreType:SMIncrementalStoreType];
        
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSError *error = nil;
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:
                                 [NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption,
                                 [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, self, SM_DataStoreKey, nil];
        [_persistentStoreCoordinator addPersistentStoreWithType:SMIncrementalStoreType
                                                  configuration:nil
                                                            URL:nil
                                                        options:options
                                                          error:&error];
        if (error != nil) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating incremental persistent store: %@", error];
        }
        
    }
    
    return _persistentStoreCoordinator;
    
}

- (NSManagedObjectContext *)privateContext
{
    if (_privateContext == nil) {
        _privateContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_privateContext setMergePolicy:self.defaultMergePolicy];
        [_privateContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _privateContext;
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_managedObjectContext setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
}

- (NSManagedObjectContext *)mainThreadContext
{
    if (_mainThreadContext == nil) {
        _mainThreadContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        [_mainThreadContext setMergePolicy:self.defaultMergePolicy];
        [_mainThreadContext setParentContext:self.privateContext];
        [_mainThreadContext setContextShouldObtainPermanentIDsBeforeSaving:YES];
    }
    return _mainThreadContext;
}

- (NSManagedObjectContext *)SM_newPrivateQueueContextWithParent:(NSManagedObjectContext *)parent
{
    NSManagedObjectContext *context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
    [context setMergePolicy:self.defaultMergePolicy];
    [context setParentContext:parent];
    [context setContextShouldObtainPermanentIDsBeforeSaving:YES];
    
    return context;
}

- (NSManagedObjectContext *)contextForCurrentThread
{
    if ([NSThread isMainThread])
	{
		return self.mainThreadContext;
	}
	else
	{
		NSMutableDictionary *threadDict = [[NSThread currentThread] threadDictionary];
		NSManagedObjectContext *threadContext = [threadDict objectForKey:SM_ManagedObjectContextKey];
		if (threadContext == nil)
		{
			threadContext = [self SM_newPrivateQueueContextWithParent:self.mainThreadContext];
			[threadDict setObject:threadContext forKey:SM_ManagedObjectContextKey];
            //[threadDict setObject:[SMRequestOptions options] forKey:SMThreadDefaultOptions];
		}
		return threadContext;
	}
}

- (void)setDefaultMergePolicy:(id)mergePolicy applyToMainThreadContextAndParent:(BOOL)apply
{
    if (mergePolicy != self.defaultMergePolicy) {
        
        self.defaultMergePolicy = mergePolicy;
        
        if (apply) {
            [self.mainThreadContext setMergePolicy:mergePolicy];
            [self.privateContext setMergePolicy:mergePolicy];
        }
    }
}

- (void)purgeCacheOfMangedObjectID:(NSManagedObjectID *)objectID
{
    dispatch_async(self.cachePurgeQueue, ^{
        NSDictionary *notificationUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:objectID, SMCachePurgeManagedObjectID, nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SMPurgeObjectFromCacheNotification object:self userInfo:notificationUserInfo];
    });
}

- (void)purgeCacheOfMangedObjects:(NSArray *)managedObjects
{
    NSMutableArray *arrayOfObjectIDs = [NSMutableArray arrayWithCapacity:[managedObjects count]];
    [managedObjects enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        [arrayOfObjectIDs addObject:[obj objectID]];
    }];
    [self purgeCacheOfManagedObjectsIDs:arrayOfObjectIDs];
}

- (void)purgeCacheOfManagedObjectsIDs:(NSArray *)managedObjectIDs
{
    dispatch_async(self.cachePurgeQueue, ^{
        NSDictionary *notificationUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:managedObjectIDs, SMCachePurgeArrayOfManageObjectIDs, nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SMPurgeObjectsFromCacheNotification object:self userInfo:notificationUserInfo];
    });
}

- (void)purgeCacheOfObjectsWithEntityName:(NSString *)entityName
{
    dispatch_async(self.cachePurgeQueue, ^{
        NSDictionary *notificationUserInfo = [NSDictionary dictionaryWithObjectsAndKeys:entityName, SMCachePurgeOfObjectsFromEntityName, nil];
        
        [[NSNotificationCenter defaultCenter] postNotificationName:SMPurgeObjectsFromCacheByEntityNotification object:self userInfo:notificationUserInfo];
    });
}

- (void)resetCache
{
    dispatch_async(self.cachePurgeQueue, ^{
        [[NSNotificationCenter defaultCenter] postNotificationName:SMResetCacheNotification object:self userInfo:nil];
    });
}

- (void)SM_didReceiveSetCachePolicyNotification:(NSNotification *)notification
{
    SMCachePolicy newCachePolicy = [[[notification userInfo] objectForKey:@"NewCachePolicy"] intValue];
    [self setCachePolicy:newCachePolicy];
}

@end

