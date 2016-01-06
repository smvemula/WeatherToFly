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
    
    class func getNFLGameSchedules(preSeason: Bool,completion: (schedules: [NSDictionary]) -> Void, failure: (failure_code: String, failure_error:String) -> Void) {
        let bodyParameters = [
            "api_key": "rYhVsx7pW54egBdZPHiOMkalGcjItvXF",
            "year": "2015",
            "season_type": "REG",
        ]
        let bodyString = self.stringFromQueryParameters(bodyParameters)
        MyNetwork.instance().requestWithUri("/schedule", httpMethod: HTTPMethod.POST, httpBodyParameters: bodyString, completion: {(status, content, error) -> Void in
            if let dict = content as? [NSDictionary] {
                completion(schedules: dict)
            } else {
                completion(schedules: MyAPIs.getBackUpData())
                //failure(failure_code: status, failure_error: "")
            }
        })
    }
    
    class func getSchedulFor(week: String, preSeason: Bool,completion: (schedules: [NSDictionary]) -> Void, failure: (failure_code: String, failure_error:String) -> Void) {
        let bodyParameters = [
            "api_key": "rYhVsx7pW54egBdZPHiOMkalGcjItvXF",
            "year": "2015",
            "season_type": "REG",
            "week": week
        ]
        let bodyString = self.stringFromQueryParameters(bodyParameters)
        MyNetwork.instance().requestWithUri("/schedule", httpMethod: HTTPMethod.POST, httpBodyParameters: bodyString, completion: {(status, content, error) -> Void in
            if let dict = content as? [NSDictionary] {
                completion(schedules: dict)
            } else {
                //completion(schedules: MyAPIs.getBackUpData())
                failure(failure_code: status, failure_error: "")
            }
        })
    }
    
    class func updateNewUserBet(name: String, betAmount: Int, team: NFLTeam, match: Schedule, update:Bool, completion: (success: Bool) -> Void, failure: (failure_code: String, failure_error:String) -> Void) {
        
        var toString = [String]()
        for each in MyNetwork.instance().friends {
            if let exists = each.refrenceID {
                if match.homeSideBets.count == 0 && match.awaySideBets.count == 0 {
                    //No bets added, notify every one for first bet
                    toString.append(exists)
                } else if match.isFriendBetting(each) && update {
                    //Notify only if the friend is betting on this match
                    toString.append(exists)
                } else if each.isLoggedIn {
                    //Notify for new bets
                    toString.append(exists)
                }
            }
        }
        
        if toString.count > 0 {
            let bodyParameters = [
                "content_available": true,
                "registration_ids": toString,
                "notification": [
                    "body": update ? "\(name) is now Betting $\(betAmount) on \(team.smallDisplayString())" : "\(name) is Betting $\(betAmount) on \(team.smallDisplayString())",
                    "title": match.isLive ? "\(match.awayTeam.smallDisplayString()) \(match.awayScore!) vs \(match.homeTeam.smallDisplayString()) \(match.homeScore!)" : "\(match.awayTeam.smallDisplayString()) vs \(match.homeTeam.smallDisplayString())",
                    "sound": "default",
                    "badge": "0"
                ]
            ]
            MyNetwork.instance().requestWithUrl("https://gcm-http.googleapis.com/gcm/send", httpMethod: HTTPMethod.POST, httpBodyParameters:bodyParameters, completion: {(status, content, error) -> Void in
                if let dict = content as? NSDictionary {
                    print("SUCCESS : Respone for \(toString.description) : \(dict)")
                    completion(success: true)
                } else {
                    failure(failure_code: status, failure_error: "")
                }
            })
        }
    }
    
    class func sendOutBetUpdatesWithUserActivity(title: String, message: String, isSmack: Bool) {
        var toString = [String]()
        for each in MyNetwork.instance().friends {
            if let exists = each.refrenceID {
                //Notify for new bets
                if !isSmack && each.isLoggedIn {
                    toString.append(exists)
                } else if each.isSmackOn && each.isLoggedIn {
                    toString.append(exists)
                }
            }
        }
        
        if toString.count > 0 {
            let bodyParameters = [
                "content_available": true,
                "registration_ids": toString,
                "notification": [
                    "body": message,
                    "title": title,
                    "sound": "default",
                    "badge": "0"
                ]
            ]
            MyNetwork.instance().requestWithUrl("https://gcm-http.googleapis.com/gcm/send", httpMethod: HTTPMethod.POST, httpBodyParameters:bodyParameters, completion: {(status, content, error) -> Void in
                if let dict = content as? NSDictionary {
                    print("SUCCESS : Respone for \(toString.description) : \(dict)")
                } else {
                    print("Failure : \(status) \(error)")
                }
            })
        }
    }
    
    class func updateBetToMyFriends(betAmount: Int, team: NFLTeam, match: Schedule) {
        if let timer = MyNetwork.instance().notificationTrigger {
            //More Bets
            timer.invalidate()
            MyNetwork.instance().pendingBets[match.id] = ["amount": betAmount, "team": team.smallDisplayString()]
            MyNetwork.instance().notificationTrigger = NSTimer.scheduledTimerWithTimeInterval(10, target: MyNetwork.instance(), selector: Selector("sendAllPendingNotifications"), userInfo: nil, repeats: false)
        } else {
            //First Bet
            MyNetwork.instance().pendingBets[match.id] = ["amount": betAmount, "team": team.smallDisplayString()]
            MyNetwork.instance().notificationTrigger = NSTimer.scheduledTimerWithTimeInterval(10, target: MyNetwork.instance(), selector: Selector("sendAllPendingNotifications"), userInfo: nil, repeats: false)
        }
    }
    
    class func updateSmackTalkToMyFriends(message: String) {

        if MyNetwork.instance().pendingMessage.utf16.count > 0 {
            MyNetwork.instance().pendingMessage = "\(MyNetwork.instance().pendingMessage). \(message)"
        } else {
            MyNetwork.instance().pendingMessage = message
        }
        MyNetwork.instance().notificationTrigger = NSTimer.scheduledTimerWithTimeInterval(10, target: MyNetwork.instance(), selector: Selector("sendAllPendingNotifications"), userInfo: nil, repeats: false)
    }
    
    class func getBackUpData() -> [NSDictionary] {
        if let path = NSBundle.mainBundle().pathForResource("sample-data", ofType: "json")
        {
            do {
                let data = try NSData(contentsOfURL: NSURL(fileURLWithPath: path), options: NSDataReadingOptions.DataReadingMappedIfSafe)
                var status : String = ""
                var content : AnyObject? = nil
                (status, content) = NSJSONSerialization.parseBasicResponse(data)
                if let array = content as? [NSDictionary] {
                    return array
                }
            } catch let error as NSError {
                print(error.localizedDescription)
                return []
            }
        }
        return []
    }
    
    class func addLocalNotificationForGame(schedule: Schedule) {
        if let _ = MyAPIs.checkIfNotificationExistsForMatch(schedule) {} else {
            print("Scheduled notifications for  \(schedule.awayTeam.smallDisplayString()) vs \(schedule.homeTeam.smallDisplayString())")
            let notification = UILocalNotification() // create a new reminder notification
            notification.alertTitle = "Reminder: \(schedule.awayTeam.smallDisplayString()) vs \(schedule.homeTeam.smallDisplayString())"
            notification.category = "Reminder"
            notification.alertBody = "1 Hour left to add your bet. Bet On!"
            notification.alertAction = "Bet On!"// text that is displayed after "slide to..." on the lock screen - defaults to "slide to view"
            /*if schedule.week! == 12 {
            notification.fireDate = NSDate().dateByAddingTimeInterval(Double(Int.random(10...100)))
            }*/
            notification.fireDate = NSDate(timeInterval: -60*60, sinceDate: schedule.gameDate) // 60 minutes before game start time
            notification.soundName = UILocalNotificationDefaultSoundName // play default sound
            notification.userInfo = ["uid": schedule.id] // assign a unique identifier to the notification that we can use to retrieve it later
            UIApplication.sharedApplication().scheduleLocalNotification(notification)
        }
    }
    
    class func removeLocalNotificationForGame(schedule: Schedule) {
        let app:UIApplication = UIApplication.sharedApplication()
        if let exists = MyAPIs.checkIfNotificationExistsForMatch(schedule) {
            app.cancelLocalNotification(exists)
        }
    }
    
    class func checkIfNotificationExistsForMatch(schedule: Schedule) -> UILocalNotification? {
        let app:UIApplication = UIApplication.sharedApplication()
        if let notifications = app.scheduledLocalNotifications {
            for oneEvent in notifications {
                let notification = oneEvent as UILocalNotification
                let userInfoCurrent = notification.userInfo! as! [String:AnyObject]
                let uid = userInfoCurrent["uid"]! as! String
                if uid == schedule.id {
                    return notification
                }
            }
        }
        return nil
    }
    
    class func fetchUserPicture(profileID: String, completion:()-> ()) {
        if let _ = MyNetwork.instance().userImage {
            completion()
        } else {
            let request: NSURLRequest = NSURLRequest(URL: NSURL(string: "https://graph.facebook.com/v2.4/\(profileID)/picture")!)
            let task = MyNetwork.instance().urlSession.dataTaskWithRequest(request){(data, response, error) in
                print("FACEBOOK: user picture is downloaded")
                MyNetwork.instance().userImage = data
                if error == nil {
                    completion()
                }
                else {
                    //print("Error: \(error.localizedDescription)")
                }
            }
            task.resume()
        }
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
