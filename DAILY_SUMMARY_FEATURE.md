# Daily Collection Summary Feature

## Overview
Added a new page to view and print daily collection summaries for the milk collection app.

## Features

### 1. **Daily Collection Summary Page**
   - Location: `lib/screens/daily_collection_summary_page.dart`
   - Shows all collections for a selected date
   - Displays:
     - Total number of farmers who delivered milk
     - Total morning milk collected
     - Total evening milk collected
     - Total rejected milk
     - Grand total (morning + evening - rejected)
     - Individual farmer collection details

### 2. **Date Selection**
   - Click on the date card at the top to open a date picker
   - Select any date from 2020 to today
   - Data is loaded instantly from local Hive database

### 3. **Summary Statistics**
   - **Farmers Card**: Shows total number of farmers
   - **Total Card**: Shows grand total milk collected in liters
   - **Breakdown Card**: Shows morning, evening, and rejected milk separately

### 4. **Collections List**
   - Scrollable list of all collections for the selected date
   - Each card shows:
     - Farmer ID (in colored circle - green if synced, orange if local)
     - Farmer name
     - Collection center
     - Morning, Evening, and Rejected amounts (color-coded chips)
     - Total amount
     - Sync status

### 5. **Print Functionality**
   - Print button in app bar to print daily summary report
   - Professional ESC/POS formatted receipt includes:
     - Company header and contact information
     - Selected date
     - Summary totals
     - Table of all farmer collections (up to 50 farmers)
     - Footer with company slogan

### 6. **Navigation**
   - Access from Dashboard → Menu Drawer → "Daily Summary"
   - Icon: `summarize_outlined`
   - Route: `/dailySummary`

## Files Modified/Created

### Created:
1. `lib/screens/daily_collection_summary_page.dart` - Main UI page
2. `DAILY_SUMMARY_FEATURE.md` - This documentation

### Modified:
1. `lib/main.dart` - Added route and import
2. `lib/screens/dashboard_page.dart` - Added menu item in drawer
3. `lib/services/printer_service.dart` - Added print methods:
   - `printDailySummary()` - Main print handler
   - `buildDailySummaryEscPos()` - ESC/POS receipt builder

## Usage

### For Users:
1. Open the app and login
2. From Dashboard, tap the menu icon (☰)
3. Select "Daily Summary"
4. Select a date using the date picker
5. View the summary and farmer collections
6. Tap print icon to print the summary

### For Developers:
```dart
// Navigate to daily summary page
Navigator.pushNamed(context, '/dailySummary');

// Or with MaterialPageRoute
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (context) => DailyCollectionSummaryPage(),
  ),
);
```

## Data Source
- Data is loaded from Hive local database (`milk_collections` box)
- Filters by date string in format: `yyyy-MM-dd`
- Shows both synced (from server) and unsynced (local) collections

## Design Choices

### Color Coding:
- **Green**: Synced data, total milk, success states
- **Orange**: Morning milk, local/unsynced data
- **Indigo/Purple**: Evening milk
- **Red**: Rejected milk
- **Blue**: Farmer count

### Performance:
- Data loads instantly from local Hive database
- No network calls required (works offline)
- Efficient filtering and sorting

### Print Format:
- ESC/POS commands for thermal printers
- Maximum 50 farmers per print (to avoid receipt being too long)
- Shows "...and X more" if more than 50 farmers

## Future Enhancements (Optional)
- [ ] Add date range selection (e.g., weekly summary)
- [ ] Export to PDF/Excel
- [ ] Email summary report
- [ ] Compare different dates side-by-side
- [ ] Filter by collection center
- [ ] Sort options (by farmer ID, name, amount)
- [ ] Search within daily collections

## Testing
1. Test with no collections for a date
2. Test with 1 farmer
3. Test with many farmers (50+)
4. Test date picker navigation
5. Test print functionality with Bluetooth printer
6. Test refresh button
7. Test with synced and unsynced data mix

## Dependencies
All existing - no new packages required:
- `hive` - Local database
- `intl` - Date formatting
- `flutter_bluetooth_printer` - Printing
- `fluttertoast` - Toast messages
