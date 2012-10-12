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

#import <CoreData/CoreData.h>

/**
 Inherit from SMUserManagedObject when your Managed Object subclass is defining a user object.
 
 This class provides a method to securly set a password for the user object, without directly setting any attributes in Core Data.  When a save call is made to Core Data, the password is persisted along with the object to StackMob.
 */
@interface SMUserManagedObject : NSManagedObject

/**
 @param password The password associated with the user object to be used for authentication.
 */
- (void)setPassword:(NSString *)password;

- (NSString *)passwordIdentifier;

@end
