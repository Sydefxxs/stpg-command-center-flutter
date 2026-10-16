"""Patch the generated android/ and ios/ projects with STPG permissions and settings.
Run once after `flutter create`:  python3 tool/setup_platforms.py
"""
import re, pathlib

root = pathlib.Path(__file__).resolve().parent.parent

# ---------- Android ----------
m = root / 'android/app/src/main/AndroidManifest.xml'
s = m.read_text()
perms = [
    'android.permission.INTERNET',
    'android.permission.ACCESS_FINE_LOCATION',
    'android.permission.ACCESS_COARSE_LOCATION',
    'android.permission.ACCESS_BACKGROUND_LOCATION',
    'android.permission.FOREGROUND_SERVICE',
    'android.permission.FOREGROUND_SERVICE_LOCATION',
    'android.permission.POST_NOTIFICATIONS',
    'android.permission.WAKE_LOCK',
]
block = ''.join(f'    <uses-permission android:name="{p}"/>\n' for p in perms if p not in s)
s = s.replace('<application', block + '    <application', 1) if block else s
s = s.replace('android:label="stpg_command_center"', 'android:label="STPG Command Center"')
queries = '''        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="https"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.DIAL"/>
            <data android:scheme="tel"/>
        </intent>
        <intent>
            <action android:name="android.intent.action.VIEW"/>
            <data android:scheme="geo"/>
        </intent>
        <package android:name="com.google.android.apps.maps"/>
        <package android:name="onxmaps.offroad"/>
'''
if '<queries>' in s and 'onxmaps.offroad' not in s:
    s = s.replace('<queries>', '<queries>\n' + queries, 1)
elif '<queries>' not in s:
    s = s.replace('</manifest>', '    <queries>\n' + queries + '    </queries>\n</manifest>')
# geolocator foreground service for background mission recording
if 'GeolocatorLocationService' not in s:
    s = s.replace('</application>', '''        <service
            android:name="com.baseflow.geolocator.GeolocatorLocationService"
            android:foregroundServiceType="location"
            android:exported="false"/>
    </application>''')
if 'screenOrientation' not in s:
    s = s.replace('android:name=".MainActivity"', 'android:name=".MainActivity"\n            android:screenOrientation="fullUser"')
m.write_text(s)

g = root / 'android/app/build.gradle.kts'
if g.exists():
    t = g.read_text()
    t = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 23', t)
    t = re.sub(r'applicationId\s*=\s*"[^"]+"', 'applicationId = "com.drivestpg.commandcenter.flutter"', t)
    g.write_text(t)

# ---------- iOS ----------
p = root / 'ios/Runner/Info.plist'
if p.exists():
    t = p.read_text()
    add = {
        'NSLocationWhenInUseUsageDescription': 'STPG Command Center uses your location for live GPS, weather, navigation and assistance requests.',
        'NSLocationAlwaysAndWhenInUseUsageDescription': 'STPG Command Center records your Coastal Convoy route while the mission is active, even when Maps is open.',
        'CFBundleDisplayName': 'STPG Command',
    }
    extra = ''
    for k, v in add.items():
        if f'<key>{k}</key>' in t:
            t = re.sub(rf'(<key>{k}</key>\s*<string>)[^<]*(</string>)', rf'\g<1>{v}\g<2>', t)
        else:
            extra += f'\t<key>{k}</key>\n\t<string>{v}</string>\n'
    if '<key>UIBackgroundModes</key>' not in t:
        extra += '\t<key>UIBackgroundModes</key>\n\t<array>\n\t\t<string>location</string>\n\t</array>\n'
    if '<key>LSApplicationQueriesSchemes</key>' not in t:
        extra += '\t<key>LSApplicationQueriesSchemes</key>\n\t<array>\n\t\t<string>comgooglemaps</string>\n\t\t<string>onxoffroad</string>\n\t\t<string>tel</string>\n\t</array>\n'
    t = t.replace('</dict>\n</plist>', extra + '</dict>\n</plist>')
    p.write_text(t)
print('platforms patched')
