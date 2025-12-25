# FaithWall Website Mega Prompt for Bolt.new

Copy and paste everything below the line into Bolt.new:

---

## Create a Premium Christian App Landing Page for FaithWall

Build a stunning, modern, and professional landing page for **FaithWall** - an iOS app that transforms your iPhone lock screen into a daily source of spiritual inspiration. The website should feel like an Apple-quality product page with smooth animations, beautiful typography, and a warm Christian aesthetic.

---

## 🎨 DESIGN SYSTEM & BRANDING

### Color Palette
```css
/* Primary Colors - Warm, Faithful, Inviting */
--primary-gold: #D4A574;           /* Warm gold - main accent */
--primary-gold-light: #E8C9A0;     /* Light gold for highlights */
--primary-gold-dark: #B8956A;      /* Darker gold for hover states */

/* Secondary Colors - Calm, Spiritual */
--secondary-purple: #7C6B8E;       /* Soft purple - spiritual accent */
--secondary-purple-light: #9B8AAE;
--secondary-blue: #6B8CAE;         /* Calm blue - trust */

/* Neutral Colors */
--background-light: #FFFBF5;       /* Warm off-white */
--background-cream: #FDF8F0;       /* Cream sections */
--background-dark: #1A1A2E;        /* Dark sections */
--text-primary: #2D2A32;           /* Main text */
--text-secondary: #5A5660;         /* Secondary text */
--text-light: #FFFFFF;             /* Light text on dark */

/* Gradient */
--gradient-hero: linear-gradient(135deg, #FFFBF5 0%, #FDF8F0 50%, #F5EDE3 100%);
--gradient-gold: linear-gradient(135deg, #D4A574 0%, #E8C9A0 100%);
--gradient-dark: linear-gradient(180deg, #1A1A2E 0%, #2D2A4A 100%);
```

### Typography
- **Headings**: SF Pro Display (fallback: -apple-system, system-ui, "Segoe UI")
- **Body**: SF Pro Text (fallback: -apple-system, system-ui, "Segoe UI")
- **Accent/Quotes**: Playfair Display (Google Fonts) for scripture and inspirational quotes
- Font weights: 300 (light), 400 (regular), 500 (medium), 600 (semibold), 700 (bold)

### Design Principles
- Generous whitespace (Apple-style breathing room)
- Subtle shadows and depth
- Rounded corners (16px-24px for cards, 12px for buttons)
- Glassmorphism effects for floating elements
- Smooth 60fps animations
- Mobile-first responsive design

---

## 📱 SECTIONS TO BUILD

### 1. NAVIGATION BAR (Sticky, Glassmorphism)
```
- Logo: "FaithWall" with subtle cross integrated into the 'W' or a small dove icon
- Links: Features | How It Works | Pricing | Testimonials | FAQ
- CTA Button: "Download Free" (gold gradient, rounded)
- On scroll: Add blur backdrop + subtle shadow
- Mobile: Hamburger menu with slide-in drawer
```

### 2. HERO SECTION
```
Layout: Split screen
- Left side (60%): 
  - Small badge: "🙏 Your Daily Faith Companion"
  - Main headline: "Transform Your Lock Screen Into a Daily Moment with God"
  - Subheadline: "Beautiful scripture, prayers, and inspiration appear every time you pick up your phone. Join 10,000+ believers starting their day with purpose."
  - CTA Buttons:
    - Primary: "Download Free on App Store" (with Apple logo)
    - Secondary: "Watch How It Works" (play icon, ghost button)
  - Trust badges: "4.9 ★ Rating" | "Privacy First" | "Made with ❤️ for Christians"

- Right side (40%):
  - iPhone mockup (iPhone 15 Pro style, slightly angled)
  - Show lock screen with beautiful scripture wallpaper
  - Floating elements around phone:
    - Small cards with verses floating gently
    - Soft glow/halo effect behind phone
  - Subtle floating animation (up/down 10px, 4s ease-in-out infinite)

Background: Warm gradient with subtle pattern (light cross watermark or dove silhouettes at 3% opacity)
```

### 3. SOCIAL PROOF BAR
```
- Horizontal scrolling logos/badges (infinite scroll animation)
- "Trusted by believers worldwide"
- Show: User count "10,000+ Active Users" | "500+ 5-Star Reviews" | "Featured in Christian App Store"
- Subtle fade edges on scroll
```

### 4. FEATURES SECTION
```
Title: "Everything You Need for Daily Spiritual Growth"
Subtitle: "Simple. Beautiful. Meaningful."

Feature Cards (3x2 grid, staggered reveal on scroll):

1. 📖 Daily Scripture
   "Fresh verses delivered to your lock screen every morning. Never miss your daily bread."
   Icon: Open Bible with glow

2. ✝️ Beautiful Wallpapers  
   "Stunning faith-inspired backgrounds that make every glance meaningful."
   Icon: Image with cross overlay

3. 📝 Personal Prayers
   "Add your own prayers and intentions. See them when you need them most."
   Icon: Praying hands with pen

4. 🔔 Gentle Reminders
   "Customizable notifications to pause and reflect throughout your day."
   Icon: Bell with heart

5. 🎨 Personalized Experience
   "Choose themes, fonts, and styles that speak to your heart."
   Icon: Palette with cross

6. 🔒 Privacy First
   "Your prayers stay on your device. No accounts required. No data collection."
   Icon: Shield with lock

Card Style:
- White/cream background
- Subtle shadow on hover (lift effect)
- Gold accent line on top
- Icon with gradient background circle
- Hover: Scale 1.02, shadow increase
```

### 5. HOW IT WORKS SECTION
```
Background: Soft gradient or light pattern
Title: "Set Up in Under 2 Minutes"
Subtitle: "It's easier than you think"

3 Steps with connecting line/path:

Step 1: 📲 Download & Open
"Get FaithWall free from the App Store. No sign-up needed."
[iPhone mockup showing app icon]

Step 2: ✍️ Add Your Inspirations
"Enter your favorite verses, prayers, or daily affirmations."
[iPhone mockup showing notes entry screen]

Step 3: 🎉 Enjoy Daily Inspiration
"Your lock screen transforms into a source of faith and peace."
[iPhone mockup showing beautiful lock screen]

Animation: Steps reveal sequentially on scroll with fade-up + slide effect
Connecting path: Curved dotted line between steps with traveling dot animation
```

### 6. APP SHOWCASE / GALLERY
```
Title: "See FaithWall in Action"

Interactive gallery:
- Large center mockup with multiple screenshots
- Thumbnail navigation below
- Or: Horizontal scroll carousel with snap points
- Screenshots to show:
  1. Lock screen with scripture
  2. Home screen widget
  3. Notes entry interface
  4. Wallpaper selection
  5. Settings/customization

Style: Dark section to make white phone mockups pop
Add subtle particle effect (floating crosses or doves at low opacity)
```

### 7. TESTIMONIALS SECTION
```
Background: Warm cream
Title: "Loved by Believers Everywhere"
Subtitle: "See what our community is saying"

Testimonial Cards (3 columns, or carousel on mobile):

"FaithWall has transformed my morning routine. Instead of checking social media, I start with God's word. It's been life-changing."
- Sarah M., Youth Pastor
⭐⭐⭐⭐⭐

"As a busy mom of 3, I needed something simple. Every time I check my phone, I'm reminded of God's promises. Beautiful app!"
- Rachel K., Mother & Teacher  
⭐⭐⭐⭐⭐

"I've tried many devotional apps, but this is different. It meets me where I am - on my lock screen. Genius concept, flawless execution."
- David L., Seminary Student
⭐⭐⭐⭐⭐

"Finally an app that respects my privacy AND strengthens my faith. No accounts, no tracking. Just pure inspiration."
- Michael T., IT Professional
⭐⭐⭐⭐⭐

Card style:
- Quote marks icon at top (gold)
- Slightly rotated cards (-2° to 2°)
- Photo avatar (use pleasant stock photos or initials)
- Soft shadow, rounded corners
```

### 8. PRICING SECTION
```
Background: Gradient dark section (adds visual break)
Title: "Simple, Fair Pricing"
Subtitle: "Start free. Upgrade when you're ready."

Two pricing cards side by side:

FREE PLAN (Left card - outlined style):
- $0 forever
- ✓ Up to 5 personal notes
- ✓ 3 beautiful wallpaper presets
- ✓ Lock screen inspiration
- ✓ Basic widget
- ✓ No ads, ever
[Button: "Download Free"]

FAITHWALL PRO (Right card - featured, gold gradient border, "Most Popular" badge):
- $2.99/month or $19.99/year (Save 44%!)
- ✓ Unlimited notes & prayers
- ✓ All premium wallpapers
- ✓ Custom photo backgrounds
- ✓ Advanced widgets
- ✓ Priority support
- ✓ Support app development
[Button: "Start Free Trial" - 7 days free]

Below cards:
- "🔒 Cancel anytime. No questions asked."
- "💝 Your support helps us keep FaithWall ad-free and privacy-focused"
```

### 9. FAQ SECTION
```
Title: "Common Questions"
Accordion-style FAQ:

Q: Is FaithWall really free?
A: Yes! The free version includes everything you need to get started. We offer a Pro version for power users who want unlimited notes and premium features.

Q: Does it work on my iPhone?
A: FaithWall works on iPhone running iOS 16 or later. We use Apple's latest lock screen and widget features.

Q: Is my data private?
A: Absolutely. Your prayers and notes stay on your device. We don't have accounts, we don't collect data, and we never will. Your faith journey is personal.

Q: How do I set up the lock screen?
A: Our simple 2-minute setup guide walks you through everything. It uses Apple's built-in Shortcuts app - no technical knowledge needed!

Q: Can I use my own photos?
A: Yes! Pro users can use any photo as their background. Free users can choose from our beautiful preset collection.

Q: Is there an Android version?
A: Not yet, but it's on our roadmap! Sign up for our newsletter to be notified when it launches.

Style:
- Smooth expand/collapse animation
- Plus/minus icon that rotates
- Gold accent on active question
```

### 10. NEWSLETTER / CTA SECTION
```
Background: Warm gradient
Title: "Join Our Faith Community"
Subtitle: "Get weekly inspiration, app updates, and exclusive wallpapers"

Email input + Subscribe button (inline on desktop)
Placeholder: "Enter your email"
Button: "Join 5,000+ Subscribers"

Below: "We respect your inbox. Unsubscribe anytime. 💌"

Add subtle floating elements (small crosses, hearts, or doves)
```

### 11. FINAL CTA SECTION
```
Full-width, impactful section
Background: Beautiful image (sunrise over mountains, cross silhouette, or peaceful nature scene) with overlay

Large text: "Start Every Day with Purpose"
Subtext: "Transform your phone into a tool for spiritual growth"

Big CTA button: "Download FaithWall Free" 
App Store badge below

Floating phone mockup to the side
```

### 12. FOOTER
```
Background: Dark (#1A1A2E)

Columns:
1. Logo + tagline "Faith on your lock screen" + social icons
2. Product: Features | Pricing | Download | What's New
3. Support: Help Center | Contact | FAQ | Setup Guide
4. Legal: Privacy Policy | Terms of Service

Bottom bar: 
"© 2024 FaithWall. Made with ❤️ and 🙏"
"Not affiliated with any church or denomination. For all believers."
```

---

## ✨ ANIMATIONS & INTERACTIONS

### Scroll Animations (use Framer Motion or CSS)
```
- Fade up + slide (translateY: 30px → 0, opacity: 0 → 1)
- Stagger children by 100ms delay
- Trigger at 20% viewport visibility
- Duration: 0.6s ease-out
```

### Hover Effects
```
- Buttons: Scale 1.02, shadow increase, subtle glow
- Cards: Lift (translateY: -4px), shadow deepens
- Links: Gold underline slides in from left
- Images: Subtle zoom (scale 1.05)
```

### Micro-interactions
```
- Logo: Subtle pulse on hover
- Download button: Shimmer effect across surface
- Testimonial cards: Gentle floating animation
- FAQ accordion: Smooth height transition
- Phone mockups: Parallax on mouse move (subtle)
```

### Loading States
```
- Skeleton screens for images
- Smooth fade-in for content
- Progress indicator for any forms
```

---

## 🛠 TECHNICAL REQUIREMENTS

### Stack
- **Framework**: Next.js 14 (App Router) or React + Vite
- **Styling**: Tailwind CSS
- **Animations**: Framer Motion
- **Icons**: Lucide React or Heroicons
- **Fonts**: Google Fonts (Playfair Display) + System fonts

### Performance
- Lazy load images below fold
- Optimize images (WebP format)
- Minimize JavaScript bundle
- Perfect Lighthouse scores target

### SEO
```html
<title>FaithWall - Transform Your Lock Screen with Daily Scripture & Inspiration</title>
<meta name="description" content="Turn your iPhone lock screen into a daily source of faith. Beautiful scripture, prayers, and inspiration every time you pick up your phone. Free download.">
<meta name="keywords" content="Christian app, Bible verses, lock screen, iOS widget, daily devotional, scripture wallpaper, prayer app, faith app">
```

### Responsive Breakpoints
```
- Mobile: < 640px
- Tablet: 640px - 1024px  
- Desktop: > 1024px
- Large: > 1280px
```

---

## 📁 FILE STRUCTURE
```
/app
  /page.tsx (main landing page)
  /layout.tsx
  /globals.css
/components
  /Navigation.tsx
  /Hero.tsx
  /Features.tsx
  /HowItWorks.tsx
  /Testimonials.tsx
  /Pricing.tsx
  /FAQ.tsx
  /Footer.tsx
  /ui (buttons, cards, etc.)
/public
  /images (mockups, icons, backgrounds)
/lib
  /utils.ts
```

---

## 🎯 KEY DELIVERABLES

1. ✅ Fully responsive landing page
2. ✅ All sections listed above
3. ✅ Smooth scroll animations
4. ✅ Mobile hamburger menu
5. ✅ App Store download link (placeholder: https://apps.apple.com/app/faithwall)
6. ✅ Contact form or email link
7. ✅ Privacy policy page (placeholder)
8. ✅ Terms of service page (placeholder)

---

## 📸 PLACEHOLDER CONTENT

For mockups and images, use:
- iPhone mockups: Search "iPhone 15 Pro mockup" on Unsplash or use Figma templates
- Background images: Peaceful nature scenes (mountains, sunrise, calm water) from Unsplash
- User avatars: UI Faces or generated initials

---

## 🙏 TONE & VOICE

- Warm, welcoming, inclusive
- Not preachy or denominational
- Professional yet personal
- Encouraging and uplifting
- Simple, clear language
- Avoid religious jargon

---

**Create this complete landing page with all sections, animations, and styling. Make it production-ready and visually stunning. The goal is to make visitors feel the peace and quality of the app before they even download it.**
