# Google Play Store Requirements Checklist

## ✅ Launcher Icons - COMPLETE

### App Icons (In-App)
All required icon sizes are properly configured:
- ✅ mdpi: 48×48px
- ✅ hdpi: 72×72px
- ✅ xhdpi: 96×96px
- ✅ xxhdpi: 144×144px
- ✅ xxxhdpi: 192×192px

### Adaptive Icons (Android 8.0+)
- ✅ Foreground layers created for all densities
- ✅ Background color: #ffffff (white)
- ✅ Properly configured XML adaptive icon

### Play Store High-Resolution Icon
- ✅ **Created:** `playstore-icon.png`
- ✅ Size: 512×512 pixels
- ✅ Format: 32-bit PNG (RGB, no alpha channel)
- ✅ File size: 173KB (under 1MB limit)
- ✅ Background: White (no transparency)

**Upload Location:** When publishing to Play Console, upload `playstore-icon.png` in:
`App content > Store listing > App icon`

---

## ⚠️ IMPORTANT: Update Application ID

**Current Application ID:** `com.example.comaziwa`

**Action Required:** Change this to a unique identifier for production:
1. Open: `android/app/build.gradle.kts`
2. Update line 24: `applicationId = "com.example.comaziwa"`
3. Change to something like: `applicationId = "com.comaziwa.dairy"` or `com.yourcompany.comaziwa`

**Why?** The `com.example.*` namespace is for development only and won't be accepted by Google Play Store.

---

## Play Store Publishing Checklist

### Graphics Assets (Required)
- ✅ **App icon:** playstore-icon.png (512×512)
- ⏳ **Feature graphic:** 1024×500 px (Required)
- ⏳ **Screenshots:** At least 2 (phone), recommended 8
  - Min: 320px on short side
  - Max: 3840px on long side
  - JPEG or 24-bit PNG (no alpha)

### App Information
- [ ] App title (max 50 characters)
- [ ] Short description (max 80 characters)
- [ ] Full description (max 4000 characters)
- [ ] App category
- [ ] Content rating questionnaire
- [ ] Privacy policy URL (if collecting user data)

### Technical Requirements
- [ ] Signed APK/AAB with production keystore
- [ ] Target API level: Android 13 (API 33) or higher (Google requirement)
- [ ] minSdkVersion: Currently set to Android 5.0+ (API 21) ✓
- [ ] Unique application ID (not com.example.*)

### Before Publishing
1. Update `applicationId` in build.gradle.kts
2. Create and configure production signing key
3. Update version code and name in pubspec.yaml
4. Build release bundle: `flutter build appbundle --release`
5. Test thoroughly on different devices
6. Create all required graphics assets
7. Complete Play Console store listing

---

## Icon Best Practices Met

✅ **Format:** PNG with proper color depth
✅ **Sizes:** All required densities provided
✅ **Adaptive Icons:** Foreground + Background layers
✅ **Safe Zone:** 72×72dp safe zone maintained in adaptive icons
✅ **Consistency:** Same design across all sizes
✅ **Quality:** Sharp, clear, and recognizable

---

## Notes

- The source icon (`assets/logo.png`) is 512×512 with transparency, which is perfect for generating all sizes
- The `flutter_launcher_icons` package is already configured in pubspec.yaml
- Adaptive icons will show properly on Android 8.0+ devices
- Legacy icons work on older Android versions

**Next Steps:**
1. Change the application ID from `com.example.comaziwa` to your production ID
2. Create feature graphic (1024×500px) for Play Store
3. Take app screenshots for store listing
4. Set up production signing configuration
