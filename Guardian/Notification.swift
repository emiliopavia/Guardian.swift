// Notification.swift
//
// Copyright (c) 2016 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

private let AuthenticationCategory = "com.auth0.notification.authentication"


@objc(A0GNotification)
public protocol Notification {
    var domain: String { get }
    var enrollmentId: String { get }
    var transactionToken: String { get }
    var source: Source? { get }
    var location: Location? { get }
    var startedAt: NSDate { get }
}

@objc(A0GSource)
public protocol Source {
    var os: OS? { get }
    var browser: Browser? { get }
}

@objc(A0GBrowser)
public protocol Browser {
    var name: String { get }
    var version: String? { get }
}

@objc(A0GOS)
public protocol OS {
    var name: String { get }
    var version: String? { get }
}

@objc(A0GLocation)
public protocol Location {
    var name: String? { get }
    var latitude: NSNumber? { get }
    var longitude: NSNumber? { get }
}

class AuthenticationNotification: NSObject, Notification {

    let domain: String
    let enrollmentId: String
    let transactionToken: String
    let source: Source?
    let location: Location?
    let startedAt: NSDate

    init(domain: String, enrollmentId: String, transactionToken: String, startedAt: NSDate, source: Source?, location: Location?) {
        self.domain = domain
        self.enrollmentId = enrollmentId
        self.transactionToken = transactionToken
        self.source = source
        self.location = location
        self.startedAt = startedAt
    }

    convenience init?(userInfo: [NSObject: AnyObject]) {
        guard
            let json = userInfo as? [String: AnyObject],
            let aps = json["aps"] as? [String: AnyObject],
            let category = aps["category"] as? String where category == AuthenticationCategory
            else { return nil }
        let locale = NSLocale(localeIdentifier: "en_US_POSIX")
        let formatter = NSDateFormatter()
        formatter.locale = locale
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        guard
            let mfa = json["mfa"] as? [String: AnyObject],
            let enrollmentId = mfa["dai"] as? String,
            let token = mfa["txtkn"] as? String,
            let when = mfa["d"] as? String,
            let startedAt = formatter.dateFromString(when),
            let domain = mfa["sh"] as? String
            else { return nil }
        let source = AuthenticationSource(fromJSON: mfa["s"])
        let location = AuthenticationLocation(fromJSON: mfa["l"])

        self.init(domain: domain, enrollmentId: enrollmentId, transactionToken: token, startedAt: startedAt, source: source, location: location)
    }
}

class AuthenticationSource: NSObject, Source {

    class NamedSource: NSObject, OS, Browser {
        let name: String
        let version: String?

        init(name: String, version: String?) {
            self.name = name
            self.version = version
        }
    }

    let os: OS?
    let browser: Browser?

    init?(fromJSON json: AnyObject?) {
        guard let source = json as? [String: AnyObject] else {
            return nil
        }

        let browser: Browser?
        let os: OS?
        if let data = source["b"] as? [String: AnyObject], let name = data["n"] as? String {
            let version = data["v"] as? String
            browser = NamedSource(name: name, version: version)
        } else {
            browser = nil
        }
        if let data = source["os"] as? [String: AnyObject], let name = data["n"] as? String {
            let version = data["v"] as? String
            os = NamedSource(name: name, version: version)
        } else {
            os = nil
        }

        if os == nil && browser == nil {
            return nil
        }
        self.os = os
        self.browser = browser
    }
}

class AuthenticationLocation: NSObject, Location {

    let name: String?
    let latitude: NSNumber?
    let longitude: NSNumber?

    init?(fromJSON json: AnyObject?) {
        guard let location = json as? [String: AnyObject] else {
            return nil
        }

        name = location["n"] as? String
        let latitudeValue = location["lat"]
        let longitudeValue = location["long"]
        if let latitudeString = latitudeValue as? String,
            let longitudeString = longitudeValue as? String {
            latitude = Double(latitudeString)
            longitude = Double(longitudeString)
        } else {
            latitude = latitudeValue as? Double
            longitude = longitudeValue as? Double
        }
    }
}
