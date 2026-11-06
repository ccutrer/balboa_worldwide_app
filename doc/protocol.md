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
F0 F1 CT HH MM F2 00 00 00 F3 F4 PP 00 F5 LF F6 00 00 00 00 ST 00 00 00
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
  * 0x0C = Filter Mode
* Flags 4:
  * 0x30 = Heating (seems it can be 0, 1, or 2)
  * 0x04 = Temperature Range (0 = Low, 1 = High)
* Flags 5:
  * 0x02 = Circulation pump
  * 0x0C = Blower
* Flags 6:
  * 0x01 = Mister
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

Other examples:
```
64dc 1100 4246425032302020 01 3d12382e 010a 0400
64dc 1400 4250323030304731 04 51800c6b 010a 0200
64c9 1300 4d51425035303120 01 0403daed 0106 0400
64e1 2400 4d53343045202020 01 c3479636 030a 4400
64e1 1400 4250323130304731 11 ebce9fd8 030a 1600
```

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


### Music

Spas with the bba music system (a Bluetooth amplifier on the bus, controlled
from the spaTouch panel's music screen) have these too. The amplifier sends
them from its own channel (0x52 here), only when something changes. The pack
repeats each as `ff af bX`, with the same content.

Text fields are null terminated.

#### Music Playback
Sent about once a second while playing.

Message type 52 bf b0

```
 0  1  2  3  4  5  6  7  8
SR 03 ST PH PL DH DL RP SH
```

 * SR - source: 0x00 line in, 0x01 Bluetooth (on line in, the rest is 0)
 * ST - state: 0x00 playing, 0x01 paused, 0x02 stopped. Flickers to paused
   for a moment while playing, and stays at playing when the phone pauses by
   itself; the position moving is the better sign of playing.
 * PH PL - position in seconds, big endian
 * DH DL - length of the song in seconds, big endian
 * RP - repeat: 0x00 off, 0x01 one, 0x02 all
 * SH - shuffle: 0x00 off, 0x01 on

#### Music Text
Sent when the song changes.

Message type 52 bf b1

```
 0  1  2 ...
FD LN <text> 00
```

 * FD - field: 0x00 title, 0x01 album, 0x02 artist
 * LN - length of the text

#### Music Volume

Message type 52 bf b2

```
 0  1  2  3  4  5  6  7
VL 00 00 MT 00 00 MX 00
```

 * VL - volume. Each source keeps its own.
 * MT - mute: 0x00 off, 0x01 on
 * MX - the highest volume (0x15, 21)

#### Music Bluetooth

Message type 52 bf b3

```
 0  1 ... 6  7  8 ...
ST <MAC>    LN <name> 00
```

 * ST - 0x01 a phone is connected, 0x02 waiting for one
 * MAC - the amplifier's Bluetooth address
 * LN - length of the name phones see, e.g. "BBA Spa Music"

#### Music Power

Message type 52 bf b4

```
 0  1  2
PW 02 11
```

 * PW - 0x00 off, 0x01 on

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
  
### Music Command

Message type 0a bf b5

```
 0  1
CM AR
```

The pack passes it on to the amplifier as `52 bf b5 CM AR`, which can be seen
on the bus. The panel's own music buttons end up as the same messages.

 * CM AR - command and argument:
   * 0x00 0x00/0x01 - power off/on
   * 0x01 0x00/0x01 - source line in/Bluetooth
   * 0x02 0x00 - play
   * 0x03 0x00 - pause
   * 0x05 0x00 - next song
   * 0x06 0x00 - previous song
   * 0x09 VL - set the volume to VL
   * 0x0A 0x00/0x01 - mute off/on
   * 0x0D RP - repeat (0x00 off, 0x01 one, 0x02 all)
   * 0x0E 0x00/0x01 - shuffle off/on
   * 0x11 NN - report a part of the state again: 0x00 playback, 0x01
     volume, 0x02 Bluetooth, 0x03 power, 0x04 title, 0x05 album, 0x06 artist.
     The amplifier only reports changes, so this is how to learn its state.
     Answers sometimes go missing; ask again.

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

Message type 0a bf 22

#### Panel Request
```
 0  1  2
 00 00 01
 ```

#### Filter Cycles Request
```
 0  1  2
01 00 00
```
#### Information Request
Sent when the app goes to the Controls screen, then it gets a response, then sends a Panel Request.
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
