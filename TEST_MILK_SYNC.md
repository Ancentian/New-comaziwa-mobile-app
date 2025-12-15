# Testing Milk Collection Sync

## Quick Test Steps

### 1. Check if Hive has synced data
```dart
// In any Dart file, check:
final box = Hive.box<MilkCollection>('milk_collections');
print("Total records in Hive: ${box.length}");

// Check how many are from server vs local
int fromServer = 0;
int local = 0;
for (var record in box.values) {
  if (record.serverId != null) {
    fromServer++;
  } else {
    local++;
  }
}
print("From Server: $fromServer, Local Only: $local");
```

### 2. Test Backend API
```bash
# Get auth token first (login)
curl -X POST "http://your-api-url/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"your@email.com","password":"yourpassword"}'

# Test milk collections sync endpoint
curl -X GET "http://your-api-url/api/milk-collections-sync?tenant_id=1" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"
```

### 3. Test in Flutter App

**Step 1: Login**
- Open the app
- Login with your credentials
- Should see "Syncing data..." toast
- Check debug console for: "✅ Downloaded X new, updated Y collections"

**Step 2: Check Milk List Page**
- Navigate to Milk List
- Pull down to refresh (should see "Syncing from server..." then "Data refreshed")
- Or tap the refresh icon in the top right
- Records should now show both:
  - Previously created collections (local)
  - Collections from server (synced)

**Step 3: Verify Receipt Totals**
- Go to Milk Collection page
- Search for a farmer
- Create a new collection
- Print receipt
- Should show:
  - Morning/Evening/Rejected
  - Today's Weight
  - Monthly Weight
  - **Yearly Weight** (NEW!)

### 4. Check Debug Logs

Look for these messages in the console:

**On Login (Dashboard):**
```
Syncing data...
📥 Downloading milk collections from: http://...
✅ Downloaded X new, updated Y collections
All data synced successfully
```

**On Milk List Page:**
```
📊 Loading X records from Hive
✅ Loaded X total records (synced + local)
```

**On Milk Collection Page:**
```
✅ Milk collections downloaded successfully
```

## Troubleshooting

### Issue: Milk list shows 0 records or only local records

**Solution 1: Check if sync completed**
```dart
// Check Hive box
final box = Hive.box<MilkCollection>('milk_collections');
print("Hive has ${box.length} records");
```

**Solution 2: Manually trigger sync**
- Go to Dashboard
- Or pull down on Milk List page
- Or tap refresh icon

**Solution 3: Check API response**
- Check backend logs
- Ensure tenant_id is correct
- Verify collections exist in database for your tenant

### Issue: Duplicate records showing

**Solution: Clear Hive and resync**
```dart
final box = Hive.box<MilkCollection>('milk_collections');
await box.clear();
await SyncService().downloadMilkCollections();
```

### Issue: Yearly total not showing on receipt

**Check:**
1. Hive has historical data (not just today's)
2. Debug print in _autoPrintReceipt shows yearlyTotal > 0
3. Receipt template includes yearly_total field

### Issue: Backend API returns empty data

**Check Laravel:**
1. Verify route is registered: `php artisan route:list | grep milk-collections-sync`
2. Check database has records: `SELECT COUNT(*) FROM milk_collections WHERE tenant_id=1;`
3. Check date filter (default is last 3 months)
4. Check Laravel logs: `tail -f storage/logs/laravel.log`

## Expected Results

### On Fresh Install
- Hive: 0 records
- After login: X records (from server)
- Milk List: Shows X records

### After Creating Local Collection
- Hive: X+1 records (X synced + 1 local unsynced)
- Milk List: Shows X+1 records
- After sync: All X+1 marked as synced

### Receipt Should Show
```
Morning: 10.5 L
Evening: 8.0 L
Rejected: 0.5 L
--------------------------------
Today's Weight: 18.0 L
Monthly Weight: 156.5 L
Yearly Weight: 2,345.0 L      ← NEW!
```

## Performance Expectations

- **Initial sync**: 3 months of data (~90-500 records) in 2-5 seconds
- **Hive query**: <100ms for 1000 records
- **Receipt generation**: <200ms including totals calculation
- **Milk list load**: <500ms from Hive

## Data Flow

```
Server DB → API → Flutter App → Hive
    ↓                              ↓
 Collections              Local + Synced
    ↓                              ↓
Laravel                      Milk List
Controller                    Display
    ↓                              ↓
  JSON                        Receipts
Response                    with Totals
```

## Manual Verification Queries

### Check Hive Contents
```dart
final box = Hive.box<MilkCollection>('milk_collections');
print("=== HIVE CONTENTS ===");
print("Total: ${box.length}");

int synced = 0;
int unsynced = 0;
int withServerId = 0;

for (var record in box.values) {
  if (record.isSynced) synced++;
  if (!record.isSynced) unsynced++;
  if (record.serverId != null) withServerId++;
}

print("Synced: $synced");
print("Unsynced: $unsynced");
print("With Server ID: $withServerId");
print("Without Server ID (local only): ${box.length - withServerId}");
```

### Check Specific Farmer's Data
```dart
final box = Hive.box<MilkCollection>('milk_collections');
final farmerId = 508; // Change to test farmer ID

print("=== FARMER $farmerId COLLECTIONS ===");
final farmerCollections = box.values.where((c) => c.farmerId == farmerId).toList();
print("Total collections: ${farmerCollections.length}");

double total = 0;
for (var c in farmerCollections) {
  total += c.morning + c.evening - c.rejected;
  print("${c.date}: ${c.morning}L + ${c.evening}L - ${c.rejected}L = ${c.morning + c.evening - c.rejected}L");
}
print("Grand Total: ${total}L");
```

## Success Indicators

✅ Dashboard shows "All data synced successfully"
✅ Milk list shows records from past months (not just today)
✅ Pulling down refreshes and adds any new server records
✅ Receipt shows yearly total > monthly total
✅ Debug logs show "Downloaded X new, updated Y collections"
✅ No duplicate records visible
✅ Offline mode still shows all synced data
