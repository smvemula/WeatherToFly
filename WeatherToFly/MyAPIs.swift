//
//  MyAPIs.swift
//  PlayNFLBetting
//
//  Created by Vemula, Manoj (Contractor) on 8/16/15.
//  Copyright © 2015 Vemula, Manoj (Contractor). All rights reserved.
//

import UIKit
import Foundation

class MyAPIs: NSObject {
    
    class func getWeatherFor(airport: String,completion: (weather: NSDictionary) -> Void, failure: (failure_code: String, failure_error:String) -> Void) {
        MyNetwork.instance().requestWithUri("?ICAO=K\(airport.uppercaseString)&username=smvemula", httpMethod: HTTPMethod.GET, httpBodyParameters: nil, completion: {(status, content, error) -> Void in
            if let dict = content as? NSDictionary {
                if let status = dict["status"] as? NSDictionary {
                    failure(failure_code: "200", failure_error: "NO RESULTS FOUND")
                } else if let weatherObservation = dict["weatherObservation"] as? NSDictionary {
                    completion(weather: weatherObservation)
                }
            } else {
                failure(failure_code: status, failure_error: "")
            }
        })
    }
}

extension MyAPIs {
    class func stringFromQueryParameters(queryParameters : Dictionary<String, String>) -> String {
        var parts: [String] = []
        for (name, value) in queryParameters {
            //            var part = NSString(format: "%@=%@",
            //                name.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!,
            //                value.stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding)!)
            //            parts.append(part as String)
            let part = NSString(format: "%@=%@",
                name,
                value)
            parts.append(part as String)
        }
        return parts.joinWithSeparator("&")
    }
    
    /**
    Creates a new URL by adding the given query parameters.
    @param URL The input URL.
    @param queryParameters The query parameter dictionary to add.
    @return A new NSURL.
    */
    class func NSURLByAppendingQueryParameters(URL : NSURL!, queryParameters : Dictionary<String, String>) -> NSURL {
        let URLString : NSString = NSString(format: "%@?%@", URL.absoluteString, MyAPIs.stringFromQueryParameters(queryParameters))
        return NSURL(string: URLString as String)!
    }
}
