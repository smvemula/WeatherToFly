//
//  Observation.swift
//  WeatherToFly
//
//  Created by Manoj Vemula on 1/5/16.
//  Copyright © 2016 Manoj Vemula. All rights reserved.
//

import UIKit

class Observation: NSObject {
    var ICAO : String!
    var clouds : String!
    var cloudsCode : String!
    var countryCode : String!
    var datetime : NSDate!
    var dewPoint : String!
    var elevation : Int!
    var humidity : Int!
    var lat : String!
    var lng : String!
    var observation : String!
    var seaLevelPressure : String!
    var stationName : String!
    var temperature : String!
    var weatherCondition : String!
    var weatherConditionCode : String!
    var windDirection : Int!
    var windSpeed : Int!
    
    func getSummary() -> String {
        var summary = "Weather info:\n"
        summary += "\n\(self.stationName)\nTemperature : \(self.temperature)C \nHumidity : \(self.humidity)%\nWind : \(self.windSpeed) mph"
        if self.clouds != "n/a" {
            summary += "\nClouds : \(self.clouds)"
        }
        return summary
    }
    
    func getSmallSummary() -> String {
        var summary = "Temp: \(self.temperature)C Humidity: \(self.humidity)% Wind: \(self.windSpeed)"
        if self.clouds != "n/a" {
            summary += " Clouds: \(self.clouds)"
        }
        return summary
    }
    
    func getAirportCode() -> String {
        let airportCode = self.ICAO.substringWithRange(Range<String.Index>(start: self.ICAO.startIndex.advancedBy(1), end: self.ICAO.endIndex))
        return airportCode
    }

    init(json: NSDictionary) {
        if let icao = json["ICAO"] as? String {
            self.ICAO = icao
        }
        if let clouds = json["clouds"] as? String {
            self.clouds = clouds
        }
        if let cloudsCode = json["cloudsCode"] as? String {
            self.cloudsCode = cloudsCode
        }
        if let countryCode = json["countryCode"] as? String {
            self.countryCode = countryCode
        }
        //datetime = "2016-01-05 20:56:00";
        if let dewPoint = json["dewPoint"] as? String {
            self.dewPoint = dewPoint
        }
        if let elevation = json["elevation"] as? Int {
            self.elevation = elevation
        }
        if let humidity = json["humidity"] as? Int {
            self.humidity = humidity
        }
        if let lat = json["lat"] as? String {
            self.lat = lat
        }
        if let lng = json["lng"] as? String {
            self.lng = lng
        }
        if let observation = json["observation"] as? String {
            self.observation = observation
        }
        if let seaLevelPressure = json["seaLevelPressure"] as? String {
            self.seaLevelPressure = seaLevelPressure
        }
        if let stationName = json["stationName"] as? String {
            self.stationName = stationName
        }
        if let temperature = json["temperature"] as? String {
            self.temperature = temperature
        }
        if let weatherCondition = json["weatherCondition"] as? String {
            self.weatherCondition = weatherCondition
        }
        if let weatherConditionCode = json["weatherConditionCode"] as? String {
            self.weatherConditionCode = weatherConditionCode
        }
        if let windDirection = json["windDirection"] as? Int {
            self.windDirection = windDirection
        }
        if let windSpeed = json["windSpeed"] as? String {
            self.windSpeed = Int(windSpeed)
        }
    }
}
