/*
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

#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

/**
 `SMLocationManager` is a CLLocationManager singleton 
 
 @note You shouldn't have to access SMLocationManager directly. It's recommended that you subclass SMLocationManager to add more functionality.
 
 ## References ##
 
 [Apple's CLLocationManager class reference](https://developer.apple.com/library/mac/#documentation/CoreLocation/Reference/CLLocationManager_Class/CLLocationManager/CLLocationManager.html )
 */
@interface SMLocationManager : NSObject <CLLocationManagerDelegate>

/**
 locationManager is the CLLocationManager this singleton uses to recieve updates
 */

@property (nonatomic, strong) CLLocationManager* locationManager;

/**
 locationManagerError is a property to store errors that the CLLocationManager returns
*/
@property (nonatomic, strong) NSError *locationManagerError;

+ (SMLocationManager *)sharedInstance;

@end
