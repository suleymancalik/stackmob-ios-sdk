<h2>StackMob iOS SDK Change Log</h2>

<h3>v1.0.0 - Sep 24, 2012</h3>

**Features**
* Support for iOS preferred camelCase Core Data property names.
* Support non case-sensitive schema names in datastore API.
* Support Core Data Date attribute type.
* API version and public key provided to SMClient during initialization must be correct format and non-nil.

**Fixes**
* Edits to dictionary serialization algorithm for improved performance.
* NewValueForRelationship incremental store method correctly returns empty array for to-many with no objects.

<h3>v1.0.0beta.3 - Aug 24, 2012</h3>

**Fixes** 
  * The method save: to the managed object context will return NO if StackMob calls fail.
  * Fetch requests not returning errors.

<h3>v1.0.0beta.2 - Aug 20, 2012</h3>

**Features**
* Performing custom code methods is now available through the `SMCustomCodeRequest` class.
* Binary Data can be converted into an NSString using the `SMBinaryDataConversion` class and persisted to a StackMob field with Binary Data type.


<h3>v1.0.0beta.1 - Aug 10, 2012</h3>

**Features**
* Initial release of new and improved iOS SDK.  Core Data integration serves as the biggest change to the way developers interact with the SDK. See [iOS SDK v1.0 beta](https://www.stackmob.com/devcenter/docs/iOS-SDK-v1.0-beta) for more information. 