# Secrets Management Guide

This project uses a `.env` file approach for managing secrets and API keys, similar to Linux backend development workflows (like python-dotenv or Node.js dotenv).

## Quick Start

1. **Copy the template:**
   ```bash
   cp .env.example .env
   ```

2. **Add your secrets to `.env`:**
   ```bash
   # Edit .env and add your actual values
   API_KEY=sk_live_your_actual_key_here
   GOOGLE_MAPS_API_KEY=AIzaSy...
   ```

3. **Use in your code:**
   ```swift
   import Foundation

   // Access secrets anywhere in your app
   if let apiKey = Secrets.apiKey {
       print("API Key loaded: \(apiKey)")
   }

   // Or use convenience methods
   let analyticsEnabled = Secrets.analyticsEnabled  // Returns Bool
   ```

## Architecture

### Files

- **`.env`** - Your actual secrets (gitignored, never committed)
- **`.env.example`** - Template showing what variables are needed (committed to git)
- **`Secrets.swift`** - Swift code that loads and parses the `.env` file
- **`.gitignore`** - Ensures `.env` and `Secrets.swift` are never committed

### Why This Approach?

✅ **Familiar** - Same pattern as backend development (.env files)
✅ **Secure** - Secrets never committed to git
✅ **Simple** - No build scripts or complex configuration
✅ **Flexible** - Works in development and can be adapted for production
✅ **Type-safe** - Swift enums provide compile-time checks

## How It Works

1. **At app launch**, `Secrets.swift` looks for `.env` file in several locations:
   - Project root (during Xcode development)
   - App bundle (if you manually copy it)
   - Documents directory (fallback)

2. **Parses the file** into key-value pairs:
   ```
   API_KEY=my_secret_key
   ENABLE_ANALYTICS=true
   ```

3. **Provides type-safe access** via Swift properties:
   ```swift
   Secrets.apiKey           // String?
   Secrets.analyticsEnabled // Bool
   ```

## Adding New Secrets

### Step 1: Add to `.env.example`
```bash
# .env.example
MY_NEW_API_KEY=your_key_here
FEATURE_FLAG_X=true
```

### Step 2: Add to `Secrets.swift`
```swift
// In Secrets.swift, add a new computed property:
static var myNewApiKey: String? {
    get("MY_NEW_API_KEY")
}

static var featureFlagX: Bool {
    getBool("FEATURE_FLAG_X", default: false)
}
```

### Step 3: Update your actual `.env`
```bash
# .env (gitignored)
MY_NEW_API_KEY=sk_live_actual_production_key
FEATURE_FLAG_X=true
```

### Step 4: Use in your code
```swift
if let apiKey = Secrets.myNewApiKey {
    APIClient.configure(apiKey: apiKey)
}
```

## Development vs Production

### Development (Xcode)

During development, the `.env` file is read from your project directory.

**Option 1: Use .env file** (recommended)
- Simple, familiar workflow
- Works like backend development

**Option 2: Xcode Scheme Environment Variables**
- Edit Scheme → Run → Arguments → Environment Variables
- These override `.env` values
- Useful for temporary overrides

### Production (App Store)

For production builds, you have several options:

**Option 1: Compile-time replacement** (recommended)
- Use Xcode build configurations to inject secrets
- Modify `Secrets.swift` to return hardcoded values for release builds
- Example:
  ```swift
  static var apiKey: String? {
      #if DEBUG
      return get("API_KEY")  // Load from .env
      #else
      return "sk_live_production_key"  // Hardcoded for release
      #endif
  }
  ```

**Option 2: Remote config**
- Fetch secrets from a secure backend on first launch
- Store in Keychain
- Good for frequently rotating keys

**Option 3: Bundle .env in release**
- Copy `.env` into app bundle during build
- Less secure (can be extracted from IPA)
- Only for non-critical configs

## Security Best Practices

### ✅ DO

- ✅ Add `.env` to `.gitignore` (already done)
- ✅ Keep `.env.example` with dummy values
- ✅ Use different keys for dev/staging/production
- ✅ Rotate keys regularly
- ✅ Review git history before pushing

### ❌ DON'T

- ❌ Commit `.env` to git
- ❌ Share `.env` via email/Slack
- ❌ Use production keys in development
- ❌ Store keys in Xcode scheme files (those can be committed)
- ❌ Hardcode secrets in source code

## Debugging

### Check if .env is loaded

```swift
// In AppDelegate or early in app lifecycle
#if DEBUG
Secrets.printAll()  // Prints all loaded variables (masked)
#endif
```

Output example:
```
=== Environment Variables ===
API_KEY = sk***ey
ENABLE_ANALYTICS = true
GOOGLE_MAPS_API_KEY = AI***pq
=============================
```

### .env file not found?

Check the console for debug output:
```
[Secrets] Warning: No .env file found. Searched paths:
  - /Users/you/Library/Developer/Xcode/DerivedData/.../RoomPlanSimple.app/../../../../../.env
  - (null)
  - /Users/you/Library/Developer/CoreSimulator/.../Documents/.env
```

Make sure `.env` is in your **project root directory** (same level as `RoomPlanSimple.xcodeproj`).

## Example: Google Maps Integration

### 1. Get API key from Google Cloud Console

### 2. Add to `.env.example`
```bash
GOOGLE_MAPS_API_KEY=your_key_here
```

### 3. Add to your `.env`
```bash
GOOGLE_MAPS_API_KEY=AIzaSyC1234567890abcdefghijklmnop
```

### 4. Add to `Secrets.swift`
```swift
static var googleMapsApiKey: String? {
    get("GOOGLE_MAPS_API_KEY")
}
```

### 5. Use in your code
```swift
import GoogleMaps

func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    guard let apiKey = Secrets.googleMapsApiKey else {
        fatalError("Google Maps API key not configured. Check .env file.")
    }

    GMSServices.provideAPIKey(apiKey)

    return true
}
```

## Migrating Existing Secrets

If you already have hardcoded secrets in your code:

### Before (❌ insecure):
```swift
let apiKey = "sk_live_1234567890abcdef"  // Hardcoded!
```

### After (✅ secure):
```swift
// 1. Add to .env
// API_KEY=sk_live_1234567890abcdef

// 2. Add to Secrets.swift
// static var apiKey: String? { get("API_KEY") }

// 3. Update code
guard let apiKey = Secrets.apiKey else {
    print("Error: API_KEY not configured")
    return
}
// Use apiKey...
```

## Alternative: Info.plist with User-Defined Settings

If you prefer Xcode's built-in approach:

1. Add to `Info.plist`:
   ```xml
   <key>API_KEY</key>
   <string>$(API_KEY)</string>
   ```

2. In Xcode build settings, add User-Defined Setting:
   - `API_KEY = your_key`

3. Read in code:
   ```swift
   let apiKey = Bundle.main.object(forInfoDictionaryKey: "API_KEY") as? String
   ```

**Note**: This approach is less flexible and harder to manage across teams.

## Team Collaboration

### For team members setting up the project:

1. **Clone the repo**
   ```bash
   git clone https://github.com/yourorg/RoomPlanExampleApp.git
   cd RoomPlanExampleApp
   ```

2. **Copy and configure .env**
   ```bash
   cp .env.example .env
   # Edit .env with your development keys
   ```

3. **Never commit .env**
   ```bash
   git status  # .env should NOT appear (it's gitignored)
   ```

### For team leads:

- Share development API keys via secure channel (1Password, LastPass, etc.)
- Document which keys are needed in `.env.example`
- Use different keys for each developer if possible

## Troubleshooting

### "API key not found" errors

1. Check `.env` exists in project root
2. Check variable name matches exactly (case-sensitive)
3. Check no extra spaces: `API_KEY=value` not `API_KEY = value`
4. Run `Secrets.printAll()` to see what's loaded

### .env changes not reflected

The `.env` file is loaded once at app startup. After editing:
1. Stop the app
2. Clean build folder (⇧⌘K)
3. Run again

### .env committed by accident

If you accidentally committed `.env`:

```bash
# Remove from git but keep local file
git rm --cached .env
git commit -m "Remove .env from git"
git push

# Then rotate all the keys in that file!
```

## Summary

You now have a Linux backend-style secret management system for your iOS app:

- ✅ `.env` file for all secrets
- ✅ `.gitignore` protects secrets from git
- ✅ `Secrets.swift` provides type-safe access
- ✅ `.env.example` documents required variables
- ✅ Debug helpers for troubleshooting

**Usage:**
```swift
// Anywhere in your app:
let key = Secrets.apiKey
let isEnabled = Secrets.analyticsEnabled
```

**Add new secrets:**
1. Update `.env.example`
2. Update `Secrets.swift`
3. Update your `.env`
4. Use in code

For questions or issues, see `Secrets.swift` source code or open an issue.
