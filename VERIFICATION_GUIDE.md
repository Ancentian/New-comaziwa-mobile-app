# API & Hive Data Verification Guide

## Backend API Verification ✅

### 1. API Endpoint Status
**Endpoint**: `GET /api/milk-collections-sync`
- **Status**: ✅ **EXISTS** - Implemented in `MilkCollectionController.php`
- **Route**: Defined in `routes/api.php` line 38
- **Method**: `apiMilkCollectionsSync()`

### 2. API Requirements
The endpoint expects these parameters:
- **tenant_id** (required) - From SharedPreferences
- **limit** (optional, default: 500) - Number of records per page
- **page** (optional, default: 1) - Page number for pagination
- **start_date** (optional) - Filter by date range (YYYY-MM-DD)
- **end_date** (optional) - Filter by date range (YYYY-MM-DD)
- **farmer_id** (optional) - Filter by specific farmer

### 3. Expected Response Format
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

---

## Testing the API Endpoint

### Option 1: Using cURL (Command Line)
```bash
# Test the endpoint directly
curl -X GET "http://your-api.com/api/milk-collections-sync?tenant_id=1&limit=10" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"
```

### Option 2: Using Postman
1. Create a GET request to: `http://your-api.com/api/milk-collections-sync`
2. Add Query Parameters:
   - `tenant_id`: `1` (your actual tenant ID)
   - `limit`: `10`
3. Add Header:
   - `Authorization`: `Bearer YOUR_TOKEN`
4. Click Send and verify:
   - Status Code: `200`
   - Response contains `"success": true`
   - `data` array is not empty

### Option 3: Using Flutter's Debug Console
Add this test code to `dashboard_page.dart` temporarily:
```dart
// Add to _DashboardPageState initState or a test button
Future<void> _testMilkApiEndpoint() async {
  final token = await _getAuthToken();
  final tenantId = await _getTenantId();
  
  if (token == null || tenantId == null) {
    print('❌ Missing token or tenant_id');
    return;
  }

  try {
    final url = Uri.parse(
      "$apiBase/milk-collections-sync?tenant_id=$tenantId&limit=5"
    );
    
    print('🔍 Testing API: $url');
    
    final response = await http.get(
      url,
      headers: {'Authorization': 'Bearer $token'},
    );

    print('📡 Status: ${response.statusCode}');
    print('📊 Response: ${response.body}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ API Working! Found ${data['data'].length} records');
    } else {
      print('❌ API Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ API Exception: $e');
  }
}
```

---

## Hive Data Verification

### 1. Check if Hive Box is Initialized
**Location**: `lib/main.dart`
```dart
// Should see this in logs on startup:
if (!Hive.isBoxOpen('milk_collections')) {
  await Hive.openBox<MilkCollection>('milk_collections');
}
```

### 2. Verify Data After Download
Add a debug function to check Hive contents:

```dart
Future<void> _checkHiveData() async {
  try {
    final box = Hive.box<MilkCollection>('milk_collections');
    
    print('📦 Hive Statistics:');
    print('   Total records in Hive: ${box.length}');
    
    if (box.isEmpty) {
      print('   ⚠️  WARNING: Hive is EMPTY!');
      print('   → Milk collections may not have been downloaded');
      print('   → Check if API endpoint is working');
      print('   → Verify tenant_id is set in SharedPreferences');
      return;
    }

    // Show first 5 records
    print('   📋 Sample records:');
    final records = box.values.take(5).toList();
    for (var i = 0; i < records.length; i++) {
      final r = records[i];
      print('     [$i] Farmer: ${r.farmerId}, Date: ${r.date}, '
            'Morning: ${r.morning}L, Evening: ${r.evening}L, Synced: ${r.isSynced}');
    }

    // Calculate some stats
    final syncedCount = box.values.where((m) => m.isSynced).length;
    final unsyncedCount = box.values.where((m) => !m.isSynced).length;
    print('   ✅ Synced: $syncedCount');
    print('   ⏳ Unsynced: $unsyncedCount');

  } catch (e) {
    print('❌ Error checking Hive: $e');
  }
}
```

### 3. When to Call This Check
Call it right after download completes in `dashboard_page.dart`:

```dart
// In dashboard_page.dart initState(), after line 91-93
final collectionsDownloaded = await SyncService().downloadMilkCollections();

// ADD THIS:
if (collectionsDownloaded) {
  await _checkHiveData();  // Debug function above
}
```

---

## Common Issues & Solutions

### Issue 1: Hive is Empty After Download
**Symptoms**: 
- Milk receipts show 0 totals
- Hive check shows: "Total records in Hive: 0"

**Solutions**:
1. ✅ Check API response - does it return data?
   ```bash
   curl -X GET "http://api/milk-collections-sync?tenant_id=1" -H "Authorization: Bearer TOKEN"
   ```

2. ✅ Verify tenant_id is correct
   ```dart
   final prefs = await SharedPreferences.getInstance();
   print('Tenant ID: ${prefs.getInt('tenant_id')}');
   ```

3. ✅ Check if no milk records exist in database
   - Login to Laravel admin
   - Go to Milk Collections table
   - Verify records exist for your tenant_id

4. ✅ Clear app cache and re-download
   - Settings → Apps → Comaziwa → Storage → Clear Cache
   - Re-login to trigger download

### Issue 2: API Returns 400 Error
**Error**: `"tenant_id is required"`

**Solution**: 
- Verify tenant_id was saved after login in `login_page.dart`
- Check line 185 in `login_page.dart`:
  ```dart
  if (data['user'] != null && data['user']['tenant_id'] != null) {
    await prefs.setInt('tenant_id', data['user']['tenant_id']);
  }
  ```

### Issue 3: API Returns Empty Data
**Symptoms**: 
- Status 200 ✅
- But `"data": []` (empty array)

**Solutions**:
1. Check if any milk records exist in database
   ```sql
   SELECT COUNT(*) FROM milk_collections WHERE tenant_id = YOUR_TENANT_ID;
   ```

2. Check if date filters are too restrictive
   - API filters by `start_date` and `end_date` if provided
   - Try without date filters first

3. Verify farmer records exist
   - If filtering by `farmer_id`, make sure farmers exist

### Issue 4: Auth Token Expired
**Error**: `Unauthorized 401`

**Solution**:
- User needs to login again
- Token is saved to SharedPreferences
- Check if `_getAuthToken()` returns null

---

## Quick Debug Checklist

Before troubleshooting, verify these in order:

- [ ] User is logged in (SharedPreferences has 'token')
- [ ] tenant_id is saved (SharedPreferences has 'tenant_id')  
- [ ] API endpoint is accessible (`/api/milk-collections-sync`)
- [ ] Database has milk records for the tenant
- [ ] Hive box opens without errors (`lib/main.dart`)
- [ ] `SyncService.downloadMilkCollections()` returns `true`
- [ ] Hive box has records after download (use `_checkHiveData()`)
- [ ] Milk receipts show correct totals on print

---

## Logs to Monitor

Watch the Flutter console for these log messages:

**Success Indicators** ✅
```
🔄 downloadMilkCollections called - token: exists, tenantId: 1
📥 Downloading milk collections from: http://api/milk-collections-sync...
📡 Response status: 200
📦 Received 150 milk collections from API
✅ Downloaded 150 new, updated 0 collections
```

**Error Indicators** ❌
```
Cannot download collections: missing auth token or tenant ID
❌ Failed to download collections: 400
❌ Error downloading collections: ...
```

---

## Implementation Details

### Files Involved:
- **Backend**: `/laravel/comaziwa/app/Http/Controllers/MilkCollectionController.php`
- **Routes**: `/laravel/comaziwa/routes/api.php` (line 38)
- **Flutter Service**: `/android/comaziwa-app/lib/services/sync_service.dart`
- **Dashboard Init**: `/android/comaziwa-app/lib/screens/dashboard_page.dart` (line 91)
- **Hive Init**: `/android/comaziwa-app/lib/main.dart`

### Flow:
1. User logs in → tenant_id saved
2. Dashboard loads → calls `SyncService.downloadMilkCollections()`
3. Service makes GET request to `/api/milk-collections-sync`
4. API returns milk records
5. Service stores records in Hive box
6. Receipt uses Hive data to calculate totals

---

## Next Steps

1. **Run the API test** (use cURL or Postman above)
2. **Check Hive after login** (add `_checkHiveData()` debug function)
3. **Review logs** during dashboard load
4. **Report any errors** from logs above
5. **Verify totals appear** on milk collection receipts
