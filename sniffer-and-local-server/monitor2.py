#Script for the Local Server that runs on the main Pi that has a wired connection with the router.
#Responsible for consolidating data from sniffers, scanning the network, identifying attacks, and notifying the remote server

import pyshark
import socket
import pickle
import time
import threading
import random
import nmap
import requests

server_id = '69696969-4200-4200-4200-696969696969'

#List of MAC addresses of testing devices for quick reference:
#     [{'mac':"90:48:6c:d9:c8:12", 'pps':300}, #Ring Camera
#      {'mac':"1c:53:f9:56:50:6a", 'pps':100}, #Nest Camera
#      {'mac':"78:9c:85:33:8e:91", 'pps':10},  #Smart Lock
#      {'mac':"44:4a:db:06:7a:fb", 'pps':10}]  #iPhone

def get_device_lists():

    unknown_url = f'http://iotsmeller.roshinator.com:8080/unknown-device?user_id={server_id}'
    device_url = f'http://iotsmeller.roshinator.com:8080/device?user_id={server_id}'

    unknown_devices = requests.get(unknown_url).json()
    devices = requests.get(device_url).json()

    return devices, unknown_devices



#Get device list from remote server
print("[Main] Getting device list from remote server...")
device_list, unadded_list = get_device_lists()
mac_list = [d['device_id'] for d in device_list]
is_attacked_deauth_2 = {}
is_attacked_krack_2 = {}
is_attacked_deauth_3 = {}
is_attacked_krack_3 = {}


print("[Main] Device List:")
for device in device_list:
    print("[Main]", device['device_id'], device['pps'])
    is_attacked_deauth_2[device['device_id']] = False
    is_attacked_deauth_3[device['device_id']] = False
    is_attacked_krack_2[device['device_id']] = False
    is_attacked_krack_3[device['device_id']] = False
print()

addresses = {}
detected_devices = set()
start_time = 0

#Create and start thread to periodically update device_list and check status of devices
print("[Main] Creating and Starting Update_List Thread...")
lock = threading.Lock()
def update_periodically():
    global device_list
    global unadded_list
    global addresses
    global mac_list
    global is_attacked_deauth
    global is_attacked_krack
    global detected_devices
    global start_time

    while True:
        #No need to worry about drifting in this thread, a simple sleep() call will do.
        time.sleep(10)
        with lock:
            print("[Update_List] Updating device list from remote server...")
            device_list, unadded_list = get_device_lists()
            mac_list = [d['device_id'] for d in device_list]
            print("[Update_List] New list: ")
            for device in device_list:
                print("[Update_List]", device['device_id'], device['pps'])
                if device['device_id'] not in is_attacked_deauth_2.keys():

                    is_attacked_deauth_2[device['device_id']] = False
                    is_attacked_deauth_3[device['device_id']] = False
                    is_attacked_krack_2[device['device_id']] = False
                    is_attacked_krack_3[device['device_id']] = False
            dl = {}
            for device in device_list:
                dl[device['device_id']] = device
            print()
            unknown_list = {}
            for device in unadded_list:
                unknown_list[device['device_id']] = device

        print("[Update_List] Performing Network Scans")
        for x in range(5):
            #Perform Scan
            print("[Update_List] Scan #",x+1)
            nm = nmap.PortScanner()
            scan = nm.scan(hosts='192.168.100.0/24', arguments='-sn')
            
            for ip in scan['scan'].keys():
                
                if 'mac' in scan['scan'][ip]["addresses"]:
                    mac = scan['scan'][ip]["addresses"]['mac'].lower()
                    name = scan['scan'][ip]['hostnames'][0]['name'].replace(".lan", "")
                    addresses[mac] = ip
                    
                    if scan['scan'][ip]['vendor'] != {}:
                        vendor = scan['scan'][ip]['vendor'][mac.upper()]
                    else:
                        vendor = 'Other'
                    
                    if mac in dl.keys(): 
                        print("[Update_List]", mac, "is connected")
                        dl[mac]['connection_status'] = 'Online'
                        body = dl[mac]
                        body['no_notify'] = True
                        detected_devices.add(mac)
                        
                        requests.put('http://iotsmeller.roshinator.com:8080/device', json=dl[mac])
                        del dl[mac]

                    elif mac not in unknown_list.keys() and mac not in mac_list:
                        print("[Update_List]", mac, "found (New Unadded Device). Notifying Remote Server")
                        #POST add unknown device
                        unknown_url = f'http://iotsmeller.roshinator.com:8080/unknown-device'
                        body = {
                            "device_id": mac,
                            "user_id": server_id,
                            "device_name": name,
                            "device_vendor":vendor
                        }

                        try:
                            res = requests.post(unknown_url, json=body)
                            unknown_list[mac] = res.json()
                        except:
                            print("UA DEVICE EXCEPTION")

        if time.time() - start_time > 6000:
            for mac in mac_list:
                if mac not in detected_devices:
                    body = dl[mac]
                    dl[mac]['connection_status'] = 'Offline'
                    body['connection_status'] = 'Offline'
                    requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
                    print(f'[UPDATE_LIST] {mac} disconnected. Notifying remote server.')

            start_time = time.time()
            detected_devices.clear()

    print()

def check_disconnection(ip, body):

    global device_list

    print("[Check_Disconnection] Performing Network Scans")
    is_disconnected = True
    scan = {}

    for x in range(5):
        #Perform Scan
        print("[Check_Disconnection] Scan #",x+1)
        nm = nmap.PortScanner()
        scan = nm.scan(hosts=ip, arguments='-sn')
    
        if scan['scan'] != {}:
            is_disconnected = False
            print("[Check_Disconnection]", scan['scan'][ip]['addresses']['mac'], "is connected.")
            break

    with lock:
        if is_disconnected:
            body['connection_status'] = 'Offline'
            body['no_notify'] = True
            requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
        else:
            body['connection_status'] = 'Online'
            body['no_notify'] = True
            requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)


Update_List = threading.Thread(target = update_periodically)
Update_List.start()

#UDP Server
print("[Main] Starting UDP server...")
mySocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
mySocket.bind(("", 20001))
buff = 1024

#Listen for incoming datagrams
print("[Main] Listening for incoming datagrams...")
while True:
    message, address = mySocket.recvfrom(buff)
    pi, attack_type, max_time, counters = pickle.loads(message)

    if pi == -1: # Sniffer requests device list
        print("[Main]",address,"is requesting device list, sending now...")
        print()
        with lock:
            mySocket.sendto(pickle.dumps(mac_list), address)
    else:
        print("[Main] Message Received from " + str(address) + " (PI #" + str(pi) + ")")
        print("[Main] Attack Type:", attack_type)
        print("[Main] Max Time: "+ str(max_time))
        for device in counters.keys():
            print("[Main]", device, counters[device])
        with lock:
            
            for device in counters.keys():
                if device not in mac_list:
                    continue

                severe_pps = 1
                body = {}
                for d in device_list:
                    if device == d['device_id']:
                        severe_pps = d['pps']
                        body = d
                

                if attack_type == "deauth":
                    if counters[device] > 10:

                        if counters[device] < severe_pps:
                            print("[Main] DEAUTHENTICATION ATTACK DETECTED ON", device)
                            body['severity'] = 'Warning'
                            body['attack_type'] = 'Deauthentication'
                    
                        elif counters[device] >= severe_pps:
                            print("[Main] DEAUTHENTICATION ATTACK DETECTED ON", device)
                            body['severity'] = 'Attack'
                            body['attack_type'] = 'Deauthentication'

                        if not is_attacked_deauth_2[device] and not is_attacked_deauth_3[device]:
                            body['no_notify'] = False
                            res = requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
                            print("[Main] REPORTED ATTACK TO REMOTE SERVER, MAC = ", device)
                        
                        if pi == 2:
                            is_attacked_deauth_2[device] = True
                        elif pi == 3:
                            is_attacked_deauth_3[device] = True
                        if device in addresses.keys():
                            Disconnection_Check = threading.Thread(target = check_disconnection, args=(addresses[device], body))
                            Disconnection_Check.start()
                        else:
                            body['connection_status'] = 'Offline'
                            requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
                    else:
                        if pi == 2:
                            is_attacked_deauth_2[device] = False
                        elif pi == 3:
                            is_attacked_deauth_3[device] = False
        
                if attack_type == "KRACK":
                    if counters[device] >= 4:
                        
                        print("[Main] KRACK DETECTED ON", device)
                    
                        #POST history to remote server
                        body['severity'] = 'Attack'
                        body['attack_type'] = 'Krack'
                    
                        if not is_attacked_krack_2[device] and not is_attacked_krack_3[device]:
                            requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
                            print("[Main] REPORTED STATE TO REMOTE SERVER, RES = ", res)
                        if pi == 2:
                            is_attacked_krack_2[device] = True
                        elif pi == 3:
                            is_attacked_krack_3[device] = True
                        del body['severity']
                        del body['attack_type']

                        if device in addresseses.keys():
                            Disconnection_Check = threading.Thread(target = check_disconnection, args=(addresses[device], body))
                            Disconnection_Check.start()
                    
                        else:
                            body['connection_status'] = 'Offline'
                            requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
                    else:
                        if pi == 2:
                            is_attacked_krack_2[device] = False
                        elif pi == 3:
                            is_attacked_krack_3[device] = False   
                if is_attacked_deauth_3[device] == False and is_attacked_deauth_2[device] == False:
                    if is_attacked_krack_3[device] == False and is_attacked_krack_2[device] == False:
                        if 'attack_type' in body.keys():
                            del body['attack_type']
                        body['severity'] = 'Ok'
                        res = requests.put('http://iotsmeller.roshinator.com:8080/device', json=body)
                        print("[Main] REPORTED NORMAL STATE TO REMOTE SERVER, RES = ", res)


        print()
