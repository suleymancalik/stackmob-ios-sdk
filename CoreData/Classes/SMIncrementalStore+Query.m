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

#import "SMIncrementalStore+Query.h"
#import "NSEntityDescription+StackMobSerialization.h"
#import "SMError.h"

@implementation SMIncrementalStore (Query)

- (SMQuery *)queryForEntity:(NSEntityDescription *)entityDescription
                  predicate:(NSPredicate *)predicate
                      error:(NSError *__autoreleasing *)error {
    
    SMQuery *query = [[SMQuery alloc] initWithEntity:entityDescription];
    [self buildQuery:&query forPredicate:predicate error:error];
    
    return query;
}

- (SMQuery *)queryForFetchRequest:(NSFetchRequest *)fetchRequest
                            error:(NSError *__autoreleasing *)error {
    
    SMQuery *query = [self queryForEntity:fetchRequest.entity
                                predicate:fetchRequest.predicate
                                    error:error];
    
    if (*error != nil) {
        *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
        return nil;
    }
    
    // Limit / pagination
    
    if (fetchRequest.fetchBatchSize) { // The default is 0, which means "everything"
        [self setError:error withReason:@"NSFetchRequest fetchBatchSize not supported"];
        return nil;
    }
    
    NSUInteger fetchOffset = fetchRequest.fetchOffset;
    NSUInteger fetchLimit = fetchRequest.fetchLimit;
    NSString *rangeHeader;
    
    if (fetchOffset) {
        if (fetchLimit) {
            rangeHeader = [NSString stringWithFormat:@"objects=%i-%i", fetchOffset, fetchOffset+fetchLimit];
        } else {
            rangeHeader = [NSString stringWithFormat:@"objects=%i-", fetchOffset];
        }
        [[query requestHeaders] setValue:rangeHeader forKey:@"Range"];
    }
    
    // Ordering
    
    [fetchRequest.sortDescriptors enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        NSString *fieldName = nil;
        if ([[obj key] rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound) {
            fieldName = [self convertPredicateExpressionToStackMobFieldName:[obj key] entity:fetchRequest.entity];
        } else {
            fieldName = [obj key];
        }
        [query orderByField:fieldName ascending:[obj ascending]];
    }];
    
    return query;
}

- (NSString *)convertPredicateExpressionToStackMobFieldName:(NSString *)keyPath entity:(NSEntityDescription *)entity
{
    NSPropertyDescription *property = [[entity propertiesByName] objectForKey:keyPath];
    if (!property) {
        [NSException raise:SMExceptionIncompatibleObject format:@"Property not found for predicate field %@ in entity %@", keyPath, entity];
    }
    return [entity SMFieldNameForProperty:property];
}

- (BOOL)setError:(NSError *__autoreleasing *)error withReason:(NSString *)reason {
    NSDictionary *userInfo = [NSDictionary dictionaryWithObject:reason forKey:NSLocalizedDescriptionKey];
    if (error != NULL) {
        *error = [[NSError alloc] initWithDomain:SMErrorDomain code:SMErrorInvalidArguments userInfo:userInfo];
        *error = (__bridge id)(__bridge_retained CFTypeRef)*error;
    }
    
    return YES;
    
}

- (BOOL)buildBetweenQuery:(SMQuery *__autoreleasing *)query leftHandExpression:(id)lhs rightHandExpression:(id)rhs error:(NSError *__autoreleasing *)error
{
    if (![rhs isKindOfClass:[NSArray class]]) {
        [self setError:error withReason:@"RHS must be an NSArray"];
        return NO;
    }
    NSString *field = (NSString *)lhs;
    NSArray *range = (NSArray *)rhs;
    NSNumber *low = (NSNumber *)[range objectAtIndex:0];
    NSNumber *high = (NSNumber *)[range objectAtIndex:1];
    
    [*query where:field isGreaterThanOrEqualTo:low];
    [*query where:field isLessThanOrEqualTo:high];
    
    return YES;
}

- (BOOL)buildInQuery:(SMQuery *__autoreleasing *)query leftHandExpression:(id)lhs rightHandExpression:(id)rhs error:(NSError *__autoreleasing *)error
{
    if (![rhs isKindOfClass:[NSArray class]]) {
        [self setError:error withReason:@"RHS must be an NSArray"];
        return NO;
    }
    NSString *field = (NSString *)lhs;
    NSArray *arrayToSearch = (NSArray *)rhs;
    
    [*query where:field isIn:arrayToSearch];
    
    return YES;
}

- (BOOL)buildQuery:(SMQuery *__autoreleasing *)query forCompoundPredicate:(NSCompoundPredicate *)compoundPredicate error:(NSError *__autoreleasing *)error
{
    if ([compoundPredicate compoundPredicateType] != NSAndPredicateType) {
        [self setError:error withReason:@"Predicate type not supported."];
        return NO;
    }
    
    for (unsigned int i = 0; i < [[compoundPredicate subpredicates] count]; i++) {
        NSPredicate *subpredicate = [[compoundPredicate subpredicates] objectAtIndex:i];
        [self buildQuery:query forPredicate:subpredicate error:error];
    }
    
    return YES;
}

- (BOOL)buildQuery:(SMQuery *__autoreleasing *)query forComparisonPredicate:(NSComparisonPredicate *)comparisonPredicate error:(NSError *__autoreleasing *)error
{
    if (comparisonPredicate.leftExpression.expressionType != NSKeyPathExpressionType) {
        [self setError:error withReason:@"LHS must be usable as a remote keypath"];
        return NO;
    } else if (comparisonPredicate.rightExpression.expressionType != NSConstantValueExpressionType) {
        [self setError:error withReason:@"RHS must be a constant-valued expression"];
        return NO;
    }
    
    // Convert leftExpression keyPath to SM equivalent field name if needed
    NSString *lhs = nil;
    if ([comparisonPredicate.leftExpression.keyPath rangeOfCharacterFromSet:[NSCharacterSet uppercaseLetterCharacterSet]].location != NSNotFound) {
        lhs = [self convertPredicateExpressionToStackMobFieldName:comparisonPredicate.leftExpression.keyPath entity:[*query entity]];
    } else {
        lhs = comparisonPredicate.leftExpression.keyPath;
    }
    
    id rhs = comparisonPredicate.rightExpression.constantValue;
    
    switch (comparisonPredicate.predicateOperatorType) {
        case NSEqualToPredicateOperatorType:
            if ([rhs isKindOfClass:[NSManagedObject class]]) {
                rhs = (NSString *)[self referenceObjectForObjectID:[rhs objectID]];;
            } else if ([rhs isKindOfClass:[NSManagedObjectID class]]) {
                rhs = (NSString *)[self referenceObjectForObjectID:rhs];;
            }
            [*query where:lhs isEqualTo:rhs];
            break;
        case NSNotEqualToPredicateOperatorType:
            [*query where:lhs isNotEqualTo:rhs];
            break;
        case NSLessThanPredicateOperatorType:
            [*query where:lhs isLessThan:rhs];
            break;
        case NSLessThanOrEqualToPredicateOperatorType:
            [*query where:lhs isLessThanOrEqualTo:rhs];
            break;
        case NSGreaterThanPredicateOperatorType:
            [*query where:lhs isGreaterThan:rhs];
            break;
        case NSGreaterThanOrEqualToPredicateOperatorType:
            [*query where:lhs isGreaterThanOrEqualTo:rhs];
            break;
        case NSBetweenPredicateOperatorType:
            [self buildBetweenQuery:query leftHandExpression:lhs rightHandExpression:rhs error:error];
            break;
        case NSInPredicateOperatorType:
            [self buildInQuery:query leftHandExpression:lhs rightHandExpression:rhs error:error];
            break;
        default:
            [self setError:error withReason:@"Predicate type not supported."];
            break;
    }
    
    return YES;
}

- (BOOL)buildQuery:(SMQuery *__autoreleasing *)query forPredicate:(NSPredicate *)predicate error:(NSError *__autoreleasing *)error;
{
    if ([predicate isKindOfClass:[NSCompoundPredicate class]]) {
        [self buildQuery:query forCompoundPredicate:(NSCompoundPredicate *)predicate error:error];
    }
    else if ([predicate isKindOfClass:[NSComparisonPredicate class]]) {
        [self buildQuery:query forComparisonPredicate:(NSComparisonPredicate *)predicate error:error];
    }
    
    return YES;
}


@end
