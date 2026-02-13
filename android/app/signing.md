# Android Release Signing Setup

## Steps to Configure Release Signing

### 1. Generate Upload Keystore

```bash
keytool -genkey -v -keystore ~/blips-upload-key.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias blips-upload
```

Keep the keystore and passwords safe — you cannot change the upload key later.

### 2. Create `android/key.properties`

Create `android/key.properties` (already in `.gitignore`):

```properties
storePassword=<your-keystore-password>
keyPassword=<your-key-password>
keyAlias=blips-upload
storeFile=/Users/<you>/blips-upload-key.jks
```

### 3. Update `android/app/build.gradle.kts`

Replace the release signing block:

```kotlin
// Load signing config
val keystoreProperties = java.util.Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(java.io.FileInputStream(keystorePropertiesFile))
}

android {
    // ... existing config ...

    signingConfigs {
        create("release") {
            keyAlias = keystoreProperties["keyAlias"] as String
            keyPassword = keystoreProperties["keyPassword"] as String
            storeFile = file(keystoreProperties["storeFile"] as String)
            storePassword = keystoreProperties["storePassword"] as String
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
        }
    }
}
```

### 4. Build Release AAB

```bash
flutter build appbundle --release
```

Output: `build/app/outputs/bundle/release/app-release.aab`

### 5. Upload to Play Console

1. Go to https://play.google.com/console
2. Create app → "Blips"
3. Internal testing → Create release → Upload AAB
4. Fill store listing (see `store_metadata/` directory)
