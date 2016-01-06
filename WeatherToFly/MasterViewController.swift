//
//  MasterViewController.swift
//  ComplexApp
//
//  Created by Manoj Vemula  on 1/5/16.
//  Copyright © 2016 Manoj Vemula. All rights reserved.
//

import UIKit

protocol NewDelegate {
    func showWeather(airport: String)
}

class MasterViewController: UITableViewController {

    var objects = [Observation]()
    var delegate: NewDelegate?

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        self.navigationItem.rightBarButtonItem = self.editButtonItem()
        if let exists = NSUserDefaults.standardUserDefaults().objectForKey("favorites") as? [NSDictionary] {
            for each in exists {
                self.objects.append(Observation(json: each))
            }
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    // MARK: - Table View

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return objects.count
    }
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        let object = objects[indexPath.row]
        if let exists = self.delegate {
            exists.showWeather(object.getAirportCode())
            self.navigationController?.popViewControllerAnimated(true)
        }
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        return 60
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier("Cell", forIndexPath: indexPath)

        let object = objects[indexPath.row]
        cell.textLabel?.text = object.stationName
        cell.detailTextLabel?.text = object.getSmallSummary()
        return cell
    }

    override func tableView(tableView: UITableView, canEditRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }

    override func tableView(tableView: UITableView, commitEditingStyle editingStyle: UITableViewCellEditingStyle, forRowAtIndexPath indexPath: NSIndexPath) {
        if editingStyle == .Delete {
            if let exists = NSUserDefaults.standardUserDefaults().objectForKey("favorites") as? [NSDictionary] {
                var new = exists
                for each in exists {
                    if let id = each["ICAO"] as? String {
                        if self.objects[indexPath.row].ICAO == id {
                            new.removeObject(&new, object: each)
                        }
                    }
                }
                NSUserDefaults.standardUserDefaults().setObject(new, forKey: "favorites")
            }
            objects.removeAtIndex(indexPath.row)
            tableView.deleteRowsAtIndexPaths([indexPath], withRowAnimation: .Fade)
        } else if editingStyle == .Insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
        }
    }


}

