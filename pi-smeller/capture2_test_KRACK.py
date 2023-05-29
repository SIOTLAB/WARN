#Script to test KRACK capturing.
#Because of the dangerous nature of KRACK, We used prerecorded PCAP files of attacks to test our snifffing capabilities.

import pyshark
import socket
import pickle
import time
import threading
import os
import sys
from detector import *

#UDP client
print("[Main] Starting UDP client...")
dst = ("192.168.100.101", 20001) # (address, port) address = pi-1 ip
mySocket = socket.socket(family=socket.AF_INET, type=socket.SOCK_DGRAM)
buff = 1024
mySocket.settimeout(1)

#Get Device List
print("[Main] Getting Device List From Local Server...")
while True:
    try:
        mySocket.sendto(pickle.dumps((-1,0,0,0)),dst)
        message, address = mySocket.recvfrom(buff)
        break
    except socket.timeout:
        print("[Main] Unable to get device list. Retrying...")
device_list = pickle.loads(message)
print("[Main] Device list: ")
for device in device_list:
    print("[Main]", device)
print()

#Pi ID number
pi = 2

#Build BPF
print("[Main] Building BPF...")
bpf = "ether host " + device_list[0]
for d in device_list[1:]:
    bpf +=" or ether host " + d

#Initialize Detectors
print("[Main] Initializing Detectors...")
detectors = []
detectors.append(detector("KRACK","eapol", KRACK, {device:0 for device in device_list}))

#Create Live Capture
print("[Main] Creating File Capture...")
#Build Display Filter
df = detectors[0].display_filter
for d in detectors[1:]:
    df += " or " + d.display_filter
capture = pyshark.FileCapture(input_file = './KRAK.pcapng', display_filter = df)

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
        time.sleep(10)
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
                os.execl(sys.executable, 'python3', 'capture2_test_KRACK.py')
Update_List = threading.Thread(target = update_periodically)
Update_List.start()
            
#Scan
print("[Main] Scanning...")
start_time = time.time()
sniff_start = float(capture[0].sniff_timestamp)
for packet in capture:
    #Spin Lock to simulate timing.
    while time.time() - start_time < float(packet.sniff_timestamp) - sniff_start:
        pass
    print(float(packet.sniff_timestamp))
    with lock:
        for d in detectors:
            d.inc_counter_eth(packet, d.detect(packet))
