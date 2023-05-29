//
//  User.swift
//  userApp
//
//  Created by Jaden Ngo on 3/9/23.
//

import Foundation

class AttackObject: ObservableObject, Codable, Identifiable, Hashable {
    
    enum CodingKeys: CodingKey {
        case history_id, user_id, timestamp, attack_type, severity, device_address, device_name, convertedTimestamp
    }
    
    @Published var history_id = ""
    @Published var user_id = ""
    @Published var timestamp: [Int] = [] // year, day, hour, minute, second, nanosecond, offset hour, offset minute, offset second
    @Published var attack_type: String?
    @Published var severity = ""
    @Published var device_address = ""
    @Published var timestampDate: Date?
    @Published var timestampString: String?
    @Published var device_name: String?
    
    init() { }
    
    static func == (lhs: AttackObject, rhs: AttackObject) -> Bool {
        return lhs.history_id == rhs.history_id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(history_id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(history_id, forKey: .history_id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(attack_type, forKey: .attack_type)
        try container.encode(severity, forKey: .severity)
        try container.encode(device_address, forKey: .device_address)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        history_id = try container.decode(String.self, forKey: .history_id)
        user_id = try container.decode(String.self, forKey: .user_id)
        timestamp = try container.decode([Int].self, forKey: .timestamp)
        attack_type = try container.decodeIfPresent(String.self, forKey: .attack_type) ?? "Unkown Attack Type"
        severity = try container.decode(String.self, forKey: .severity)
        device_address = try container.decode(String.self, forKey: .device_address)
        for d in deviceInfo.connectedDevices {
            if d.device_id == device_address {
                device_name = d.device_name
            }
        }
        
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        var d = DateComponents()
        d.year = timestamp[0]
        d.day = timestamp[1]
        d.hour = timestamp[2]
        d.minute = timestamp[3]
        d.second = timestamp[4]
        let userCalendar = Calendar(identifier: .gregorian)
        timestampDate = userCalendar.date(from: d)
        timestampString = utcToLocal(dateStr: df.string(from: timestampDate ?? Date()))
    }
    
    func utcToLocal(dateStr: String) -> String? {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC")
        
        if let date = dateFormatter.date(from: dateStr) {
            dateFormatter.timeZone = TimeZone.current
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .medium
        
            return dateFormatter.string(from: date)
        }
        return nil
    }
}
