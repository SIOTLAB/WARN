//
//  ViewController.swift
//  WARN
//
//  Created by Jaden Ngo on 4/25/23.
//

import UIKit
import UserNotifications

class ViewController: UIViewController {
    
    override func viewDidLoad() {
        print("in view did load")
        super.viewDidLoad()
        checkForPermissions()
    }
    
    func checkForPermissions() {
        print("HERE")
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized:
                self.dispatchNotification()
            case .denied:
                return
            case .notDetermined:
                notificationCenter.requestAuthorization(options: [.alert, .sound]) { didAllow, error in
                    if (didAllow) {
                        self.dispatchNotification()
                    }
                }
            default:
                return
            }
        }
    }
    
    func dispatchNotification() {
        let identifier = "load-device-view"
        let title = "Loaded your connected devices!"
        let body = "Here is a list of all your devices"
        let hour = 9
        let minute = 15
        let isDaily = true
        
        let notificationCenter = UNUserNotificationCenter.current()
        
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let calendar = Calendar.current
        var dateComponents = DateComponents(calendar: calendar, timeZone: TimeZone.current)
        dateComponents.hour = hour
        dateComponents.minute = minute
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: isDaily)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        notificationCenter.removePendingNotificationRequests(withIdentifiers: [identifier])
        notificationCenter.add(request)
    }
}
