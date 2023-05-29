#Detect functions return how much to inc counters by

def deauth(packet):
	if str(packet.wlan.fc_type_subtype).lower() == "0x000c":
		return 1
	return 0
	
#M1 and M2 decrement, M3 and M4 increment
def KRACK(packet):
	if "EAPOL" in packet:
		if packet["EAPOL"].wlan_rsna_keydes_msgnr == "3" or packet["EAPOL"].wlan_rsna_keydes_msgnr == "4":
			return 1
		elif packet["EAPOL"].wlan_rsna_keydes_msgnr == "1" or packet["EAPOL"].wlan_rsna_keydes_msgnr == "2":
			return -1
	return 0

def beacon(packet):
	if str(packet.wlan.fc_type_subtype).lower() == "0x0008":
		return 1
	return 0

class detector:

	def __init__(self, name, display_filter, detect, counters):
		self.name = name
		self.display_filter = display_filter
		self.detect = detect
		self.counters = counters
		self.devices = self.counters.keys()

	def inc_counter(self, packet, i):
		if i == 0:
			return
		if str(packet.wlan.sa).lower() in self.devices:
			self.counters[str(packet.wlan.sa).lower()] = self.counters[str(packet.wlan.sa).lower()] + i
		elif str(packet.wlan.da).lower() in self.devices:
			self.counters[str(packet.wlan.da).lower()] = self.counters[str(packet.wlan.da).lower()] + i
		elif str(packet.wlan.ta).lower() in self.devices:
			self.counters[str(packet.wlan.ta).lower()] = self.counters[str(packet.wlan.ta).lower()] + i
		elif str(packet.wlan.ra).lower() in self.devices:
			self.counters[str(packet.wlan.ra).lower()] = self.counters[str(packet.wlan.ra).lower()] + i

	#Special function to inc counter through a wired connection.
	def inc_counter_eth(self, packet, i):
		if i == 0:
			return
		if str(packet.eth.src) in self.devices:
			self.counters[str(packet.eth.src).lower()] = self.counters[str(packet.eth.src).lower()] + i
		elif str(packet.eth.dst) in self.devices:
			self.counters[str(packet.eth.dst).lower()] = self.counters[str(packet.eth.dst).lower()] + i