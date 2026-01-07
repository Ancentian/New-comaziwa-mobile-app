# Role-Based Filtering Implementation

## Overview
Implemented role-based access control for milk collection records. Administrators can view all records, while employees (milk graders) can only view records they personally created.

## Changes Made

### 1. **MilkCollection Model** (`lib/models/milk_collection.dart`)
Added new fields to track who created each milk collection record:
- `createdById` (int?) - User/Employee ID who created the record
- `createdByType` (String?) - User type: 'admin', 'owner', 'employee', 'grader', etc.

These fields are:
- Saved when creating new collections
- Synced to/from the server
- Used for filtering records by ownership

### 2. **Daily Collection Summary Page** (`lib/screens/daily_collection_summary_page.dart`)
- Added user info loading on initialization
- Implemented role-based filtering:
  - **Admin/Owner**: See ALL collections for the selected date
  - **Employee/Grader**: See ONLY collections they personally recorded
- Filtering happens client-side using Hive data

### 3. **Milk List Page** (`lib/screens/milk_list_page.dart`)
- Added same role-based filtering as daily summary
- Employees see only their own records across all dates
- Maintains existing date range and search filters

### 4. **Milk Collection Page** (`lib/screens/milk_collection_page.dart`)
- Now saves creator information when recording new collections
- Automatically captures current user's ID and type from SharedPreferences
- Creator info is stored in Hive and synced to server

### 5. **Schema Version** (`lib/main.dart`)
- Incremented schema version to 3 (was 2)
- Triggers data migration when app updates
- Ensures Hive adapters are regenerated

### 6. **Hive Adapters**
- Regenerated type adapters to support new fields
- Uses `build_runner` to generate `milk_collection.g.dart`

## How It Works

### User Login
When a user logs in (`lib/screens/login_page.dart`):
```dart
- type: 'admin', 'owner', 'employee', 'grader'
- user_id: 123
```
This info is saved to SharedPreferences.

### Recording Collection
When a milk grader records a new collection:
```dart
MilkCollection(
  farmerId: 101,
  morning: 10.5,
  evening: 8.0,
  ...
  createdById: 123,        // Current user ID
  createdByType: 'grader', // Current user type
)
```

### Viewing Records
When viewing daily summary or milk list:

**If user is Admin/Owner:**
```dart
// No filtering - show all records
collections = box.values.where((c) => c.date == selectedDate)
```

**If user is Employee/Grader:**
```dart
// Filter to only their records
collections = box.values.where((c) => 
  c.date == selectedDate && 
  c.createdById == currentUserId
)
```

## User Roles

### Administrator / Owner
- **Type**: `admin` or `owner`
- **Access**: ALL records from ALL users
- **Use Case**: Management oversight, reporting, auditing

### Employee / Milk Grader
- **Type**: `employee`, `grader`, or any other non-admin type
- **Access**: ONLY records they personally created
- **Use Case**: Individual grader performance tracking, personal daily summary

## Database Fields

### Local Storage (Hive)
```dart
@HiveField(10) int? createdById
@HiveField(11) String? createdByType
```

### Server API
Sync service sends/receives:
```json
{
  "created_by_id": 123,
  "created_by_type": "grader"
}
```

## Security Considerations

### Client-Side Filtering
- Filtering is done on the mobile app (client-side)
- Uses data stored in local Hive database
- Trust model: Users cannot manipulate their own role/permissions

### Server-Side Validation
The backend API should also implement role-based access:
- Verify user role when fetching collections
- Ensure employees can only see their own records
- Admins get unrestricted access

### Data Sync
- When syncing FROM server, records include creator info
- When syncing TO server, local records include creator info
- Server validates and may override creator fields if needed

## Testing

### Test Cases
1. **Admin Login**
   - View daily summary → Should see ALL collections
   - View milk list → Should see ALL collections
   - Create new collection → Saves as created by admin

2. **Grader Login**
   - View daily summary → Should see ONLY own collections
   - View milk list → Should see ONLY own collections
   - Create new collection → Saves as created by grader

3. **Multiple Graders**
   - Grader A records 5 collections
   - Grader B records 8 collections
   - Grader A views summary → Sees only their 5
   - Grader B views summary → Sees only their 8
   - Admin views summary → Sees all 13

4. **Mixed Data**
   - Old records without creator info (createdById = null)
   - New records with creator info
   - Filtering handles both cases gracefully

## Migration Notes

### Existing Data
Old milk collection records in Hive won't have `createdById` or `createdByType`:
- These fields will be `null`
- Filtering logic handles null values
- Old records are visible to admins but not to employees

### After Update
- Schema version bumps to 3
- Hive adapters regenerated automatically
- New collections include creator info
- Server sync includes creator fields

## Logs

Console output shows filtering in action:

**Admin:**
```
👑 Admin/Owner - showing all 45 collections
```

**Employee:**
```
🔒 Filtered to 12 collections for user 123
```

## Future Enhancements

- [ ] Add collection center filtering for graders
- [ ] Add date range restrictions per role
- [ ] Add export/print permissions by role
- [ ] Add supervisor role (sees all in specific centers)
- [ ] Add audit trail for record modifications
- [ ] Backend API role validation
