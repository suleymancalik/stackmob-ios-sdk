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
#import "SMModel.h"
#import "SMError.h"
#import "NSEntityDescription+StackMobSerialization.h"

@implementation NSManagedObject (StackMobSerialization)

- (NSString *)sm_schema
{
    return [[self entity] sm_schema];
}

- (NSString *)sm_objectId
{
    NSString *objectIdField = [self sm_primaryKeyField];
    if ([[[self entity] attributesByName] objectForKey:objectIdField] == nil) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Unable to locate a primary key field for %@, expected %@ or the return value from +(NSString *)primaryKeyFieldName if adopting the SMModel protocol.", [self description], objectIdField];
    }
    return [self valueForKey:objectIdField];
}

- (NSString *)sm_assignObjectId
{    
    id objectId = nil;
    CFUUIDRef uuid = CFUUIDCreate(CFAllocatorGetDefault());
    objectId = (__bridge_transfer NSString *)CFUUIDCreateString(CFAllocatorGetDefault(), uuid);
    [self setValue:objectId forKey:[self sm_primaryKeyField]];
    CFRelease(uuid);
    return objectId;
}

- (NSString *)sm_primaryKeyField
{
    NSString *objectIdField = nil;
    
    // Search for SMModel protocol
    if ([self conformsToProtocol:@protocol(SMModel)]) {
        objectIdField = [(id <SMModel>)[self class] primaryKeyFieldName];
        return objectIdField;
    }
    
    
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
    [NSException raise:SMExceptionIncompatibleObject format:@"No Primary Key Field found for entity %@ which matches the following format: <lowercase_entity_name>Id or <lowercase_entity_name>_id.  If you adopt the SMModel protocol, you may return either of those formats or any lowercase string with optional underscores that matches the primary key field on StackMob.", [[self entity] name]];
    return nil;
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
    [selfEntity.propertiesByName enumerateKeysAndObjectsUsingBlock:^(id propertyName, id property, BOOL *stopPropEnum) {
        if ([property isKindOfClass:[NSAttributeDescription class]]) {
            NSAttributeDescription *attributeDescription = (NSAttributeDescription *)property;
            if (attributeDescription.attributeType != NSUndefinedAttributeType) {
                if (attributeDescription.attributeType == NSDateAttributeType) {
                    NSDate *dateValue = [self valueForKey:(NSString *)propertyName];
                    if (dateValue != nil) {
                        double convertedDate = [dateValue timeIntervalSince1970];
                        [objectDictionary setObject:[NSNumber numberWithInt:convertedDate] forKey:[selfEntity sm_fieldNameForProperty:property]];
                    }
                } else {
                    id value = [self valueForKey:(NSString *)propertyName];
                    // do not support [NSNull null] values yet
                    // if (value == nil) { value = [NSNull null]; }
                    if (value != nil) {
                        [objectDictionary setObject:value forKey:[selfEntity sm_fieldNameForProperty:property]];
                    }
                }
            }
        }
        else if ([property isKindOfClass:[NSRelationshipDescription class]]) {
            NSRelationshipDescription *relationship = (NSRelationshipDescription *)property;
            
            // get the relationship contents for the property
            id relationshipContents = [self valueForKey:propertyName];
            
            // to-many relationship
            if ([relationship isToMany]) {
                if ([relationshipContents count] > 0) {
                    NSMutableArray *relatedObjectDictionaries = [NSMutableArray array];
                    [(NSSet *)relationshipContents enumerateObjectsUsingBlock:^(id child, BOOL *stopRelEnum) {
                        NSString *childObjectId = [child sm_objectId];
                        if (childObjectId == nil) {
                            *stopRelEnum = YES;
                            [NSException raise:SMExceptionIncompatibleObject format:@"Trying to serialize an object with a to-many relationship whose value references an object with a nil value for it's primary key field.  Please make sure you assign object ids with sm_assignObjectId before attaching to relationships.  The object in question is %@", [child description]];
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
                }
            } else { 
                if (relationshipContents) {
                    if ([processedObjects containsObject:relationshipContents]) {
                        // add relationship header
                        NSMutableString *relationshipKeyPath = [NSMutableString string];
                        if (keyPath && [keyPath length] > 0) {
                            [relationshipKeyPath appendFormat:@"%@.", keyPath];
                        }
                        [relationshipKeyPath appendString:[selfEntity sm_fieldNameForProperty:relationship]];
                        
                        [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] sm_schema]]];
                        
                        [objectDictionary setObject:[NSDictionary dictionaryWithObject:[relationshipContents sm_objectId] forKey:[relationshipContents sm_primaryKeyField]] forKey:[selfEntity sm_fieldNameForProperty:property]];
                    }
                    else {
                        NSMutableString *relationshipKeyPath = [NSMutableString string];
                        if (keyPath && [keyPath length] > 0) {
                            [relationshipKeyPath appendFormat:@"%@.", keyPath];
                        }
                        [relationshipKeyPath appendString:[selfEntity sm_fieldNameForProperty:relationship]];
                        
                        [*values addObject:[NSString stringWithFormat:@"%@=%@", relationshipKeyPath, [[relationship destinationEntity] sm_schema]]];
                        
                        [objectDictionary setObject:[relationshipContents sm_dictionarySerializationByTraversingRelationshipsExcludingObjects:processedObjects entities:processedEntities relationshipHeaderValues:values relationshipKeyPath:relationshipKeyPath] forKey:[selfEntity sm_fieldNameForProperty:property]];
                    }
                }
            }
        }
    }];
    
    return objectDictionary;
}
@end
