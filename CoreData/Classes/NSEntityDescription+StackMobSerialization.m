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

#import "NSEntityDescription+StackMobSerialization.h"
#import "SMUserManagedObject.h"
#import "SMError.h"
#import "SMClient.h"
#import "SMDataStore.h"
#import "SMUserSession.h"

@implementation NSEntityDescription (StackMobSerialization)

- (NSString *)SMSchema
{
    if (SM_CONVERT_SCHEMA_NAMES) {
        return [[self name] lowercaseString];
    } else {
        return [self name];
    }
}

- (NSString *)SMLowercasedSchema
{
    return [[self name] lowercaseString];
}

- (NSString *)primaryKeyField
{
    NSString *objectIdField = nil;
     
    // Search for schemanameId
    objectIdField = [[self SMLowercasedSchema] stringByAppendingFormat:@"Id"];
    if ([[self propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Search for schemaname_id
    objectIdField = [[self SMLowercasedSchema] stringByAppendingFormat:@"_id"];
    if ([[self propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    
    // Raise an exception and return nil
    [NSException raise:SMExceptionIncompatibleObject format:@"No Attribute found for entity %@ which maps to the primary key on StackMob. The Attribute name should match one of the following formats: lowercasedEntityNameId or lowercasedEntityName_id.  If the managed object subclass for %@ inherits from SMUserManagedObject, meaning it is intended to define user objects, you may return either of the above formats or whatever lowercase string with optional underscores matches the primary key field on StackMob.", [self name], [self name]];
    return nil;
}

- (NSString *)SMEDPrimaryKeyFieldFromDataStore:(SMDataStore *)dataStore
{
    return [self SMEDFieldNameForProperty:[[self propertiesByName] objectForKey:[self primaryKeyField]] dataStore:dataStore];
}

- (NSString *)SMEDFieldNameForProperty:(NSPropertyDescription *)property dataStore:(SMDataStore *)dataStore
{
    NSCharacterSet *uppercaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
    NSMutableString *stringToReturn = [[property name] mutableCopy];
    
    if (!SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES) {
        if (dataStore) {
            if (![[property name] isEqualToString:[dataStore.session userPrimaryKeyField]] && ![[property name] isEqualToString:[self primaryKeyField]]) {
                return stringToReturn;
            }
        } else {
            if (![[property name] isEqualToString:[self primaryKeyField]]) {
                return stringToReturn;
            }
        }
        
    }
    
    NSRange range = [stringToReturn rangeOfCharacterFromSet:uppercaseSet];
    if (range.location == 0 && SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Property %@ cannot start with an uppercase letter.  Acceptable formats are camelCase or lowercase letters with optional underscores", [property name]];
    }
    while (range.location != NSNotFound) {
        
        unichar letter = [stringToReturn characterAtIndex:range.location] + 32;
        [stringToReturn replaceCharactersInRange:range withString:[NSString stringWithFormat:@"_%C", letter]];
        range = [stringToReturn rangeOfCharacterFromSet:uppercaseSet];
    }
    
    return stringToReturn;
}

- (NSPropertyDescription *)propertyForSMFieldName:(NSString *)fieldName dataStore:(SMDataStore *)dataStore
{
    
    // Look for matching names with all lowercase or underscores first
    NSPropertyDescription *propertyToReturn = [[self propertiesByName] objectForKey:fieldName];
    if (propertyToReturn) {
        return propertyToReturn;
    }
    
    if (!SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES && ![fieldName isEqualToString:[dataStore.session userPrimaryKeyField]] && ![fieldName isEqualToString:[self SMEDPrimaryKeyFieldFromDataStore:dataStore]]) {
        return nil;
    }
    
    // Then look for camelCase equivalents
    NSCharacterSet *underscoreSet = [NSCharacterSet characterSetWithCharactersInString:@"_"];
    NSMutableString *convertedFieldName = [fieldName mutableCopy];
    
    NSRange range = [convertedFieldName rangeOfCharacterFromSet:underscoreSet];
    while (range.location != NSNotFound) {
        
        unichar letter = [convertedFieldName characterAtIndex:(range.location + 1)] - 32;
        [convertedFieldName replaceCharactersInRange:NSMakeRange(range.location, 2) withString:[NSString stringWithFormat:@"%C", letter]];
        range = [convertedFieldName rangeOfCharacterFromSet:underscoreSet];
    }
    
    propertyToReturn = [[self propertiesByName] objectForKey:convertedFieldName];
    if (propertyToReturn) {
        return propertyToReturn;
    }
    
    // No matching properties
    return nil;
}

@end
