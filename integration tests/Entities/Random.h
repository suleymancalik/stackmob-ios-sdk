//
//  Random.h
//  stackmob-ios-sdk
//
//  Created by Matt Vaznaian on 11/1/12.
//  Copyright (c) 2012 StackMob. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>


@interface Random : NSManagedObject

@property (nonatomic, retain) NSNumber * done;
@property (nonatomic, retain) NSString * name;
@property (nonatomic, retain) NSString * randomId;
@property (nonatomic, retain) NSString * server_id;
@property (nonatomic, retain) NSDate * time;
@property (nonatomic, retain) NSNumber * yearBorn;
@property (nonatomic, retain) NSNumber * createddate;

@end
