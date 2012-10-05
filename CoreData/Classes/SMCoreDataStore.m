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

@interface SMCoreDataStore ()

@property(nonatomic, readwrite, strong)NSManagedObjectModel *managedObjectModel;

- (NSURL *)getStoreURL;
- (void)createStoreURLPathIfNeeded:(NSURL *)storeURL;

@end

@implementation SMCoreDataStore

@synthesize persistentStoreCoordinator = _persistentStoreCoordinator;
@synthesize managedObjectModel = _managedObjectModel;
@synthesize managedObjectContext = _managedObjectContext;

- (id)initWithAPIVersion:(NSString *)apiVersion session:(SMUserSession *)session managedObjectModel:(NSManagedObjectModel *)managedObjectModel
{
    self = [super initWithAPIVersion:apiVersion session:session];
    if (self) {
        _managedObjectModel = managedObjectModel;
    }
    
    return self;
}

- (NSPersistentStoreCoordinator *)persistentStoreCoordinator
{
    if (_persistentStoreCoordinator == nil) {
        [NSPersistentStoreCoordinator registerStoreClass:[SMIncrementalStore class] forStoreType:SMIncrementalStoreType];
        
        _persistentStoreCoordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:self.managedObjectModel];
        
        NSError *error = nil;
        [_persistentStoreCoordinator addPersistentStoreWithType:SMIncrementalStoreType
                                   configuration:nil 
                                             URL:nil
                                            options:[NSDictionary dictionaryWithObject:self forKey:SM_DataStoreKey] 
                                           error:&error];
        if (error != nil) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating incremental persistent store: %@", error];
        }
        
        /*
        NSURL *storeURL = [self getStoreURL];
        [self createStoreURLPathIfNeeded:storeURL];
        
        NSDictionary *options = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithBool:YES], NSMigratePersistentStoresAutomaticallyOption, [NSNumber numberWithBool:YES], NSInferMappingModelAutomaticallyOption, nil];
        
        error = nil;
        [_persistentStoreCoordinator addPersistentStoreWithType:NSSQLiteStoreType
                                                  configuration:nil
                                                            URL:storeURL
                                                        options:options
                                                          error:&error];
        if (error != nil) {
            [NSException raise:SMExceptionAddPersistentStore format:@"Error creating sqlite persistent store: %@", error];
        }
         */
        
    }
    
    return _persistentStoreCoordinator;
    
}

- (NSManagedObjectContext *)managedObjectContext
{
    if (_managedObjectContext == nil) {
        _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [_managedObjectContext setPersistentStoreCoordinator:self.persistentStoreCoordinator];
    }
    return _managedObjectContext;
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

@end

