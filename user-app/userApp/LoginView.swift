//
//  LoginView.swift
//  userApp
//
//  Created by Jaden Ngo on 3/9/23.
//

import SwiftUI
import UserNotifications

//local_server_id:69696969-4200-4200-4200-696969696969
//userid:69696969-4200-4200-4200-696969696969

struct LoginView: View {
    
    @EnvironmentObject var us: UserState
    @State private var userId = ""
    @State private var serverId = ""
    @State private var confirmationMessage = ""
    @State private var showingConfirmationMessage = false
    @ObservedObject var user: UserObject
    
    var isGetUserIDButtonDisabled: Bool {
            [serverId].contains(where: \.isEmpty)
        }
    
    var isSignInButtonDisabled: Bool {
            [userId].contains(where: \.isEmpty)
        }
    
    var body: some View {
        VStack {
            Spacer().frame(height: 50)
            
            Image(systemName: "shield.lefthalf.filled").resizable().frame(width: 50, height: 50).foregroundColor(CustomColor.lightBlue)
            Text("WARN")
            
            VStack(alignment: .leading, spacing: 15) {
                
                Spacer()
                
                /** Server ID Text Field **/
                TextField("Server Id",
                          text: $serverId ,
                          prompt: Text("Server ID").foregroundColor(.red)
                )
                .padding(10)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.red, lineWidth: 2)
                }
                .padding(.horizontal)
                
                Button {
                    Task {
                        await getUser()
                    }
                } label: {
                    Text("Get User ID")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(
                    isGetUserIDButtonDisabled ?
                    LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [.red], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)
                .disabled(isGetUserIDButtonDisabled) // how to disable while some condition is applied
                .padding()
                
                Spacer()
                
                /** User Login Text Field **/
                TextField("User Id",
                          text: $userId ,
                          prompt: Text("User ID").foregroundColor(.blue)
                )
                .padding(10)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(.blue, lineWidth: 2)
                }
                .padding(.horizontal)
                
                Button {
                    us.userid = userId
                    us.serverid = serverId
                    us.isLoggedIn = true
                    sendAPNS()
                } label: {
                    Text("Sign In")
                        .font(.title2)
                        .bold()
                        .foregroundColor(.white)
                }
                .frame(height: 50)
                .frame(maxWidth: .infinity)
                .background(
                    isSignInButtonDisabled ?
                    LinearGradient(colors: [.gray], startPoint: .topLeading, endPoint: .bottomTrailing) :
                        LinearGradient(colors: [CustomColor.lightBlue], startPoint: .topLeading, endPoint: .bottomTrailing)
                )
                .cornerRadius(20)
                .disabled(isSignInButtonDisabled) // how to disable while some condition is applied
                .padding()
                
                Spacer()
            }.alert("Requested User ID", isPresented: $showingConfirmationMessage) {
                Button("OK") { }
            } message: {
                Text(confirmationMessage)
            }
        }
    }
    
    func sendAPNS() {
        let json: [String: Any] = [
            "apns_id": notificationInfo.token,
            "user_id": us.userid
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        let url = URL(string: "http://iotsmeller.roshinator.com:8080/apns")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        print("apns_id (in apns): \(notificationInfo.token)")
        print("user_id (in apns): \(us.userid)")
        print()
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            if let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let result = responseJSON["user_id"] {
                    print("We succeeded!")
                }
            } else {
                confirmationMessage = "Something went wrong with connection to remote server. Please close and refresh the app to solve issue."
                showingConfirmationMessage = true
            }
        }
        dataTask.resume()
    }
    
    func getUser() async {
        let json: [String: Any] = ["local_server_id": serverId]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        let url = URL(string: "http://iotsmeller.roshinator.com:8080/user")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        print(String(data: request.httpBody ?? Data(), encoding: .utf8)!)
        let dataTask = URLSession.shared.dataTask(with: request) { data, response, error in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            if let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                if let result = responseJSON["user_id"] {
                    confirmationMessage = "Your corresponding User ID is: \(result) \n Please click the Sign In button to login."
                    showingConfirmationMessage = true
                    userId = String("\(result)")
                }
            } else {
                confirmationMessage = "Failed to retrieve User Id. Please make sure entered Server ID is correct."
                showingConfirmationMessage = true
            }
        }
        dataTask.resume()
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        LoginView(user: UserObject())
    }
}

/*
 References:
 - Login Functionality: https://holyswift.app/how-to-create-a-login-screen-in-swiftui/
 */
