# Shortcut Folder Selection Guide - Which Folder to Use?

## 🎯 The Answer: Use the PRIMARY Location

**Use this path in your shortcut:**
```
On My iPhone → NoteWall → NoteWall → HomeScreen
On My iPhone → NoteWall → NoteWall → LockScreen
```

**NOT this one:**
```
On My iPhone → NoteWall → Shortcuts → NoteWall → HomeScreen  ❌ (This is legacy/backup)
```

---

## 📁 Understanding the Two Folder Locations

### 1. PRIMARY Location (Use This One) ✅
**Path:** `On My iPhone/NoteWall/NoteWall/HomeScreen` and `On My iPhone/NoteWall/NoteWall/LockScreen`

**What it is:**
- This is where the app **actually saves** wallpaper files
- This is the **main** location the app uses
- Files are saved here: `homescreen.jpg` and `lockscreen.jpg`

**In code:**
- Defined by `baseDirectoryURL` in `HomeScreenImageManager`
- Path: `Documents/NoteWall/HomeScreen/` and `Documents/NoteWall/LockScreen/`
- Since the app's Documents folder shows as `On My iPhone/NoteWall/` in Files app, the full path is `On My iPhone/NoteWall/NoteWall/HomeScreen/`

**What you see in Files app:**
- Navigate to: `On My iPhone → NoteWall → NoteWall`
- You'll see: `HomeScreen` folder, `LockScreen` folder, `TextEditor` folder
- Each folder contains the wallpaper files

### 2. LEGACY/MIRROR Location (Don't Use This) ❌
**Path:** `On My iPhone/NoteWall/Shortcuts/NoteWall/HomeScreen` and `On My iPhone/NoteWall/Shortcuts/NoteWall/LockScreen`

**What it is:**
- This is a **backup/mirror** location for backward compatibility
- Files are **copied** here from the primary location
- This was the old location used in earlier versions
- The app maintains this for old shortcuts that might still reference it

**In code:**
- Defined by `legacyBaseDirectoryURL` in `HomeScreenImageManager`
- Path: `Documents/Shortcuts/NoteWall/HomeScreen/` and `Documents/Shortcuts/NoteWall/LockScreen/`
- Since the app's Documents folder shows as `On My iPhone/NoteWall/` in Files app, the full path is `On My iPhone/NoteWall/Shortcuts/NoteWall/HomeScreen/`
- Files are mirrored here via `mirrorFileToLegacyDirectory()` function

**Why it exists:**
- Backward compatibility with old shortcuts
- The app automatically mirrors files here, but it's not the primary location

---

## ✅ Correct Shortcut Configuration

### For "Get contents of HomeScreen" action:
1. Tap on the blue "HomeScreen" variable
2. Navigate to: **`On My iPhone → NoteWall → NoteWall → HomeScreen`**
3. Select the **HomeScreen** folder (the one inside the second NoteWall folder, NOT inside Shortcuts)
4. Tap "Always Allow"

### For "Get contents of LockScreen" action:
1. Tap on the blue "LockScreen" variable
2. Navigate to: **`On My iPhone → NoteWall → NoteWall → LockScreen`**
3. Select the **LockScreen** folder (the one inside the second NoteWall folder, NOT inside Shortcuts)
4. Tap "Always Allow"

---

## 🔍 How to Verify You're Using the Right Folder

### Visual Check:
When you navigate in the Files app, you should see this structure:

**CORRECT PATH (Use This):**
```
On My iPhone
  └── NoteWall          ← App's document folder (shows as app name)
      └── NoteWall      ← The NoteWall subfolder created by app
          ├── HomeScreen    ← Select this folder
          │   └── homescreen.jpg
          └── LockScreen   ← Select this folder
              └── lockscreen.jpg
```

**WRONG PATH (Don't Use This):**
```
On My iPhone
  └── NoteWall
      └── Shortcuts        ← Don't go here
          └── NoteWall
              ├── HomeScreen
              └── LockScreen
```

### In Shortcuts App:
After selecting the folder, check:
- The folder path should show: `On My iPhone/NoteWall/NoteWall/HomeScreen`
- It should **NOT** show: `On My iPhone/NoteWall/Shortcuts/NoteWall/HomeScreen`
- The folder name should **NOT** be blue/variable anymore (should be hardcoded)

---

## 🤔 Why Both Folders Exist

The app maintains both locations because:

1. **Primary location** (`On My iPhone/NoteWall/`) is the new, correct location
2. **Legacy location** (`On My iPhone/Shortcuts/NoteWall/`) is kept for:
   - Old shortcuts that still reference it
   - Backward compatibility
   - Automatic file mirroring (files are copied there automatically)

**But for NEW shortcuts, always use the PRIMARY location.**

---

## ⚠️ Common Mistakes

### Mistake 1: Using the Shortcuts folder
- ❌ Selecting `On My iPhone/NoteWall/Shortcuts/NoteWall/HomeScreen`
- ✅ Should be: `On My iPhone/NoteWall/NoteWall/HomeScreen`

### Mistake 2: Selecting the wrong NoteWall folder
- When you go to `On My iPhone/NoteWall`, you'll see THREE folders:
  - `NoteWall` folder (with 4 items) - **USE THIS ONE** ✅
  - `Shortcuts` folder (contains NoteWall subfolder) - Don't use this ❌
  - `RevenueCat` folder - Don't use this ❌
- You need to go INTO the `NoteWall` folder (the one with 4 items), then select `HomeScreen` or `LockScreen`

### Mistake 3: Not going deep enough
- ❌ Selecting `On My iPhone/NoteWall/NoteWall` (the parent folder)
- ✅ Should select `On My iPhone/NoteWall/NoteWall/HomeScreen` (the specific folder)

---

## 📝 Step-by-Step Configuration

1. **Open Shortcuts app**
2. **Edit your "Set Notewall Wallpaper" shortcut**
3. **Find "Get contents of HomeScreen" action**
4. **Tap on the blue "HomeScreen" text**
5. **Tap "Choose" or the folder icon**
6. **Navigate:**
   - Tap "On My iPhone" (at the top)
   - Tap "NoteWall" folder (the app's document folder)
   - Tap "NoteWall" folder again (the subfolder with 4 items)
   - Tap "HomeScreen" folder
   - Tap "Open" or select it
7. **When prompted, tap "Always Allow"**
8. **Repeat for LockScreen:**
   - Find "Get contents of LockScreen" action
   - Tap on blue "LockScreen" text
   - Navigate to: `On My iPhone → NoteWall → NoteWall → LockScreen`
   - Tap "Always Allow"

---

## ✅ Verification Checklist

After configuring, verify:
- [ ] HomeScreen folder path shows: `On My iPhone/NoteWall/NoteWall/HomeScreen`
- [ ] LockScreen folder path shows: `On My iPhone/NoteWall/NoteWall/LockScreen`
- [ ] Folder names are NOT blue/variable (they're hardcoded)
- [ ] You can see the folder path when you tap on the action
- [ ] Test the shortcut - it should work without asking for folder selection

---

## 🎯 Summary

**USE:** `On My iPhone/NoteWall/NoteWall/HomeScreen` and `On My iPhone/NoteWall/NoteWall/LockScreen`

**DON'T USE:** `On My iPhone/NoteWall/Shortcuts/NoteWall/HomeScreen` (this is just a backup mirror)

**Note:** When you navigate to `On My iPhone/NoteWall`, you'll see three folders:
1. **NoteWall** (with 4 items) - Go into THIS one, then select HomeScreen/LockScreen ✅
2. **Shortcuts** (contains NoteWall subfolder) - Don't use this ❌
3. **RevenueCat** - Don't use this ❌

The primary location is where the app actually saves files. The Shortcuts folder is just a legacy mirror for backward compatibility.

