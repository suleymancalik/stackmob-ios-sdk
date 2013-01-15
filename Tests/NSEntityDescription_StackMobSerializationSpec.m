/**
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

#import <Kiwi/Kiwi.h>
#import "SMError.h"
#import "NSEntityDescription+StackMobSerialization.h"
#import "SMClient.h"

SPEC_BEGIN(NSEntityDescription_StackMobSerializationSpec)

describe(@"NSEntityDescription_StackMobSerializationSpec", ^{
    __block NSEntityDescription *mapEntity = nil;
    beforeEach(^{
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        SM_CONVERT_SCHEMA_NAMES = YES;
        mapEntity = [[NSEntityDescription alloc] init];
        [mapEntity setName:@"Map"];
        [mapEntity setManagedObjectClassName:@"Map"];
        
        NSAttributeDescription *map_id = [[NSAttributeDescription alloc] init];
        [map_id setName:@"map_id"];
        [map_id setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *mapid = [[NSAttributeDescription alloc] init];
        [mapid setName:@"mapid"];
        [mapid setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
        [name setName:@"name"];
        [name setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *url = [[NSAttributeDescription alloc] init];
        [url setName:@"URL"];
        [url setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *camelCase = [[NSAttributeDescription alloc] init];
        [camelCase setName:@"camelCase"];
        [camelCase setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *poorlyNamed = [[NSAttributeDescription alloc] init];
        [poorlyNamed setName:@"PoorlyNamed"];
        [poorlyNamed setAttributeType:NSStringAttributeType];
        
        [mapEntity setProperties:[NSArray arrayWithObjects:map_id, mapid, name, url, camelCase, poorlyNamed, nil]];
    });
    
    describe(@"-SMSchema", ^{
        it(@"returns the lower case version of the entity name", ^{
            [[[mapEntity SMSchema] should] equal:@"map"];
        });
    });
    
    describe(@"-SMFieldNameForProperty:", ^{
        it(@"Returns StackMob equivalent format for camelCase properties", ^{
            NSPropertyDescription *camelCaseProperty = [[mapEntity propertiesByName] objectForKey:@"camelCase"];
            [[[mapEntity SMFieldNameForProperty:camelCaseProperty] should] equal:@"camel_case"];
        });
        it(@"Throws an exception for properties beginning with a capital letter", ^{
            __block NSPropertyDescription *capitalLetterProperty = [[mapEntity propertiesByName] objectForKey:@"poorlyNamed"];
            [[theBlock(^{
                [mapEntity SMFieldNameForProperty:capitalLetterProperty];
            }) should] raiseWithName:SMExceptionIncompatibleObject];
        });
        it(@"Returns StackMob equivalent format for all lowercase properties", ^{
            NSPropertyDescription *lowercaseProperty = [[mapEntity propertiesByName] objectForKey:@"name"];
            [[[mapEntity SMFieldNameForProperty:lowercaseProperty] should] equal:@"name"];
        });
        it(@"Returns StackMob equivalent format for lowercase with underscore properties", ^{
            NSPropertyDescription *lowercase_property = [[mapEntity propertiesByName] objectForKey:@"map_id"];
            [[[mapEntity SMFieldNameForProperty:lowercase_property] should] equal:@"map_id"];
        });
    });
    
    describe(@"-propertyForSMFieldName:", ^{
        context(@"Converting from fields to properties returns the correct property names", ^{
            it(@"returns map_id given map_id when map_id is a property", ^{
                [[[mapEntity propertyForSMFieldName:@"map_id"] should] equal:[[mapEntity propertiesByName] objectForKey:@"map_id"]];
            });
            it(@"returns camelCase given camel_case when camelCase is a property", ^{
                [[[mapEntity propertyForSMFieldName:@"camel_case"] should] equal:[[mapEntity propertiesByName] objectForKey:@"camelCase"]];
            });
            it(@"returns mapid given mapid when mapid is a property", ^{
                [[[mapEntity propertyForSMFieldName:@"mapid"] should] equal:[[mapEntity propertiesByName] objectForKey:@"mapid"]];
            });
        });
        context(@"when no properties match", ^{
            it(@"should return nil", ^{
                [[mapEntity propertyForSMFieldName:@"unknown"] shouldBeNil];
            });
        });
    });
});

describe(@"-userPrimaryKeyField", ^{
    __block NSEntityDescription *theEntity = nil;
    context(@"With an entity that has a StackMob-like userPrimaryKeyField", ^{
        beforeEach(^{
            SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
            SM_CONVERT_SCHEMA_NAMES = YES;
            theEntity = [[NSEntityDescription alloc] init];
            [theEntity setName:@"Entity"];
            [theEntity setManagedObjectClassName:@"Entity"];
            
            NSAttributeDescription *entity_id = [[NSAttributeDescription alloc] init];
            [entity_id setName:@"entity_id"];
            [entity_id setAttributeType:NSStringAttributeType];
            
            NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
            [name setName:@"name"];
            [name setAttributeType:NSStringAttributeType];
            
            [theEntity setProperties:[NSArray arrayWithObjects:entity_id, name, nil]];
        });
        it(@"Should return entity_id for userPrimaryKeyField", ^{
            [[[theEntity primaryKeyField] should] equal:@"entity_id"];
        });
    });
    context(@"With an entity that has a CoreData-like userPrimaryKeyField", ^{
        beforeEach(^{
            theEntity = [[NSEntityDescription alloc] init];
            [theEntity setName:@"Entity"];
            [theEntity setManagedObjectClassName:@"Entity"];
            
            NSAttributeDescription *entityId = [[NSAttributeDescription alloc] init];
            [entityId setName:@"entityId"];
            [entityId setAttributeType:NSStringAttributeType];
            
            NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
            [name setName:@"name"];
            [name setAttributeType:NSStringAttributeType];
            
            [theEntity setProperties:[NSArray arrayWithObjects:entityId, name, nil]];
        });
        it(@"Should return entityId for userPrimaryKeyField", ^{
            [[[theEntity primaryKeyField] should] equal:@"entityId"];
        });
        
    });
});

describe(@"CaseSensitiveFields, NSEntityDescription+StackMobSerialization", ^{
    __block NSEntityDescription *mapEntity = nil;
    beforeEach(^{
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = NO;
        SM_CONVERT_SCHEMA_NAMES = NO;
        mapEntity = [[NSEntityDescription alloc] init];
        [mapEntity setName:@"Map"];
        [mapEntity setManagedObjectClassName:@"Map"];
        
        NSAttributeDescription *mapId = [[NSAttributeDescription alloc] init];
        [mapId setName:@"mapId"];
        [mapId setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *mapid = [[NSAttributeDescription alloc] init];
        [mapid setName:@"mapid"];
        [mapid setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *name = [[NSAttributeDescription alloc] init];
        [name setName:@"name"];
        [name setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *url = [[NSAttributeDescription alloc] init];
        [url setName:@"URL"];
        [url setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *camelCase = [[NSAttributeDescription alloc] init];
        [camelCase setName:@"camelCase"];
        [camelCase setAttributeType:NSStringAttributeType];
        
        NSAttributeDescription *poorlyNamed = [[NSAttributeDescription alloc] init];
        [poorlyNamed setName:@"PoorlyNamed"];
        [poorlyNamed setAttributeType:NSStringAttributeType];
        
        [mapEntity setProperties:[NSArray arrayWithObjects:mapId, mapid, name, url, camelCase, poorlyNamed, nil]];
    });
    afterEach(^{
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = NO;
        SM_CONVERT_SCHEMA_NAMES = NO;
    });
    it(@"SMSchema", ^{
        [[[mapEntity SMSchema] should] equal:@"Map"];
        
        SM_CONVERT_SCHEMA_NAMES = YES;
        
        [[[mapEntity SMSchema] should] equal:@"map"];
    });
    
    it(@"primaryKeyField", ^{
        [[[mapEntity primaryKeyField] should] equal:@"mapId"];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        SM_CONVERT_SCHEMA_NAMES = YES;
        
        // no change should happen from this method
        [[[mapEntity primaryKeyField] should] equal:@"mapId"];
    });

    it(@"SMPrimaryKeyField", ^{
        
        // We do not convert primary keys
        [[[mapEntity SMPrimaryKeyField] should] equal:@"map_id"];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        
        [[[mapEntity SMPrimaryKeyField] should] equal:@"map_id"];
        
        SM_CONVERT_SCHEMA_NAMES = YES;
        
        [[[mapEntity SMPrimaryKeyField] should] equal:@"map_id"];
        
        
    });
    
    it(@"SMFieldNameForProperty", ^{
        NSPropertyDescription *property = [[mapEntity propertiesByName] objectForKey:@"mapId"];
        [[[mapEntity SMFieldNameForProperty:property] should] equal:@"map_id"];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        
        [[[mapEntity SMFieldNameForProperty:property] should] equal:@"map_id"];
        
        SM_CONVERT_SCHEMA_NAMES = YES;
        
        [[[mapEntity SMFieldNameForProperty:property] should] equal:@"map_id"];
        
        // Try for non-primary key attribute
        SM_CONVERT_SCHEMA_NAMES = NO;
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = NO;
        
        property = [[mapEntity propertiesByName] objectForKey:@"camelCase"];
        [[[mapEntity SMFieldNameForProperty:property] should] equal:@"camelCase"];
        
        SM_CONVERT_SCHEMA_NAMES = YES;
        
        [[[mapEntity SMFieldNameForProperty:property] should] equal:@"camelCase"];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        
        [[[mapEntity SMFieldNameForProperty:property] should] equal:@"camel_case"];
    });
    
    
    it(@"propertyForSMFieldName", ^{
        
        [[[mapEntity propertyForSMFieldName:@"mapId"] should] equal:[[mapEntity propertiesByName] objectForKey:@"mapId"]];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        
        [[[mapEntity propertyForSMFieldName:@"mapId"] should] equal:[[mapEntity propertiesByName] objectForKey:@"mapId"]];
        
        [[[mapEntity propertyForSMFieldName:@"map_id"] should] equal:[[mapEntity propertiesByName] objectForKey:@"mapId"]];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = NO;
        
        [[[mapEntity propertyForSMFieldName:@"map_id"] should] equal:[[mapEntity propertiesByName] objectForKey:@"mapId"]];
        
        [[[mapEntity propertyForSMFieldName:@"camelCase"] should] equal:[[mapEntity propertiesByName] objectForKey:@"camelCase"]];
        
        [[mapEntity propertyForSMFieldName:@"camel_case"] shouldBeNil];
        
        SM_CONVERT_ATTRIBUTES_AND_RELATIONSHIPS_NAMES = YES;
        
        [[[mapEntity propertyForSMFieldName:@"camelCase"] should] equal:[[mapEntity propertiesByName] objectForKey:@"camelCase"]];
        
        [[[mapEntity propertyForSMFieldName:@"camel_case"] should] equal:[[mapEntity propertiesByName] objectForKey:@"camelCase"]];
        
        
    });
    
});

SPEC_END
