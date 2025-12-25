# 🙏 FaithWall Bible Feature - Vibe Coder Mega Prompt Guide

> **For:** Vibe coders using Claude (Opus 4.5/Sonnet 4.5) or GitHub Copilot
> **Project:** Adding Bible verse database to FaithWall iOS app
> **Estimated Sessions:** 5-7 AI coding sessions
> **Difficulty:** Medium (but broken into easy chunks)

---

## 📋 Table of Contents

1. [Pre-Work: Download Database Files](#pre-work-download-database-files)
2. [Session 1: Database Foundation](#session-1-database-foundation)
3. [Session 2: Bible Data Models](#session-2-bible-data-models)
4. [Session 3: Bible Picker UI](#session-3-bible-picker-ui)
5. [Session 4: Search Feature](#session-4-search-feature)
6. [Session 5: Language Selection in Onboarding](#session-5-language-selection-in-onboarding)
7. [Session 6: Connect to Lock Screen Feature](#session-6-connect-to-lock-screen-feature)
8. [Session 7: Testing & Polish](#session-7-testing--polish)
9. [Troubleshooting Prompts](#troubleshooting-prompts)

---

## 🔧 Pre-Work: Download Database Files

**Do this BEFORE any coding sessions:**

### Step 1: Download SQLite Files

Go to: https://github.com/scrollmapper/bible_databases/tree/master/formats/sqlite

Download these files (click each → Download):
- `KJV.sqlite` (English - King James Version)
- `BSB.sqlite` (English - Berean Standard Bible) 
- `UkrOgienko.sqlite` (Ukrainian)
- `RusSynodal.sqlite` (Russian)

### Step 2: Add to Xcode Project

1. Create folder: `Faithwall/Database/`
2. Drag all `.sqlite` files into this folder in Xcode
3. **IMPORTANT:** Check "Copy items if needed" and "Add to target: FaithWall"

### Step 3: Verify Files Are Bundled

In Xcode: Project → Build Phases → Copy Bundle Resources
Make sure all `.sqlite` files are listed there.

---

## 🧠 Session 1: Database Foundation

### PROMPT 1A - THINKING (Copy this entire block)

```
I'm building FaithWall, an iOS app in SwiftUI. I need to add a Bible verse feature using local SQLite databases.

CURRENT SITUATION:
- I have SQLite files in my Xcode project under Faithwall/Database/
- Files: KJV.sqlite, BSB.sqlite, UkrOgienko.sqlite, RusSynodal.sqlite
- Each SQLite file has tables:
  - `{translation}_books` with columns: id, name
  - `{translation}_verses` with columns: id, book_id, chapter, verse, text
  - Example: KJV_books, KJV_verses

WHAT I NEED:
Create a BibleDatabaseService.swift file that:
1. Can open any of my bundled SQLite files
2. Has functions to:
   - Get all books for a translation
   - Get all chapters for a book
   - Get all verses for a chapter
   - Get a specific verse by book, chapter, verse number
3. Uses proper Swift error handling
4. Works offline (all data is local)

CONSTRAINTS:
- Must work with iOS 15+
- Use SQLite3 (built into iOS, no external packages)
- Keep it simple - I'm a vibe coder

Before writing any code, explain:
1. What the file structure will look like
2. How the database connection will work
3. What functions you'll create and why
```

### PROMPT 1B - EXECUTION (After AI explains, send this)

```
Perfect, now create the complete BibleDatabaseService.swift file.

Requirements:
- Put it in the Faithwall/ folder
- Include all the functions you described
- Add helpful comments explaining what each part does
- Include a simple test function I can call to verify it works
- Handle the case where database file doesn't exist gracefully

Show me the complete file, then tell me exactly how to add it to my Xcode project.
```

### PROMPT 1C - VERIFICATION (After adding the file)

```
I added BibleDatabaseService.swift to my project. Now I need to verify it works.

Create a simple test view called BibleDatabaseTestView.swift that:
1. On appear, tries to load all books from KJV
2. Shows a list of book names if successful
3. Shows an error message if it fails
4. Has a button to test getting John 3:16

This is just for testing - we'll delete it later. Keep it simple.

Also tell me how to preview this view in Xcode to see if it works.
```

---

## 📦 Session 2: Bible Data Models

### PROMPT 2A - THINKING

```
I have BibleDatabaseService.swift working in my FaithWall app. Now I need proper data models.

CURRENT APP CONTEXT:
- App already has Models.swift with Note struct and other types
- App uses @AppStorage for user preferences
- App has PaywallManager, NotificationManager patterns

WHAT I NEED:
Create BibleModels.swift with:
1. BibleTranslation enum (KJV, BSB, UkrOgienko, RusSynodal)
2. BibleBook struct (id, name, translationKey)
3. BibleChapter struct
4. BibleVerse struct (book, chapter, verse number, text, translation)
5. A way to format verses nicely like "John 3:16 - For God so loved..."

Before coding, explain:
1. How these models will connect to the database service
2. How the translation enum will map to SQLite file names
3. What Codable/Identifiable protocols each needs
```

### PROMPT 2B - EXECUTION

```
Create BibleModels.swift with all the models you described.

Requirements:
- Make models work well with SwiftUI (Identifiable, etc.)
- Add a computed property to BibleVerse for formatted display
- Include language display names (English, Ukrainian, Russian)
- Add helper to get the SQLite table prefix for each translation

Also update BibleDatabaseService.swift to use these new models instead of raw data.
```

### PROMPT 2C - VERIFICATION

```
I added BibleModels.swift. Update my BibleDatabaseTestView.swift to:
1. Show a picker to switch between translations
2. Display book names in that translation
3. Show a verse with its formatted string

This will verify the models work correctly with the database service.
```

---

## 🎨 Session 3: Bible Picker UI

### PROMPT 3A - THINKING

```
I need to create the main Bible verse picker UI for FaithWall.

USER FLOW:
1. User opens Bible tab/section
2. Sees list of Bible books (Genesis, Exodus, etc.)
3. Taps a book → sees chapters (1, 2, 3...)
4. Taps a chapter → sees verses
5. Taps a verse → verse is selected and can be added to their lock screen

EXISTING APP PATTERNS:
- App uses NavigationView with custom styling
- Colors: mostly dark theme, accent colors
- Already has ContentView.swift with notes list
- Has SettingsView.swift for reference on styling

WHAT I NEED:
A 3-level navigation picker:
- BiblePickerView.swift (main entry, shows books)
- BibleChapterPickerView.swift (shows chapters for selected book)
- BibleVersePickerView.swift (shows verses, allows selection)

Before coding, explain:
1. Navigation structure (sheets vs navigation links)
2. How selected verse will be passed back
3. UI layout for each screen
```

### PROMPT 3B - EXECUTION

```
Create all three Bible picker views:

1. BiblePickerView.swift
   - Shows translation picker at top
   - Lists all books (maybe grouped: Old Testament, New Testament)
   - Search/filter books by name
   - Navigation to chapters

2. BibleChapterPickerView.swift  
   - Shows book name as title
   - Grid of chapter numbers (1, 2, 3... in a grid)
   - Tap to go to verses

3. BibleVersePickerView.swift
   - Shows "Book Chapter" as title (e.g., "John 3")
   - Lists all verses with their text
   - Tap verse to select it
   - "Add to Lock Screen" button when verse selected

Requirements:
- Match the dark theme style of my existing app
- Use @Environment(\.dismiss) for navigation
- Pass selected verse back via a completion handler or binding
- Loading states while fetching from database
```

### PROMPT 3C - VERIFICATION

```
I added all three picker views. Now I need to test the flow.

1. Create a simple test in ContentView that shows a button "Pick Bible Verse"
2. When tapped, present BiblePickerView as a sheet
3. When user selects a verse, print it to console and dismiss

Tell me exactly what code to add to ContentView.swift to test this.
If there are any errors, help me fix them.
```

---

## 🔍 Session 4: Search Feature

### PROMPT 4A - THINKING

```
I need to add Bible verse search to FaithWall.

SEARCH REQUIREMENTS:
1. Search by reference: "John 3:16" → goes directly to that verse
2. Search by words: "love" → finds all verses containing "love"
3. Search should work across the selected translation

TECHNICAL CONTEXT:
- Using SQLite with tables like KJV_verses
- Verses have: id, book_id, chapter, verse, text
- Books have: id, name
- Database is local, ~4MB per translation

QUESTIONS TO ANSWER:
1. How to parse "John 3:16" format reliably?
2. How to make word search fast (LIKE vs FTS)?
3. Should search be on a separate view or integrated into picker?
4. How to handle partial matches (John vs 1 John vs 2 John)?
```

### PROMPT 4B - EXECUTION

```
Create BibleSearchView.swift with:

1. Search bar at top
2. Smart parsing that detects:
   - Book name search: "gene" → shows Genesis, etc.
   - Reference search: "John 3:16" or "Jn 3:16" → direct verse
   - Word search: "faith hope love" → verses containing these words

3. Results list showing:
   - Verse reference (John 3:16)
   - Verse text preview (first 100 chars...)
   - Tap to select

4. Add search to BibleDatabaseService:
   - searchVersesByText(query: String, translation: String) -> [BibleVerse]
   - parseReference(input: String) -> (book: String, chapter: Int, verse: Int)?

Make search feel responsive - maybe add debouncing so it doesn't search on every keystroke.
```

### PROMPT 4C - VERIFICATION

```
Test the search feature:

1. Add a search icon/tab to BiblePickerView that opens BibleSearchView
2. Test these searches and tell me what to look for:
   - "John" (should show John, 1 John, 2 John, 3 John)
   - "John 3:16" (should jump to that verse)
   - "love" (should show multiple verses)
   - "Deuteronomy 30:19" (should find it)

If search is slow (>1 second), suggest optimizations.
```

---

## 🌍 Session 5: Language Selection in Onboarding

### PROMPT 5A - THINKING

```
I need to add language/Bible translation selection to FaithWall's onboarding.

CURRENT ONBOARDING:
- File: OnboardingView.swift (8000+ lines, very complex)
- Has multiple steps with videos and instructions
- Uses @AppStorage for saving user choices
- Has OnboardingEnhanced.swift as well

WHAT I WANT:
- Early in onboarding, ask user: "Choose your Bible language"
- Options: English, Ukrainian, Russian (with flag emojis maybe)
- Save their choice to @AppStorage
- This selection determines which SQLite database to use throughout the app

MY CONCERN:
OnboardingView.swift is HUGE (8000 lines). I don't want to break it.

Questions:
1. Where in the onboarding flow should language selection go?
2. Should it be a new step or modify existing step?
3. How to safely edit such a large file?
4. How will the rest of the app know which language was selected?
```

### PROMPT 5B - EXECUTION

```
Let's do this safely:

1. First, create a standalone LanguageSelectionView.swift
   - Beautiful UI with language options
   - Flag emojis or icons for each language
   - Saves to @AppStorage("selectedBibleTranslation")
   - Can work standalone AND be embedded in onboarding

2. Create a LanguageManager.swift
   - Singleton that reads the @AppStorage value
   - Provides current translation to the whole app
   - Has default (English/KJV) if nothing selected

3. THEN give me the minimal changes needed to OnboardingView.swift
   - Show me exactly which lines to find and what to add
   - Keep changes as small as possible
   - Don't rewrite large sections

Show me each file separately with clear instructions.
```

### PROMPT 5C - VERIFICATION

```
Test the language selection:

1. How do I reset onboarding to test it again?
2. Add a way in SettingsView to see/change the selected language
3. Verify BiblePickerView uses the selected language by default

Show me what to add to SettingsView.swift to display and change language.
```

---

## 🔗 Session 6: Connect to Lock Screen Feature

### PROMPT 6A - THINKING

```
Now the big moment: connecting Bible verses to the existing lock screen feature.

CURRENT LOCK SCREEN SYSTEM:
- Users add "notes" which appear on their lock screen wallpaper
- Note struct in Models.swift: id, text, isCompleted
- Notes are rendered to an image by WallpaperRenderer.swift
- An iOS Shortcut applies the wallpaper

WHAT I WANT:
When user selects a Bible verse:
1. Format it nicely: "John 3:16 - For God so loved the world..."
2. Add it as a new Note to their list
3. Trigger wallpaper update
4. Verse appears on their lock screen!

QUESTIONS:
1. Should Bible verses be stored as Notes or separate BibleFavorite type?
2. How to format verses to look good on lock screen?
3. Should I add verse reference styling (bold book name)?
4. Max character limit for lock screen display?
```

### PROMPT 6B - EXECUTION

```
Connect Bible verses to the lock screen system:

1. In BibleVersePickerView, when user taps "Add to Lock Screen":
   - Format verse as: "Book Chapter:Verse\nVerse text"
   - Create a new Note with this text
   - Add to the existing notes array
   - Trigger wallpaper update notification
   - Dismiss the picker with success feedback

2. Look at how ContentView.swift adds notes currently
   - Follow the same pattern for adding Bible verses
   - Make sure the note saves to @AppStorage("savedNotes")

3. Add haptic feedback when verse is added

Show me:
- Changes to BibleVersePickerView.swift
- Any helper functions needed
- How to trigger the wallpaper update notification
```

### PROMPT 6C - VERIFICATION

```
Test the full flow:

1. Open app → Bible picker → select a verse → "Add to Lock Screen"
2. Verify verse appears in main notes list
3. Verify wallpaper update is triggered
4. Check that verse looks good on the rendered wallpaper

If verse text is too long:
- How should we truncate it?
- Should we show "..." for long verses?
- What's the max characters that look good?

Help me test and adjust the formatting.
```

---

## ✅ Session 7: Testing & Polish

### PROMPT 7A - FULL TEST CHECKLIST

```
Help me test everything end-to-end in FaithWall Bible feature:

TEST CHECKLIST:
[ ] App launches without crashes
[ ] Language selection appears in onboarding
[ ] Selected language persists after app restart
[ ] Bible picker shows correct books for selected language
[ ] Can navigate: Books → Chapters → Verses
[ ] Search by reference works (John 3:16)
[ ] Search by word works (love, faith)
[ ] Can select a verse
[ ] "Add to Lock Screen" creates a note
[ ] Note appears in main list
[ ] Wallpaper renders with the verse
[ ] Can change language in Settings
[ ] Changing language updates Bible picker

For each item, tell me:
1. How to test it
2. What to look for (success/failure indicators)
3. Common issues and fixes
```

### PROMPT 7B - POLISH

```
Polish the Bible feature UI:

1. Add loading indicators where needed
2. Add empty states ("No verses found" for search)
3. Add error handling with user-friendly messages
4. Smooth animations for navigation
5. Consistent styling with rest of app

Review my Bible-related files and suggest specific improvements:
- BiblePickerView.swift
- BibleChapterPickerView.swift
- BibleVersePickerView.swift
- BibleSearchView.swift
- BibleDatabaseService.swift

Focus on user experience and visual polish.
```

### PROMPT 7C - FINAL CLEANUP

```
Final cleanup for Bible feature:

1. Remove BibleDatabaseTestView.swift (testing view)
2. Remove any print() statements used for debugging
3. Add proper error logging for production
4. Verify no memory leaks (database connections closed properly)
5. Check app size increase from SQLite files
6. Update Info.plist if needed for any permissions

Also create a summary of all new files added and their purpose.
```

---

## 🆘 Troubleshooting Prompts

### If Database Won't Open

```
I'm getting an error opening the SQLite database in FaithWall.

Error message: [paste error here]

My setup:
- SQLite files are in Faithwall/Database/ folder
- Files: KJV.sqlite, BSB.sqlite, etc.
- Using BibleDatabaseService.swift

Check:
1. Is the file being copied to app bundle?
2. Am I using the correct path?
3. Is the database file corrupted?

Show me how to debug this step by step.
```

### If Search Is Slow

```
Bible verse search is slow in FaithWall (takes 2-3 seconds).

Current implementation:
[paste your search function]

Database size: ~4MB
Typical search: word like "love" or "faith"

How can I speed this up? Options:
1. Add SQLite indexes
2. Use FTS5 full-text search
3. Limit results
4. Cache common searches
5. Other optimizations?
```

### If App Crashes

```
FaithWall crashes when [describe when].

Crash log:
[paste crash log from Xcode]

Recent changes:
[list what you recently added]

Help me:
1. Understand what's causing the crash
2. Find the exact line of code
3. Fix it
```

### If UI Looks Wrong

```
The Bible picker UI doesn't match my app's style.

My app style:
- Dark theme
- [describe your colors and fonts]
- Uses NavigationView with custom title styling

Current Bible picker looks:
[describe or screenshot]

Help me match the styling by updating:
- Colors
- Fonts
- Spacing
- Navigation bar appearance
```

---

## 📁 File Reference

After completing all sessions, you should have these new files:

```
Faithwall/
├── Database/
│   ├── KJV.sqlite
│   ├── BSB.sqlite
│   ├── UkrOgienko.sqlite
│   └── RusSynodal.sqlite
├── BibleDatabaseService.swift    (Session 1)
├── BibleModels.swift             (Session 2)
├── BiblePickerView.swift         (Session 3)
├── BibleChapterPickerView.swift  (Session 3)
├── BibleVersePickerView.swift    (Session 3)
├── BibleSearchView.swift         (Session 4)
├── LanguageSelectionView.swift   (Session 5)
├── LanguageManager.swift         (Session 5)
└── [existing files modified]
```

---

## 💡 Vibe Coder Tips

1. **One session at a time** - Don't rush. Do one session per day if needed.

2. **Save your code** - After each session, commit to git:
   ```bash
   git add .
   git commit -m "Session X: [what you did]"
   ```

3. **Test constantly** - Run the app after every change. Don't wait until the end.

4. **Copy error messages exactly** - When asking AI for help, paste the FULL error.

5. **Take breaks** - If frustrated, step away. Fresh eyes help.

6. **Backup before big changes** - Especially before editing OnboardingView.swift!

7. **Use Xcode previews** - They're faster than building the whole app.

---

## 🎯 Success Metrics

You'll know you're done when:

- [ ] User can select Bible language during onboarding
- [ ] User can browse Bible by book → chapter → verse
- [ ] User can search for verses by reference or words
- [ ] Selected verse appears on lock screen wallpaper
- [ ] App doesn't crash 😅
- [ ] Everything works offline

---

**Created:** December 25, 2025
**For:** FaithWall iOS App
**Author:** Your AI Coding Assistant

Good luck, and may your code compile on the first try! 🙏
