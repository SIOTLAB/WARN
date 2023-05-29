//
//  DeviceView.swift
//  userApp
//
//  Created by Jaden Ngo on 1/26/23.
//

import SwiftUI
import Foundation
import UserNotifications

struct AttackView: View {
    let attack: AttackObject
    let isExpanded: Bool
   
    var body: some View {
        
        HStack {
            content
            Spacer()
        }
        .contentShape(Rectangle())
    }
    
    private var content: some View {
        
        VStack(alignment: .leading) {
            
            HStack {
                let statusColor = getColor(status: attack.severity)
                Text("\(attack.attack_type ?? "Unkown Attack Type")").font(.title3)
                Image(systemName: "circle.fill").resizable().frame(width: 10, height: 10).foregroundColor(statusColor)
                Spacer()
                Text("\(attack.timestampString ?? "")")
                Spacer()
            }
            
            if isExpanded {
                VStack(alignment: .leading) {
                    HStack {
                        Text("Affected Device: ").font(.subheadline)
                        Text("\(attack.device_name ?? "Unkown Name")").font(.subheadline)
                    }
                    if (attack.severity == "Attack") {
                        Text("Identified as an attack!").font(.subheadline)
                    } else if (attack.severity == "Warning") {
                        Text("Identified as an warning. This could indicate an attempted attack!").font(.subheadline)
                    }
                }
            }
        }
    }
    
    func getColor(status: String) -> Color {
        if (status == "Warning") {
            return .yellow
        } else if (status == "Attack") {
            return .red
        } else {
            return .gray
        }
    }
}

struct AttacksListView: View {
    let attacks: [AttackObject]
    @State private var selection: Set<AttackObject> = []

    var body: some View {
        scrollForEach
            .background(.white)
    }
    
    var list: some View {
        List(attacks) { attack in
            AttackView(attack: attack, isExpanded: self.selection.contains(attack))
                .onTapGesture { self.selectDeselect(attack) }
                .animation(.easeInOut(duration: 2), value: 1)
        }
    }
    
    var scrollForEach: some View {
        ScrollView {
            ForEach(attacks) { attack in
                AttackView(attack: attack, isExpanded: self.selection.contains(attack))
                    .modifier(ListRowModifier())
                    .onTapGesture { self.selectDeselect(attack) }
                    .animation(.easeInOut(duration: 2), value: 1)
            }
        }
    }
    
    private func selectDeselect(_ attack: AttackObject) {
        if selection.contains(attack) {
            selection.remove(attack)
        } else {
            closeOthers()
            selection.insert(attack)
        }
    }
    
    private func closeOthers() {
        selection.removeAll()
    }
}

struct AttacksList_Previews: PreviewProvider {
    static var previews: some View {
        let a: [AttackObject] = []
        AttacksListView(attacks: a)
    }
}

struct AttackPageView: View {
    @EnvironmentObject var us: UserState
    @State private var confirmationMessageDevice = ""
    @State private var showingConfirmationDevice = false
    @State var attacks: [AttackObject] = []
    
    var body: some View {

            NavigationView {
                VStack {
                    Spacer()
                        .frame(height: 25)
                    
                    Image(systemName: "shield.lefthalf.filled").resizable().frame(width: 50, height: 50).foregroundColor(CustomColor.lightBlue)
                    Text("WARN").bold()
                    Spacer()
                        .frame(height: 50)
                    
                    Text("Past 5 Days").bold().font(.title2)
                        .frame(maxWidth: 350, alignment: .leading)

                    AttacksListView(attacks: attacks.filter {$0.timestampDate! >= getDate(days: 5) } )
                    
                    Spacer()
                    
                    Text("Previous").bold().font(.title2)
                        .frame(maxWidth: 350, alignment: .leading)
                    
                    AttacksListView(attacks: attacks.filter {$0.timestampDate! < getDate(days: 5) } )
                    
                    Text("\n")
                }
                .background(CustomColor.lightGray)
                .alert("Attack History!", isPresented: $showingConfirmationDevice) {
                            Button("OK") { }
                        } message: {
                            Text(confirmationMessageDevice)
                        }
                .background(CustomColor.lightGray)
            }.onAppear(perform: getAttackHistory)
        }
    
    func getAttackHistory() {
        guard let url = URL(string: "http://iotsmeller.roshinator.com:8080/history?user_id=\(us.userid)&count=20") else { fatalError("Missing URL") }

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
                           attacks = try JSONDecoder().decode([AttackObject].self, from: data)
                           if (attacks.isEmpty) {
                               confirmationMessageDevice = "Your attack history is currently empty. This is great news!"
                               showingConfirmationDevice = true
                           }
                           print("attacks: \(attacks)")
                       } catch let error {
                           confirmationMessageDevice = "Something went wrong with retreiving attack history. Please close and refresh the app the solve the issue."
                           showingConfirmationDevice = true
                       }
                   }
               }
           }
           dataTask.resume()
    }
     
    func getDate(days: Int) -> Date {
        let df = DateFormatter()
        df.dateStyle = .medium
        df.timeStyle = .medium
        
        let date = Date()
        let result = Calendar.current.date(byAdding: .day, value: -days, to: date)
        return result!
    }
}

struct AttackView_Previews: PreviewProvider {
    @State static var activeTab = 3
    
    static var previews: some View {
        AttackPageView().tag(3)
    }
}


/* References
 - Expandable list functionality inspired by: V8tr, https://github.com/V8tr/ExpandableListSwiftUI
 */
