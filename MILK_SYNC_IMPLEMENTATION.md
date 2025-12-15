# Milk Collection Offline/Online Sync Implementation

## Overview
This implementation enables the Flutter app to sync milk collections from the server to Hive storage, allowing:
- Offline viewing of milk collection history
- Accurate monthly and yearly totals on receipts
- Combined offline and online data viewing

## Changes Made

### 1. Flutter App Changes

#### Updated Models (`lib/models/milk_collection.dart`)
- Added `serverId` field to track server-side record IDs
- Added `fromJson()` factory method to parse API responses
- Updated `toJson()` to include `serverId`

#### Updated Services (`lib/services/sync_service.dart`)
- Added `downloadMilkCollections()` method to fetch collections from server
- Supports pagination and date range filtering (default: last 3 months)
- Checks for existing records by `serverId` to avoid duplicates
- Updates existing records or creates new ones

#### Updated Screens
**Milk Collection Page** (`lib/screens/milk_collection_page.dart`):
- Calls `downloadMilkCollections()` on init to fetch history
- Updated `_autoPrintReceipt()` to calculate yearly totals from Hive
- Now calculates today's, monthly, and yearly totals from all Hive records

**Dashboard Page** (`lib/screens/dashboard_page.dart`):
- Syncs both farmers and milk collections on login
- Shows combined sync status message

**Milk List Page** (`lib/screens/milk_list_page.dart`):
- Already loads from Hive (no changes needed)
- Shows combined offline and online records

#### Updated Printer Service (`lib/services/printer_service.dart`)
- Updated receipt template to show yearly total
- Changed "Cumulative Weight" to "Monthly Weight" for clarity
- Added conditional "Yearly Weight" line to receipt

### 2. Backend (Laravel) Changes

#### New API Endpoint (`app/Http/Controllers/MilkCollectionController.php`)
Added `apiMilkCollectionsSync()` method:
- URL: `/api/milk-collections-sync`
- Requires `tenant_id` parameter
- Supports pagination (default 500 records per page)
- Supports date filtering (default: last 3 months)
- Returns milk collection data with farmer and center info
- Optimized query with joins for performance

#### Updated Routes (`routes/api.php`)
- Added route: `GET /api/milk-collections-sync`
- Protected with `auth:sanctum` middleware

## Important: Regenerate Hive Adapter

After updating the `MilkCollection` model, you **MUST** regenerate the Hive adapter:

```bash
cd /home/ancent/Projects/android/comaziwa-app
flutter packages pub run build_runner build --delete-conflicting-outputs
```

This will regenerate `lib/models/milk_collection.g.dart` with the new `serverId` field.

## Testing

### 1. Test Backend API
```bash
# Test milk collections sync endpoint
curl -X GET "http://your-api-url/api/milk-collections-sync?tenant_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"
```

Expected response:
```json
{
  "success": true,
  "data": [
    {
      "id": 123,
      "farmer_id": 45,
      "collection_date": "2025-12-13",
      "morning": 10.5,
      "evening": 8.0,
      "rejected": 0.5,
      "total": 18.0,
      "center_name": "Main Center",
      "farmerID": "508",
      "fname": "John",
      "lname": "Doe"
    }
  ],
  "pagination": {
    "total": 150,
    "page": 1,
    "limit": 500,
    "pages": 1
  }
}
```

### 2. Test Flutter App

1. **Login and Sync**
   - Login to the app
   - Should see "Syncing data..." toast
   - Check logs for "✅ Downloaded X new, updated Y collections"

2. **Verify Hive Storage**
   - Navigate to Milk Collection page
   - Search for a farmer
   - Receipt should show:
     - Today's total
     - Monthly total
     - **Yearly total** (new!)

3. **Check Milk List**
   - Navigate to Milk List page
   - Should show both online and offline records
   - Filter by date range to test

4. **Offline Mode Test**
   - Turn off internet
   - Check milk list (should still show data)
   - Create new collection (saves offline)
   - Turn on internet
   - Collections should sync up

## API Parameters

### `/api/milk-collections-sync`

**Required:**
- `tenant_id` - Tenant identifier

**Optional:**
- `start_date` - Start date (YYYY-MM-DD), default: 3 months ago
- `end_date` - End date (YYYY-MM-DD), default: today
- `farmer_id` - Filter by specific farmer
- `page` - Page number, default: 1
- `limit` - Records per page, default: 500

**Example:**
```
GET /api/milk-collections-sync?tenant_id=1&start_date=2025-10-01&end_date=2025-12-31&page=1&limit=500
```

## Performance Considerations

1. **Initial Sync**: Downloads last 3 months by default (configurable)
2. **Pagination**: Fetches 500 records per request to avoid timeouts
3. **Deduplication**: Checks `serverId` before inserting to avoid duplicates
4. **Incremental Updates**: Updates existing records if they changed on server

## Future Enhancements

1. **Delta Sync**: Only fetch records updated since last sync
2. **Background Sync**: Periodic automatic sync in background
3. **Conflict Resolution**: Handle conflicts when same record edited offline and online
4. **Sync Progress**: Show progress bar during large syncs
5. **Selective Sync**: Allow users to choose date ranges to sync

## Troubleshooting

### Collections Not Syncing
- Check network connection
- Verify `tenant_id` is set in SharedPreferences
- Check API logs for errors
- Verify auth token is valid

### Totals Incorrect on Receipt
- Ensure `downloadMilkCollections()` completed successfully
- Check Hive box contains expected records
- Verify date calculations in `_autoPrintReceipt()`

### Duplicate Records
- Check if `serverId` field is properly set
- Regenerate Hive adapter if model changed
- Clear Hive box and resync if needed:
  ```dart
  final box = Hive.box<MilkCollection>('milk_collections');
  await box.clear();
  await SyncService().downloadMilkCollections();
  ```

## Files Modified

### Flutter App
- `lib/models/milk_collection.dart`
- `lib/services/sync_service.dart`
- `lib/screens/milk_collection_page.dart`
- `lib/screens/dashboard_page.dart`
- `lib/services/printer_service.dart`

### Laravel Backend
- `app/Http/Controllers/MilkCollectionController.php`
- `routes/api.php`

## Next Steps

1. ✅ Regenerate Hive adapter (run build_runner)
2. ✅ Test backend API endpoint
3. ✅ Test Flutter app sync on login
4. ✅ Verify receipt shows yearly totals
5. ✅ Test offline mode
6. Deploy to production
