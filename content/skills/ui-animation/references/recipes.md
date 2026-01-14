# UI Animation Recipes

Extended examples and copy-paste patterns organized by category. For quick reference and decision-making, see `SKILL.md`.

---

## Common UI Patterns

### Button Press Feedback

Provide instant visual feedback on press. The subtle scale reduction makes the button feel responsive.

```html
<button class="transition-transform active:scale-[0.97]">
  Click me
</button>
```

For CSS:

```css
.button {
  transition: transform 0.1s ease;
}

.button:active {
  transform: scale(0.97);
}
```

### Modal Enter/Exit (Tailwind + tailwindcss-animate)

```html
<div
  class="
    data-[state=open]:animate-in
    data-[state=open]:fade-in-0
    data-[state=open]:zoom-in-95
    data-[state=closed]:animate-out
    data-[state=closed]:fade-out-0
    data-[state=closed]:zoom-out-95
    duration-200
  "
>
  Modal content
</div>
```

### Error Shake

A quick shake animation for form validation errors. The custom easing gives it a snappy, physical feel.

```css
@keyframes shake {
  0%, 100% {
    transform: translateX(0);
  }
  25% {
    transform: translateX(-4px);
  }
  75% {
    transform: translateX(4px);
  }
}

.animate-shake {
  animation: shake 0.3s cubic-bezier(0.36, 0.07, 0.19, 0.97) both;
}
```

```html
<!-- Apply class on validation error -->
<input class="animate-shake" />
```

### Staggered List Reveal

Children animate in sequence with a small delay between each item.

```tsx
const container = {
  hidden: {},
  visible: {
    transition: {
      staggerChildren: 0.05,
    },
  },
};

const item = {
  hidden: {
    opacity: 0,
    y: 10,
  },
  visible: {
    opacity: 1,
    y: 0,
  },
};

<motion.ul
  variants={container}
  initial="hidden"
  animate="visible"
>
  {items.map((i) => (
    <motion.li key={i} variants={item}>
      {i}
    </motion.li>
  ))}
</motion.ul>
```

### Accordion (Height Auto)

CSS Grid track interpolation is the only reliable CSS-only solution for animating to `height: auto`.

```html
<div
  class="
    grid
    transition-[grid-template-rows]
    duration-300
    ease-out
    data-[state=open]:grid-rows-[1fr]
    data-[state=closed]:grid-rows-[0fr]
  "
>
  <div class="overflow-hidden">
    <div class="p-4">
      Accordion content goes here
    </div>
  </div>
</div>
```

### Tab Indicator (Shared Element)

The indicator smoothly animates between tabs using `layoutId`.

```tsx
{tabs.map((tab) => (
  <button
    key={tab}
    onClick={() => setSelected(tab)}
    className="relative px-4 py-2"
  >
    {tab}
    {selected === tab && (
      <motion.div
        layoutId="active-tab"
        className="absolute inset-0 bg-primary rounded-lg -z-10"
        transition={{
          type: "spring",
          stiffness: 300,
          damping: 30,
        }}
      />
    )}
  </button>
))}
```

---

## Touch & Interaction Patterns

### Accessible Touch Targets

Small icons are hard to tap accurately. Use padding or a pseudo-element to create an invisible hit area that meets touch accessibility standards.

| Standard | Size | Tailwind | Notes |
|----------|------|----------|-------|
| **Material Design** | 48×48 dp | `min-h-12 min-w-12` | ~9mm, recommended for cross-platform |
| **Apple HIG** | 44×44 pt | `min-h-11 min-w-11` | ~7mm, iOS-specific minimum |
| **WCAG 2.2 (AA)** | 24×24 px | `min-h-6 min-w-6` | ~5mm, absolute minimum |

```css
.touch-target {
  position: relative;
}

.touch-target::before {
  content: "";
  position: absolute;
  top: 50%;
  left: 50%;
  transform: translate(-50%, -50%);
  width: 100%;
  height: 100%;
  min-width: 48px;  /* Material Design recommended */
  min-height: 48px;
}
```

Tailwind equivalent:

```html
<button class="relative min-h-12 min-w-12">
  <Icon class="w-4 h-4" />
</button>
```

### Disable Hover Effects on Touch Devices

Hover states are confusing on mobile—they trigger on tap and persist. Only apply hover effects when the device actually supports hover.

```css
/* Only apply hover styles on devices that support hover */
@media (hover: hover) and (pointer: fine) {
  .card:hover {
    transform: scale(1.02);
    box-shadow: 0 10px 40px rgba(0, 0, 0, 0.15);
  }
}
```

### Instant Subsequent Tooltips

The first tooltip needs a delay to prevent accidental activation. After that, subsequent tooltips should appear instantly as the user explores.

```css
.tooltip {
  transition: opacity 0.15s ease-out, transform 0.15s ease-out;
  transition-delay: 0.4s; /* 400ms delay for first tooltip */
}

/* After first tooltip shown, library adds data-instant */
.tooltip[data-instant] {
  transition-delay: 0ms;
  transition-duration: 0ms;
}
```

---

## Layout Animation Examples

### Basic Layout Prop

Add `layout` to automatically animate position and size changes. Use `layout="position"` for text to prevent distortion.

```tsx
<motion.div
  layout
  className="p-4 rounded-xl bg-white shadow"
>
  <motion.h3 layout="position">
    Title stays crisp
  </motion.h3>

  {isOpen && (
    <motion.p
      initial={{ opacity: 0 }}
      animate={{ opacity: 1 }}
    >
      This content pushes other elements smoothly
      when it appears or disappears.
    </motion.p>
  )}
</motion.div>
```

### Shared Element Transitions (layoutId)

Elements with matching `layoutId` animate between each other seamlessly.

```tsx
// Tab underline that follows selection
<div className="flex gap-2">
  {tabs.map((tab) => (
    <button
      key={tab}
      onClick={() => setSelected(tab)}
      className="relative px-4 py-2"
    >
      {tab}

      {selected === tab && (
        <motion.div
          layoutId="underline"
          className="absolute bottom-0 left-0 right-0 h-1 bg-blue-500 rounded-full"
        />
      )}
    </button>
  ))}
</div>
```

### layoutId Collision - Problem and Solutions

When two unrelated components use the same `layoutId`, elements teleport between them unexpectedly.

**The Problem:**

```tsx
// ❌ TELEPORTATION BUG: Elements fly across the page
<ProductCard>
  {isSelected && (
    <motion.div layoutId="highlight" className="..." />
  )}
</ProductCard>

<UserCard>
  {isActive && (
    <motion.div layoutId="highlight" className="..." />
    {/* Same layoutId = COLLISION! */}
  )}
</UserCard>
```

**Solution 1: Unique layoutId per context**

```tsx
// ✅ Use unique layoutId values
<ProductCard>
  <motion.div layoutId="product-highlight" />
</ProductCard>

<UserCard>
  <motion.div layoutId="user-highlight" />
</UserCard>
```

**Solution 2: Scope with LayoutGroup**

```tsx
// ✅ LayoutGroup creates isolated scopes
<LayoutGroup id="products">
  <motion.div layoutId="highlight" />
  {/* Scoped to "products" */}
</LayoutGroup>

<LayoutGroup id="users">
  <motion.div layoutId="highlight" />
  {/* Separate scope - no collision */}
</LayoutGroup>
```

**Debugging tip:** When elements fly across the page unexpectedly, search for duplicate `layoutId` values.

---

## Radix UI + Motion Integration

Radix controls mounting/unmounting internally. To animate exits with Motion, use `forceMount` so Motion can control visibility.

```tsx
<Dialog.Root open={isOpen} onOpenChange={setIsOpen}>
  <Dialog.Trigger asChild>
    <button>Open Dialog</button>
  </Dialog.Trigger>

  <Dialog.Portal forceMount>
    <AnimatePresence>
      {isOpen && (
        <>
          {/* Overlay */}
          <Dialog.Overlay asChild>
            <motion.div
              initial={{ opacity: 0 }}
              animate={{ opacity: 1 }}
              exit={{ opacity: 0 }}
              transition={{ duration: 0.2 }}
              className="fixed inset-0 bg-black/50"
            />
          </Dialog.Overlay>

          {/* Content */}
          <Dialog.Content asChild>
            <motion.div
              initial={{ opacity: 0, scale: 0.95 }}
              animate={{ opacity: 1, scale: 1 }}
              exit={{ opacity: 0, scale: 0.95 }}
              transition={{
                duration: 0.2,
                ease: [0.32, 0.72, 0, 1],
              }}
              className="fixed left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-white rounded-lg p-6 shadow-xl"
            >
              <Dialog.Title>Dialog Title</Dialog.Title>
              <Dialog.Description>
                Dialog content goes here.
              </Dialog.Description>
            </motion.div>
          </Dialog.Content>
        </>
      )}
    </AnimatePresence>
  </Dialog.Portal>
</Dialog.Root>
```

### Key Integration Points

| Prop | Purpose |
|------|---------|
| `forceMount` | Tells Radix to always render, letting Motion control visibility |
| `asChild` | Passes Motion props through Radix wrapper components |
| `AnimatePresence` | Required for exit animations to run before unmount |

### Origin-Aware Popovers

Make popovers feel connected to their trigger by animating from the correct origin point.

```css
/* Radix UI - uses CSS custom property */
[data-radix-popper-content-wrapper] {
  transform-origin: var(--radix-popper-transform-origin);
}

/* Or manually for custom positioning */
.popover-content[data-side="bottom"] {
  transform-origin: top center;
}

.popover-content[data-side="top"] {
  transform-origin: bottom center;
}

.popover-content[data-side="left"] {
  transform-origin: right center;
}

.popover-content[data-side="right"] {
  transform-origin: left center;
}
```

---

## Accessibility Patterns

### Focus Management Timing

Moving focus during an animation breaks keyboard navigation—the element isn't visible yet when focus moves to it.

```tsx
// ❌ WRONG: Focus moves while content is still invisible
const openModal = () => {
  setIsOpen(true);
  modalRef.current?.focus(); // Focus moves during animation!
};

// ✅ CORRECT: Move focus after animation starts
const openModal = () => {
  setIsOpen(true);
  requestAnimationFrame(() => {
    modalRef.current?.focus();
  });
};
```

### Focus Restoration on Close

When closing modals/dialogs, restore focus to the element that triggered it.

```tsx
// ❌ WRONG: Focus is lost to <body>
<Dialog onClose={() => setIsOpen(false)} />

// ✅ CORRECT: Return focus to trigger
function Modal({ trigger, children }) {
  const triggerRef = useRef<HTMLButtonElement>(null);
  const [isOpen, setIsOpen] = useState(false);

  const handleClose = () => {
    setIsOpen(false);
    // Restore focus after close animation
    requestAnimationFrame(() => {
      triggerRef.current?.focus();
    });
  };

  return (
    <>
      <button
        ref={triggerRef}
        onClick={() => setIsOpen(true)}
      >
        {trigger}
      </button>
      <Dialog open={isOpen} onClose={handleClose}>
        {children}
      </Dialog>
    </>
  );
}
```

### Reduced Motion Variants

Simplify animations for users who prefer reduced motion. Don't disable completely—remove spatial movement but keep opacity transitions.

```tsx
import { useReducedMotion } from "motion/react";

function AnimatedCard({ children }) {
  const shouldReduce = useReducedMotion();

  // Full animation for standard users
  const fullVariants = {
    initial: { opacity: 0, y: 20, scale: 0.95 },
    animate: { opacity: 1, y: 0, scale: 1 },
    exit: { opacity: 0, y: -10 },
  };

  // Simplified: opacity only, no spatial movement
  const reducedVariants = {
    initial: { opacity: 0 },
    animate: { opacity: 1 },
    exit: { opacity: 0 },
  };

  const variants = shouldReduce ? reducedVariants : fullVariants;

  return (
    <motion.div
      initial="initial"
      animate="animate"
      exit="exit"
      variants={variants}
    >
      {children}
    </motion.div>
  );
}
```

---

## Performance Patterns

### Height/Width Animation (Wrong vs Right)

Animating `height` or `width` directly causes layout thrashing and janky 60fps drops, especially on mobile.

```tsx
// ❌ WRONG: Causes layout recalculation every frame
<motion.div
  animate={{
    height: isOpen ? 200 : 0,
  }}
/>

// ❌ ALSO WRONG: Same problem
<motion.div
  animate={{
    width: expanded ? "100%" : "50%",
  }}
/>

// ✅ CORRECT: Use layout prop (FLIP technique)
<motion.div
  layout
  style={{
    height: isOpen ? "auto" : 0,
    overflow: "hidden",
  }}
/>
```

### Fix Shaky Transform Animations

If you see 1px "jiggling" during CSS transforms, hint the browser to use GPU acceleration.

```css
/* Apply during animation, remove after */
.element-animating {
  will-change: transform;
}

/* Or for persistent animated elements */
.always-animated {
  will-change: transform, opacity;
}
```

**Warning:** Don't apply `will-change` to everything—it causes layer explosion and crashes on mobile.

```css
/* ❌ DANGEROUS: Layer explosion */
* {
  will-change: transform;
}

/* ✅ CORRECT: Only on actively animating elements */
.card.is-dragging {
  will-change: transform;
}
```

### Invisible But Still Clickable

Elements with `opacity: 0` are invisible but still receive pointer events. This causes ghost clicks on hidden elements.

```tsx
// ❌ DANGEROUS: Invisible button still clickable
<motion.div animate={{ opacity: 0 }}>
  <button onClick={doSomethingBad}>
    I'm invisible but you can click me!
  </button>
</motion.div>

// ✅ CORRECT: Disable pointer events when hidden
<motion.div
  animate={{
    opacity: isVisible ? 1 : 0,
    pointerEvents: isVisible ? "auto" : "none",
  }}
>
  <button onClick={doSomething}>Safe button</button>
</motion.div>

// ✅ ALTERNATIVE: Use visibility for true removal
<motion.div
  animate={{
    opacity: isVisible ? 1 : 0,
    visibility: isVisible ? "visible" : "hidden",
  }}
>
  ...
</motion.div>
```

### Expensive Operations to Avoid

| Operation | Problem | Alternative |
|-----------|---------|-------------|
| `blur()` >20px | Exceeds GPU cache on HiDPI, causes jank | ≤10px safe; 11-20px test on mobile; >20px use pre-blurred images |
| `backdrop-filter` on large areas | Expensive compositing | Limit to small overlays |
| `box-shadow` transitions | Causes repaint | Use `opacity` on a pseudo-element with shadow |
| Large `border-radius` changes | Layout recalculation | Animate `clip-path` or use fixed radius |

---

## Exit Animation Patterns

### popLayout with forwardRef

Custom components with `popLayout` mode silently fail without `forwardRef`—Motion can't measure the element.

```tsx
// ❌ SILENTLY FAILS: No ref forwarding
const ListItem = (props) => {
  return <motion.li {...props} />;
};

<AnimatePresence mode="popLayout">
  {items.map((item) => (
    <ListItem key={item.id} exit={{ opacity: 0 }}>
      {item.name}
    </ListItem>
    // Exit animation doesn't work!
  ))}
</AnimatePresence>

// ✅ CORRECT: Forward the ref
const ListItem = forwardRef((props, ref) => {
  return <motion.li ref={ref} {...props} />;
});

<AnimatePresence mode="popLayout">
  {items.map((item) => (
    <ListItem
      key={item.id}
      exit={{ opacity: 0, scale: 0.9 }}
    >
      {item.name}
    </ListItem>
    // Now exit animations work!
  ))}
</AnimatePresence>
```

### SSR/Hydration - Preventing Animation Flash

Without `initial={false}`, elements animate on every page load, creating a jarring flash.

```tsx
// ❌ WRONG: Items animate in on every page load
<AnimatePresence>
  {items.map((item) => (
    <motion.li
      key={item.id}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
    >
      {item.name}
    </motion.li>
  ))}
</AnimatePresence>

// ✅ CORRECT: Only animate changes, not initial render
<AnimatePresence initial={false}>
  {items.map((item) => (
    <motion.li
      key={item.id}
      initial={{ opacity: 0, y: 20 }}
      animate={{ opacity: 1, y: 0 }}
      exit={{ opacity: 0 }}
    >
      {item.name}
    </motion.li>
  ))}
</AnimatePresence>
```

---

## Gesture Patterns

### Swipe Dismiss with Velocity Check

Always check BOTH distance AND velocity. Users expect quick flicks to dismiss even if they don't drag very far.

```tsx
<motion.div
  drag="x"
  dragConstraints={{ left: 0, right: 0 }}
  dragElastic={0.2}
  onDragEnd={(event, info) => {
    const offsetThreshold = 100;  // pixels
    const velocityThreshold = 500; // pixels per second

    const shouldDismiss =
      Math.abs(info.offset.x) > offsetThreshold ||
      Math.abs(info.velocity.x) > velocityThreshold;

    if (shouldDismiss) {
      // Animate out in the direction of the swipe
      const direction = info.offset.x > 0 ? 1 : -1;
      animateOut(direction);
      onDismiss();
    }
  }}
>
  <Card>Swipe to dismiss</Card>
</motion.div>
```

### Drag with Elastic Boundaries

Configure drag behavior with per-direction elasticity and constraints.

```tsx
<motion.div
  drag
  dragElastic={{
    top: 0,      // No elasticity at top
    bottom: 0.5, // Bouncy at bottom
    left: 0.2,   // Slight elasticity on sides
    right: 0.2,
  }}
  dragConstraints={{
    top: 0,
    bottom: 100,
    left: -50,
    right: 50,
  }}
  dragMomentum={false} // Disable for precise UIs like sliders
/>
```

---

## Custom Easing Reference

Built-in CSS easings are often too weak. Use these custom curves for more energetic, polished animations.

> **Source**: Values below are from [easings.net](https://easings.net) (current canonical reference). They are mathematically accurate cubic-bezier approximations of polynomial easing functions. Legacy "Caesar" values (circa 2011) are still used by some libraries but are less precise.

### Ease-Out Curves (For Enter Animations)

```css
/* Subtle - quadratic: 1-(1-t)^2 */
--ease-out-quad: cubic-bezier(0.5, 1, 0.89, 1);

/* Moderate - cubic: 1-(1-t)^3 */
--ease-out-cubic: cubic-bezier(0.33, 1, 0.68, 1);

/* Pronounced - quartic: 1-(1-t)^4 */
--ease-out-quart: cubic-bezier(0.25, 1, 0.5, 1);

/* Strong - quintic: 1-(1-t)^5 */
--ease-out-quint: cubic-bezier(0.22, 1, 0.36, 1);

/* Very Strong - exponential: 1-2^(-10t) */
--ease-out-expo: cubic-bezier(0.16, 1, 0.3, 1);
```

### Ease-In-Out Curves (For On-Screen Movement)

```css
/* Subtle - quadratic */
--ease-in-out-quad: cubic-bezier(0.45, 0, 0.55, 1);

/* Moderate - cubic */
--ease-in-out-cubic: cubic-bezier(0.65, 0, 0.35, 1);

/* Pronounced - quartic */
--ease-in-out-quart: cubic-bezier(0.76, 0, 0.24, 1);

/* Strong - quintic */
--ease-in-out-quint: cubic-bezier(0.83, 0, 0.17, 1);
```

### Signature Curves

```css
/* Vaul - buttery smooth for sheets/drawers (github.com/emilkowalski/vaul) */
--ease-vaul: cubic-bezier(0.32, 0.72, 0, 1);

/* Material Design 3 - emphasized (m3.material.io) */
--ease-md3: cubic-bezier(0.2, 0, 0, 1);

/* Snappy - fast UI transitions (matches ease-out-quart) */
--ease-snappy: cubic-bezier(0.25, 1, 0.5, 1);
```

---

## Debugging Tips

### Developer Perception Bias

Developers often perceive their own animations as faster than users do—you've seen it hundreds of times while building. Take a break and return with fresh eyes, or have someone else test it.

### Record and Scrub

The best way to spot subtle imperfections is to **screen record** your animation and scrub through frame-by-frame. Issues invisible at 60fps become obvious in slow motion.

### The "When in Doubt, Blur" Trick

If an animation still feels "off" after tweaking easing and duration, adding a subtle `filter: blur(2px)` during the transition can mask imperfections and smooth the visual result.

```css
.element-entering {
  animation: fadeIn 0.2s ease-out;
}

@keyframes fadeIn {
  0% {
    opacity: 0;
    filter: blur(4px);
  }
  100% {
    opacity: 1;
    filter: blur(0);
  }
}
```
