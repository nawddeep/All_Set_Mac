# All Set — Frontend Design Rules

> **Purpose:** This file is the permanent frontend design specification for the All Set application.
> Use it as the source of truth for UI/UX decisions, visual consistency, animation behavior, media handling, and frontend performance.
>
> **Reference:** The approved visual direction is the dark, cinematic, glassmorphism/macOS-style design shown in the provided reference screenshot.

---

## 1. Core Design Principle

All Set must feel like a **premium native-feeling macOS desktop customization app**, not a generic SaaS dashboard or website.

The overall experience should be:

- Premium
- Dark
- Cinematic
- Futuristic
- Calm
- Visual-first
- Motion-rich but controlled
- Fast
- Spacious
- Consistent

The design should feel closer to:

**Apple system UI + premium creative media library + futuristic desktop customization tool**

than to:

**Admin dashboard + generic component library + standard CRUD application**

### Never sacrifice

1. Usability for aesthetics
2. Performance for visual effects
3. Consistency for novelty
4. Existing functionality for visual redesign

---

# 2. Visual Reference Rules

The provided reference image is the **visual source of truth**.

Do not copy the screenshot mechanically.

Instead, extract and maintain its design language:

- Floating navigation
- Segmented pill controls
- Dark navy/black surfaces
- Glassmorphism
- Large typography
- Cinematic imagery
- Rounded cards
- Soft borders
- Subtle gradients
- Generous spacing
- Image-first content
- Floating actions
- Small metadata
- Horizontal media rails
- Large hero compositions
- Minimal visual noise
- Smooth transitions

Every new screen must look like it belongs to this same product.

---

# 3. Application Navigation Pattern

The application should use a **layered navigation system** rather than a heavy permanent sidebar.

## Primary Navigation

Recommended top-level structure:

- Island
- Desktop
- Workspace
- Tools
- System

## Secondary Navigation

### Island
- Dynamic Island
- Live Activities

### Desktop
- Home
- Themes
- Wallpapers
- Widgets
- Art
- Collections
- Favorites
- Recent
- Downloads

### Workspace
- My Setup
- Layouts
- Presets
- Scenes
- Desktop Profiles

### Tools
- Clipboard
- Shelf
- Sound Mixer
- TapTap
- AI Screenshot
- Notes
- Shortcuts

### System
- Monitor
- Lid Plane
- General
- Notifications
- Privacy
- About

The exact tab list may evolve with the product, but the **navigation pattern must remain consistent**.

---

# 4. Navigation Visual Rules

Navigation should visually follow the reference:

```text
Main Navigation
       ↓
Secondary Navigation
       ↓
Page Content
```

Use:

- Floating pill groups
- Segmented controls
- Soft glass backgrounds
- Rounded containers
- Small gaps between items
- Clear active state

## Active navigation item

Active item should have:

- Brighter text
- Stronger visual contrast
- Subtle glass surface
- Soft glow if appropriate
- Smooth pill movement/transition

## Inactive navigation item

Inactive items should be:

- Muted
- Calm
- Clearly readable
- Visually subordinate

Do not make every navigation item visually loud.

---

# 5. Global Layout

The application should use a spacious centered content layout.

General structure:

```text
┌──────────────────────────────────────────┐
│ macOS Window Controls                    │
│                                          │
│              Main Navigation             │
│                                          │
│           Secondary Navigation           │
│                                          │
│                 CONTENT                  │
│                                          │
└──────────────────────────────────────────┘
```

### Layout rules

- Use generous horizontal padding.
- Avoid cramped compositions.
- Maintain visual breathing room.
- Use large content containers.
- Let imagery breathe.
- Avoid unnecessary permanent sidebars.
- Use contextual side panels only when useful.
- Side panels must follow the same glass/dark visual language.

---

# 6. Design Tokens

Create and use centralized design tokens.

At minimum define:

- Background
- Surface
- Surface Hover
- Surface Active
- Border
- Text Primary
- Text Secondary
- Text Muted
- Accent
- Success
- Warning
- Danger
- Shadow
- Blur
- Radius
- Spacing
- Animation duration
- Easing

Avoid large numbers of random one-off values.

Prefer a predictable token system.

---

# 7. Color System

The application should remain predominantly dark.

Recommended direction:

- Deep navy
- Near-black
- Blue-black
- Soft neutral whites
- Cool grays
- Muted accent colors

Accents may be:

- Blue
- Purple
- Pink
- Cyan
- Green
- Orange

But accents should be **controlled and intentional**.

### Important

Content may influence accent color.

Examples:

- Purple artwork → subtle purple accent
- Nature wallpaper → subtle green accent
- Sunset wallpaper → subtle orange accent

However:

> The entire UI must NOT dynamically change into a different theme for every card.

Keep the product's base visual system stable.

---

# 8. Glassmorphism Rules

Glass is a major visual element, but should be used selectively.

Good use cases:

- Navigation
- Floating controls
- Cards
- Modals
- Search overlays
- Small contextual panels
- Buttons
- Toolbar surfaces

Avoid:

- Giant areas of continuous blur
- Full-screen expensive backdrop-filter layers
- Multiple stacked blur layers
- Heavy blur behind every component

Glass should feel:

- Translucent
- Soft
- Premium
- Lightweight

It should never make the interface look foggy.

---

# 9. Borders and Shadows

Borders should be subtle.

Use:

- Low-opacity light borders
- Soft inner highlights
- Minimal separators

Avoid:

- Thick card borders
- Bright outlines around everything
- Heavy neon borders
- Huge shadows

Shadows should provide depth, not dominate the visual hierarchy.

---

# 10. Corner Radius System

Use a consistent radius hierarchy.

Suggested direction:

- Small: 10–12px
- Medium: 16–18px
- Large: 22–28px
- Hero: 28–36px
- Pills: 999px

Exact values may adapt to the existing design system, but consistency is required.

Avoid mixing many unrelated radii.

---

# 11. Typography

Typography should provide most of the hierarchy.

Use:

- Large bold hero headings
- Medium section headings
- Small metadata
- Muted supporting text
- Uppercase eyebrow labels where useful

Suggested hierarchy:

### Eyebrow
- 10–12px
- Uppercase
- Letter spacing
- Muted

### Hero
- ~48–72px depending on viewport

### Page title
- ~36–52px

### Section title
- ~22–28px

### Card title
- ~15–18px

### Metadata
- ~11–13px

Do not make every label bold.

Do not make every element oversized.

---

# 12. Spacing

The interface should feel spacious and premium.

Prefer consistent spacing tokens.

Use more whitespace around:

- Hero sections
- Page headings
- Major content transitions
- Large visual cards
- Featured content

Use less whitespace around:

- Metadata
- Toolbars
- Compact control groups
- Dense utility information

Avoid both extremes:

- cramped dashboard
- empty page with no hierarchy

---

# 13. Card Design

Cards are a core part of the product.

Cards should generally have:

- Large visual area
- Rounded corners
- Dark/glass surface where appropriate
- Subtle border
- Minimal shadow
- Clear title
- Optional metadata
- Clear hover behavior

Avoid:

- Square generic cards
- Heavy card chrome
- Too many buttons on cards
- Excessive text

All visual cards should prioritize the media itself.

---

# 14. Home Page Rules

Home should feel like a **cinematic product landing/dashboard**, not an admin overview.

Recommended composition:

```text
Hero
↓
Collection shortcuts
↓
Trending Wallpapers
↓
Themes
↓
Widgets
↓
Recent
```

## Hero

Hero should contain:

- Large cinematic image/video
- Strong title
- Short supporting text
- Primary CTA
- Optional secondary CTA
- Optional status/time/weather utility
- Gradient overlay
- Floating glass controls if useful

The hero should be visually dominant.

Do not fill the top of the page with many small cards.

---

# 15. Media Rails

Horizontal rails should be used extensively for discoverability.

Good sections:

- Trending
- Recently Added
- Featured
- Themes
- Widgets
- Collections
- Favorites

Rules:

- Smooth horizontal scrolling
- Clear visual grouping
- Optional navigation arrows
- Drag/scroll behavior where appropriate
- Hide unnecessary scrollbars visually
- Maintain accessibility

Media rails should not feel like rigid carousel widgets.

---

# 16. Wallpaper Library Rules

Wallpaper Library is one of the most important areas of All Set.

The design should be image-first.

Top area:

- Page title
- Subtitle
- Count/metadata
- Search
- Filters

Suggested filters:

- All
- Live
- Stills
- 4K
- Anime
- Nature
- Cars
- Cities
- Space
- Games
- Abstract
- Minimal
- Favorites
- Recent

Use categories that actually exist in the catalog.

## Wallpaper card

Each card may include:

- Preview
- Name
- Live/Still indicator
- Resolution
- Duration
- Favorite action
- Preview/play indicator
- Download state

Avoid displaying every metadata field simultaneously.

---

# 17. Animated / Live Wallpaper Rules

Animation is required for the redesigned app.

Live wallpapers must communicate motion clearly without becoming visually noisy.

## Live indicator

Use a subtle:

- LIVE badge
- Pulsing dot
- Duration
- Play indicator

Example:

`LIVE • 00:12`

The pulse must be subtle.

## Hover playback

Recommended behavior:

1. Poster image loads first.
2. User hovers.
3. Small delay before playback starts.
4. Video fades in.
5. Card scales slightly.
6. Controls appear.

When pointer leaves:

1. Pause video.
2. Stop unnecessary playback.
3. Return visually to poster where appropriate.

Do not autoplay hundreds of videos.

---

# 18. Animated Wallpaper Detail Viewer

Wallpaper detail should become an immersive viewing experience.

Use:

- Large wallpaper/video
- Dark gradient overlays
- Floating glass controls
- Metadata
- Thumbnail rail
- Primary action
- Favorite
- Download

Example:

```text
┌──────────────────────────────────────────┐
│                                          │
│              WALLPAPER                  │
│                                          │
│       Wallpaper Title                   │
│       4K • LIVE • 00:12                 │
│                                          │
│      [Set Wallpaper] [Download] [♡]    │
│                                          │
│              Thumbnails                 │
└──────────────────────────────────────────┘
```

For animated wallpapers, show actual motion.

Controls may include:

- Play/Pause
- Mute
- Fullscreen
- Set Wallpaper
- Download
- Favorite

---

# 19. Theme Page Rules

Themes represent complete desktop experiences.

A theme card should visually communicate a complete setup:

- Wallpaper
- Widgets
- Color system
- Layout
- Typography
- Desktop composition

Theme cards should look like miniature desktops rather than standard product cards.

Hover behavior:

- Slight zoom
- Soft glow
- Reveal action
- Show useful metadata

---

# 20. Theme Detail Page

Theme detail should feel editorial/premium.

Include:

- Large preview
- Theme name
- Description
- Wallpaper count
- Widget count
- Author/category where applicable
- Use Theme
- Customize

Additional sections:

- Included Widgets
- Wallpaper
- Color System
- Layout
- Related Themes

Do not make this page look like an admin detail form.

---

# 21. Widgets Page

Widgets should be presented as visual products.

Categories may include:

- Time
- Weather
- Music
- System
- Calendar
- Productivity
- Minimal
- Colorful

Widget cards should show actual widget previews wherever possible.

Use:

- Live preview
- Install/Add action
- Subtle hover interactions
- Clear category metadata

---

# 22. Art Page

Art should have its own identity while using the shared design language.

Use:

- Large artwork
- Editorial compositions
- Collections
- Featured artists/creators where available
- Popular
- Recent
- Curated groups

Do not simply duplicate the Wallpaper page layout.

Art can use:

- asymmetrical cards
- larger hero pieces
- varied proportions

But all components must still belong to the same design system.

---

# 23. Collections

Collections should feel curated.

Example collection themes:

- Cyberpunk Nights
- Anime Worlds
- Minimal Desk
- Space
- Nature
- Retro
- Dark
- Productivity

Collection pages should include:

- Large hero
- Description
- Item count
- Visual grid
- Filters
- Related collections

Use strong cover imagery.

---

# 24. Favorites

Favorites should support multiple content types.

Tabs:

- All
- Wallpapers
- Themes
- Widgets
- Art

Use the same segmented-pill control language as the rest of the app.

---

# 25. Search

Search should feel native and premium.

Recommended shortcut:

`⌘ K`

Search overlay should include:

- Large glass search field
- Recent searches
- Suggestions
- Grouped results
- Wallpapers
- Themes
- Widgets
- Art
- Collections

Implementation rules:

- Debounce input
- Cache where useful
- Avoid unnecessary rerenders
- Search actual data
- Keep response visually smooth

---

# 26. Workspace

Workspace should focus on assembling a desktop environment.

Sections:

- My Setup
- Layouts
- Presets
- Scenes
- Desktop Profiles

Use a visual Mac desktop preview containing:

- Wallpaper
- Widgets
- Dynamic Island
- Dock/system UI
- Optional overlays

Actions:

- Change Wallpaper
- Customize Widgets
- Change Theme
- Save Preset

---

# 27. Dynamic Island

Dynamic Island should feel like a genuine system layer.

States may include:

- Closed
- Now Playing
- Volume
- Charging
- Low Battery
- Audio Device
- Timer
- File Transfer
- System Activity

Animation rules:

- Closed → expanded
- Expanded → closed
- Content changes smoothly
- Progress indicators animate
- Waveforms animate
- Stats animate

Motion must feel:

- Fast
- Smooth
- Spring-like
- Responsive
- Controlled

The Dynamic Island should not constantly demand attention.

---

# 28. System Monitor

System monitor should use visual metric cards.

Example categories:

- CPU
- GPU
- Memory
- Network
- Disk
- Battery

Each card can include:

- Large current value
- Secondary metadata
- Mini chart
- Progress visualization
- State/status

Keep rapidly updating values localized.

Do not make the whole application rerender every time a metric changes.

---

# 29. Tools

Tools should use the same design language but can be more utility-oriented.

Example tools:

- Clipboard
- Shelf
- Sound Mixer
- TapTap
- AI Screenshot
- Notes
- Shortcuts

Typical tool structure:

```text
Tool Navigation
      ↓
Main Workspace
      ↓
Optional Contextual Controls
```

Avoid excessive panel nesting.

---

# 30. Settings

Settings should be visually consistent with All Set rather than becoming a generic clone of macOS Settings.

Suggested sections:

- General
- Appearance
- Animation
- Performance
- Wallpaper
- Dynamic Island
- Widgets
- Notifications
- Privacy
- Keyboard Shortcuts
- Storage
- About

Controls may include:

- Toggles
- Sliders
- Segmented controls
- Radio groups
- Dropdowns
- Glass cards

---

# 31. Animation Philosophy

Animation is a first-class part of the All Set identity.

Animations should improve:

- Feedback
- Spatial understanding
- Delight
- Navigation
- Content discovery

Animation should NOT exist simply because it looks cool.

---

# 32. Animation Timing

Suggested timing ranges:

### Micro
120–180ms

### Standard
180–280ms

### Large
300–500ms

### Hero
400–700ms only when visually justified

Use spring-like motion where it improves interaction.

Avoid:

- Slow UI transitions
- Constant floating motion
- Excessive parallax
- Long delays before interaction becomes available
- Animation that blocks user input

---

# 33. Animation Properties

Prefer animating:

- opacity
- transform
- scale
- translate
- rotate when appropriate

Avoid frequently animating expensive layout properties when possible.

Do not animate:

- huge expensive surfaces unnecessarily
- large blur regions continuously
- complex layout structures without a clear benefit

---

# 34. Reduced Motion

Support:

`prefers-reduced-motion`

When reduced motion is enabled:

- Reduce or remove large parallax
- Reduce spring intensity
- Reduce transitions
- Disable aggressive autoplay previews
- Simplify Dynamic Island movement
- Keep functional feedback intact

Reduced motion should be part of the design system, not a late patch.

---

# 35. Hover Rules

Hover must feel subtle.

## Wallpaper

Hover:

- slight image zoom
- small play icon
- metadata reveal
- favorite action

## Theme

Hover:

- slight preview zoom
- subtle glow
- reveal View Theme

## Widget

Hover:

- lightweight interaction/preview
- install/add action

## Collection

Hover:

- slight cover movement
- subtle parallax if affordable

Never make hover distracting.

---

# 36. Button Rules

Buttons should be simple and tactile.

Primary button:

- High contrast
- Rounded
- Clear label
- Slight highlight
- Strong hover state

Secondary button:

- Glass
- Muted
- Clear border

Icon-only buttons:

- Must have tooltips
- Must have visible focus
- Must remain accessible

Press state:

- Slight scale-down
- Fast response

---

# 37. Modals

Use glass modals for:

- Wallpaper actions
- Theme customization
- Search
- Download queue
- Import flows
- Keyboard shortcuts
- System details

Modal design:

- Dark translucent surface
- Soft border
- Rounded corners
- Subtle shadow
- Strong hierarchy

Opening transition:

- Fade
- Small scale
- Slight vertical movement

Keep the animation quick.

---

# 38. Toasts

Use polished, lightweight toasts.

Examples:

- Wallpaper applied
- Theme installed
- Added to favorites
- Download complete
- Import successful

Toast content:

- Icon
- Message
- Optional progress
- Optional dismiss

Do not let notifications become visually intrusive.

---

# 39. Download UI

Represent download states clearly:

- Downloading
- Progress
- Completed
- Paused
- Failed

Downloads should not block the entire interface.

Use:

- Compact progress
- Status icons
- Optional queue

---

# 40. Loading States

Never leave large blank spaces while content loads.

Use skeletons that match the final UI.

Skeleton style:

- Dark surface
- Rounded corners
- Subtle shimmer
- Low visual noise

For wallpaper grids:

- Image placeholder
- Title placeholder
- Metadata placeholder

For hero sections:

- Hero skeleton
- Content skeleton
- Control skeleton

---

# 41. Error States

Never expose broken image icons as the primary error presentation.

Fallback should be a designed surface:

```text
Preview unavailable
```

Use a subtle icon and preserve the card structure.

---

# 42. Empty States

Create designed empty states for:

- Favorites
- Downloads
- Search
- Collections
- History
- Other empty areas

Empty states should be:

- Calm
- Useful
- Visually polished
- Concise

---

# 43. Responsive Rules

The app is desktop-first.

Primary target widths:

- 1280px
- 1440px
- 1728px
- 2560px

At smaller widths:

- Reduce grid columns
- Make secondary navigation horizontally scrollable
- Reduce hero typography
- Maintain spacing
- Prevent horizontal overflow

Do not make the desktop product feel like a compressed mobile website.

---

# 44. Wallpaper Grid Scaling

The wallpaper grid should adapt to available width.

Example direction:

- 1280 → 3–4 cards
- 1440 → 4 cards
- 1728 → ~5 cards
- 2560 → 6+ where appropriate

Do not blindly force columns.

Prioritize:

- card size
- readability
- visual quality
- balanced whitespace

---

# 45. Performance Is Part of Design

All Set is a **media-heavy desktop application**.

It can contain:

- Large wallpaper catalogs
- Thousands of images
- Many videos
- Animated previews
- System metrics
- Multiple dynamic panels

A visually beautiful UI that becomes slow is considered a failed implementation.

---

# 46. Image Loading Rules

Always prefer:

```text
Thumbnail
    ↓
Preview
    ↓
Full Resolution
```

Do NOT:

```text
Full-resolution media
    ↓
Every card
    ↓
All at once
```

Use:

- Lazy loading
- Appropriate image dimensions
- Efficient decoding
- Responsive sources where supported
- Poster images for videos

---

# 47. Live Video Performance

Live wallpaper videos must be carefully managed.

Rules:

- Do not autoplay all videos.
- Prefer poster frames.
- Start preview only when useful.
- Pause off-screen videos.
- Release unnecessary media resources.
- Use IntersectionObserver or equivalent viewport logic.
- Avoid repeated video initialization.
- Avoid loading unnecessary full-resolution videos.

For gallery previews:

```text
Poster
   ↓
Hover / visibility trigger
   ↓
Video starts
   ↓
Pointer leaves / card hidden
   ↓
Video pauses
```

---

# 48. Virtualization

Large collections should not render thousands of expensive DOM/media elements simultaneously.

Consider virtualization for:

- Wallpaper grids
- Search results
- Downloads
- Clipboard history
- Large collections
- System lists

Use virtualization when the existing architecture/library supports it appropriately.

---

# 49. React Rendering Rules

Avoid unnecessary re-renders.

Particularly isolate rapidly changing state:

- System metrics
- Download progress
- Video playback state
- Hover state
- Dynamic Island state

Do not cause the entire wallpaper library to re-render because one wallpaper was favorited.

Use:

- Memoization where valuable
- Localized state
- Stable keys
- Efficient selectors
- Derived data caching

Do not apply memoization blindly; measure expensive paths first.

---

# 50. Search / Filtering Performance

Search and filters should feel immediate.

Use:

- Debouncing for text input
- Cached metadata
- Stable derived data
- Efficient filtering
- Virtualization for large results

Do not perform expensive work on every keystroke.

---

# 51. Backdrop / Blur Performance

Heavy blur is expensive.

Rules:

- Blur small surfaces
- Avoid full-screen blur when possible
- Avoid stacked backdrop-filter layers
- Do not animate blur continuously
- Use static/translucent fallback surfaces when necessary

Premium appearance must not come from brute-force GPU effects.

---

# 52. System Metrics Performance

System data should update at an appropriate frequency.

Do not update UI dozens of times per second unless the visual effect truly requires it.

Prefer:

- Local state for rapidly changing values
- Small update surfaces
- Aggregated metrics
- Efficient polling/subscriptions

Do not make navigation, wallpaper grids, or unrelated components rerender with every metric update.

---

# 53. Component Architecture

Use reusable components.

Recommended base components:

- AppShell
- TopNavigation
- SecondaryNavigation
- GlassPill
- GlassCard
- HeroSection
- MediaCard
- WallpaperCard
- ThemeCard
- WidgetCard
- CollectionCard
- MediaRail
- SectionHeader
- FilterBar
- SearchBar
- SearchOverlay
- WallpaperViewer
- WallpaperPreview
- VideoPreview
- ThumbnailRail
- StatsCard
- MiniChart
- GlassModal
- SettingsGroup
- ToggleRow
- SliderRow
- DesktopPreview
- DynamicIsland
- SystemMetricCard
- SkeletonCard
- EmptyState
- Toast

Before creating a new component:

> Check whether an existing component can be reused or extended.

Avoid duplicate components with slightly different styling.

---

# 54. Component Responsibility

Components should have a clear responsibility.

Prefer:

```text
WallpaperCard
```

over:

```text
WallpaperCardWithFavoriteDownloadHoverAndPreviewAndMetadataAnd...
```

Keep component APIs understandable.

Do not create giant components that control the entire application.

---

# 55. Icon Rules

Use one consistent icon library/style.

Do not mix unrelated icon families.

Icons should generally be:

- Small
- Simple
- Clean
- Consistent
- Mostly monochrome

Use accent colors sparingly.

---

# 56. Accessibility

A premium interface must remain accessible.

Support:

- Keyboard navigation
- Visible focus states
- Proper labels
- ARIA where appropriate
- Sufficient contrast
- Reduced motion
- Tooltips for icon-only controls

Do not use visual design as an excuse to remove keyboard accessibility.

---

# 57. Focus States

Interactive elements need visible focus.

Focus should match the design system:

- Soft glow
- Subtle outline
- Clear contrast

Do not remove focus indicators without replacing them with an equally clear alternative.

---

# 58. Scroll Behavior

Scrolling should feel natural and fast.

Use smooth scrolling only where it improves the experience.

Do not make the page feel slow because of exaggerated smooth scrolling.

Horizontal rails should support:

- Mouse wheel
- Trackpad
- Drag
- Optional arrow buttons

---

# 59. Visual Hierarchy Rules

Every page should have:

1. One clear primary visual
2. One clear primary heading
3. One primary action
4. Supporting metadata
5. Secondary content
6. Tertiary controls

Do not make every element compete for attention.

---

# 60. Content Density

The first viewport should feel premium and spacious.

Do not try to show the entire application at once.

Use progressive discovery:

```text
Hero
↓
Featured
↓
Trending
↓
More content
↓
Deep content
```

Let scrolling reveal more.

---

# 61. Motion and Visual Hierarchy

Motion should reinforce hierarchy.

Large elements:

- slower, smoother motion

Small interactions:

- faster feedback

Persistent animations:

- extremely subtle

Important actions:

- clear feedback

Avoid making multiple unrelated things move simultaneously.

---

# 62. Page Transitions

Transitions should make navigation feel connected.

Use subtle combinations of:

- Fade
- Translate
- Scale

Do not use long page transition animations.

Fast navigation must remain fast.

---

# 63. Media Transitions

When going from:

```text
Wallpaper Card → Wallpaper Detail
```

the transition should feel spatially connected where practical.

Avoid abrupt changes.

Use:

- Shared visual continuity
- Fade/scale
- Image continuity
- Fast feedback

Do not create transitions that delay interaction.

---

# 64. Search Overlay Rules

Search overlay should be:

- Large
- Glassy
- Centered
- Keyboard friendly
- Fast

Potential structure:

```text
Search
────────────────────
Recent
Suggestions
Results
  Wallpapers
  Themes
  Widgets
  Art
```

Do not turn search into a full page unless necessary.

---

# 65. Settings Control Rules

Controls should use the same visual vocabulary as the rest of the application.

Do not use unrelated default browser form controls when custom styling is appropriate.

Use:

- Glass toggles
- Soft segmented controls
- Clean sliders
- Rounded inputs
- Consistent labels

---

# 66. No Generic SaaS Patterns

Avoid default patterns such as:

- Left sidebar + top navbar + tiny cards
- Huge data tables
- Dense KPI dashboards
- Generic white-card layouts
- Excessive outline buttons
- Multiple competing banners
- Traditional admin panels

All Set is a visual media/productivity desktop application.

---

# 67. No Excessive Glass

Do not put glass on every element.

Good hierarchy:

```text
Background
    ↓
Large media
    ↓
Glass navigation
    ↓
Glass controls
    ↓
Solid/dark content surfaces
```

Glass should create hierarchy.

If everything is glass, nothing feels special.

---

# 68. No Excessive Gradients

Gradients should:

- Improve readability
- Create atmosphere
- Emphasize imagery
- Guide attention

Do not use gradients as decoration on every card.

---

# 69. No Excessive Neon

Neon accents should be used for:

- Active state
- Live state
- Important actions
- Special visual moments

Do not turn the application into an RGB gaming dashboard.

---

# 70. Do Not Overuse Shadows

Use shadow primarily for:

- Floating layers
- Modals
- Raised cards
- Navigation

Avoid giant, soft, repeated shadows on every element.

---

# 71. Do Not Overuse Rounded Shapes

Rounded corners are part of the visual language, but do not make every tiny element extremely round.

Use:

- Pills for controls
- Moderate radius for cards
- Larger radius for hero/media
- Compact radius for small utility surfaces

---

# 72. Visual Consistency Rule

When creating a new UI component, ask:

> Does this look like it could already exist in the reference application?

If no:

- Reuse existing tokens
- Reuse existing component patterns
- Simplify the shape
- Reduce visual noise
- Match spacing
- Match radius
- Match typography

---

# 73. Existing Functionality Must Be Preserved

Frontend redesign should not unnecessarily rewrite working behavior.

Preserve where possible:

- API calls
- Database usage
- Wallpaper catalog logic
- Media loading
- Downloads
- Favorites
- Theme logic
- Widget logic
- System monitoring
- Clipboard behavior
- Dynamic Island behavior
- Settings
- Existing routes

Change presentation before changing functionality.

---

# 74. Real Data Over Fake Data

Do not create fake dashboards when the app already has real data.

Use:

- Existing wallpaper catalog
- Existing theme data
- Existing widget data
- Existing favorites
- Existing download state
- Existing system data
- Existing settings

Only use placeholder data where actual data genuinely does not exist.

---

# 75. Do Not Rewrite Working Logic for Aesthetics

Never rewrite functional business logic solely because the visual architecture changed.

Prefer changing:

- Layout
- Styling
- Composition
- Animation
- Component boundaries

before changing:

- Data models
- API architecture
- Persistence
- Catalog logic
- Download architecture

---

# 76. Implementation Strategy

Frontend work should be done in controlled phases.

Recommended order:

### Phase 1
Analyze existing codebase.

### Phase 2
Design tokens + base components.

### Phase 3
Application shell + navigation.

### Phase 4
Home.

### Phase 5
Wallpapers.

### Phase 6
Animated wallpaper viewer + media optimizations.

### Phase 7
Themes.

### Phase 8
Widgets.

### Phase 9
Art + Collections + Favorites + Downloads.

### Phase 10
Workspace.

### Phase 11
Tools.

### Phase 12
System.

### Phase 13
Settings.

### Phase 14
Global animation pass.

### Phase 15
Performance pass.

### Phase 16
Visual consistency pass.

---

# 77. Inspect Before Editing

Before modifying code:

- Inspect architecture
- Inspect routes
- Inspect existing components
- Inspect styling
- Inspect state management
- Inspect media handling
- Inspect performance-sensitive areas

Do not modify blindly.

---

# 78. Work Incrementally

Avoid giant one-shot rewrites.

Prefer:

```text
Analyze
↓
Plan
↓
Design system
↓
Shell
↓
One major screen
↓
Test
↓
Next screen
```

This lowers regression risk and makes performance issues easier to isolate.

---

# 79. Token-Efficient Development

When working with AI coding tools:

- Do not repeatedly restate these rules.
- Use this file as the persistent design specification.
- Keep implementation tasks focused.
- Inspect only relevant files.
- Avoid long explanations.
- Avoid rewriting unrelated code.
- Reuse components.
- Keep task scope explicit.
- Make one meaningful visual change at a time.

Preferred task style:

> "Redesign Wallpapers using `rules_frontend.md`. Preserve functionality and optimize media."

Not:

> "Explain the entire project and redesign everything from scratch."

---

# 80. Final QA — Visual

Before considering a frontend area complete, verify:

- Typography is consistent
- Spacing is consistent
- Radius is consistent
- Navigation matches the system
- Glass surfaces are consistent
- Cards match the visual language
- Active states are clear
- Hover states are subtle
- Icons are consistent
- Empty states are polished
- Loading states match the design
- Page transitions are smooth
- No section feels like a different app

---

# 81. Final QA — Animation

Verify:

- No unnecessary animation
- No delayed controls
- No janky hover effects
- No animation blocking interaction
- Page transitions are fast
- Dynamic Island transitions are smooth
- Video previews behave correctly
- Reduced motion works

---

# 82. Final QA — Performance

Verify:

- Large wallpaper libraries remain responsive
- Images are lazy-loaded
- Videos use posters before playback
- Off-screen videos pause
- Unnecessary video playback is minimized
- Search remains responsive
- Filtering remains responsive
- System updates do not rerender unrelated UI
- No obvious memory leaks
- No excessive backdrop-filter usage
- Animations maintain smoothness
- No unnecessary global rerenders

---

# 83. Final QA — Functional

Verify:

- Navigation works
- Secondary tabs work
- Wallpaper selection works
- Live wallpapers work
- Still wallpapers work
- Wallpaper detail works
- Themes work
- Widgets work
- Search works
- Filters work
- Favorites work
- Downloads work
- Tools work
- System monitoring works
- Dynamic Island works
- Settings work

---

# 84. Final Quality Bar

The final application should look and feel like a **real premium macOS product**, not a generated prototype.

Ask:

> "Would this UI look believable as a polished product shown in a professional product demo or Mac App Store presentation?"

The answer should be yes.

The product should feel:

- Premium
- Fast
- Cinematic
- Smooth
- Cohesive
- Interactive
- Intentional

It should NOT feel:

- Template-like
- Generic
- Cluttered
- Slow
- Inconsistent
- Over-animated
- Over-designed

---

# 85. Golden Rule

When in doubt:

> **Follow the reference design language, preserve functionality, prioritize performance, and keep the interface visually calm.**

Beautiful is good.

Beautiful + fast + consistent is the actual goal.
