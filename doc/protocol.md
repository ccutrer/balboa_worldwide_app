MAC addresses beginning with 00:15:27 belong to Balboa Instruments (useful for looking at DHCP leases to find your Spa's IP address without using discovery)

For discovery, send a UDP broadcast to port 30303. The spa (and possibly other devices on your network!) will respond (unicast) with two lines (CRLF endings). The first line is the hostname (BWGSPA), and the second line is its MAC address. Currently I'm filtering responses by Balboa's MAC prefix.

The Spa listens on port 4257. Once you connect via TCP, it immediately starts sending you status updates, about once per second.

When using RS-485, it's 115200,8,N,1.

A message (either status update, or command) looks like:

```
 0 1  2  3  4  ... -2 -1
MS ML MT MT MT ... CS ME
```

* MS, ME: Message Start/End (always 0x7e "~")
* MT: Message Type
* ML: Message Length
* CS: Checksum (CRC-8 with 0x02 initial value, and 0x02 final XOR)

## Incoming Messages

### Ready
Sent on RS-485 only, when commands can be sent. Because RS-485 is a shared bus, you can't just send messages whenever you want, or they'll clobber each other. This message indicates it's safe to _immediately_ send a message onto the bus.

Message type 10 bf 06

### Configuration Response
Sent in response to a configuration request.

Message type 0a bf 94

```
 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24
02 02 80 00 15 27 10 ab d2 00 00 00 00 00 00 00 00 00 15 27 ff ff 10 ab d2
```

### Status Update
This message is sent every second.

```
 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22 23
F0 F1 CT HH MM F2 00 00 00 F3 F4 PP 00 F5 LF 00 00 00 00 00 ST 00 00 00
```

Message Type: ff af 13

* CT: Current Temperature (divide by two if in Celsius; ff if unknown)
* ST: Set Temperature (ditto)
* Flags 0:
  * 0x05 = Hold Mode
* Flags 1:
  * 0x01 = Priming
* Flags 2:
  * 0x03 = Heating Mode (0 = Ready, 1 = Rest, 3 = Ready in rest)
* Flags 3:
  * 0x01 = Temperature Scale (0 = Fahrenheit, 1 = Celsius)
  * 0x02 = 24 Hour Time (0 = 12 hour time, 1 = 24 hour time)
* Flags 4:
  * 0x30 = Heating (seems it can be 0, 1, or 2)
  * 0x04 = Temperature Range (0 = Low, 1 = High)
* Flags 5:
  * 0x02 = Circulation pump
  * 0x0C = Blower
* PP: Pump status: 0x03 for pump 1, 0x0C for pump 2 (or, shift two bits right, and then mask to 0x03), 0x30 for pump 3 (or, shift 4 bits right, and then mask to 0x3). Valid values for each are 0, 1 or 2.
* LF: Light flag: 0x03 == 0x03 for on (I only have one light, and the app displays "Light 1", so I don't know why it's using two bits)
* HH: Hour (always 0-24, even in 12 hour mode; flag is used to control display)
* MM: Minute

### Filter Cycles Response
This message is sent to all connected clients when any client sends a filter cycles request.

Message type: 0a bf 23

```
 0  1  2  3  4  5  6  7
1H 1M 1D 1E 2H 2M 2D 2E
```

* 1H: Filter 1 start hour (always 0-24)
* 1M: Filter 1 start minute
* 1D: Filter 1 duration hours
* 1E: Filter 2 duration minutes
* 2H: Filter 2 start hour, masking out the high order bit, which is used as an enable/disable flag
* 2M: Filter 2 start minute
* 2D: Filter 2 duration hours
* 2E: Filter 2 duration minutes

### Information Response
In response to a control configuration request type 1.

Message type: 0a bf 24

```
 0  1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20
SI SI SV SV SM SM SM SM SM SM SM SM SU CS CS CS CS HT HT DS DS
64 dc 11 00 42 46 42 50 32 30 20 20 01 3d 12 38 2e 01 0a 04 00
```

* SI: Software ID (SSID). Ex.: "M100_220"
* SV: Software ID (SSID) Version. Ex.: "V17"
* SM: System Model, in ASCII. Ex.: "BFBP20  "
* SU: Current Setup
* CS: Configuration Signature. Ex.: "3D12382E"
* HV: Heater Voltage:
  * 0x01 = 240V
* HT: Heater Type
  * 0x0A = Standard
* DS: DIP Switch Settings. Ex.: "1000000000"

### Fault Log Response
Message type 0a bf 28

```
 0  1  2  3  4  5  6  7  8  9
FC EN MC DD HH MM FF ST TA TB
```
* FC: Fault Count
* EN: Entry Number
* MC: Message Code
* DD: Days Ago
* HH: Time Hours
* MM: Time Minutes
* FF: Flags (Heating Mode, Temp. Range)
* ST: Set Temperature
* TA: Sensor A Temperature
* TB: Sensor B Temperature

### Control Configuration 2
Sent when the app goes to the Controls screen

Message type 0a bf 2e

```
 0  1  2  3  4  5
0a 00 01 d0 00 44
```


## Outgoing Messages

### Configuration Request
The app sends this message shortly after connecting.

Message type: 0a bf 04

No content

### Filter Configuration Request
You must have previously sent general configuration request before sending this.

Message type: 0a bf 22

```
 0  1  2
01 00 00
```

### Toggle Item

Message type 0a bf 11

```
 0  1
II 00
```

 * II - item:
   * 0x04 - pump 1
   * 0x05 - pump 2
   * 0x06 - pump 3
   * 0x0C - blower
   * 0x11 - light 1
   * 0x3C - hold mode
   * 0x51 - heating mode
   * 0x50 - temperature range
  
### Set Temperature

Message type 0a bf 20

```
 0
TT
```

 * TT - the temperature, doubled if in Celsius

range is 80-104 for F, 26-40 for C in high range
range is 50-80 for F, 10-26 for C in low range

### Set Temperature Scale

Message type 0a bf 27

```
 0  1
01 TS
```

 * TS - Temperature Scale
   * 0x00 - Fahrenheit
   * 0x01 - Celsius

### Set Time

Message type 0a bf 21

```
 0  1
HH MM
```

 * HH - Hour. The high bit enables 24-hour time
 * MM - Minute

### Set Wi-Fi Settings

Message type 0a bf 92

```
 0  1 ...                             35 36 ....
CT SL <32 bytes of SSID; null padded> ET PL <64 bytes of the passkey; null padded>
```

 * CT - Configuration Type
   * 0x01 - Open, WEP, or WPA
   * 0x02 - WPS
 * ET - Encryption Type
   * 0x00 - Open or WPS
   * 0x02 - WEP
   * 0x08 - WPA
 * SL - SSID length
 * PL - passkey length

### Settings Request
Sent when the app goes to the Controls screen. First it sends it with arguments
of 02 00 00, then it gets a response, and then sends it again with arguments of
00 00 01.

Message type 0a bf 22

#### Filter Cycles Request
```
 0  1  2
01 00 00
```
#### Information Request
```
 0  1  2
02 00 00
```
#### Preferences Request
```
 0  1  2
08 00 00
```
#### Fault Log Request
```
 0  1  2
20 EN 00
```
* EN: Entry Number
  * `00` is first entry
  * Values larger than count roll-over (modulo)
  * `FF` is last entry (-1)
