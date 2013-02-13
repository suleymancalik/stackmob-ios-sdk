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

#import <CoreLocation/CoreLocation.h>

/**
 `SMLocationManager` is a CLLocationManager singleton. 
 
 ## Using SMLocationManager ##
 
 SMLocationManager is a built-in CLLocationManager singleton for use in retrieving CLLocationCoordinate2D points. Many apps make use of geo location data; SMLocationManager aides in this process by eliminating the boilerplate code needed to build a CLLocationManager singleton.
 
 You can tell SMLocationManager to start listening for updates:
    [[[SMLocationManager sharedInstance] locationManager] startUpdatingLocation];
 
 Retrieving coordinates is straightforward:
    NSNumber *latitude = [[NSNumber alloc] initWithDouble:[[[[SMLocationManager sharedInstance] locationManager] location] coordinate].latitude];
    NSNumber *longitude = [[NSNumber alloc] initWithDouble:[[[[SMLocationManager sharedInstance] locationManager] location] coordinate].longitude];
 
 Alternatively, you can use the SMGeoPoint method <i>getGeoPointForCurrentLocationOnSuccess:successBlock onFailure:failureBlock</i>, which will pass back an SMGeoPoint in the success block or an NSError should the method fail.

 ## Subclassing SMLocationManager ##
 
 If you would like more control and customization for SMLocationManager, it's recommended you subclass it. In the init method of your subclass, you can configure the properties of the CLLocationManager.
 
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

/**
 sharedInstance returns the instance on SMLocationManager
 */
+ (SMLocationManager *)sharedInstance;

@end
