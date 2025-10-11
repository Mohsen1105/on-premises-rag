# Add Duplicate Filename Check to Your Workflow

## Current Flow
```
Loop Over Items → GetContentOfOne → Document Data2 → ...
```

## New Flow
```
Loop Over Items → CheckFileExists (PostgreSQL) → ProcessCheck (Code) → ShouldProcess (IF)
                                                                              ↓
                                                                    True → GetContentOfOne → ...
                                                                    False → Loop Over Items (skip)
```

## Step-by-Step Instructions

### Step 1: Add PostgreSQL Node "CheckFileExists"

**Position:** Right after "Loop Over Items" node (position: [200, 1024])

**Configuration:**
1. **Node Type:** PostgreSQL
2. **Name:** `CheckFileExists`
3. **Operation:** Execute Query
4. **Connection:** Use your existing "Postgres account 2" credentials

**Query:**
```sql
SELECT
  COUNT(*) as file_count,
  '{{ $json.fileName }}' as fileName
FROM vectors.documents
WHERE metadata->>'fileName' = '{{ $json.fileName }}';
```

**What it does:** Checks if a document with this fileName already exists in the metadata column.

---

### Step 2: Add Code Node "ProcessCheckResult"

**Position:** After CheckFileExists (position: [400, 1024])

**Configuration:**
1. **Node Type:** Code
2. **Name:** `ProcessCheckResult`

**JavaScript Code:**
```javascript
// Get the file count from PostgreSQL query
const fileCount = parseInt($input.first().json.file_count) || 0;

// Get fileName from the query result
const fileName = $input.first().json.fileName;

// Get fileId from Loop Over Items node
const loopData = $('Loop Over Items').item.json;
const fileId = loopData.fileId;

// Determine if file exists
const fileExists = fileCount > 0;

// Log the result
if (fileExists) {
  console.log(`⚠️ File already exists: ${fileName} (Skipping)`);
} else {
  console.log(`✅ New file detected: ${fileName} (Processing)`);
}

return {
  json: {
    fileName: fileName,
    fileId: fileId,
    fileExists: fileExists,
    fileCount: fileCount,
    shouldProcess: !fileExists,
    status: fileExists ? 'skipped' : 'processing'
  }
};
```

---

### Step 3: Add IF Node "ShouldProcessFile"

**Position:** After ProcessCheckResult (position: [600, 1024])

**Configuration:**
1. **Node Type:** IF
2. **Name:** `ShouldProcessFile`

**Conditions:**
- **Condition 1:**
  - **Field Name:** `shouldProcess`
  - **Operation:** Equal to (=)
  - **Value:** `true`

**Output:**
- **True branch:** Connect to `GetContentOfOne`
- **False branch:** Connect back to `Loop Over Items` (to continue with next file)

---

### Step 4: Update Connections

**Old Connection:**
```
Loop Over Items (output 2) → GetContentOfOne
```

**New Connections:**
```
Loop Over Items (output 2) → CheckFileExists
CheckFileExists → ProcessCheckResult
ProcessCheckResult → ShouldProcessFile
ShouldProcessFile (True) → GetContentOfOne
ShouldProcessFile (False) → Loop Over Items (to continue loop)
```

---

## Visual Guide

```
┌─────────────────────┐
│   Loop Over Items   │
└──────────┬──────────┘
           │
           ├─ Output 1: Loop complete → [End]
           │
           └─ Output 2: Process item
                  ↓
           ┌─────────────────────┐
           │  CheckFileExists    │ ← NEW
           │  (PostgreSQL Query) │
           └──────────┬──────────┘
                      ↓
           ┌─────────────────────┐
           │ ProcessCheckResult  │ ← NEW
           │   (Code Node)       │
           └──────────┬──────────┘
                      ↓
           ┌─────────────────────┐
           │  ShouldProcessFile  │ ← NEW
           │     (IF Node)       │
           └──────┬───────┬──────┘
                  │       │
         True ────┘       └──── False (Skip)
           │                     │
           ↓                     ↓
    ┌─────────────────┐   Back to Loop
    │ GetContentOfOne │
    └─────────────────┘
           ↓
    [Rest of workflow...]
```

---

## Testing

### Test 1: New File (First Time)
1. Run workflow with a new filename
2. Expected: Should process normally
3. Log: `✅ New file detected: filename (Processing)`

### Test 2: Existing File (Duplicate)
1. Run workflow with same filename again
2. Expected: Should skip processing
3. Log: `⚠️ File already exists: filename (Skipping)`

---

## Monitoring Results

Add this **Code Node** at the end of your workflow (after Loop completes) to see summary:

**Node Name:** `IngestionSummary`

**JavaScript Code:**
```javascript
// This runs after the loop completes
const allItems = $input.all();

const processed = allItems.filter(i => i.json.status === 'processing').length;
const skipped = allItems.filter(i => i.json.status === 'skipped').length;
const total = allItems.length;

console.log(`
═══════════════════════════════════
  Ingestion Complete
═══════════════════════════════════
  ✅ Processed: ${processed}
  ⏭️  Skipped:   ${skipped}
  📊 Total:     ${total}
═══════════════════════════════════
`);

return {
  json: {
    summary: {
      processed,
      skipped,
      total,
      timestamp: new Date().toISOString()
    },
    details: allItems
  }
};
```

Connect this to **Output 1** of "Loop Over Items" (when loop completes).

---

## Important Notes

1. **Metadata Structure**: The query assumes your documents store `fileName` in the metadata JSONB column like:
   ```json
   {
     "metadata": {
       "fileName": "example.docx"
     }
   }
   ```

2. **Case Sensitivity**: The check is case-sensitive. If you want case-insensitive:
   ```sql
   WHERE LOWER(metadata->>'fileName') = LOWER('{{ $json.fileName }}')
   ```

3. **Performance**: This adds one PostgreSQL query per file. For large batches, consider the batch approach mentioned in the reference document.

4. **Metadata Storage**: Make sure your ingestion process stores the fileName in metadata. You might need to add this before the "Postgres PGVector Store" node.

---

## Adding Metadata to Storage

If your current workflow doesn't store fileName in metadata, add this **Code Node** before "Postgres PGVector Store":

**Node Name:** `AddMetadata`

**JavaScript Code:**
```javascript
const items = $input.all();

return items.map(item => ({
  json: {
    ...item.json,
    metadata: {
      ...item.json.metadata,
      fileName: $('Loop Over Items').item.json.fileName,
      fileId: $('Loop Over Items').item.json.fileId,
      ingestedAt: new Date().toISOString()
    }
  }
}));
```

This ensures the fileName is stored in the vector store metadata for future checks.
