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
#import "SMModel.h"
#import "SMError.h"

@implementation NSEntityDescription (StackMobSerialization)

- (NSString *)sm_schema
{
    return [[self name] lowercaseString];
}

- (NSString *)sm_primaryKeyField
{
    NSString *objectIdField = nil;
    
    // Search for SMModel protocol
    id aClass = NSClassFromString([self name]);
    if (aClass != nil) {
        if ([aClass conformsToProtocol:@protocol(SMModel)]) {
            objectIdField = [(id <SMModel>)aClass primaryKeyFieldName];
            return objectIdField;
        }
    }
    
    // Search for schemanameId
    objectIdField = [[self sm_schema] stringByAppendingFormat:@"Id"];
    if ([[self propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Search for schemaname_id
    objectIdField = [[self sm_schema] stringByAppendingFormat:@"_id"];
    if ([[self propertiesByName] objectForKey:objectIdField] != nil) {
        return objectIdField;
    }
    
    // Raise an exception and return nil
    [NSException raise:SMExceptionIncompatibleObject format:@"No Primary Key Field found for entity %@ which matches the following format: <lowercase_entity_name>Id or <lowercase_entity_name>_id.  If you adopt the SMModel protocol, you may return either of those formats or any lowercase string with optional underscores that matches the primary key field on StackMob.", [self name]];
    return nil;
}

- (NSString *)sm_fieldNameForProperty:(NSPropertyDescription *)property 
{
    NSCharacterSet *uppercaseSet = [NSCharacterSet uppercaseLetterCharacterSet];
    NSMutableString *stringToReturn = [[property name] mutableCopy];
    
    NSRange range = [stringToReturn rangeOfCharacterFromSet:uppercaseSet];
    if (range.location == 0) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Property %@ cannot start with an uppercase letter.  Acceptable formats are camelCase or lowercase letters with optional underscores", [property name]];
    }
    while (range.location != NSNotFound) {
        
        unichar letter = [stringToReturn characterAtIndex:range.location] + 32;
        [stringToReturn replaceCharactersInRange:range withString:[NSString stringWithFormat:@"_%C", letter]];
        range = [stringToReturn rangeOfCharacterFromSet:uppercaseSet];
    }
    
    return stringToReturn;
}

- (NSPropertyDescription *)sm_propertyForField:(NSString *)fieldName
{
    // Look for matching names with all lowercase or underscores first
    NSPropertyDescription *propertyToReturn = [[self propertiesByName] objectForKey:fieldName];
    if (propertyToReturn) {
        return propertyToReturn;
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
