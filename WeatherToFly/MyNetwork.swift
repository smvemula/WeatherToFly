
//
//  MyNetwork.swift
//  PlayNFLBetting
//
//  Created by Vemula, Manoj (Contractor) on 4/1/15.
//  Copyright (c) 2015 Vemula, Manoj (Contractor). All rights reserved.
//

import Foundation
import UIKit

public enum HTTPMethod: String {
    case GET = "GET", POST = "POST", PUT = "PUT", DELETE = "DELETE"
}

public class MyNetwork:NSObject, NSURLSessionDataDelegate {
    
    let urlSession: NSURLSession = NSURLSession.sharedSession()
    let hostURL = "https://profootballapi.com"
    let lookForLogin = "LoginJustStarted"
    let newFavorite = "NEWFavoriteSelected"
    let friendsDownloadComplete = "FriendsDownloadComplete"
    let newSchedule = "NEWSCHEDULEUPDATED"
    let logOut = "USERLOGGEDOUT"
    let Scroll = "ScrollToSchedule"
    let SmackTalk = "OpenSmackTalk"
    var rootRef = Firebase(url: "https://bet-on-dev.firebaseio.com")
    //let rootRef = Firebase(url: "https://bet-on-test.firebaseio.com")

    var task : NSURLSessionDataTask?
    var user: CurrentUser?
    var shouldShare = false
    var weeksUpcoming = [Week]()
    var weeksHistory = [Week]()
    var thisWeek : Week?

    var currentWeek: Int? {
        didSet {
            if let current = currentWeek {
                rootRef.queryOrderedByChild("/games/nfl/schedule/week").queryEqualToValue(current).observeSingleEventOfType(FEventType.Value, withBlock: {(snapshot) -> Void in
                    NSNotificationCenter.defaultCenter().postNotificationName("UPDATEWEEK", object: nil)
                })
            }
        }
    }
    var nextGameDay : NSDate?
    var totalAmount : Int?
    var myLastMessagesCount = 0
    var messages = [String: NSDictionary]()
    
    var sortedMessages = [NSDictionary]()
    
    func updateMessages() {
        self.sortedMessages = []
        if sortedMessages.count == 0 && MyNetwork.instance().isLoggedIn() {
            for (_,message) in MyNetwork.instance().messages {
                self.sortedMessages.append(message)
            }
        }
        self.sortedMessages = self.sortedMessages.sort{return $1["timestamp"] as! Double >  $0["timestamp"] as! Double}
    }
    
    func getAllMessages(completion: ()->()) {
        var totalWait = 0
        if let user = MyNetwork.instance().user {
            totalWait++
            MyNetwork.instance().rootRef.childByAppendingPath("users/facebook:\(user.userID!)/smack_talk").queryOrderedByChild("timestamp").queryLimitedToLast(30).observeEventType(.Value, withBlock: { snapshot -> Void in
                if let value = snapshot.value as? [String: NSDictionary] {
                    for (key,message) in value {
                        self.messages[key] = message
                    }
                    self.updateMessages()
                    NSNotificationCenter.defaultCenter().postNotificationName("New Changes", object: nil)
                }
                totalWait--
                if totalWait <= 0 {
                    completion()
                }
            })
        }
        
        for each in MyNetwork.instance().friends {
            totalWait++
            MyNetwork.instance().rootRef.childByAppendingPath("users/facebook:\(each.userID!)/smack_talk").queryOrderedByChild("timestamp").queryLimitedToLast(30).observeEventType(.Value, withBlock: { snapshot -> Void in
                if let value = snapshot.value as? [String: NSDictionary] {
                    for (key,message) in value {
                        self.messages[key] = message
                    }
                    self.updateMessages()
                    NSNotificationCenter.defaultCenter().postNotificationName("New Changes", object: nil)
                }
                totalWait--
                if totalWait <= 0 {
                    completion()
                }
            })
        }
        //completion()
    }
    
    var notificationTrigger : NSTimer?
    var pendingMessage = ""
    var pendingBets = [String: NSDictionary]()
    
    func sendAllPendingNotifications() {
        var TotalBet = 0
        var Teams = ""
        for each in pendingBets.values {
            if let bet = each["amount"] as? Int {
                TotalBet += bet
            }
            if let team = each["team"] as? String {
                if Teams == "" {
                    Teams = team
                } else {
                    Teams = "\(Teams), \(team)"
                }
            }
        }
        
        if let person = MyNetwork.instance().user {
            if self.pendingBets.count > 0 {
                print("\(person.firstName!) is Betting $\(TotalBet) on \(Teams)")
                MyAPIs.sendOutBetUpdatesWithUserActivity("New Bets", message: "\(person.firstName!) is Betting $\(TotalBet) on \(Teams)", isSmack: false)
            }
            if pendingMessage.utf16.count > 0 {
                print("Sending Smack Talk message \(pendingMessage)")
                MyAPIs.sendOutBetUpdatesWithUserActivity("New Message", message: "\(person.firstName!) says \(pendingMessage)", isSmack: true)
            }
        }
        
        self.pendingMessage = ""
        self.pendingBets = [String: NSDictionary]()
        self.notificationTrigger?.invalidate()
        self.notificationTrigger = nil
    }
    
    func addNewSchedule(schedule:Schedule, week: Int, upcoming: Bool) {
        var found = false
        if upcoming {
            for eachWeek in weeksUpcoming {
                if eachWeek.weekNumber == week {
                    eachWeek.schedules.append(schedule)
                    found = true
                }
            }
            if !found {
                let newWeek = Week(weekNumber: week, season: schedule.season)
                self.weeksUpcoming.append(newWeek)
                newWeek.schedules.append(schedule)
            }
        } else {
            for eachWeek in weeksHistory {
                if eachWeek.weekNumber == week {
                    eachWeek.schedules.append(schedule)
                    found = true
                }
            }
            if !found {
                let newWeek = Week(weekNumber: week, season: schedule.season)
                self.weeksHistory.append(newWeek)
                newWeek.schedules.append(schedule)
            }
        }
    }
    
    func generateWeek() -> [Schedule] {
        if let week = self.thisWeek {
            return week.schedules
        } else {
            var leastWeek : Week?
            for week in weeksUpcoming {
                if let least = leastWeek {
                    if least.weekNumber.integerValue > week.weekNumber.integerValue && least.season == week.season {
                        leastWeek = week
                    } else if leastWeek?.season == "REGSEASON" && week.season == "PRESEASON" {
                        leastWeek = week
                    }
                } else {
                    leastWeek = week
                }
            }
            if let least = leastWeek {
                let schedules = least.schedules
                least.schedules = []
                self.thisWeek = least
                if let nextGameDate = self.nextGameDay {
                    for schedule in schedules {
                        schedule.homeSideBets = []
                        schedule.awaySideBets = []
                        if NSDate.getStartOfDayOnDate(nextGameDate).compare(NSDate.getStartOfDayOnDate(schedule.gameDate)) == NSComparisonResult.OrderedSame {
                            least.schedules.append(schedule)
                        }
                    }
                }
                return least.schedules
            }
        }
        return []
    }
    
    func todaySchedules() -> [Schedule] {
        return self.generateWeek()
    }
    func getTodayMatchIDs () -> [String] {
        var ids = [String]()
        for each in self.todaySchedules() {
            ids.append(each.id)
        }
        return ids
    }
    
    var scheduleDictionary = [String: Schedule]()
    var friendsDictionary = [String: Friend]()
    var winCounter = [NFLTeam: Int]()
    var lossCounter = [NFLTeam: Int]()
    
    var userImage : NSData?
    var favoriteTeam : NFLTeam?
    //var history = [Schedule]()
    //var schedules = [Schedule]()
    //var groups = [Group]()
    var invitableFriends = [Friend]()
    var friends = [Friend]() {
        didSet {
            MyNetwork.instance().getRankedFriends()
        }
    }
    var friendIDs = [String]()
    var friendNames = [String]()
    
    func getRankedFriends() -> [Friend] {
        var array = [Friend]()
        var userFound = false
        for (index, each) in EnumerateSequence(MyNetwork.instance().friends) {
            if userFound {
                each.rank = index + 2
                array.append(each)
            } else if let user = MyNetwork.instance().user {
                if user.totalWon > each.totalWon || (user.totalWon == each.totalWon && user.availableCash > each.cash) {
                    let friend = Friend()
                    friend.userID = user.userID!
                    friend.name = user.name!
                    friend.totalWon = user.totalWon
                    friend.totalLost = user.totalLost
                    friend.betsCount = UInt(user.betsDict.count)
                    
                    friend.cash = user.availableCash
                    friend.imageData = user.imageData
                    friend.url = user.url!
                    array.append(friend)
                    userFound = true
                }

                each.rank = userFound ? index + 2 : index + 1
                array.append(each)
            }
        }
        
        if !userFound {
            if let user = MyNetwork.instance().user {
                let friend = Friend()
                friend.userID = user.userID!
                friend.name = user.name!
                friend.totalWon = user.totalWon
                friend.totalLost = user.totalLost
                friend.betsCount = UInt(user.betsDict.count)
                friend.cash = user.availableCash
                if let data = user.imageData {
                    friend.imageData = data
                }
                friend.url = user.url!
                array.append(friend)
            }
        }
        
        return array
    }
    
    func sortFriends() {
        MyNetwork.instance().friends = MyNetwork.instance().friends.sort{t1, t2 in
            if t1.totalWon == t2.totalWon
            {
                if t1.cash == t2.cash {
                    return t1.betsCount > t2.betsCount
                }
                return t1.cash > t2.cash
            }
            return t1.totalWon > t2.totalWon
        }
    }
    
    required public override init() {
        super.init()
    }
    
    //singleton for network instance
    public class func instance() -> MyNetwork {
        struct Static {
            static var instance: MyNetwork? = nil
            static var onceToken: dispatch_once_t = 0
        }
        
        dispatch_once(&Static.onceToken) {
            Static.instance = self.init()
        }
        
        return Static.instance!
    }
    
    func isLoggedIn() -> Bool {
        if rootRef.authData != nil {
            // user authenticated
            //print(ref.authData)
            return true
        } else {
            // No user is signed in
        }
        return false
    }
    /*
    func updateScore(match: Schedule) {
        if let user = match.userBet {
            notification.alertBody = "You are Betting $\(user.betAmount) on \(user.team.smallDisplayString())"
        }
    }*/
    
    func scheduleNotificationfor(title: String, message: String, matchId: String) {
        let notification = UILocalNotification() // create a new reminder notification
        notification.alertTitle = title
        notification.category = "ScoreUpdate"
        notification.alertBody = message
        notification.alertAction = "Bet On!"// text that is displayed after "slide to..." on the lock screen - defaults to "slide to view"
        notification.fireDate = NSDate().dateByAddingTimeInterval(0)//NSDate(timeIntervalSince1970: episode.originalAirDateDouble) // 30 minutes from current time
        notification.soundName = UILocalNotificationDefaultSoundName // play default sound
        notification.userInfo = ["matchID": matchId] // assign a unique identifier to the notification that we can use to retrieve it later
        UIApplication.sharedApplication().scheduleLocalNotification(notification)
    }
}


//MARK: Public API
extension MyNetwork {

    //with uniform resource identifier
    public func requestWithUri(uri:String,
        httpMethod: HTTPMethod,
        httpBodyParameters:AnyObject?,
        completion: ((String, AnyObject?, NSError?) -> Void)!){
            _request(uri, httpMethod: httpMethod, httpBody: httpBodyParameters, shouldAppendURL: true, completion: completion)
    }
    
    public func requestWithUri(uri:String,
        httpMethod: HTTPMethod,
        httpBodyParameters:AnyObject?,
        isJSONObject:Bool,
        completion: ((String, AnyObject?, NSError?) -> Void)!){
            _request(uri, httpMethod: httpMethod, httpBody: httpBodyParameters, shouldAppendURL: true, isJSONObject : isJSONObject,completion: completion)
    }
    
    //with uniform resource locator
    public func requestWithUrl(url:String,
        httpMethod: HTTPMethod,
        httpBodyParameters:AnyObject?,
        completion: ((String, AnyObject?, NSError?) -> Void)){
            _request(url, httpMethod: httpMethod, httpBody: httpBodyParameters, shouldAppendURL: false, completion: completion)
    }
    
}

//MARK: Private Methods
extension MyNetwork {
    
    private func _request(target:String,
        httpMethod:HTTPMethod,
        httpBody: AnyObject?,
        shouldAppendURL : Bool,
        isJSONObject : Bool,
        completion: ((String, AnyObject?, NSError?) -> Void)!)
    {
        var url : String = target
        if shouldAppendURL {
            url = "\(self.hostURL)\(target)"
            //if self.isLoggedIn() {
                //url = "\(self.loggedInURL)\(target)"
            //}
        }
        print("Outgoing URL : \(url)")
        if let encodedURLString = (url as NSString).stringByAddingPercentEscapesUsingEncoding(NSUTF8StringEncoding){
            let request = buildHttpRequest(encodedURLString, httpBody: httpBody, isJSONObject : isJSONObject, httpMethod: httpMethod)
            print(request.allHTTPHeaderFields)
            task = urlSession.dataTaskWithRequest(request) {(data, response, error) in
                
                if (error == nil) {
                    // Success
                    let statusCode = (response as! NSHTTPURLResponse).statusCode
                    print("URL Session Task Succeeded: HTTP \(statusCode)")
                }
                else {
                    // Failure
                    print("URL Session Task Failed: %@", error!.localizedDescription);
                }
                
                var status : String = ""
                var content : AnyObject? = nil
                if error != nil {
                    print("HTTP request error code:\(status) : \(error!.localizedDescription),\(error!.localizedRecoverySuggestion) , for URL: \(url)")
                    status = "-999" //network error
                    completion(status, nil, error)
                } else {
                    let _: NSString? = NSString(data: data!, encoding: NSUTF8StringEncoding)
                    (status, content) = NSJSONSerialization.parseBasicResponse(data!)
                    if let contentExists: AnyObject = content{
                        if let _ = contentExists as? NSDictionary{
                            //print("content as Dictionary : \(contentAsDictionary)")
                        }
                        
                        if let _ = contentExists as? NSString{
                            //print("content as String : \(contentAsString)")
                        }
                        
                        if let _ = contentExists as? NSArray{
                            //print("content as Array : \(contentAsArray)")
                        }
                        
                        completion(status, contentExists, nil)
                    }
                }
            }
            
            if let exists = task {
                exists.resume()
            }
        }
    }
    
    private func _request(target:String,
        httpMethod:HTTPMethod,
        httpBody: AnyObject?,
        shouldAppendURL : Bool,
        completion: ((String, AnyObject?, NSError?) -> Void)!)
    {
        _request(target, httpMethod: httpMethod, httpBody: httpBody, shouldAppendURL: shouldAppendURL, isJSONObject : false, completion: completion)
    }
    
    public func buildHttpRequest(urlString: String,
        httpBody: AnyObject?,
        isJSONObject : Bool,
        httpMethod: HTTPMethod) -> NSMutableURLRequest {
            
            if let url = NSURL(string: urlString){
                
                let request = NSMutableURLRequest(URL:url)
                request.HTTPMethod = httpMethod.rawValue
                
                
                // Headers
                //request.addValue("rYhVsx7pW54egBdZPHiOMkalGcjItvXF", forHTTPHeaderField: "api_key")
                request.addValue("application/json", forHTTPHeaderField: "Content-Type")
                request.addValue("key=AIzaSyDde_f5k7-fvlRnxieYsRP6NhAzUSkFg2o", forHTTPHeaderField: "Authorization")
                
                if let bodyParams = httpBody as? NSDictionary {
                    //var error: NSError?
                    
                    if let body: NSString = bodyParams.contentsAsURLQueryString(){
                        if isJSONObject {
                            do {
                                let value = try NSJSONSerialization.dataWithJSONObject(bodyParams, options: [])
                                request.HTTPBody = value
                            }
                                
                            catch let error as NSError {
                                print("HTTPBODY : A JSON Object build error occurred, here are the details:\n \(error)")
                            }

                        } else {
                            request.HTTPBody = body.dataUsingEncoding(NSUTF8StringEncoding)
                        }
                    }
                    else{
                        
                        do {
                            let value = try NSJSONSerialization.dataWithJSONObject(bodyParams, options: [])
                            request.HTTPBody = value
                        }
                            
                        catch let error as NSError {
                            print("HTTPBODY : A JSON Object build error occurred, here are the details:\n \(error)")
                        }
                    }
                    
        
                    
                } else if let bodyParams = httpBody as? NSArray {
                    
                    do {
                        let value = try NSJSONSerialization.dataWithJSONObject(bodyParams, options: [])
                        request.HTTPBody = value
                    }
                        
                    catch let error as NSError {
                        print("HTTPBODY : A JSON Object build error occurred, here are the details:\n \(error)")
                    }
                }
                else if let bodyParams = httpBody as? NSString{
                    //var error: NSError?
                    if let body = bodyParams.dataUsingEncoding(NSUTF8StringEncoding) {
                        request.HTTPBody = body
                    }
                }
                else if let bodyParams = httpBody as? NSData {
                    request.HTTPBody = bodyParams
                }
                else if let bodyParams = httpBody as? Bool {
                    let booleanString = bodyParams ? "true" : "false"
                    request.HTTPBody = booleanString.dataUsingEncoding(NSUTF8StringEncoding)
                }
                
                return request
            }
            return NSMutableURLRequest()
    }
    
    private func _buildHttpRequest(urlString: String,
        httpBody: AnyObject?,
        httpMethod: HTTPMethod) -> NSMutableURLRequest {
            return buildHttpRequest(urlString, httpBody: httpBody, isJSONObject : false, httpMethod: httpMethod)
    }
    
}

extension MyNetwork {
    
    func scrollToMatch(id: String?) {
        if let tab = UIApplication.sharedApplication().windows[0].rootViewController as? UITabBarController {
            tab.selectedIndex = 0
            if let exists = id {
                self.postForNotificationName(self.Scroll, data: ["id": exists])
                NSUserDefaults.standardUserDefaults().setObject(exists, forKey: "ScrollToID")
            }
        }
    }
    
    func openSmackTalk() {
        if let tab = UIApplication.sharedApplication().windows[0].rootViewController as? UITabBarController {
            tab.selectedIndex = 0
            NSUserDefaults.standardUserDefaults().setObject(true, forKey: "SmackTalk")
            if let _ = MyNetwork.instance().user {
                self.postForNotificationName(self.SmackTalk)
            }
        }
    }
    
    func startObjeservingForNotificationName(name: String) {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "notificationRecieved:", name: name, object: nil)
    }
    
    func postForNotificationName(name: String) {
        NSNotificationCenter.defaultCenter().postNotificationName(name, object: nil)
    }
    
    func postForNotificationName(name: String, data: Dictionary<String,String>) {
        NSNotificationCenter.defaultCenter().postNotificationName(name, object: nil, userInfo: data)
    }
    
    func notificationRecieved(notification: NSNotification) {
        switch notification.name {
        case self.lookForLogin:
            NSNotificationCenter.defaultCenter().removeObserver(self, name: self.lookForLogin, object: nil)
            if let _ = FBSDKAccessToken.currentAccessToken() {
                //update user info
                if let _ = FBSDKProfile.currentProfile() {
                    /*
                    let newQuery = PFQuery(className: "User")
                    newQuery.whereKey("fbUserID", equalTo: profile.userID)
                    newQuery.findObjectsInBackgroundWithBlock({(object, error) -> Void in
                        print(object)
                        if object?.count > 0 {
                            if let user = object?.last {
                                user["loggedIn"] = true
                                user.saveInBackgroundWithBlock { (success: Bool, error: NSError?) -> Void in
                                    if success {
                                        print("PARSE: USER Object has been updated.")
                                    } else {
                                        print("PARSE: ERROR: USER Object has NOT been saved.")
                                        print(error!)
                                    }
                                    
                                }
                                MyNetwork.instance().userObject = user
                            }
                        } else {
                            //Create a New User on PARSE
                            let testObject = PFObject(className: "User")
                            testObject["fbUserID"] = profile.userID
                            testObject["firstName"] = profile.firstName
                            testObject["lastName"] = profile.lastName
                            testObject["name"] = profile.name
                            testObject["loggedIn"] = true
                            testObject["availableCash"] = 10000
                            testObject.saveInBackgroundWithBlock { (success: Bool, error: NSError?) -> Void in
                                if success {
                                    NSNotificationCenter.defaultCenter().removeObserver(self, name: self.lookForLogin, object: nil)
                                    print("PARSE: USER Object has been Created.")
                                    MyNetwork.instance().userObject = testObject
                                } else {
                                    print("PARSE: ERROR: Object has NOT been Created.")
                                    print(error!)
                                }
                                
                            }
                        }
                    })
                    
                    */
                    
                }
            }
        case self.friendsDownloadComplete:
            print("friends updated")
        default:
            print("Need to handle notifications for '\(notification.name)'")
        }
    }
}

