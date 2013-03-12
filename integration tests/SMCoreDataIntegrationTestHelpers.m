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

#import "SMCoreDataIntegrationTestHelpers.h"
#import "SMIncrementalStore.h"
#import "SMIntegrationTestHelpers.h"

static SMCoreDataIntegrationTestHelpers *_singletonInstance;

@interface SMCoreDataIntegrationTestHelpers ()

+ (SMCoreDataIntegrationTestHelpers *)singleton;

@end

@implementation SMCoreDataIntegrationTestHelpers

@synthesize stackMobMOM = _stackMobMOM;
@synthesize stackMobPSC = _stackMobPSC;
@synthesize stackMobMOC = _stackMobMOC;
@synthesize client = _client;

+ (NSURL *)SM_getStoreURLForCacheMapTableWithPublicKey:(NSString *)publicKey
{
    
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *applicationDocumentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
    
    NSString *defaultName = [NSString stringWithFormat:@"%@-CacheMap.plist", publicKey];
    
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
    
    NSURL *aURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
    return aURL;
}

+ (NSURL *)SM_getStoreURLForDirtyQueueTableWithPublicKey:(NSString *)publicKey
{
    
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *applicationDocumentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
    
    NSString *defaultName = [NSString stringWithFormat:@"%@-DirtyQueue.plist", publicKey];
    
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
    
    NSURL *aURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
    return aURL;
}

+ (NSDictionary *)getContentsOfFileAtPath:(NSString *)path
{
    NSString *errorDesc = nil;
    NSPropertyListFormat format;
    if ([[NSFileManager defaultManager] fileExistsAtPath:path]) {
        NSData *plistXML = [[NSFileManager defaultManager] contentsAtPath:path];
        NSDictionary *temp = (NSDictionary *)[NSPropertyListSerialization
                                              propertyListFromData:plistXML
                                              mutabilityOption:NSPropertyListMutableContainersAndLeaves
                                              format:&format
                                              errorDescription:&errorDesc];
        
        if (!temp) {
            [NSException raise:SMExceptionCacheError format:@"Error reading cachemap: %@, format: %d", errorDesc, format];
        } else {
            return [temp mutableCopy];
        }
    }
    
    return nil;
}

+ (SMCoreDataIntegrationTestHelpers *)singleton {
    if (_singletonInstance == nil) {
        _singletonInstance = [[SMCoreDataIntegrationTestHelpers alloc] init];
    }
    return _singletonInstance;
}

+ (void)removeSQLiteDatabaseAndMapsWithPublicKey:(NSString *)publicKey
{
    NSString *applicationName = [[[NSBundle mainBundle] infoDictionary] valueForKey:(NSString *)kCFBundleNameKey];
    NSString *applicationStorageDirectory = [[NSSearchPathForDirectoriesInDomains(NSApplicationSupportDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:applicationName];
    NSString *defaultName = [NSString stringWithFormat:@"%@-CoreDataStore.sqlite", publicKey];
    NSURL *sqliteDBURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    if ([fileManager fileExistsAtPath:[sqliteDBURL path]]) {
        NSError *sqliteDeleteError = nil;
        BOOL sqliteDelete = [fileManager removeItemAtURL:sqliteDBURL error:&sqliteDeleteError];
        if (!sqliteDelete) {
            [NSException raise:@"SMCouldNotDeleteSQLiteDatabase" format:@""];
        }
    }
    
    defaultName = [NSString stringWithFormat:@"%@-UserIdentifierMap.plist", publicKey];
    NSURL *aURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
    if ([fileManager fileExistsAtPath:[aURL path]]) {
        NSError *sqliteDeleteError = nil;
        BOOL sqliteDelete = [fileManager removeItemAtURL:aURL error:&sqliteDeleteError];
        if (!sqliteDelete) {
            [NSException raise:@"SMCouldNotDeleteUserIdentifierMap" format:@""];
        }
    }
    
    defaultName = [NSString stringWithFormat:@"%@-CacheMap.plist", publicKey];
    aURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
    if ([fileManager fileExistsAtPath:[aURL path]]) {
        NSError *sqliteDeleteError = nil;
        BOOL sqliteDelete = [fileManager removeItemAtURL:aURL error:&sqliteDeleteError];
        if (!sqliteDelete) {
            [NSException raise:@"SMCouldNotDeleteCacheMap" format:@""];
        }
    }
    
    defaultName = [NSString stringWithFormat:@"%@-DirtyQueue.plist", publicKey];
    aURL = [NSURL fileURLWithPath:[applicationStorageDirectory stringByAppendingPathComponent:defaultName]];
    if ([fileManager fileExistsAtPath:[aURL path]]) {
        NSError *sqliteDeleteError = nil;
        BOOL sqliteDelete = [fileManager removeItemAtURL:aURL error:&sqliteDeleteError];
        if (!sqliteDelete) {
            [NSException raise:@"SMCouldNotDeleteDirtyQueueMap" format:@""];
        }
    }
}

+ (NSManagedObjectContext *)moc {
    return [[SMCoreDataIntegrationTestHelpers singleton] stackMobMOC];
}

+ (NSEntityDescription *)entityForName:(NSString *)entityName {
    NSManagedObjectContext *moc = [SMCoreDataIntegrationTestHelpers moc];
    NSEntityDescription *entity = [NSEntityDescription entityForName:entityName inManagedObjectContext:moc];
    NSAssert(entity != nil, @"Entity names are case-sensitive, also, check the .xcdatamodeld");
    return entity;
}

+ (NSFetchRequest *)makePersonFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc {
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Person" inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"last_name" ascending:YES]]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    return fetchRequest;
}

+ (NSFetchRequest *)makeFavoriteFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc {
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Favorite" inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"genre" ascending:YES]]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    return fetchRequest;
}

+ (NSFetchRequest *)makeInterestFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc {
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Interest" inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    return fetchRequest;
}

+ (NSFetchRequest *)makeSuperpowerFetchRequest:(NSPredicate *)predicate context:(NSManagedObjectContext *)moc {
    NSEntityDescription *entity = [NSEntityDescription entityForName:@"Superpower" inManagedObjectContext:moc];
    NSFetchRequest *fetchRequest = [[NSFetchRequest alloc] init];
    [fetchRequest setEntity:entity];
    [fetchRequest setPredicate:predicate];
    [fetchRequest setSortDescriptors:[NSArray arrayWithObject:[NSSortDescriptor sortDescriptorWithKey:@"name" ascending:YES]]];
    [fetchRequest setReturnsObjectsAsFaults:NO];
    [fetchRequest setRelationshipKeyPathsForPrefetching:[NSArray arrayWithObject:@"person"]];
    return fetchRequest;
}

+ (void)executeSynchronousFetch:(NSManagedObjectContext *)moc withRequest:(NSFetchRequest *)fetchRequest andBlock:(SynchronousFetchBlock)block {
    DLog()
    NSError *error = nil;
    NSArray *results = [moc executeFetchRequestAndWait:fetchRequest error:&error];
    block(results, error);
}

+ (void)executeSynchronousSave:(NSManagedObjectContext *)moc withBlock:(SynchronousErrorBlock)block {
    DLog()
    NSError *anError = nil;
    BOOL saveSuccess = [moc saveAndWait:&anError];
    
    if (!saveSuccess) {
        DLog(@"save error is %@", [anError description]);
    }
    block(anError);
}

+ (void)executeSynchronousUpdate:(NSManagedObjectContext *)moc withObject:(NSManagedObjectID *)objectID andBlock:(SynchronousErrorBlock)block {
    DLog()
    NSError *__autoreleasing anError = nil;
    NSManagedObject *toUpdate = [moc objectWithID:objectID];
    [toUpdate setValue:[NSNumber numberWithInt:20] forKey:@"armor_class"];
    BOOL success = [moc saveAndWait:&anError];
    if (!success) {
        DLog(@"save error is %@", [anError description]);
    }
    block(anError);
    
}

+ (void)executeSynchronousDelete:(NSManagedObjectContext *)moc withObject:(NSManagedObjectID *)objectID andBlock:(SynchronousErrorBlock)block {
    DLog()
    NSError *__autoreleasing anError = nil;
    NSManagedObject *toDelete = [moc objectWithID:objectID];
    [moc deleteObject:toDelete];
    BOOL success = [moc saveAndWait:&anError];
    if (!success) {
        DLog(@"save error is %@", [anError description]);
    }
    block(anError);

}




+ (void)registerForMOCNotificationsWithContext:(NSManagedObjectContext *)context
{
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(MOCDidChange:) name:NSManagedObjectContextObjectsDidChangeNotification object:context];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(MOCWillSave:) name:NSManagedObjectContextWillSaveNotification object:context];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(MOCDidSave:) name:NSManagedObjectContextDidSaveNotification object:context];
}

+ (void)removeObserversrForMOCNotificationsWithContext:(NSManagedObjectContext *)context
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextObjectsDidChangeNotification object:context];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextWillSaveNotification object:context];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:NSManagedObjectContextDidSaveNotification object:context];
}

+ (void)MOCDidChange:(NSNotification *)notification
{
    //DLog(@"MOCDidChange user info is %@", [notification userInfo]);
}

+ (void)MOCWillSave:(NSNotification *)notification
{
    //DLog(@"MOCWillSave user info is %@", [notification userInfo]);
}

+ (void)MOCDidSave:(NSNotification *)notification
{
    //DLog(@"MOCDidSave user info is %@", [notification userInfo]);
}

- (NSManagedObjectModel *)stackMobMOM {
    if (_stackMobMOM == nil) {
        _stackMobMOM = [NSManagedObjectModel mergedModelFromBundles:[NSBundle allBundles]];
    }
    return _stackMobMOM;
}

- (NSPersistentStoreCoordinator *)stackMobPSC {
    if (_stackMobPSC == nil) {
        self.client = [SMIntegrationTestHelpers defaultClient];
        [NSPersistentStoreCoordinator registerStoreClass:[SMIncrementalStore class] forStoreType:SMIncrementalStoreType];
        _stackMobPSC = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.stackMobMOM];
        NSError *error;
        
        [_stackMobPSC addPersistentStoreWithType:SMIncrementalStoreType
                                   configuration:nil 
                                             URL:nil
                                         options:[NSDictionary dictionaryWithObject:self.client.dataStore forKey:SM_DataStoreKey]
                                           error:&error];
        if (error != nil) {
            DLog(@"Error: %@", error);
            abort();
        }
    }
    return _stackMobPSC;
}

- (NSManagedObjectContext *)stackMobMOC {
    if (_stackMobMOC == nil) {
        _stackMobMOC = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_stackMobMOC setMergePolicy:NSMergeByPropertyObjectTrumpMergePolicy];
        [_stackMobMOC setPersistentStoreCoordinator:self.stackMobPSC];
    }
    return _stackMobMOC;
}


@end
