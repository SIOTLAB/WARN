//
//  User.swift
//  userApp
//
//  Created by Jaden Ngo on 3/9/23.
//

import Foundation

class KnownDeviceObject: ObservableObject, Codable, Identifiable, Hashable {
    
    enum CodingKeys: CodingKey {
            case manf_name, device_name, pps
    }

    @Published var manf_name = ""
    @Published var device_name = ""
    @Published var pps: Int = -1

    init() { }
    
    static func == (lhs: KnownDeviceObject, rhs: KnownDeviceObject) -> Bool {
        return (lhs.device_name == rhs.device_name) && (lhs.manf_name == rhs.manf_name)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(manf_name)
        hasher.combine(device_name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        try container.encode(manf_name, forKey: .manf_name)
        try container.encode(device_name, forKey: .device_name)
        try container.encode(pps, forKey: .pps)
    }

    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        device_name = try container.decode(String.self, forKey: .device_name)
        manf_name = try container.decode(String.self, forKey: .manf_name)
        pps = try container.decode(Int.self, forKey: .pps)
    }
}
