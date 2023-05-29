# user-app
User App for WARN built in SwiftUI 4.0

### Getting Started
To run, make sure you complete the following steps: 

* SwiftUI 4.0 is [installed](https://developer.apple.com/xcode/swiftui/) locally on your machine
* To enable push notifications, ensure you have a [Apple Developer License](https://developer.apple.com/programs/) and have shared [necessary keys and identifiers](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server) with remote server
* Once the above steps are completed, you will be able to [run a simulated version of WARN](https://developer.apple.com/documentation/xcode/running-your-app-in-simulator-or-on-a-device) onto your handheld device and recieve all the product's functionality
   * Upon the first run, your device will ask to *enable push notifications* (be sure to enable this)

### Important
* Everytime a user enters the *local server id* into the Local Server ID text field, a new user id will be given
  * This mimics the creation of a new user, and will hold separate data from other users on the network 
* To login to an existing account, simply enter the corresponding *user id* into the User ID text field 
* Users will only be able to add devices that are detected on the smart home network
