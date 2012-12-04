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

#import "NSManagedObject+StackMobSerialization.h"
#import "SMError.h"
#import "SMUserManagedObject.h"
#import "SMError.h"
#import "NSEntityDescription+StackMobSerialization.h"

@implementation NSManagedObject (StackMobSerialization)

- (NSString *)sm_schema
{
    return [[self entity] sm_schema];
}

- (NSString *)sm_objectId
{
    NSString *objectIdField = [self primaryKeyField];
    if ([[[self entity] attributesByName] objectForKey:objectIdField] == nil) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Unable to locate a primary key field for %@, expected %@.  If this is an Entity which describes user objects, and your managed object subclass inherits from SMUserManagedObject, make sure to include an attribute that matches the value returned by your SMClient's userPrimaryKeyField property.", [self description], objectIdField];
    }
    return [self valueForKey:objectIdField];
}

- (NSString *)assignObjectId
{
    id objectId = nil;
    CFUUIDRef uuid = CFUUIDCreate(CFAllocatorGetDefault());
    objectId = (__bridge_transfer NSString *)CFUUIDCreateString(CFAllocatorGetDefault(), uuid);
    [self setValue:objectId forKey:[self primaryKeyField]];
    CFRelease(uuid);
    return objectId;
}

- (NSString *)primaryKeyField
{
    NSString *objectIdField = nil;
    
    // Search for schemanameId
    objectIdField = [[self sm_schema] stringByAppendingFormat:@"Id"];
    if ([[[self entity] propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Search for schemaname_id
    objectIdField = [[self sm_schema] stringByAppendingFormat:@"_id"];
    if ([[[self entity] propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Raise an exception and return nil
    [NSException raise:SMExceptionIncompatibleObject format:@"No Attribute found for entity %@ which maps to the primary key on StackMob. The Attribute name should match one of the following formats: lowercasedEntityNameId or lowercasedEntityName_id.  If the managed object subclass for %@ inherits from SMUserManagedObject, meaning it is intended to define user objects, you may return either of the above formats or whatever lowercase string with optional underscores matches the primary key field on StackMob.", [[self entity] name], [[self entity] name]];
    return nil;
}

- (NSString *)sm_primaryKeyField
{
    return [[self entity] sm_fieldNameForProperty:[[[self entity] propertiesByName] objectForKey:[self primaryKeyField]]];
}

- (NSDictionary *)sm_dictionarySerialization
{
    NSMutableArray *arrayOfRelationshipHeaders = [NSMutableArray array];
    NSMutableDictionary *contentsOfSerializedObject = [NSMutableDictionary dictionaryWithObject:[self sm_dictionarySerializationByTraversingRelationshipsExcludingObjects:nil entities:nil relationshipHeaderValues:&arrayOfRelationshipHeaders relationshipKeyPath:nil] forKey:@"SerializedDict"];
    
    if ([arrayOfRelationshipHeaders count] > 0) {
        
        // add array joined by & to contentsDict
        [contentsOfSerializedObject setObject:[arrayOfRelationshipHeaders componentsJoinedByString:@"&"] forKey:@"X-StackMob-Relations"];
    }
    
    return contentsOfSerializedObject;
    
}

- (NSDictionary *)sm_dictionarySerializationByTraversingRelationshipsExcludingObjects:(NSMutableSet *)processedObjects entities:(NSMutableSet *)processedEntities relationshipHeaderValues:(NSMutableArray *__autoreleasing *)values relationshipKeyPath:(NSString *)keyPath
{
    if (processedObjects == nil) {
        processedObjects = [NSMutableSet set];
    }
    if (processedEntities == nil) {
        processedEntities = [NSMutableSet set];
    }
    
    [processedObjects addObject:self];
    
    NSEntityDescription *selfEntity = [self entity];
    
    NSMutableDictionary *objectDictionary = [NSMutableDictionary dictionary];
    [self.changedValues enumerateKeysAndObjectsUsingBlock:^(id propertyKey, id propertyValue, BOOL *stop) {
        NSPropertyDescription *property = [[selfEntity propertiesByName] objectForKey:propertyKey];
        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *attributeDescription = (NSAttributeDescription *)property;
            if (attributeDescription.attributeType != NSUndefinedAttributeType) {
                if (attributeDescription.attributeType == NSDateAttributeType) {
                    NSDate *dateValue = propertyValue;
                    if (dateValue != nil) {
                        double convertedDate = [dateValue timeIntervalSince1970];
                        [objectDictionary setObject:[NSNumber numberWithInteger:convertedDate] forKey:[selfEntity sm_fieldNameForProperty:property]];
                    }
                } else if (attributeDescription.attributeType == NSBooleanAttributeType) {
                    // make sure that boolean values are serialized as true or false
                    id value = propertyValue;
                    if (value != nil) {
                        if ([value boolValue]) {
                            [objectDictionary setObject:[NSNumber numberWithBool:YES] forKey:[selfEntity sm_fieldNameForProperty:property]];
                        }
                        else {
                            [objectDictionary setObject:[NSNumber numberWithBool:NO] forKey:[selfEntity sm_fieldNameForProperty:property]];
                        }
                    }
                } else {
                    id value = propertyValue;
                    if (value != nil) {
                        [objectDictionary setObject:value forKey:[selfEntity sm_fieldNameForProperty:property]];
                    }
                }
            }
        }
        else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
            if ([relationship isToMany]) {
                NSMutableArray *relatedObjectDictionaries = [NSMutableArray array];
                [(NSSet *)propertyValue enumerateObjectsUsingBlock:^(id child, BOOL *stopRelEnum) {
                    NSString *childObjectId = [child sm_objectId];
                    if (childObjectId == nil) {
                        *stopRelEnum = YES;
                        [NSException raise:SMExceptionIncompatibleObject format:@"Trying to serialize an object with a to-many relationship whose value references an object with a nil value for it's primary key field.  Please make sure you assign object ids with assignObjectId before attaching to relationships.  The object in question is %@", [child description]];
                    }
                    [relatedObjectDictionaries addObject:[child sm_objectId]];
                }];
                
                // add relationship header only if there are actual keys
                if ([relatedObjectDictionaries count] > 0) {
                    NSMutableString *relationshipKeyPath = [NSMutableString string];
                    if (keyPath && [keyPath length] > 0) {
                        [relationshipKeyPath appendFormat:@"%@.", keyPath];
                    }
                    [relationshipKeyPath appendString:[selfEntity sm_fieldNameForProperty:relationship]];
                    
                    [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] sm_schema]]];
                }
                [objectDictionary setObject:relatedObjectDictionaries forKey:[selfEntity sm_fieldNameForProperty:property]];
            } else {
                if (propertyValue == [NSNull null]) {
                    [objectDictionary setObject:propertyValue forKey:[selfEntity sm_fieldNameForProperty:property]];
                }
                else if ([processedObjects containsObject:propertyValue]) {
                    // add relationship header
                    NSMutableString *relationshipKeyPath = [NSMutableString string];
                    if (keyPath && [keyPath length] > 0) {
                        [relationshipKeyPath appendFormat:@"%@.", keyPath];
                    }
                    [relationshipKeyPath appendString:[selfEntity sm_fieldNameForProperty:relationship]];
                    
                    [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] sm_schema]]];
                    
                    
                    NSPropertyDescription *primaryKeyProperty = [[[relationship destinationEntity] propertiesByName] objectForKey:[propertyValue primaryKeyField]];
                    [objectDictionary setObject:[NSDictionary dictionaryWithObject:[propertyValue sm_objectId] forKey:[[relationship destinationEntity] sm_fieldNameForProperty:primaryKeyProperty]] forKey:[selfEntity sm_fieldNameForProperty:property]];
                }
                else {
                    NSMutableString *relationshipKeyPath = [NSMutableString string];
                    if (keyPath && [keyPath length] > 0) {
                        [relationshipKeyPath appendFormat:@"%@.", keyPath];
                    }
                    [relationshipKeyPath appendString:[selfEntity sm_fieldNameForProperty:relationship]];
                    
                    [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] sm_schema]]];
                    
                    [objectDictionary setObject:[propertyValue sm_dictionarySerializationByTraversingRelationshipsExcludingObjects:processedObjects entities:processedEntities relationshipHeaderValues:values relationshipKeyPath:relationshipKeyPath] forKey:[selfEntity sm_fieldNameForProperty:property]];
                }
            }
        }
    }];
    
    // Add value for primary key field if needed
    NSString *primaryKeyField = [self sm_primaryKeyField];
    if (![objectDictionary valueForKey:primaryKeyField]) {
        [self attachObjectIdToDictionary:&objectDictionary];
    }
    
    
    return objectDictionary;
}

- (void)attachObjectIdToDictionary:(NSDictionary **)objectDictionary
{
    NSMutableDictionary *dictionaryToReturn = [*objectDictionary mutableCopy];
    
    [dictionaryToReturn setObject:[self sm_objectId] forKey:[self sm_primaryKeyField]];
    
    *objectDictionary = dictionaryToReturn;
}

- (id)valueForRelationshipKey:(NSString *)key error:(NSError *__autoreleasing*)error
{
    id result = nil;
    @try {
        result = [self valueForKey:key];
    }
    @catch (NSException *exception) {
        if ([exception name] == SMExceptionCannotFillRelationshipFault && NULL != error) {
            *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorCouldNotFillRelationshipFault userInfo:[NSDictionary dictionaryWithObject:[exception reason] forKey:NSLocalizedDescriptionKey]];
        }
            
            return nil;
    }
    
    return result;
    
}

@end
