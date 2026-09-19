# 📱 APK Deployment Guide - Nol Coffee POS App

## 📦 Latest Build Information

### Current Version
- **Version:** v1.0.0+1
- **Commit:** 9767f86
- **Date:** Aug 18, 2026 21:53 WIB
- **Build Size:** 60 MB
- **APK Name:** app-release.apk

### Location of Built APK
```bash
/Users/macbooksale/Work/Projects/tiknol-mobile-flutter/build/app/outputs/flutter-apk/app-release.apk
```

---

## 🔧 Build Process

### Manual Build Steps (Local)

```bash
cd /Users/macbooksale/Work/Projects/tiknol-mobile-flutter

# 1. Clean previous builds
flutter clean

# 2. Get dependencies
flutter pub get

# 3. Build release APK
flutter build apk --release \
  --dart-define=ENV=production \
  --dart-define=API_BASE_URL=https://api.nol.coffee

# Output will be at:
# build/app/outputs/flutter-apk/app-release.apk
```

### Automated Build (GitHub Actions)

When you push to `master` or create a tag like `v1.0.0+1`:
- CI automatically builds the APK
- Creates GitHub Release with changelog
- Uploads APK as downloadable asset

See `.github/workflows/release.yml` for details.

---

## 🚀 Deployment Options

### Option A: Direct Server Upload (Manual)

1. **Upload APK to your web server:**
```bash
scp build/app/outputs/flutter-apk/app-release.apk \
  superadmin@your-server.com:/var/www/html/apks/nol-coffee-pos-v1.0.0+1.apk
```

2. **Create download page (`index.html`):**
```html
<!DOCTYPE html>
<html>
<head>
    <title>Download Nol Coffee POS</title>
</head>
<body style="font-family: Arial, sans-serif; max-width: 800px; margin: 50px auto;">
    <div style="text-align: center;">
        <h1>Nol Coffee Reserve POS App</h1>
        
        <div style="background: #f5f5f5; padding: 20px; border-radius: 8px; margin: 20px 0;">
            <h2>Latest Release: v1.0.0+1</h2>
            <p><strong>Build Date:</strong> Aug 18, 2026</p>
            <p><strong>Commit:</strong> 9767f86</p>
            
            <h3>🎉 What's New:</h3>
            <ul>
                <li>Manual QRIS payment check button ("Periksa Sekarang")</li>
                <li>Last checked timestamp display</li>
                <li>Enhanced success feedback with haptic + sound</li>
                <li>Loading indicator during checks</li>
                <li>Anti-spam protection (3s cooldown)</li>
                <li>Better UX with immediate feedback</li>
            </ul>
            
            <a href="/apks/nol-coffee-pos-v1.0.0+1.apk" 
               style="display: inline-block; background: #4CAF50; color: white; 
                      padding: 15px 30px; text-decoration: none; 
                      border-radius: 5px; font-size: 18px; margin-top: 20px;">
                ⬇️ Download APK Now
            </a>
        </div>
        
        <p style="color: #666; font-size: 14px;">
            Requires Android 6.0+ • Login required after installation<br>
            For support: dev-team@example.com
        </p>
    </div>
</body>
</html>
```

3. **Setup Basic Authentication (.htaccess):**
```apache
AuthType Basic
AuthName "Restricted Access"
AuthUserFile /etc/apache2/.htpasswd
Require valid-user
```

4. **Create password file:**
```bash
sudo htpasswd -c /etc/apache2/.htpasswd superadmin
# Enter strong password when prompted
```

5. **Restart Apache:**
```bash
sudo systemctl restart apache2
```

---

### Option B: GitHub Releases (Auto)

Push to create automatic releases:

```bash
# Tag your version
git tag v1.0.0+1
git push origin v1.0.0+1

# Or just push to master
git push origin master
```

This triggers GitHub Actions workflow that:
1. Builds APK automatically
2. Creates GitHub Release with changelog
3. Uploads APK as downloadable asset
4. Generates version-specific download link

Access releases at: `https://github.com/salminthahir/tiknol-mobile/releases`

---

## 🏗️ Project Structure

```
tiknol-mobile-flutter/
├── .github/
│   └── workflows/
│       └── release.yml          # Auto-build & release automation
├── scripts/
│   ├── build-production.sh     # Production build script
│   └── run-dev.sh              # Development launch script
├── android/
│   └── app/
│       └── build.gradle.kts    # Android build configuration
├── lib/
│   └── core/
│       └── constants.dart      # Environment configuration
└── build/
    └── app/
        └── outputs/
            └── flutter-apk/
                └── app-release.apk    # FINAL APK HERE
```

---

## 🔒 Security Considerations

### APK Signing
Current build uses debug signing for testing. For production:

```bash
# Create release keystore
keytool -genkey -v -keystore ~/release-key.keystore -alias tiknol_key \
  -keyalg RSA -keysize 2048 -validity 10000

# Update android/key.properties
storePassword=<keystore-password>
 keyPassword=<key-password>
 keyAlias=tiknol_key
 storeFile=/path/to/release-key.keystore
```

Then modify `build.gradle.kts`:
```kotlin
signingConfigs {
    release {
        if (file('android/key.properties').exists()) {
            def properties = new Properties()
            properties.load(new FileInputStream(file('android/key.properties')))
            storeFile = file(properties['storeFile'])
            storePassword = properties['storePassword']
            keyAlias = properties['keyAlias']
            keyPassword = properties['keyPassword']
        }
    }
}
```

### Download Protection
Use one of these methods:

1. **Basic Auth** (Simple) - Password protect folder
2. **Token-based** (Better) - JWT validation on download endpoint
3. **Signed URLs** (Best) - Time-limited download links

---

## 📊 Version Numbering System

**Format:** `MAJOR.MINOR.PATCH+BUILD`

Examples:
- `1.0.0+1` → Initial stable release
- `1.1.0+2` → Minor feature added, 2nd build
- `1.1.1+5` → Bug fix, 5th build

**Increment Rules:**
- `fix:` commit → Increment PATCH
- `feat:` commit → Increment MINOR
- `BREAKING CHANGE` → Increment MAJOR
- Every successful build → Increment BUILD number

Update in `pubspec.yaml`:
```yaml
version: 1.0.0+1  # Change this before each release
```

---

## 📋 Pre-Deployment Checklist

Before deploying any APK:

- [ ] Test on real devices (Android 6.0+)
- [ ] Verify API endpoints are accessible
- [ ] Check all permissions work correctly
- [ ] Test login flow end-to-end
- [ ] Verify payment flows (QRIS/CASH)
- [ ] Check printer connectivity
- [ ] Review changelog accuracy
- [ ] Ensure secure HTTPS connection
- [ ] Set up monitoring/logging

---

## 🔍 Testing Checklist

Test these scenarios before releasing:

1. **Installation**
   - [ ] APK installs without errors
   - [ ] Permissions granted properly
   - [ ] App opens successfully

2. **Login**
   - [ ] Can login with valid credentials
   - [ ] Session persists correctly
   - [ ] Logout works and clears data

3. **POS Functions**
   - [ ] Add items to cart
   - [ ] Apply vouchers/discounts
   - [ ] Calculate totals correctly
   - [ ] Print receipt successfully

4. **Payments**
   - [ ] QRIS generates correctly
   - [ ] Payment status auto-checks work
   - [ ] Manual check button functions
   - [ ] Timeout handling works

5. **Kitchen Display**
   - [ ] Orders appear in real-time
   - [ ] Status updates sync correctly
   - [ ] Timer counting works
   - [ ] Sound alerts trigger

---

## 🆘 Troubleshooting

### Build Fails
```bash
flutter clean
flutter pub cache repair
flutter pub get
flutter build apk --release
```

### APK Too Large
- Reduce image assets
- Use ProGuard/R8 obfuscation
- Remove unused resources
- Split APK by ABI/architecture

### Installation Blocked
- Enable "Install from Unknown Sources" in device settings
- Check Android version compatibility (minSdk >= 21)
- Verify APK is not corrupted

### Runtime Errors
- Check logcat output: `adb logcat | grep -i flutter`
- Verify API base URL is correct
- Check network permissions in manifest

---

## 📞 Support & Contact

For issues or questions:
- **Email:** dev-team@example.com
- **Documentation:** See Docs/ folder
- **Issues:** GitHub Issues tab
- **紧急 Support:** WhatsApp group

---

**Last Updated:** Aug 18, 2026  
**Maintained By:** Development Team
