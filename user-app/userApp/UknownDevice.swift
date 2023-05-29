//
//  User.swift
//  userApp
//
//  Created by Jaden Ngo on 3/9/23.
//

import Foundation

class UnkownDeviceObject: ObservableObject, Codable, Identifiable, Hashable {
    
    enum CodingKeys: CodingKey {
        case device_id, user_id, device_name, device_vendor, timestamp
    }
    
    @Published var device_id = ""
    @Published var user_id = ""
    @Published var device_name: String?
    @Published var device_vendor = ""
    @Published var timestamp: [Int] = []
    
    init() { }
    
    static func == (lhs: UnkownDeviceObject, rhs: UnkownDeviceObject) -> Bool {
        return lhs.device_id == rhs.device_id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(device_id)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encode(device_id, forKey: .device_id)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(device_name, forKey: .device_name)
        try container.encode(device_vendor, forKey: .device_vendor)
        try container.encode(timestamp, forKey: .timestamp)
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        device_id = try container.decode(String.self, forKey: .device_id)
        user_id = try container.decode(String.self, forKey: .user_id)
        device_vendor = try container.decode(String.self, forKey: .device_vendor)
        device_name = try container.decodeIfPresent(String.self, forKey: .device_name) ?? device_vendor
        if (device_name == "") {
            device_name = device_vendor
        }
        timestamp = try container.decode([Int].self, forKey: .timestamp)
    }
}
