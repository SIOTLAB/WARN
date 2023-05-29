//
//  UserState.swift
//  userApp
//
//  Created by Jaden Ngo on 3/14/23.
//

import Foundation

@MainActor
class UserState: ObservableObject {
    
    @Published var isLoggedIn = false
    @Published var userid = ""
    @Published var serverid = ""
    @Published var notifToken = ""
    
}
