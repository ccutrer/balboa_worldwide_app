MAC addresses beginning with 00:15:27 belong to Balboa Instruments (useful for looking at DHCP leases to find your Spa's IP address without using discovery)

For discovery, send a UDP broadcast to port 30303. The spa (and possibly other devices on your network!) will respond (unicast) with two lines (CRLF endings). The first line is the hostname (BWGSPA), and the second line is its MAC address. Currently I'm filtering responses by Balboa's MAC prefix.

The Spa listens on port 4257. Once you connect via TCP, it immediately starts sending you status updates, about once per second.

A message (either status update, or command) looks like:

01 02 03 04 05 ... -2 -1
MS ML MT MT MT ... CB ME

MS, ME: Message Start/End (always 0x7e "~")
MT: Message Type
ML: Message Length
CB: Check Byte (CRC-8 with 0x02 initial value, and 0x02 final XOR)

Status update (this message is sent every second):
 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
00 F1 CT HH MM F2 00 00 00 F3 F4 PP 00 CP LF 00 00 00 00 00 ST 00 00 00

Message Type: ff af 13

CT: Current Temperature (divide by two if in Celsius; ff if unknown)
ST: Set Temperature (ditto)

Flags 1: 0x01 = Priming

Flags 2: 0x03 = Heating Mode (0 = Ready, 1 = Rest, 3 = Ready in rest)

Flags 3: 0x01 = Temperature Scale (0 = Fahrenheit, 1 = Celsius)
         0x02 = 24 Hour Time (0 = 12 hour time, 1 = 24 hour time)

Flags 4: 0x30 = Heating (seems it can be 0, 1, or 2)
         0x04 = Temperature Range (0 = Low, 1 = High)

PP: Pump status: 0x03 for pump 1, 0x12 for pump 2 (or, shift two bits off, and then mask to 0x03). Valid values for each are 0, 1 or 2.

CP: Circ pump: 0x02 = on

LF: Light flag: 0x03 == 0x03 for on (I only have one light, and the app displays "Light 1", so I don't know why it's using two bits)

HH: Hour (always 0-24, even in 12 hour mode; flag is used to control display)
MM: Minute

Filter configuration (this message is sent to all connected clients when any client sends some sort of command requesting it):

Message type: 0a bf 23

 0  1  2  3  4  5  6  7
1H 1M 1D 1E 2H 2M 2D 2E

1H: Filter 1 start hour (always 0-24)
1M: Filter 1 start minute
1D: Filter 1 duration hours
1E: Filter 2 duration minutes

2H: Filter 2 start hour, masking out the high order bit, which is used as an enable/disable flag
2M: Filter 2 start minute
2D: Filter 2 duration hours
2E: Filter 2 duration minutes

Configuration request? (the app sends this message shortly after connecting):

Message type: 0a bf 04

No content

CB: 77

Configuration response? (sent in response to the above):

Message type 0a bf 94

 1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
02 02 80 00 15 27 10 ab d2 00 00 00 00 00 00 00 00 00 15 27 ff 10 ab d2

Filter configuration request (must have previously sent general configuration request):

Message type: 0a bf 22

 1  2  3
01 00 00

CB 34

Control request:

Message type 0a bf 11

 1  2
II 00

II - item:
  11 - light 1 (CB 93)
  04 - pump 1 (CB 85)
  05 - pump 2 (CB 90)
  
Set temperature:

Message type 0a bf 20

 1
TT

TT - the temperature, doubled if in Celsius

range is 80-104 for F, 26-40 for C in high range
range is 50-80 for F, 10-26 for C in low range

Set time:

Message type 0a bf 21

 1  2
HH MM

HH - Hour. The high bit enables 24-hour time
MM - Minute

Set Wi-Fi Settings:

Message type 0a bf 92

 1  2 ...                             36 37 ....
01 SL <32 bytes of SSID; null padded> 08 PL <64 bytes of the passkey; null padded>

SL - SSID length
PL - passkey length