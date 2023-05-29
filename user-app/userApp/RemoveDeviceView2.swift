//
//  AddDeviceView.swift
//  userApp
//
//  Created by Jaden Ngo on 4/7/23.
//

import SwiftUI

struct RemoveDeviceView2: View {
    @EnvironmentObject var us: UserState
    @State private var confirmationMessageDevice = ""
    @State private var showingConfirmationDevice = false
    @State var connectedDevices: [DeviceObject] = []
    var selectedManufacturer: KnownDeviceObject
    
    var body: some View {
        VStack {
            Spacer()
                .frame(height: 25)
            
            Image(systemName: "shield.lefthalf.filled").resizable().frame(width: 50, height: 50).foregroundColor(CustomColor.lightBlue)
            Text("WARN").bold()
            Spacer()
                .frame(height: 50)
            
            Text("Remove Device With Manufacturer: ").bold().font(.title2)
                .frame(maxWidth: 400, alignment: .center).offset()
            Text("\(selectedManufacturer.manf_name)").bold().font(.title2).frame(maxWidth: 350, alignment: .center).offset().foregroundColor(CustomColor.lightBlue)
            Spacer()
            
            DevicesListView2(devices: connectedDevices, sm: selectedManufacturer)
            
            Text("\n")
        }.onAppear(perform: getConnectedDevices)
    }
    
    func getConnectedDevices() {
        guard let url = URL(string: "http://iotsmeller.roshinator.com:8080/device?user_id=\(us.userid)") else { fatalError("Missing URL") }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"

        let dataTask = URLSession.shared.dataTask(with: request) { (data, response, error) in
           if let error = error {
               print("Request error: ", error)
               return
           }

           guard let response = response as? HTTPURLResponse else { return }

           if let data = data {
               DispatchQueue.main.async {
                   do {
                       connectedDevices = try JSONDecoder().decode([DeviceObject].self, from: data)
                   } catch let error {
                       confirmationMessageDevice = "Something went wrong. Please close and refresh the app to solve issue."
                       showingConfirmationDevice = true
                   }
               }
           }
       }
       dataTask.resume()
    }
}


struct DevicesListView2: View {
    let devices: [DeviceObject]
    let sm: KnownDeviceObject
    @State private var confirmationMessage = ""
    @State private var showingConfirmationMessage = false
    @State private var selection: Set<DeviceObject> = []

    var body: some View {
        scrollForEach
            .background(.white)
        VStack {
        }.alert("Removed Device", isPresented: $showingConfirmationMessage) {
            Button("OK") { }
        } message: {
            Text(confirmationMessage)
        }
    }
    
    var list: some View {
        List(devices) { device in
            DeviceView(device: device, isExpanded: self.selection.contains(device))
                .onTapGesture { self.selectDeselect(device) }
                .animation(.easeInOut(duration: 2), value: 1)
        }
    }
    
    var scrollForEach: some View {
        ScrollView {
            ForEach(devices) { device in
                DeviceView(device: device, isExpanded: self.selection.contains(device))
                    .modifier(ListRowModifier())
                    .onTapGesture { self.removeDevice(device) }
                    .animation(.easeInOut(duration: 2), value: 1)
            }
        }
    }
    
    private func selectDeselect(_ device: DeviceObject) {
        if selection.contains(device) {
            selection.remove(device)
        } else {
            closeOthers()
            selection.insert(device)
        }
    }
    
    private func closeOthers() {
        selection.removeAll()
    }
    
    func removeDevice(_ device: DeviceObject) {
        let json: [String: Any] = [
            "device_id": device.device_id,
            "device_name": device.device_name,
            "user_id": device.user_id,
            "connection_status": "Offline",
            "severity": "Attack",
            "info_manf": sm.manf_name,
            "info_name": sm.device_name
        ]
        let jsonData = try? JSONSerialization.data(withJSONObject: json)
        
        guard let url = URL(string: "http://iotsmeller.roshinator.com:8080/device") else { fatalError("Missing URL") }
        var request = URLRequest(url: url)
        request.httpMethod = "DELETE"
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
                confirmationMessage = "Successully removed device \(device.device_name)! Please return to the home page to view device statuses."
                showingConfirmationMessage = true
            } else {
                confirmationMessage = "Something went wrong with removing device. Please close and refresh the app to solve issue."
                showingConfirmationMessage = true
            }
        }
        dataTask.resume()
    }
}

struct RemoveDeviceView2_Previews: PreviewProvider {
    @State static var d = deviceInfo.knownDevices[0]
    
    static var previews: some View {
        RemoveDeviceView2(selectedManufacturer: d)
    }
}
