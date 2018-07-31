<p align="center">
   <!-- <a href="https://vicrab.io" target="_blank" align="center">
        <img src="https://vicrab-brand.storage.googleapis.com/vicrab-logo-black.png" width="280">
    </a> -->
<br/>
    <h1>Official Vicrab SDK for iOS/macOS/tvOS/watchOS<sup>(1)</sup>.</h1>
</p>

[![Travis](https://img.shields.io/travis/getvicrab/vicrab-cocoa.svg?maxAge=2592000)](https://travis-ci.org/getvicrab/vicrab-cocoa)
![platforms](https://img.shields.io/badge/platforms-iOS%20%7C%20tvOS%20%7C%20OSX-333333.svg)
![langauges](https://img.shields.io/badge/languages-Swift%20%7C%20ObjC-333333.svg)
[![CocoaPods Shield](https://img.shields.io/cocoapods/v/Vicrab.svg)](https://cocoapods.org/pods/Sentry)
[![CocoaPods Shield](https://img.shields.io/cocoapods/dt/Vicrab.svg)](https://cocoapods.org/pods/Vicrab)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)
[![codecov](https://codecov.io/gh/getvicrab/vicrab-cocoa/branch/master/graph/badge.svg)](https://codecov.io/gh/getvicrab/vicrab-cocoa)

This SDK is written in Objective-C but also works for Swift projects.

```swift
import Vicrab

func application(application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {

    // Create a Vicrab client and start crash handler
    do {
        Client.shared = try Client(dsn: "___PUBLIC_DSN___")
        try Client.shared?.startCrashHandler()
    } catch let error {
        print("\(error)")
        // Wrong DSN or KSCrash not installed
    }

    return true
}
```

- [Installation](https://docs.vicrab.io/clients/cocoa/#installation)
- [Documentation](https://docs.vicrab.io/clients/cocoa/)

<sup>(1)</sup>limited symbolication support
# vicrab-cocoa
