# Draksha Farm Diary Architecture

## Mobile App

Draksha Farm Diary is a Flutter-only mobile app for Android and iOS. It is not a web app. The app uses a clean service-based architecture:

- `core/`: theme, language strings, app scope and bootstrap state.
- `data/models/`: AI-ready Firestore models for farmers, farms, diary entries, expenses, bills and reports.
- `data/services/`: Firebase Auth, Firestore repository, Storage media uploads, Analytics/admin counters, offline sync queue, OCR, speech-to-text and farmer-data-only AI advisor.
- `features/`: authentication, profile setup, dashboard, diary, analytics, reports, gallery, OCR bill scanner, AI advisor and settings.
- `shared/widgets/`: reusable premium farmer-friendly UI components.

## Firestore Schema

```text
users/{farmerId}
  farmerId
  name
  phone
  village
  preferredLanguage
  aiTrainingConsent
  createdAt
  updatedAt

users/{farmerId}/farms/{farmId}
  farmName
  crop: "Grapes"
  acres
  location
  createdAt

users/{farmerId}/farms/{farmId}/diaryEntries/{entryId}
  date
  cropStage
  workType
  originalText
  cleanedText
  languageCode
  voiceUrl
  photos[]
  expenses[]
    category
    itemName
    quantity
    amount
    date
  structuredData
    crop
    farmId
    tags[]
    source
    aiSchemaVersion
  totalExpense
  aiReady
  farmerConfirmed
  createdAt
  updatedAt

users/{farm
































































## OCR Bill Scanner

Bill OCR uses on-device ML Kit text recognition and extracts only:

- shop name
- product/fertilizer/pesticide name
- quantity/items
- amount per item
- final total amount

Other bill text is preserved as raw `extractedText` for audit but not used as the main structured bill schema.

## Analytics Tracking Plan

Firebase Analytics events:

- `app_opened`
- `user_signup`
- `diary_entry_created`
- `expense_added`
- `photo_uploaded`
- `bill_scanned`
- `report_generated`

Admin-ready counters are mirrored into `adminStats/{day}` and `adminMetrics/totals` for future dashboards covering farmers, active users, farms, diary entries, uploaded photos, bills scanned, usage and crashes.

## Deployment Plan

1. Create a Firebase project.
2. Add Android and iOS apps in Firebase.
3. Download `google-services.json` into `android/app/`.
4. Download `GoogleService-Info.plist` into `ios/Runner/`.
5. Enable Firebase Authentication Phone provider.
6. Create Cloud Firestore in production mode.
7. Create Firebase Storage.
8. Enable Firebase Analytics, Crashlytics and Cloud Messaging.
9. Deploy security rules:

```bash
firebase deploy --only firestore:rules,storage
```

10. Run:

```bash
flutter pub get
flutter run
```

11. For release builds configure app signing, SHA-1/SHA-256 for Phone Auth, APNs for iOS FCM and Crashlytics symbol upload.
