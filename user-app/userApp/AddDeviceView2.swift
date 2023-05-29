//
//  AddDeviceView.swift
//  userApp
//
//  Created by Jaden Ngo on 4/7/23.
//

import SwiftUI

struct AddDeviceView2: View {
    @EnvironmentObject var us: UserState
//    @State var confirmationMessage = ""
 //   @State var showingConfirmationMessage = false
    @State var unknownDevices: [UnkownDeviceObject] = []
    var selectedManufacturer: KnownDeviceObject
    
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 25)
            
            Image(systemName: "shield.lefthalf.filled").resizable().frame(width: 50, height: 50).foregroundColor(CustomColor.lightBlue)
            Text("WARN")
            Spacer()
                .frame(height: 50)
            
            Text("Add Device With Manufacturer: ").bold().font(.title2)
                .frame(maxWidth: 350, alignment: .center).offset()
            Text("\(selectedManufacturer.manf_name)").bold().font(.title2).frame(maxWidth: 350, alignment: .center).offset().foregroundColor(CustomColor.lightBlue)
            Spacer()
            
            UnknownDevicesListView2(ukd: unknownDevices, sm: selectedManufacturer)
            
            Text("\n")
        }.onAppear(perform: getUnkownDevices)
    }
    
    func getUnkownDevices() {
        guard let url = URL(string: "http://iotsmeller.roshinator.com:8080/unknown-device?user_id=\(us.userid)") else { fatalError("Missing URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
               if let error = error {
                   print("Request error: ", error)
                   return
               }

               if let data = data {
                   DispatchQueue.main.async {
                       do {
                           unknownDevices = try JSONDecoder().decode([UnkownDeviceObject].self, from: data)
                       } catch let error {
                           print(error)
                       }
                   }
               }
           }
           dataTask.resume()
    }
}

struct UnknownDevicesListView2: View {
    let ukd: [UnkownDeviceObject]
    let sm: KnownDeviceObject
    @State private var confirmationMessage = ""
    @State private var showingConfirmationMessage = false
    @State private var selection: Set<UnkownDeviceObject> = []

    var body: some View {
        scrollForEach
            .background(.white)
        VStack {
        }.alert("Added Device", isPresented: $showingConfirmationMessage) {
            Button("OK") { }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    var list: some View {
        List(ukd) { device in
            UnkownDeviceView(device: device, isExpanded: self.selection.contains(device))
                .onTapGesture { self.addDevice(device) }
                .animation(.easeInOut(duration: 2), value: 1)
        }
    }
    
    var scrollForEach: some View {
        ScrollView {
            ForEach(ukd) { device in
                UnkownDeviceView(device: device, isExpanded: self.selection.contains(device))
                    .modifier(ListRowModifier())
                    .onTapGesture { self.addDevice(device) }
                    .animation(.easeInOut(duration: 2), value: 1)
            }
        }
    }
    
    func addDevice(_ device: UnkownDeviceObject) {
        let json: [String: Any] = [
            "device_id": device.device_id,
            "device_name": device.device_name ?? "",
            "user_id": device.user_id,
            "connection_status": "Offline",
            "severity": "Ok",
            "info_manf": sm.manf_name,
            "info_name": sm.device_name
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        guard let url = URL(string: "http://iotsmeller.roshinator.com:8080/device") else { fatalError("Missing URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = jsonData
        
        print(String(data: request.httpBody ?? Data(), encoding: .utf8)!)
        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
            guard let data = data, error == nil else {
                print(error?.localizedDescription ?? "No data")
                return
            }
            if let responseJSON = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                print(responseJSON)
                confirmationMessage = "Successully added device \(device.device_name ?? "Unkown Name")! Please return to the home page to view device statuses."
                showingConfirmationMessage = true
            } else {
                confirmationMessage = "Something went wrong with adding device. Please close and refresh the app to solve issue."
                showingConfirmationMessage = true
            }
        }
        dataTask.resume()
    }
}

struct AddDeviceView2_Previews: PreviewProvider {
    @State static var d = deviceInfo.knownDevices[0]
    
    static var previews: some View {
        AddDeviceView2(selectedManufacturer: d)
    }
}
