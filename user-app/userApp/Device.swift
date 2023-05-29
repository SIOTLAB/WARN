//
//  User.swift
//  userApp
//
//  Created by Jaden Ngo on 3/9/23.
//

import Foundation

class DeviceObject: ObservableObject, Codable, Identifiable, Hashable {
    
    enum CodingKeys: CodingKey {
            case device_id, device_name, user_id, connection_status, severity, info_manf, info_name, pps
    }

    @Published var device_id = ""
    @Published var device_name = ""
    @Published var user_id = ""
    @Published var connection_status = ""
    @Published var severity = ""
    @Published var info_manf = ""
    @Published var info_name = ""
    @Published var pps: Int = -1

    init() { }
    
    static func == (lhs: DeviceObject, rhs: DeviceObject) -> Bool {
        return lhs.device_id == rhs.device_id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(device_id)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(device_id, forKey: .device_id)
        try container.encode(device_name, forKey: .device_name)
        try container.encode(user_id, forKey: .user_id)
        try container.encode(connection_status, forKey: .connection_status)
        try container.encode(severity, forKey: .severity)
        try container.encode(info_manf, forKey: .info_manf)
        try container.encode(info_name, forKey: .info_name)
        try container.encode(pps, forKey: .pps)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        device_id = try container.decode(String.self, forKey: .device_id)
        device_name = try container.decode(String.self, forKey: .device_name)
        user_id = try container.decode(String.self, forKey: .user_id)
        connection_status = try container.decode(String.self, forKey: .connection_status)
        severity = try container.decode(String.self, forKey: .severity)
        info_manf = try container.decode(String.self, forKey: .info_manf)
        info_name = try container.decode(String.self, forKey: .info_name)
        pps = try container.decode(Int.self, forKey: .pps)
    }
}
