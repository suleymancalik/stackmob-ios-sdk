# Welcome to the docs for the StackMob iOS SDK!

### Current Version: 1.4.0

### Jump To:
<a href="#overview">Overview</a>

<a href="#getting_started">Getting Started</a>

<a href="#coding_practices">StackMob <--> Core Data Coding Practices</a>

[StackMob <--> Core Data Support Specifications](http://stackmob.github.com/stackmob-ios-sdk/CoreDataSupportSpecs.html)

<a href="#commonly_used_classes">Commonly Used Classes</a>

<a href="#tutorials">Tutorials</a>

<a href="#core_data_references">Core Data References</a>

<a href="#class_index">Index of Classes</a>

<a name="overview">&nbsp;</a>
## Overview

The goal of the iOS SDK is to provide the best experience possible for developing an application that uses StackMob as a cloud backend.  

<br/>
### How is the new iOS SDK different from the older version? 

The biggest difference between the new and the current SDKs is our use of Core Data as a foundation for the new SDK. We believe Core Data is a powerful approach for integrating StackMob’s REST based API into an iOS application.

That being said, we understand that Core Data is not suitable for every application, which is why we still expose the complete REST based API for making create, read, update and delete calls and performing queries on your database.

<br/>
### Why base the new SDK on Core Data? 
Our number one goal is to create a better experience. Core Data allows us to place a familiar wrapper around StackMob REST calls and Datastore API. iOS developers can leverage their existing knowledge of Core Data to quickly integrate StackMob into their applications.  For those interested in sticking to the REST-based way of making requests, we provide the full Datastore API as well.

<br/>
### Already know Core Data?
Then you already know how to use StackMob!

All you need to do to get started with StackMob is initialize an instance of SMClient and grab the configured managed object context by following the instructions in <a href="#getting_started">Initialize an SMClient</a>.

<br/>
### What Core Data functionality is supported with our integration?

Check out the [StackMob <--> Core Data Support Specifications](http://stackmob.github.com/stackmob-ios-sdk/CoreDataSupportSpecs.html).

<br/>
### Reporting issues or feature requests  

You can file issues through the [GitHub issue tracker](https://github.com/stackmob/stackmob-ios-sdk/issues).

<br/>
### Still have questions about the new iOS SDK? 

Email us at [support@stackmob.com](mailto:support@stackmob.com).

<a name="getting_started">&nbsp;</a>
## Getting Started

If you don't already have the StackMob SDK imported into your application, [get started with StackMob](https://developer.stackmob.com/start).

**The fundamental class for StackMob is SMClient**.  From an instance of this class you have access to a configured managed object context and persistent store coordinator as well as a REST-based Datastore. Check out the [class reference for SMClient](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMClient.html) for more information.  Let's see how to initialize our `SMClient`:

<br/>

### Initialize an SMClient

Wherever you plan to use StackMob, add `#import "StackMob.h"` to the header file.

Create a variable of class `SMClient`, most likely in your AppDelegate file where you initialize other application wide variables, and initialize it like this:

	// Assuming your variable is declared SMClient *client;
	client = [[SMClient alloc] initWithAPIVersion:@"YOUR_API_VERSION" publicKey:@"YOUR_PUBLIC_KEY"];

For YOUR_API_VERSION, pass @"0" for Development, @"1" or higher for the corresponding version in Production.

If you haven't found your public key yet, check out **Manage App Info** under the **App Settings** sidebar on the [Dashboard page](https://dashboard.stackmob.com).

<br/>
	
### Start persisting data

There are two ways to persist data to StackMob:

* Core Data
* Lower Level Datastore API

<br/>

#### Core Data


StackMob recommends using Core Data… it provides a powerful and robust object graph management system that otherwise would be a nightmare to implement.  Although it may have a reputation for being pretty complex, the basics are easy to grasp and understand.  If you want to learn the basics, check out <a href="#core_data_references">Core Data References</a> below.

The three main pieces of Core Data are instances of:

* [NSManagedObjectContext](https://developer.apple.com/library/ios/#documentation/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObjectContext\_Class/NSManagedObjectContext.html) - This is what you use to create, read, update and delete objects in your database.
* [NSPersistentStoreCoordinator](https://developer.apple.com/library/ios/#documentation/Cocoa/Reference/CoreDataFramework/Classes/NSPersistentStoreCoordinator\_Class/NSPersistentStoreCoordinator.html) - Coordinates between the managed object context and the actual database, in this case StackMob.
* [NSManagedObjectModel](https://developer.apple.com/library/ios/#documentation/Cocoa/Reference/CoreDataFramework/Classes/NSManagedObjectModel\_Class/Reference/Reference.html) - References a file where you defined your object graph.

**Access a StackMob-configured managed object context**

You can obtain a managed object context configured from your SMClient instance like this:

	// aManagedObjectModel is an initialized instance of NSManagedObjectModel
	// client is your instance of SMClient
	SMCoreDataStore *coreDataStore = [client coreDataStoreWithManagedObjectModel:aManagedObjectModel];
	
	// assuming you have a variable called managedObjectContext
	self.managedObjectContext = [coreDataStore contextForCurrentThread];
	
Use this instance of NSManagedObjectContext for the current thread you are on. You can always call contextForCurrentThread at any time to obtain an initialized managed object context if you are not sure what thread you are on.
<br/>
**Saving in the background**

When you are ready to save your context, the [NSManagedObjectContext+Concurrency](http://stackmob.github.com/stackmob-ios-sdk/Categories/NSManagedObjectContext+Concurrency.html) class offers asynchronous callback-based methods that perform off of the main thread, as well as methods that wait for the save to complete before continuing execution.  Both take advantage of the child / parent context pattern for optimized performance. 
<br/>
**Fetching in the background**

When you want to fetch objects, the [NSManagedObjectContext+Concurrency](http://stackmob.github.com/stackmob-ios-sdk/Categories/NSManagedObjectContext+Concurrency.html) class offers asynchronous callback-based methods that perform off of the main thread, as well as methods that wait for the fetch to complete before continuing execution.  You also have the option of returning instances of NSManagedObject or NSManagedObjectID.  Both take advantage of a pattern involving fetching object IDs from a private queue context and passing those IDs to the calling context.
<br/>
**Important:** Make sure you adhere to the <a href="#coding_practices">StackMob <--> Core Data Coding Practices</a>!

<br/>

#### Lower Level Datastore API

If you want to make direct REST-based calls to the Datastore, check out the [SMDataStore](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMDataStore.html) class.

<br/>

### Caching System

Included with version 1.4.0+ of the SDK is a caching system built in to the Core Data Integration to allow for local fetching of objects which have previously been fetched from the server.  See the [SMCoreDataStore class reference](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMCoreDataStore.html) for details on how to turn on the cache, set the cache policy, manually purge the cache, etc.

<br/>

### User Schema and Authentication

SMClient provides all the necessary methods for user authentication.

The default schema to use for authentication is **user**, with **username** and **password** fields.

You can set these using setters or the extended `SMClient` initialization method.

For more information see **The User Schema** and **User Authentication** sections of the [SMClient Class Reference](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMClient.html).

<br/>

### Push Notifications

Push Notification support comes built into the iOS SDK, which can be downloaded from the [SDK Downloads Page](https://developer.stackmob.com/sdk). 
 
If you will only be using StackMob for Push Notifications, you can [download the standalone version](https://github.com/downloads/stackmob/stackmob-ios-push-sdk/stackmob-ios-push-sdk-v1.0.2.zip) which **only** includes push support.

All the details on how to set up your application for push can be found in the [iOS Push Notifications Tutorial](https://developer.stackmob.com/tutorials/ios/Push-Notifications).

<br/>

### Checking Network Reachability

While the SDK has built in support for returning errors when there is no network connection, SMNetworkReachability provides an interface for developers to manually check if the device is connected to the network and can in turn reach StackMob.  All the details, including how to subscribe to notifications and set blocks to be executed when the network status changes, can be found in the [SMNetworkReachability class reference](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMNetworkReachability.html).

<br/>
### Error Codes

The `SMError` class translates numeric error codes into readable errors, so you know what went wrong.  SDK specific error codes have also been defined for even more specific errors.  Check out the [Error Code Translations](http://stackmob.github.com/stackmob-ios-sdk/ErrorCodeTranslations.html) page for all the details.

<br/>
### Debugging

The iOS SDK gives developers access to two global variables that will enable additional logging statements when using the Core Data integration:

* **SM_CORE_DATA_DEBUG** - In your AppDelegate's `application:DidFinishLaunchingWithOptions:` method, include the line `SM_CORE_DATA_DEBUG = YES;` to turn on log statements from `SMIncrementalStore`. This will provide information about the Datastore calls to StackMob happening behind the scenes during Core Data saves and fetches. The default is `NO`.
* **SM_MAX_LOG_LENGTH** - Used to control how many characters are printed when logging objects. The default is **10,000**, which is plenty, so you will almost never have to set this.  The only time you will see the string representation of an object truncated is when you have an Attribute of type String that maps to a field of type Binary on StackMob, because you are sending a string containing the binary of the image, etc. String representations of objects that have been truncated end with \<MAX\_LOG\_LENGTH\_REACHED\>.   


<a name="coding_practices">&nbsp;</a>
## StackMob <--> Core Data Coding Practices

There are a few coding practices to adhere to as well as general things to keep in mind when using StackMob with Core Data.  This allows StackMob to seamlessly translate to and from the language that Core Data speaks.

First, a table of how Core Data, StackMob and regular databases map to each other:
<table cellpadding="8px" width="600px">
	<tr align="center">
		<th>Core Data</th>
		<th>StackMob</th>
		<th>Database</th>
	</tr>
	<tr>
		<td>Entity</td>
		<td>Schema</td>
		<td>Table</td>
	</tr>
	<tr>
		<td>Attribute</td>
		<td>Field</td>
		<td>Column</td>
	</tr>
	<tr>
		<td>Relationship</td>
		<td>Relationship</td>
		<td>Reference Column</td>
	</tr>
</table>

**General Information:**

1. **Entity Names:** Core Data entities are encouraged to start with a capital letter and will translate to all lowercase on StackMob. Example: **Superpower** entity on Core Data translates to **superpower** schema on StackMob.
2. **Property Names:** Core Data attribute and relationship names are encouraged to be in camelCase, but can also be in StackMob form, all lowercase with optional underscores. Acceptable formats are therefore **yearBorn**, **year_born**, or **yearborn**. All camelCased names will be converted to and from their equivalent form on StackMob, i.e. the property yearBorn will appear as year\_born on StackMob.
3. **StackMob Schema Primary Keys:** All StackMob schemas have a primary key field that is always schemaName\_id, unless the schema is a user object, in which case it defaults to "username" but can be changed manually by setting the userPrimaryKeyField property in your `SMClient` instance.

<br/>

**Coding Practices for successful app development:**

1. **Entity Primary Keys:** Following #3 above, each Core Data entity must include an attribute of type string that maps to the primary key field on StackMob. Acceptable formats are _schemaName_Id or _schemaName_\_id. If the managed object subclass for the Entity inherits from `SMUserManagedObject`, meaning it is intended to define user objects, you may use either of the above formats or whatever lowercase string with optional underscores matches the primary key field on StackMob. For example: entity **Soda** should have attribute **sodaId** or **soda_id**, whereas your **User** entity primary key field defaults to **@"username"**. 
2. **Assign IDs:** When inserting new objects into your managed object context, you must assign an id value to the attribute which maps to the StackMob primary key field BEFORE you make save the context.
90% of the time you can get away with assigning ids like this:
		
		// assuming your instance is called newManagedObject
		[newManagedObject setValue:[newManagedObject assignObjectId] forKey:[newManagedObject primaryKeyField]];
		
		// now you can save your context
		
	The other 10% of the time is when you want to assign your own ids that aren't unique strings based on a UUID algorithm. A great example of this is user objects, where you would probably assign the user's name to the primary key field.  In that case, your code might look more like this:
	
		// assuming your instance is called newManagedObject
		[newManagedObject setValue:@"bob" forKey:[newManagedObject primaryKeyField]];
		
		// now you can save your context
		
3. **NSManagedObject Subclasses:** Creating an NSManagedObject subclass for each of your entities is highly recommended for convenience. You can add an init method to each subclass and include the ID assignment line from above - then you don't have to remember to do it each time you create a new object!
4. **SMUserManagedObject Subclasses:** After creating an NSManagedObject subclass for an entity that maps to a user object on StackMob, change the inherited class to SMUserManagedObject.  This class will give you a method to securely set a password for the user object, without directly setting any attributes in Core Data.  It is important to make sure you initialize an SMUserManagedObject instance properly.
5. **Create and Save Objects Before Relating Them:**  Before saving updated objects and depending on the merge policy, Core Data will grab persistent values from the server to compare against.  Problems arise when a relationship is updated with an object that hasn't been saved on the server yet.  To play it safe, try to create and save objects before relating them to one another. 
6. **Working With NSDate Attributes:** As of v1.4.0, NSDate attribute values are serialized to the StackMob server as integers in ms.  Declare the fields on StackMob as Integer.  By keeping consistency with the way the auto-generated **createddate** and **lastmoddate** fields are stored (ms), NSDate attributes for them will be deserialized correctly.

	If you want to check if one date is equal to another, use the <i>timeIntervalSinceDate:</i> method.  Dates being equal is equivalent to the time interval being < 1.  Using methods like <i>isEqualToDate:</i> track sub-second differences between dates, which are not present in the serialized integers.  Here's an example of how to check if two dates are equal:
	
		NSDate *date1 = [object1 valueForKey:@"date"];
		NSDate *date2 = [object2 valueForKey:@"date"];
		if ([date1 timeIntervalSinceDate:date2] < 1) {
			// The dates are equal.
		}

<a name="commonly_used_classes">&nbsp;</a>
## Commonly Used Classes
* [SMClient](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMClient.html) - Gives you access to everything you need to communicate with StackMob.
* [SMCoreDataStore](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMCoreDataStore.html) -  Gives you access to configured `NSManagedObjectContext` instances to communicate with StackMob directly through Core Data.  Includes the necessary methods for interacting with the cache.
* [NSManagedObjectContext+Concurrency](http://stackmob.github.com/stackmob-ios-sdk/Categories/NSManagedObjectContext+Concurrency.html) - Provides methods to save and fetch in the background.
* [SMDataStore](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMDataStore.html) - Gives you access to make direct REST-based calls to StackMob.
* [SMRequestOptions](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMRequestOptions.html) - When making direct calls to StackMob, an instance of `SMRequestOptions` gives you request configuration options.
* [SMUserManagedObject](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMUserManagedObject.html) - The managed object subclass that defines your users should inherit from `SMUserManagedObject`.  
* [SMCustomCodeRequest](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMCustomCodeRequest.html) - Starting place for making custom code calls.
* [SMBinaryDataConversion](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMBinaryDataConversion.html) - Convert `NSData` to `NSString` for persisting to a field on StackMob with type Binary Data (s3 Integration).
* [SMGeoPoint](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMGeoPoint.html) - Helper class for working with Geo Points with StackMob.
* [SMLocationManager](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMLocationManager.html) - Abstracts the boiler plate code of `CLLocationManager` used in retrieving geo data from the device.
* [SMPushClient](http://stackmob.github.com/stackmob-ios-sdk/Classes/SMPushClient.html) - Guide to sending push notifications.
* [Error Code Translations](http://stackmob.github.com/stackmob-ios-sdk/ErrorCodeTranslations.html) - A copy of what's listed in `SMError`, this shows all the readable typedefs for specific error codes.

<a name="tutorials">&nbsp;</a>
## Tutorials

You can find all the iOS SDK tutorials at our <a href="https://developer.stackmob.com/tutorials/ios" target="_blank">Dev Center</a>.

<a name="core_data_references">&nbsp;</a>
## Core Data References

* [Core Data Primer eBook](http://go.stackmob.com/learncoredata.html) - StackMob has put together an eBook based on one of our tutorial series which walks you through the full implementation of an app that uses Core Data.
* [Getting Started With Core Data](http://www.raywenderlich.com/934/core-data-on-ios-5-tutorial-getting-started) - Ray Wenderlich does a great tutorial on the basics of Core Data.
* [iPhone Core Data: Your First Steps](http://mobile.tutsplus.com/tutorials/iphone/iphone-core-data/) - Well organized tutorial on Core Data.
* [Introduction To Core Data](https://developer.apple.com/library/ios/\#documentation/Cocoa/Conceptual/CoreData/cdProgrammingGuide.html\#//apple\_ref/doc/uid/TP40001075) - Apple's Core Data Programming Guide
* [Introduction To Predicates](https://developer.apple.com/library/ios/\#documentation/Cocoa/Conceptual/Predicates/predicates.html\#//apple\_ref/doc/uid/TP40001789) - Apple's Predicates Programming Guide


<a name="class_index">&nbsp;</a>
## Index





