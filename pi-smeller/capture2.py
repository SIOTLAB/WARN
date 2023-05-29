#Script for WARN Sniffers

#Before running:
#Connect internal Wi-Fi card to PiAP network
#Set external Wi-Fi card to monitor on the correct channel with: sudo iwconfig wlan1 mode monitor channel 4
#Put unique identifier in ../pi.conf

import pyshark
import socket
import pickle
import time
import threading
import os
import sys
from detector import *

monitor_interface = "wlan1"

#UDP client
print("[Main] Starting UDP client...")
dst = ("192.168.100.101", 20001) # (address, port) address = pi-1 ip
mySocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
buff = 1024
mySocket.settimeout(1)

#Get Device List
print("[Main] Getting Device List From Local Server...")
device_list=[]
while True:
    try:
        mySocket.sendto(pickle.dumps((-1,0,0,0)),dst)
        message, address = mySocket.recvfrom(buff)
        device_list = pickle.loads(message)
        if device_list == []:
            time.sleep(10)
            continue
        break
    except socket.timeout:
        print("[Main] Unable to get device list. Retrying...")

print("[Main] Device list: ")
for device in device_list:
    print("[Main]", device)
print()

#Pi ID number
print("[Main] Getting Pi ID...")
f = open("../pi.conf", "r")
pi = int(f.read(1))
f.close()

#Build BPF
print("[Main] Building BPF...")
bpf = "ether host " + device_list[0]
for d in device_list[1:]:
    bpf +=" or ether host " + d

#Initialize Detectors
print("[Main] Initializing Detectors...")
detectors = []
detectors.append(detector("deauth", "wlan.fc.type_subtype == 0x000c", deauth, {device:0 for device in device_list}))
detectors.append(detector("KRACK","eapol", KRACK, {device:0 for device in device_list}))

#Create Live Capture
print("[Main] Creating Live Capture...")
#Build Display Filter
df = detectors[0].display_filter
for d in detectors[1:]:
    df += " or " + d.display_filter
capture = pyshark.LiveCapture(bpf_filter = bpf, interface = monitor_interface, display_filter = df) # dont set monitor_interfece = true. set to monitor mode manually to avoid issues
capture.set_debug()

#Create and start thread to periodically send counters to LS
print("[Main] Creating and Starting Send_Counters Thread...")
lock = threading.Lock()
interval = 10
def send_periodically():
    t = round(time.time(), 0)
    t = t - t%interval + interval
    while True:
        curr = time.time()
        if curr > t:
            with lock:
                for d in detectors:
                    print("[Send_Counters] Sending "+d.name+" counters to " + str(dst))
                    print("[Send_Counters] Max Time: "+ str(t))
                    for device in d.devices:
                            print("[Send_Counters]",device, d.counters[device])
                    print()
                    mySocket.sendto(pickle.dumps((pi, d.name, t, d.counters)), dst)
                    for device in d.devices:
                        d.counters[device] = 0
            while t < time.time():
                t = t + interval
        else:
            time.sleep(t - curr)
Send_Counters = threading.Thread(target = send_periodically)
Send_Counters.start()

#Create and start thread to periodically update device_list
print("[Main] Creating and Starting Update_List Thread...")
def update_periodically():
    while True:
        #No need to worry about drifting in this thread, a simple sleep() call will do.
        time.sleep(60)
        with lock:
            print("[Update_List] Requesting updated device list...")
            while True:
                try:
                    mySocket.sendto(pickle.dumps((-1, 0, 0, 0)),dst)
                    message, address = mySocket.recvfrom(buff)
                    break
                except socket.timeout:
                    print("[Update_List] Unable to get device list. Retrying...")
            new_device_list = pickle.loads(message)
            if new_device_list == device_list:
                print("[Update_List] Device list is up to date")
                print()
            else:
                print("[Update_List] New device list found, restarting... ")
                os.execl(sys.executable, 'python3', 'capture2.py')
Update_List = threading.Thread(target = update_periodically)
Update_List.start()
            

#Scan
while True:
    print("[Main] Scanning...")
    for packet in capture.sniff_continuously():
         with lock:
            for d in detectors:
                d.inc_counter(packet, d.detect(packet))
