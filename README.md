# Draksha Farm Diary (ದ್ರಾಕ್ಷಿ ಫಾರ್ಮ್ ಡೈರಿ / द्राक्ष फार्म डायरी)

Draksha Farm Diary is a secure, offline-friendly, premium Flutter mobile application designed exclusively for grape farmers to document daily work, log expenses, scan bills, capture crop photos, and record voice notes. 

This structured, high-quality data platform serves as an intuitive farm diary today and lays the foundation for future AI-driven agricultural advisory (pest forecasting, yield prediction, cost optimization).

---

## 🌟 Key Features

1. **Speech-First Journaling (Confirm-Before-Save)**: Speak naturally in Kannada, Hindi, or English. The app transcribes and parses the speech into structured observations, work categories, and expenses. The farmer reviews and adjusts the parsed details on the *"We understood this"* confirmation panel before saving.
2. **Offline-First SharedPreferences Caching**: Fully functional 100% offline out-of-the-box. Operates via local caches when cellular service in grape plots is unavailable. Offers one-tap cloud backup synchronization.
3. **Data Quality & AI-Readiness Scoring**: Automatically evaluates diary entries on a quality metric from `0.0` to `1.0`. Provides immediate corrective feedback to help farmers add missing fields (e.g. quantity or stages) so their entries are fully structured for future ML pipelines.
4. **Power BI-Style Expense Analytics**: Offers interactive charts (category donuts, monthly expenditure trends, plot-by-plot cost comparison) alongside automated language summaries (e.g., *"This month your highest expense is labour..."*).
5. **Bill Scan & Confirmation**: Mock OCR pipeline camera capture helper allowing farmers to snap purchase bills and confirm item costs and shop names.
6. **Granular Privacy & Anonymized Sharing**: Generate PDF/Text summaries with toggles to hide contact details, farm locations, or financial costs before exporting reports to researchers or agronomists.
7. **Soft Delete & Backup Trash**: Deleting history entries moves them to a secure offline trash status where they can be reviewed and fully restored anytime.

---

## 🛠️ Technology Stack & Setup

* **Framework**: Flutter (Dart) for high-performance native iOS and Android.
* **State Management**: Provider (MultiProvider) with local SharedPreferences caching providers.
* **Charts**: `fl_chart` for highly interactive, custom-themed agricultural analytics.
* **Audio**: `record` and `path_provider` for capturing voice wave notes.
* **Backend**: Firebase Auth (Phone OTP Verification), Cloud Firestore (Offline Persistent Structured Database), and Firebase Storage (Audio WAV files and crop leaf photos uploads).

---

## 📦 Project Architecture & Code Structure

The project strictly follows a clean architectural division:

```
lib/
  main.dart                   # MultiProvider, preloading languages, and try-catch Firebase booting
  app/
    app.dart                  # Material App shell, visual curvature themes, onGenerateRoute mapping
  core/
    constants/
      colors.dart             # HSL-tailored Agricultural Greens, Accent Grape Purples, Background Warm Creams
      constants.dart          # 12 Crop Growth Stages, 12 Farm Work Types, 9 Expense Categories
    theme/
      app_theme.dart          # Rounded curved styling tokens and large inputs
    localization/
      language_notifier.dart  # Preferred language state provider persisting preferences locally
      translations.dart       # UI translations dictionaries for en-IN, kn-IN, and hi-IN
    utils/
      date_formatter.dart     # Farmer-friendly dates ("Today", "Yesterday", locale-based months)
      data_validator.dart     # AI-readiness quality scoring algorithm
  services/
    firebase_auth_service.dart # Phone verification, OTP validation, and authentication mocks
    firestore_service.dart    # SharedPreferences local CRUD, soft-deletes, and live Firebase sync pipeline
    storage_service.dart      # Storage media uploads with robust fallback urls
    speech_service.dart       # Native Speech-to-Text handler with local confidence scoring
    analytics_service.dart    # Aggregates donut percentages, trends, and language insights
  models/
    farmer_model.dart         # Farmer profile holding village and AI training preferences
    farm_model.dart           # Multi-plot grape farm profiles (acres, location, soil characteristics)
    diary_entry_model.dart    # AI-ready structured models (Raw input, Clean notes, Structured properties)
    expense_model.dart        # Itemized cost structures
    bill_model.dart           # Mock OCR bill structure
    report_model.dart         # Historical breakdown templates
  widgets/
    app_button.dart           # High-visibility, large buttons for easy physical interaction
    app_card.dart             # Curve-bordered card container
    expense_chart.dart        # Custom Donut and Bar chart renderers
    diary_card.dart           # History card summary highlighting sync states, voice notes, and costs
  features/
    ...                       # SUITE OF 21 VISUAL MOBILITY SCREENS (Settings, Splash, Details, Auth, etc.)
```

---

## 🔥 Robust Firebase Configuration Steps

To wire this application to your production Firebase instance:

### Step 1: Create a Firebase Project
1. Navigate to [Firebase Console](https://console.firebase.google.com/).
2. Select **Create Project** and name it `Draksha-Farm-Diary`.

### Step 2: Register Android and iOS apps
* **Android Setup**:
  1. Register package `com.example.draksha_farm_diary` (or your customized package name).
  2. Download your generated `google-services.json` file.
  3. Move the file into your local project directory under `android/app/`.
* **iOS Setup**:
  1. Register Bundle ID `com.example.drakshaFarmDiary`.
  2. Download your generated `GoogleService-Info.plist` file.
  3. Move the file into `ios/Runner/` using Xcode.

### Step 3: Deploy Security Configurations
We have written the optimal, secure rules files to the root directory. Run the following CLI commands to deploy:

```bash
# Login and select your active project
firebase login
firebase use --add

# Deploy database security rules
firebase deploy --only firestore
firebase deploy --only storage
```

*These rules guarantee that farmers can only view and modify records that they created themselves.*

---

## 🏃 Run & Compile Instructions

1. **Download Dependencies**:
   ```bash
   flutter pub get
   ```
2. **Execute Development Simulator**:
   Ensure you have an active emulator or plugged-in physical phone.
   ```bash
   flutter run
   ```
3. **Switch Live Connection**:
   Go to **Profile / Settings Screen** (Tab 5) and toggle the **"Offline Mock Database Mode"** switch to test the live connection once Firebase files have been configured!
