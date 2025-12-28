+++
date = '2025-12-24T18:48:14+08:00'
draft = false
title = "Stop Guessing Hex Codes: A Better Way to Pick Theme Colors"
tags = ["neovim", "oklab", "color-theory"]
toc = true
+++

I've probably made like 20 different Neovim themes over the years. Each time I
thought "this is the one" and each time, a month later, I'd be tweaking colors
again because something just felt... off.

The problem? I was doing what everyone does—picking colors by eye, converting
between RGB and HSL, hoping the math would somehow make sense. Spoiler: it
doesn't.

Then I found Oklab and everything got way easier.

## RGB/HSL Are Kinda Broken for This

Here's the thing: in RGB, changing red from 200 to 210 might look like a tiny
shift, but changing blue from 200 to 210 could be a massive difference. HSL is
better but still weird—adjusting saturation can make some colors way brighter
and others barely change.

You end up with this:

```lua
-- Wait, which one is brighter? 🤷
local color1 = "#c5895b"
local color2 = "#a87d52"
```

No idea without actually looking at them. And if you want to make color1 "just a
bit dimmer"? Good luck.

## Enter Oklab: Colors That Actually Make Sense

Oklab is a "perceptually uniform" color space. Translation: move a color 0.1
units and it *looks* 0.1 units different. Predictably.

It has three channels:
- **L** (0-1): Brightness. 0 = black, 1 = white, simple.
- **a** (-0.4 to +0.4): Red ↔ Green
- **b** (-0.4 to +0.4): Yellow ↔ Blue

Want an orange that's 68% bright? Easy:

```lua
oklab_to_srgb(0.68, 0.055, 0.065)  -- L=0.68, slightly red, slightly yellow = orange
```

Want it brighter? Change the first number:

```lua
oklab_to_srgb(0.72, 0.055, 0.065)  -- Same hue, 4% brighter
```

That's it. No guessing.

## Implementation

The conversion from Oklab to RGB goes through a few steps:

**Step 1: Oklab → LMS (cone response)**
\[
\begin{bmatrix} l \\ m \\ s \end{bmatrix} = \begin{bmatrix} 1 & 0.3963 & 0.2158 \\ 1 & -0.1056 & -0.0639 \\ 1 & -0.0895 & -1.2915 \end{bmatrix} \begin{bmatrix} L \\ a \\ b \end{bmatrix}
\]

**Step 2: Inverse cube root**
\[
\text{LMS}_{\text{linear}} = [l^3, m^3, s^3]^T
\]

**Step 3: LMS → Linear RGB**
\[
\begin{bmatrix} R \\ G \\ B \end{bmatrix} = \begin{bmatrix} 4.0767 & -3.3077 & 0.2310 \\ -1.2684 & 2.6098 & -0.3413 \\ -0.0042 & -0.7034 & 1.7076 \end{bmatrix} \begin{bmatrix} l^3 \\ m^3 \\ s^3 \end{bmatrix}
\]

**Step 4: Gamma correction (sRGB)**
\[
C_{\text{sRGB}} = \begin{cases} 12.92 \times C_{\text{linear}} & \text{if } C_{\text{linear}} \leq 0.0031308 \\ 1.055 \times C_{\text{linear}}^{1/2.4} - 0.055 & \text{otherwise} \end{cases}
\]

Here's the implementation:

```lua
local function oklab_to_linear_rgb(L, a, b)
  -- Transform Oklab to LMS (cone response)
  local l = L + 0.3963377774 * a + 0.2158037573 * b
  local m = L - 0.1055613458 * a - 0.0638541728 * b
  local s = L - 0.0894841775 * a - 1.2914855480 * b

  -- Apply inverse cube root
  local l3, m3, s3 = l * l * l, m * m * m, s * s * s

  -- LMS to linear RGB
  local r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
  local g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
  local b_out = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

  return r, g, b_out
end

local function linear_to_srgb_component(c)
  if c <= 0.0031308 then
    return c * 12.92
  else
    return 1.055 * (c ^ (1 / 2.4)) - 0.055
  end
end

local function oklab_to_srgb(L, a, b)
  local r, g, b_comp = oklab_to_linear_rgb(L, a, b)

  r = linear_to_srgb_component(r)
  g = linear_to_srgb_component(g)
  b_comp = linear_to_srgb_component(b_comp)

  -- Convert to 8-bit and clamp
  r = math.floor(math.max(0, math.min(1, r)) * 255 + 0.5)
  g = math.floor(math.max(0, math.min(1, g)) * 255 + 0.5)
  b_comp = math.floor(math.max(0, math.min(1, b_comp)) * 255 + 0.5)

  return string.format('#%02x%02x%02x', r, g, b_comp)
end
```

Those magic numbers come from the Oklab spec. Just copy-paste and it works.

## Designing a Palette

Here's how I actually use this. Instead of random hex codes, I think in terms of
brightness and hue.

**Background and foreground first:**

```lua
local colors = {}

-- Dark but not pure black (L=0.24, basically neutral)
colors.bg = oklab_to_srgb(0.24, 0.001, 0.006)

-- Bright text (L=0.74, also basically neutral)
colors.fg = oklab_to_srgb(0.74, 0.0, 0.008)
```

**Then decide on a brightness hierarchy.**

There are two common approaches:

**Style 1: Structure-First**
- Brighten keywords, functions, types - emphasize code structure
- Dim data (strings, numbers) - they're secondary
- Example: structure at L=0.68, data at L=0.64

**Style 2: Data-First** ([Tonsky's philosophy](https://tonsky.me/blog/syntax-highlighting/))
- Dim keywords (low brightness + low saturation) - they're just syntactic noise
- Brighten function definitions, strings, numbers - that's your actual code
- Example: keywords at L=0.60, data at L=0.68-0.70

## How to Pick a/b Values (Hue)

Here's a quick reference for common colors in Oklab space:

```lua
-- Red: a > 0, b near 0 or slightly positive
oklab_to_srgb(L, 0.08, 0.04)   -- orange-red
oklab_to_srgb(L, 0.10, 0.02)   -- pure red
oklab_to_srgb(L, 0.10, -0.02)  -- magenta-red

-- Orange: a > 0, b > 0, roughly equal
oklab_to_srgb(L, 0.055, 0.065) -- typical orange
oklab_to_srgb(L, 0.05, 0.07)   -- more yellow-orange

-- Yellow: a ≈ 0, b > 0
oklab_to_srgb(L, 0.02, 0.08)   -- yellow-orange
oklab_to_srgb(L, 0.0, 0.08)    -- pure yellow
oklab_to_srgb(L, -0.02, 0.08)  -- yellow-green

-- Green: a < 0, b > 0
oklab_to_srgb(L, -0.05, 0.06)  -- typical green
oklab_to_srgb(L, -0.08, 0.04)  -- deeper green

-- Cyan: a < 0, b < 0, |a| > |b|
oklab_to_srgb(L, -0.055, -0.01) -- cyan
oklab_to_srgb(L, -0.06, -0.03)  -- more blue-cyan

-- Blue: a < 0, b < 0, |b| > |a|
oklab_to_srgb(L, -0.02, -0.06)  -- typical blue
oklab_to_srgb(L, -0.01, -0.08)  -- deeper blue

-- Violet/Purple: a > 0, b < 0
oklab_to_srgb(L, 0.05, -0.04)   -- violet
oklab_to_srgb(L, 0.08, -0.06)   -- purple
```

**Saturation control:** \(\text{saturation} = \sqrt{a^2 + b^2}\)

- `s < 0.05`: very muted, almost gray
- `s ≈ 0.08`: moderate, comfortable for long sessions
- `s > 0.10`: vivid, can be fatiguing

So if you want a "medium orange at 68% brightness with moderate saturation
around 0.08":

```lua
-- Start with the hue ratio you want (orange ≈ equal a and b)
-- Then scale to get saturation ≈ 0.08
local orange = oklab_to_srgb(0.68, 0.055, 0.065)  -- sqrt(0.055² + 0.065²) ≈ 0.085
```

## Blending Colors

Sometimes you need a subtle background color—like for diagnostic messages. You
want it to be related to the error color but way more subtle.

Here's my blend function:

```lua
local function hex_to_rgb(hex)
  hex = hex:gsub('#', '')
  return {
    tonumber(hex:sub(1, 2), 16),
    tonumber(hex:sub(3, 4), 16),
    tonumber(hex:sub(5, 6), 16),
  }
end

local function rgb_to_hex(c)
  return string.format('#%02x%02x%02x', c[1], c[2], c[3])
end

local function blend(fg, t)
  local a, b = hex_to_rgb(fg), hex_to_rgb(colors.bg)
  local c = {
    math.floor(a[1] * (1 - t) + b[1] * t + 0.5),
    math.floor(a[2] * (1 - t) + b[2] * t + 0.5),
    math.floor(a[3] * (1 - t) + b[3] * t + 0.5),
  }
  return rgb_to_hex(c)
end
```

Use it like this:

```lua
-- Red error text on a very subtle reddish background
h('DiagnosticVirtualTextError', {
  fg = colors.red,
  bg = blend(colors.red, 0.65)  -- 65% background, 35% red
})
```

The `t` parameter controls the mix. 0.0 = pure foreground color, 1.0 = pure
background, 0.65 = mostly background with a hint of the foreground.

This is way better than manually picking a "light red" background that might not
even match.

## Putting It Together

Just some quick examples of how to use this:

```lua
-- Make a few colors
local orange = oklab_to_srgb(0.68, 0.055, 0.065)
local blue   = oklab_to_srgb(0.68, -0.02, -0.06)
local green  = oklab_to_srgb(0.64, -0.05, 0.06)
local red    = oklab_to_srgb(0.66, 0.08, 0.04)

vim.api.nvim_set_hl(0, 'Keyword', { fg = orange })
vim.api.nvim_set_hl(0, 'Function', { fg = blue })
vim.api.nvim_set_hl(0, 'String', { fg = green })
vim.api.nvim_set_hl(0, 'DiagnosticError', { fg = red })

vim.api.nvim_set_hl(0, 'DiagnosticVirtualTextError', {
  bg = blend(red, 0.65)
})
```

That's pretty much it. Pick some L values, tweak the a/b until it looks right, done.

## Why This Actually Helps

**Before Oklab:**
- "This orange looks too bright... let me try #c58960... no wait #b87a55... hmm maybe #ca8e62?"
- *One hour later, still tweaking*

**After Oklab:**
- "Too bright? Change L from 0.68 to 0.65"
- *Done in 30 seconds*

The real win is **systematic adjustments**:
- Make everything 5% brighter? Add 0.05 to all L values
- Reduce saturation? Scale down all a/b values by 20%
- Switch from data-first to structure-first? Just swap the L values

You're not guessing anymore. You're tuning a system.

## Some Practical Tips

**Testing colors quickly:**

```lua
local test = oklab_to_srgb(0.68, 0.055, 0.065)
print(test)  -- prints: #c5895b
```

**Adjusting systematically:**

```lua
-- Make everything 5% brighter
colors.orange = oklab_to_srgb(0.73, 0.055, 0.065)  -- was 0.68

-- Reduce saturation by 20%
colors.orange = oklab_to_srgb(0.68, 0.044, 0.052)  -- was (0.055, 0.065)

-- Warm up the whole palette
colors.orange = oklab_to_srgb(0.68, 0.055, 0.075)  -- increase b value
```

**When not to use Oklab:** If you're trying to match an existing hex code
exactly, just use the hex. Oklab is for *designing* colors, not copying them.

---

## References

- **Oklab spec:** https://bottosson.github.io/posts/oklab/ (this is where all those magic numbers come from)

That's it. No need to make this more complicated than it is. Pick some L values
for brightness, tweak a/b until the hues look right, and you're done.
