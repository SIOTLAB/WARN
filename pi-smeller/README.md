# Sniffer & Local Server Code For WARN
This repository contains the code for the local server and sniffers for WARN. It is responsible for the capture, analysis and relaying of information to the remote server.

# Sniffer
## Prerequisite
- Python 3.8+
- Nmap
- Kali Linux OS (Not required, but recommended)
- Raspberry Pi

## How It Works?
### General Design
The code is designed to run a pi that is connected via ethernet to the access point. It can then generate its own access point using the setup.sh script in the config-tool directory. Upon starting, the code opens a UDP client on port 20001 with at IP: 192.168.100.101(the device's own ip address on the network).

**Note**:All IP addresses used in this project were assigned as static via the router to facilitate the project. Therefore if you use the code change these values accordingly.

The code updates the list of devices to keep track of and propagates the information to sniffers.

A new thread is spawned that is responsible for looking for new devices on the network and periodically updating the status of already connected devices.

On the main thread, the code looks for incoming datagrams from the sniffers. It then unpacks the recieved datagrams and perform analysis on the counters. 

### Analysis
If the deauthentication counters show a value of more than 10, a deauthentication attack might have occured. Based on testing, we have determined different numbers of packets per seconds(pps) needed to take offline a device. This information is stored on the remote server and retrieved when the list of devices is updated. If that number of pps is met, an attack is reported to the remote server. Else, a warning is reported.

In either case, another thread is spawned and a disconnection check is performed on the device that was attacked. If the status was originally reported as a warning and the device goes offline, we update the status as being an attack.

To detect a KRACK attack, we check for counter values of at least 4, indicating at least a triple exchange of the third and fourth messages of the WPA2 4-way handshake. In this case, we report it as an attack to the remote server.

## How To Run?
```
python3 monitor2.py
```
# Sniffer
## Prerequisite
- Python 3.8+
- Pyshark
- Kali Linux OS (Not required, but recommended)
- Raspberry Pi

## How it works?
### General Overview
The capture code works by creating a UDP client and connecting to the Local Server, which sends the devices to keep track of. Detectors are created for deauthentication and KRACK attacks. For each detector type, a Berkeley Packet Filter(BPF) is created. The filters are then passed to pyshark and scanning is performed. The sniffers then periodically sends counters to the Local Server.

### What We Look For
To detect deauthentication attacks, we look for deauthentication packets denoted by the value 0x00c in pyshark(and wireshark as well). The filter to detect deauthentication is therefore `wlan.fc.type_subtype == 0x000c`.

To detect KRACK, we look for retransmissions of messages 3 and 4 in the 4-way handshake. To detect the 4-way handshake we need to look for transmissions of type EAPOL in pyshark.

## How To Run?
```
sudo iwconfig <interface> mode monitor

sudo python3 capture2.py
```

## Testing KRACK
While we are able to use our detection logic for KRACK, we are not able to directly test it. This is because we were not able to create the attack ourselves due to time constraints. Instead, we made use of the [test scripts developed by Mathy Vanhoef](https://github.com/vanhoefm/krackattacks-scripts). However, these scripts cannot be run on our network directly but rather through one of our computers. In order to check our code for KRACK, we made use of the capture2_test_KRACK.py, which reads a pcapng file we obtained from running the attack through our machine. The script then operates as if it were normal sniffer, sending KRACK counters to the Local Server. We can run the script the test following way:
```
sudo iwconfig <interface> mode monitor

sudo python3 capture2_test_KRACK.py
```
**Note:** 
1. Update file to be read in capture2_test_KRACK.py.
2. A sample pcapng file has been provided to test the code.