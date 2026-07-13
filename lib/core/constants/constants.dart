class AppConstants {
  static const String appName = "Soudi Farming";

  // Grape Crop Stages
  static const List<String> cropStages = [
    "Land preparation",
    "Pruning",
    "Bud stage",
    "Flowering",
    "Fruit setting",
    "Berry growth",
    "Color change",
    "Harvesting",
    "Drying grapes",
    "Raisin storage",
    "Selling",
    "Other"
  ];

  // Work Types
  static const List<String> workTypes = [
    "Spraying",
    "Fertilizer",
    "Irrigation",
    "Canopy management",
    "Labour work",
    "Harvesting",
    "Drying grapes",
    "Packing",
    "Selling",
    "Disease observation",
    "Market visit",
    "Other"
  ];

  // Expense Categories
  static const List<String> expenseCategories = [
    "Pesticide",
    "Fertilizer",
    "Labour",
    "Irrigation",
    "Transport",
    "Packing",
    "Machinery / tractor",
    "Market expense",
    "Other"
  ];

  // Measurement Units
  static const List<String> measurementUnits = [
    "kg",
    "litre",
    "packet",
    "bottle",
    "worker",
    "day",
    "acre",
    "trip",
    "other"
  ];

  // Supported Languages
  static const List<Map<String, String>> languages = [
    {"code": "en-IN", "name": "English", "nativeName": "English"},
    {"code": "kn-IN", "name": "Kannada", "nativeName": "ಕನ್ನಡ"},
    {"code": "hi-IN", "name": "Hindi", "nativeName": "हिंदी"}
  ];
}
