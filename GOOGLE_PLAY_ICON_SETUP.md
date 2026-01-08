# Google Play Store App Icon Setup Guide

## Overview
This guide explains how to properly set up your Comaziwa app icon for Google Play Store distribution.

---

## Google Play Store Icon Requirements

### 1. **App Icon (Launcher Icon)**
- **Size**: 512 × 512 pixels (minimum)
- **Format**: PNG (32-bit ARGB)
- **Features**:
  - Should be recognizable at small sizes (down to 48×48px)
  - Must have all four corners rounded slightly
  - Should work on all background colors
  - No transparency recommended (use solid background)

### 2. **Android Adaptive Icon** (Android 8.0+)
- **Foreground Layer**: 108 × 108 pixels
- **Background Layer**: 108 × 108 pixels
- **Safe Zone**: Center 72 × 72 pixels
- **Format**: PNG with transparency

### 3. **Google Play Store Listing**
- **Feature Graphic**: 1024 × 500 pixels
- **App Icon (for Store)**: 512 × 512 pixels
- **Screenshots**: Various sizes

---

## Current Setup

### Your Project Structure
```
android/app/src/main/res/
├── mipmap-xxxhdpi/       (512 × 512 px)
├── mipmap-xxhdpi/        (384 × 384 px)
├── mipmap-xhdpi/         (192 × 192 px)
├── mipmap-hdpi/          (144 × 144 px)
├── mipmap-mdpi/          (96 × 96 px)
├── drawable/             (Vector for older versions)
└── drawable-v21/         (Vector for Android 5.0+)

assets/
└── logo.png              (Your current logo)
```

---

## Step 1: Create Icon Variants

You have several options:

### Option A: Use Flutter Icons Generator (Recommended)
**Tool**: `flutter_launcher_icons` package

1. **Add to pubspec.yaml**:
```yaml
dev_dependencies:
  flutter_launcher_icons: "^0.13.1"

flutter_icons:
  image_path: "assets/logo.png"
  image_path_android: "assets/logo.png"
  android: true
  ios: false
  min_sdk_android: 21  # Android 5.0+
  adaptive_icon_background: "#ffffff"  # White background
  adaptive_icon_foreground: "assets/logo.png"
```

2. **Run command**:
```bash
cd /home/ancent/Projects/android/comaziwa-app
flutter pub get
flutter pub run flutter_launcher_icons
```

This automatically generates all required sizes!

### Option B: Manual Setup (If Your Logo is Already Ready)

If your `logo.png` is already 512×512, just place copies in:
- `android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png` (512×512)
- `android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png` (384×384)
- `android/app/src/main/res/mipmap-xhdpi/ic_launcher.png` (192×192)
- `android/app/src/main/res/mipmap-hdpi/ic_launcher.png` (144×144)
- `android/app/src/main/res/mipmap-mdpi/ic_launcher.png` (96×96)

---

## Step 2: Verify Android Manifest

Check `android/app/src/main/AndroidManifest.xml`:

```xml
<application
    android:label="Comaziwa"
    android:icon="@mipmap/ic_launcher"
    android:roundIcon="@mipmap/ic_launcher_round"
    android:usesCleartextTraffic="true">
```

**Key Points**:
- `android:icon` - Your app icon
- `android:roundIcon` - Rounded version (if you have one)
- `android:label` - App name (Comaziwa)

---

## Step 3: Android 8.0+ Adaptive Icon (Optional but Recommended)

**File**: `android/app/src/main/res/values/styles.xml`

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Black.NoTitleBar">
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
    </style>
</resources>
```

**For Adaptive Icon**, create `android/app/src/main/res/values-v26/styles.xml`:

```xml
<?xml version="1.0" encoding="utf-8"?>
<resources>
    <style name="LaunchTheme" parent="@android:style/Theme.Material.Light.NoActionBar">
        <item name="android:windowFullscreen">true</item>
        <item name="android:windowBackground">@drawable/launch_background</item>
        <item name="android:windowLightStatusBar">false</item>
    </style>
</resources>
```

**Create `android/app/src/main/res/mipmap-anydpi-v26/ic_launcher.xml`**:

```xml
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@drawable/ic_launcher_foreground"/>
</adaptive-icon>
```

**Create background and foreground drawables**:
- `android/app/src/main/res/drawable/ic_launcher_background.xml` (solid color)
- `android/app/src/main/res/drawable/ic_launcher_foreground.xml` (logo)

---

## Step 4: iOS Setup (If Needed)

For iOS App Store, add icon to `ios/Runner/Assets.xcassets/AppIcon.appiconset/`:

Sizes needed:
- 1024 × 1024 (Marketing)
- 180 × 180 (iPhone)
- 167 × 167 (iPad)
- 152 × 152 (iPad)
- 120 × 120 (iPhone)

---

## Step 5: Google Play Store Upload

### For Play Console:

1. **App Icon** (Upload to Play Console):
   - **512 × 512 PNG**
   - This is what users see in Play Store
   - Separate from the launcher icon!

2. **Feature Graphic**:
   - **1024 × 500 PNG**
   - Shown at top of listing

3. **Screenshots**:
   - **Minimum 2, Maximum 8**
   - Sizes: 1080 × 1920 (phone) or 1600 × 900 (tablet)

---

## Quick Checklist

- [ ] Logo is 512 × 512 pixels minimum
- [ ] Logo is PNG format (with or without transparency)
- [ ] Logo works on white, black, and colored backgrounds
- [ ] Logo has no transparent corners (Play Store requirement)
- [ ] Icon is placed in all mipmap folders (or use flutter_launcher_icons)
- [ ] AndroidManifest.xml references the icon correctly
- [ ] App builds successfully: `flutter build apk`
- [ ] Icon appears correctly on launcher
- [ ] Adaptive icon setup (Android 8.0+) is configured
- [ ] Google Play Store icon (512×512) is separate and ready

---

## Common Issues & Solutions

### Issue 1: Icon Not Showing on Launcher
**Solution**:
```bash
flutter clean
flutter pub get
flutter build apk
```

### Issue 2: Icon Appears Blurry
**Solution**: 
- Check if image is vector (SVG) and needs rasterization
- Verify size is at least 512×512
- Use PNG instead of JPG

### Issue 3: Transparency Issues
**Solution**:
- Google Play Store doesn't allow transparency in launcher icon
- Use solid background color
- Remove alpha channel if present

### Issue 4: Icon Doesn't Fit Android 8.0+ Adaptive Format
**Solution**:
- Create proper foreground/background layers
- Use `flutter_launcher_icons` package for automatic handling

---

## File Locations for Your Project

### Current Icon Location
```
assets/logo.png  ← Your current logo
```

### Required Icon Locations
```
android/app/src/main/res/
├── mipmap-mdpi/ic_launcher.png              (96 × 96)
├── mipmap-hdpi/ic_launcher.png              (144 × 144)
├── mipmap-xhdpi/ic_launcher.png             (192 × 192)
├── mipmap-xxhdpi/ic_launcher.png            (384 × 384)
├── mipmap-xxxhdpi/ic_launcher.png           (512 × 512)
├── mipmap-anydpi-v26/ic_launcher.xml        (Adaptive icon config)
└── drawable/ic_launcher.png                 (Fallback)
```

---

## Recommended Approach for Your Project

### Step 1: Prepare Logo
Ensure `assets/logo.png` is:
- ✅ 512 × 512 pixels
- ✅ PNG format
- ✅ Solid background (no transparency)
- ✅ Professional quality

### Step 2: Use Automated Tool
Add to `pubspec.yaml`:
```yaml
dev_dependencies:
  flutter_launcher_icons: "^0.13.1"

flutter_icons:
  image_path: "assets/logo.png"
  android: true
  adaptive_icon_background: "#ffffff"
  adaptive_icon_foreground: "assets/logo.png"
```

### Step 3: Generate
```bash
flutter pub run flutter_launcher_icons
```

### Step 4: Verify
```bash
flutter clean && flutter build apk
```

### Step 5: Test
- Install APK on device
- Verify icon appears on launcher
- Verify icon quality

---

## Resources

- **Google Play Policies**: https://play.google.com/console
- **Material Design Icons**: https://material.io/resources/icons/
- **Flutter Launcher Icons**: https://pub.dev/packages/flutter_launcher_icons
- **Android Icon Design**: https://developer.android.com/guide/practices/ui_guidelines/icon_design

---

## Next Steps

1. **Verify your logo** - Is `assets/logo.png` ready?
2. **Choose setup method** - Automated (recommended) or manual?
3. **Generate icons** - Run `flutter pub run flutter_launcher_icons`
4. **Test build** - `flutter build apk`
5. **Upload to Play Store** - When ready for release

Need help with any step? Let me know!
