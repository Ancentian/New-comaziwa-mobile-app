# Bluetooth Printer Troubleshooting Guide

## Common Issues and Solutions

### Issue 1: Printer Not Printing

**Symptoms:**
- Print button doesn't work
- No error message or generic "Print failed" message
- Printer connects but nothing prints

**Solutions:**

1. **Check Bluetooth Permissions:**
   - Go to Settings → Apps → Comaziwa → Permissions
   - Ensure "Nearby devices" or "Bluetooth" permission is granted
   - On Android 12+, you need BLUETOOTH_SCAN and BLUETOOTH_CONNECT permissions

2. **Verify Bluetooth is Enabled:**
   - Turn on Bluetooth in your phone settings
   - Ensure the printer is powered on and in pairing mode

3. **Select/Re-select Printer:**
   - Go to Dashboard → Printer Settings (printer icon)
   - Click "Select Printer" button
   - Choose your Bluetooth printer from the list
   - The app will save this selection

4. **Test Print:**
   - In Printer Settings, click "Test Print"
   - If test print fails, check printer power and connection
   - If test succeeds but real prints fail, the issue is in the receipt formatting

5. **Check Printer Address is Saved:**
   - The app now automatically saves the selected printer
   - Previous versions didn't save the printer address
   - Re-select your printer to ensure it's saved

### Issue 2: "No Printer Selected" Message

**Solution:**
- Go to Printer Settings
- Click "Select Printer"
- Choose your printer from the Bluetooth devices list
- The selection will now be saved automatically

### Issue 3: Permission Denied

**Solution:**
- When prompted, grant Bluetooth permissions
- If you denied permissions previously:
  1. Go to Settings → Apps → Comaziwa → Permissions
  2. Grant "Nearby devices" permission
  3. Restart the app

### Issue 4: Printer Connects but Prints Blank

**Possible causes:**
- Receipt rendering timeout (now fixed with longer delays)
- Printer memory issue
- Bluetooth connection unstable

**Solutions:**
1. Wait at least 3 seconds after printing before moving away
2. Try printing again (app has 2 retry attempts)
3. Move closer to the printer
4. Restart the printer

### Issue 5: Auto-Print Not Working

**Solution:**
1. Go to Printer Settings
2. Select a printer first
3. Toggle "Enable Auto-Print" to ON
4. Verify "Auto-Print Status" shows "Enabled"

## Changes Made to Fix Printing Issues

### 1. Printer Address Persistence
- **Before:** Printer selection was lost after app restart
- **After:** Printer address is now saved to SharedPreferences automatically

### 2. Better Error Messages
- Added detailed logging with emojis for easy debugging
- Print logs visible in console: 🔍 🎯 📄 ✅ ❌

### 3. Improved Timing
- Increased overlay render time: 150ms → 200ms
- Increased rendering delay: 300ms → 500ms  
- Increased print transmission time: 2500ms → 3000ms
- Controller timeout: 3s → 5s

### 4. Connection Checks
- App now loads saved printer address on startup
- Verifies Bluetooth permissions before printing
- Shows helpful dialogs for permission issues

### 5. Error Handling
- Added try-catch blocks with specific error messages
- Toast notifications show success/failure
- Timeout exceptions are caught and reported

## Debugging Tips

### Enable Debug Logs

Check the console/logcat output when printing:
```
🔍 Checking Bluetooth connection...
📱 Bluetooth Connect Status: granted
📋 Loaded saved printer: 00:11:22:33:44:55
🖨️ Starting print job...
🎯 Printer address: 00:11:22:33:44:55
📄 Inserting receipt overlay...
⏳ Waiting for controller initialization...
✅ Receipt controller initialized
⏳ Rendering receipt...
📤 Sending to printer: 00:11:22:33:44:55
⏳ Waiting for print to complete...
✅ Print job completed successfully
```

### Check for Errors

Look for these error indicators:
- ❌ (red X) = Error occurred
- ⚠️ (warning) = Potential issue
- ✅ (checkmark) = Success

### Common Error Messages

- "Bluetooth connection not ready" → Turn on Bluetooth
- "No printer selected" → Go to Printer Settings
- "Controller initialization timeout" → Try again, may need app restart
- "Print failed: [error]" → Check specific error message

## Testing Checklist

Before reporting an issue, try these steps:

- [ ] Bluetooth is turned on
- [ ] Printer is powered on and charged
- [ ] Bluetooth permissions are granted
- [ ] Printer is selected in Printer Settings
- [ ] Test print works from Printer Settings
- [ ] App has been restarted after selecting printer
- [ ] Printer is within range (< 10 meters)
- [ ] No other device is connected to the printer

## How to Report Issues

If printing still doesn't work after trying all solutions:

1. Check the debug console logs
2. Note the exact error message
3. Screenshot the error (if visible)
4. List which steps you've already tried
5. Include phone model and Android version
6. Include printer model

## Technical Details

### Required Permissions
```xml
<uses-permission android:name="android.permission.BLUETOOTH"/>
<uses-permission android:name="android.permission.BLUETOOTH_ADMIN"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
<uses-permission android:name="android.permission.BLUETOOTH_SCAN"/>
```

### Dependencies
- flutter_bluetooth_printer: ^2.20.0
- permission_handler: ^12.0.0
- shared_preferences: ^2.2.3

### Print Flow
1. Check Bluetooth permissions
2. Load saved printer address
3. Verify printer is selected
4. Create receipt widget
5. Render to overlay (offscreen)
6. Initialize controller (5s timeout)
7. Wait for rendering (500ms)
8. Send to printer via Bluetooth
9. Wait for transmission (3000ms)
10. Clean up overlay and controller
