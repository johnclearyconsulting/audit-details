# Device Audit Details

This little project was built out of necessity. I work in Education, where we often have hundreds of iPads to sort and re-allocate at the end of each year. While the units are labelled, it's not always possible to trust the labels! 😂 

As all iPads are managed with mobile device management (MDM), the details for each device can be pushed via a Managed Preferences file to the iPad, and the app then displays it.

## Setup

1. 'Buy' the App from Apple School Manager (free) or Apple Business Manager ($0.05 per licence).
2. Install the App via MDM to all iPads
3. Create a .mobileconfig file using your MDM with the XML keys requried (see sample below for Intune) and push to the devices from MDM.
4. **Optional:** Force iPad to open Audit Details app in single app mode via Config Profile (for speed).

#### Sample Preferences (Intune)

> [!NOTE]
>
> Intune allows variables in the format {{variable}} to be used in the XML that is uploaded, which then is converted to the device specific info before it is pushed to the device in question. I'm not covering how this works here, but [Microsoft's documentation](https://learn.microsoft.com/en-us/intune/intune-service/configuration/custom-settings-macos) is great.

```xml
<key>user</key>
<string>{{UserName}}</string>
<key>upn</key>
<string>{{userprincipalname}}</string>
<key>Serial</key>
<string>{{serialnumber}}</string>
```



#### Sample Config (All Keys)

> [!TIP]
>
> 

Intune allows variables in the format {{variable}} to be used in the XML that is uploaded, which then is converted to the device specific info before it is pushed to the device in question. I'm not covering how this works here, but [Microsoft's documentation](https://learn.microsoft.com/en-us/intune/intune-service/configuration/custom-settings-macos) is great.

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>serial</key>
	<string>C02XXXXXXX</string>
	<key>user</key>
	<string>Sample User</string>
	<key>upn</key>
	<string>sample.user@example.com</string>
	<key>debugging</key>
	<false/>
  <key>logo_base64</key>
    <string>iVBORw0KGgoAAAANSUh.....DUYD</string>
</dict>
</plist>

```



## Available Keys

This app will display 4 basic keys:

1. User's Name (user)