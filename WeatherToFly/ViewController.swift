//
//  ViewController.swift
//  WeatherToFly
//
//  Created by Manoj Vemula on 1/5/16.
//  Copyright © 2016 Manoj Vemula. All rights reserved.
//

import UIKit
import MapKit
import AddressBookUI

class ViewController: UIViewController, UISearchBarDelegate, NewDelegate {
    
    @IBOutlet var weatherInfo : UITextView!
    @IBOutlet var searchBar : UISearchBar!
    @IBOutlet var addButton : UIButton!
    
    //constants
    let kStoreProfileIDKey = "storeProfileID"
    let kLocationUpdateNotification = "LocationUpdateNotification"
    let kCoordinate = "Coordinate"
    
    
    @IBAction func addToFavorites() {
        if let exists = NSUserDefaults.standardUserDefaults().objectForKey("favorites") as? [NSDictionary] {
            var new = exists
            if let newDict = self.currentDict {
                if new.contains(newDict) {
                    self.addButton.setImage(UIImage(named: "plus")?.tintWithColor(UIColor.grayColor()), forState: UIControlState.Normal)
                    new.removeObject(&new, object: newDict)
                } else {
                    self.addButton.setImage(UIImage(named: "plus")?.tintWithColor(UIColor.greenColor()), forState: UIControlState.Normal)
                    new.append(newDict)
                }
                NSUserDefaults.standardUserDefaults().setObject(new, forKey: "favorites")
            }
        } else if let new = self.currentDict {
            NSUserDefaults.standardUserDefaults().setObject([new], forKey: "favorites")
            self.addButton.setImage(UIImage(named: "plus")?.tintWithColor(UIColor.greenColor()), forState: UIControlState.Normal)
        }
    }
    
    var currentDict : NSDictionary?
    
    func updateAddButtonStatusForDict(object: NSDictionary) {
        if let exists = NSUserDefaults.standardUserDefaults().objectForKey("favorites") as? [NSDictionary] {
            var found = false
            var new = exists
            if let check = object["ICAO"] as? String {
                for each in exists {
                    if let id = each["ICAO"] as? String {
                        if check == id {
                            found = true
                            //Update weather info
                            new.removeObject(&new, object: each)
                            new.append(object)
                        }
                    }
                }
            }
            if found {
                NSUserDefaults.standardUserDefaults().setObject(new, forKey: "favorites")
                self.addButton.setImage(UIImage(named: "plus")?.tintWithColor(UIColor.greenColor()), forState: UIControlState.Normal)
            } else {
                self.addButton.setImage(UIImage(named: "plus")?.tintWithColor(UIColor.grayColor()), forState: UIControlState.Normal)
            }
        }
    }
    
    func dictoObservation(object: NSDictionary) {
        self.currentDict = object
        let newWeather = Observation(json: object)
        NSUserDefaults.standardUserDefaults().setObject(object, forKey: "recent")
        dispatch_async(dispatch_get_main_queue(), {
            self.view.stopLoading()
            self.addButton.hidden = false
            self.updateAddButtonStatusForDict(object)
            self.weatherInfo.text = newWeather.getSummary()
            self.searchBar.text = newWeather.getAirportCode()
        })
    }
    
    @IBAction func refresh() {
        searchBar.endEditing(true)
        if let exists = searchBar.text {
            self.view.startLoadingWithText("Loading weather info for \(exists)")
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
                MyAPIs.getWeatherFor(exists, completion: {(object) -> Void in
                    //print(object)
                    self.dictoObservation(object)
                    }, failure: { code, message -> Void in
                        print("\(code): \(message)")
                        self.currentDict = nil
                        dispatch_async(dispatch_get_main_queue(), {
                            self.addButton.hidden = true
                            self.view.stopLoading()
                            self.searchBar.text = ""
                            self.weatherInfo.text = ""
                            UIAlertController.showAlertView("No results found", text: "Please try again with a different Airport code", actionButtonBlock: {
                                self.searchBar.becomeFirstResponder()
                                }, vc: self)
                        })
                })
            })
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.weatherInfo.font = UIFont(name: "HelveticaNeue", size: 25)!
        self.addButton.hidden = true
        UserLocation.manager
    }
    
    override func viewWillAppear(animated: Bool) {
        if let exists = NSUserDefaults.standardUserDefaults().objectForKey("recent") as? NSDictionary {
            self.currentDict = exists
            let newWeather = Observation(json: exists)
            self.weatherInfo.text = newWeather.getSummary()
            self.searchBar.text = newWeather.getAirportCode()
            self.updateAddButtonStatusForDict(exists)
            self.addButton.hidden = false
        } else {
            self.searchBar.becomeFirstResponder()
            self.getUserLocation()
        }
    }
    
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        if let vc = segue.destinationViewController as? MasterViewController {
            vc.delegate = self
        }
    }
    
    func showWeather(airport: String) {
        self.searchBar.text = airport
        self.refresh()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func getUserLocation() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "receiveLocationUpdateNotification:", name: kLocationUpdateNotification, object: nil)
        UserLocation.manager.locationManager.startUpdatingLocation()
    }
    
    func receiveLocationUpdateNotification(notification: NSNotification)
    {
        if let aDict = notification.userInfo {
                NSNotificationCenter.defaultCenter().removeObserver(self, name: kLocationUpdateNotification, object: nil)
                UserLocation.manager.locationManager.stopUpdatingLocation()
            if let clLocation = aDict[kCoordinate] as? CLLocation {
                if let exists = self.searchBar.text {
                    if exists.utf16.count == 0 {
                        self.getAirportAsUserLocaton(clLocation)
                    }
                } else {
                    self.getAirportAsUserLocaton(clLocation)
                }
            }
        }
    }
    
    func getAirportAsUserLocaton(clLocation: CLLocation) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), {
        MyAPIs.getAirportFor("\(clLocation.coordinate.latitude)", long: "\(clLocation.coordinate.longitude)", completion: {(weather) -> Void in
            dispatch_async(dispatch_get_main_queue(), {
                self.dictoObservation(weather)
            })
            }, failure: {code, message -> Void in
        })
        })
    }
}

//MARK - UISearchBarDelegate Methods
extension ViewController {
    func searchBarShouldBeginEditing(searchBar: UISearchBar) -> Bool {
        return true
    }
    func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
        return true
    }
    func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        self.refresh()
    }
    func searchBarBookmarkButtonClicked(searchBar: UISearchBar) {
        
    }
    func searchBarCancelButtonClicked(searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }
    func searchBarResultsListButtonClicked(searchBar: UISearchBar) {
        
    }
    func searchBar(searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        
    }
}

