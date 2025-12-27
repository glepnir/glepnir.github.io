+++
date = '2025-12-24T18:48:14+08:00'
draft = false
title = "The Best Theme Isn't the Prettiest—It's the One You Forget Exists"
tags = ["neovim", "color-science", "vision-research", "oklab"]
toc = true
+++

For years, I was stuck in this cycle: find something that looks decent, tweak HSL values until it "feels right," use it for a few weeks, then get that creeping eye strain. Suddenly colors that looked fine before would start to irritate me. Back to the drawing board.

I must have done this dozens of times. Each round felt more arbitrary than the last—just moving sliders around hoping something would click. Honestly, it was getting ridiculous. Why couldn't I just find something that worked and stick with it?

Then one night, while adjusting my umpteenth orange hue, it hit me: people have been studying vision for decades. There's actual science about how we see color, what causes eye strain, how to make things readable. Maybe instead of guessing, I could actually, you know, use that science.

So I did. And it turns out, building a theme from first principles works way better than tweaking hex codes.

## Part 1: Your Color Picker is Probably Lying to You

Here's the thing no one tells you: RGB and HSL are kind of broken for designing themes. They make sense to computers but not to human eyes. In RGB, the "distance" between colors has nothing to do with how different they actually look. HSL is slightly better, but still weird—changing saturation can make some colors get much brighter while others barely change.

It's like trying to measure temperature with a ruler. You're using the wrong tool for the job.

### Enter Oklab: A Color Space That Actually Makes Sense

After digging around, I found something called Oklab. It's a "perceptually uniform" color space, which is a fancy way of saying: if you move a color 10 units in Oklab, it looks about 10 units different to your eyes. No surprises.

The math goes something like this:

**Step 1: Oklab → LMS (how your eye's cones respond)**
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

Yeah, that looks intimidating. But here's the Lua code that makes it usable:

```lua
local function oklab_to_linear_rgb(L, a, b)
  -- Oklab to LMS
  local l = L + 0.3963377774 * a + 0.2158037573 * b
  local m = L - 0.1055613458 * a - 0.0638541728 * b
  local s = L - 0.0894841775 * a - 1.2914855480 * b

  -- Inverse cube root
  local l3, m3, s3 = l * l * l, m * m * m, s * s * s

  -- LMS to linear RGB
  local r = 4.0767416621 * l3 - 3.3077115913 * m3 + 0.2309699292 * s3
  local g = -1.2684380046 * l3 + 2.6097574011 * m3 - 0.3413193965 * s3
  local b_out = -0.0041960863 * l3 - 0.7034186147 * m3 + 1.7076147010 * s3

  return r, g, b_out
end

local function linear_to_srgb_component(c)
  -- Gamma correction
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

  -- Clamp and convert to hex
  r = math.floor(math.max(0, math.min(1, r)) * 255 + 0.5)
  g = math.floor(math.max(0, math.min(1, g)) * 255 + 0.5)
  b_comp = math.floor(math.max(0, math.min(1, b_comp)) * 255 + 0.5)

  return string.format('#%02x%02x%02x', r, g, b_comp)
end
```

The cool part? Now instead of this:

```lua
-- Random hex code I found somewhere
local orange = "#c5895b"
```

I can do this:

```lua
-- "I want a color that's 68% bright, slightly warm"
local orange = oklab_to_srgb(0.68, 0.055, 0.065)
```

That first number is brightness (0-1). The next two control hue and saturation. Want it brighter? Increase the first number. Want it more orange? Adjust the ratio. It's predictable in a way hex codes never were.

## Part 2: What Actually Needs to be Colorful?

Here's where I made my first big mistake. I used to color everything—variables, operators, you name it. Turns out, that's probably wrong.

I found this 2018 study with 390 programming beginners. The surprising finding? Syntax highlighting doesn't really help with understanding code. But wait—it *does* help when it emphasizes **structural elements** rather than coloring everything equally.

The takeaway: **Highlight structure, not noise.**

Then I read Ivan Tonsky's article where he points out that most of your code is variables and function calls. If you highlight all of those, you're coloring like 75% of the screen. No wonder everything looks busy!

His suggestion made so much sense: keep variables and operators neutral (same color as regular text). Only use bright colors for the stuff that actually matters.

### My New Three-Tier System

This research led me to a much simpler approach:

1. **Bright colors** for the important bits:
   - Control flow (if, for, while, return)
   - Function definitions
   - Type declarations

2. **Regular text color** for the rest:
   - Variable names
   - Operators
   - Function parameters

3. **Dimmed colors** for secondary stuff:
   - Comments
   - Delimiters

The result is subtle but effective. The code's structure jumps out at you, but most of the screen stays calm and readable.

## Part 3: Brightness is Everything (Seriously)

This was my biggest "aha" moment. I used to spend hours debating whether keywords should be orange or yellow. Turns out, I was asking the wrong question.

Human eyes are way more sensitive to **brightness differences** than to **color differences**. Like, 5-10 times more sensitive. There's actual science behind this called the "Contrast Sensitivity Function."

So the real question isn't "what color should this be?" It's "how bright should this be compared to that?"

### Building a Brightness Hierarchy That Actually Works

I started with some basic constraints:
- **Background:** L=0.24 (dark enough to be comfortable at night)
- **Regular text:** L=0.74 (great contrast, meets accessibility standards)

From the research, I knew structure was most important, errors needed attention, and data was secondary. So I made three brightness levels:

1. **Brightest (L=0.68):** Structure elements (keywords, functions, types)
2. **Middle (L=0.66):** Errors and warnings
3. **Dimmest (L=0.64):** Data (strings, numbers, constants)

The math checks out for contrast ratios:
\[
\begin{aligned}
\text{CR}(L_1, L_{\text{bg}}) &= \frac{0.68 + 0.05}{0.24 + 0.05} = 5.52:1 \\
\text{CR}(L_2, L_{\text{bg}}) &= \frac{0.66 + 0.05}{0.24 + 0.05} = 5.03:1 \\
\text{CR}(L_3, L_{\text{bg}}) &= \frac{0.64 + 0.05}{0.24 + 0.05} = 4.76:1
\end{aligned}
\]

All three meet WCAG AA standards, and the brightness differences (ΔL=0.02) are noticeable without being jarring.

Here's what's cool: in my old themes, errors were the same brightness as strings. No wonder I'd miss them! Now errors stand out just enough to catch my attention without looking like an alarm went off.

### The Complete Brightness System

| Level | Brightness | Use For | Why It Works |
|-------|-----------|---------|--------------|
| 1 | L=0.68 | Keywords, Functions, Types | Guides your eye to the code's structure |
| 2 | L=0.66 | Errors, Warnings | Noticeable but not overwhelming |
| 3 | L=0.64 | Strings, Numbers, Constants | Stays in the background |
| - | L=0.24 | Background | Easy on the eyes |
| - | L=0.74 | Regular text | Maximum readability |

## Part 4: The Fatigue Factor

Here's something I never considered: different colors actually cause different amounts of eye strain. Red wavelengths are the worst—they make your pupils constrict more, which gets tiring. Yellow is the easiest on your eyes.

There's research (they measure pupil response and everything) that shows for comfortable long sessions, you want to keep colors muted:
- Average saturation around 0.08
- Red saturation under 0.09
- Yellow/green under 0.10

In Oklab, saturation is simple:
\[
s = \sqrt{a^2 + b^2}
\]

So I made sure all my colors stayed in the safe zone:

```lua
-- Orange for keywords: √(0.055² + 0.065²) ≈ 0.085
colors.orange = oklab_to_srgb(0.68, 0.055, 0.065)

-- Red for errors: √(0.08² + 0.04²) ≈ 0.089 (just under 0.09)
colors.red = oklab_to_srgb(0.66, 0.08, 0.04)

-- Yellow for types: √(0.0² + 0.08²) ≈ 0.08
colors.yellow = oklab_to_srgb(0.68, 0.0, 0.08)
```

No more wondering why my eyes hurt after a marathon coding session.

## Part 5: What Colors "Mean"

Colors aren't just pretty—they carry associations. Research shows we tend to agree on what colors mean:

- **Red** → Error, Danger, Stop
- **Orange** → Action, Warning, Warm
- **Yellow** → Important, Attention
- **Green** → Success, Natural, Content
- **Blue** → Logic, Stability, Cool
- **Cyan** → Technical, Meta
- **Violet** → Abstract, Special

This gave me a logical way to assign colors:

| Code Element | Why This Color | Oklab Values |
|--------------|----------------|--------------|
| Keywords | Action → Orange | (0.68, 0.055, 0.065) |
| Functions | Logic → Blue | (0.68, -0.02, -0.06) |
| Types | Important → Yellow | (0.68, 0.02, 0.08) |
| Errors | Danger → Red | (0.66, 0.08, 0.04) |
| Strings | Content → Green | (0.64, -0.05, 0.06) |
| Constants | Technical → Cyan | (0.64, -0.055, -0.01) |
| Numbers | Abstract → Violet | (0.64, 0.05, -0.04) |

## Putting It All Together

Here's the final palette. Every value comes from those principles, not random guesses:

```lua
local colors = {}

-- Background and text
colors.bg = oklab_to_srgb(0.24, 0.001, 0.006)
colors.fg = oklab_to_srgb(0.74, 0.0, 0.008)

-- Layer 1: Structure (brightest)
colors.orange = oklab_to_srgb(0.68, 0.055, 0.065)  -- Keywords
colors.blue   = oklab_to_srgb(0.68, -0.02, -0.06)  -- Functions
colors.yellow = oklab_to_srgb(0.68, 0.0,  0.08)   -- Types

-- Layer 2: Diagnostics
colors.red    = oklab_to_srgb(0.66, 0.08,  0.04)   -- Errors

-- Layer 3: Data
colors.green  = oklab_to_srgb(0.64, -0.05, 0.06)   -- Strings
colors.cyan   = oklab_to_srgb(0.64, -0.055, -0.01) -- Constants
colors.violet = oklab_to_srgb(0.64, 0.05, -0.04)   -- Numbers

return colors
```

And the highlight groups:

```lua
-- Important stuff (bright)
vim.api.nvim_set_hl(0, 'Keyword', { fg = colors.orange })
vim.api.nvim_set_hl(0, 'Function', { fg = colors.blue })
vim.api.nvim_set_hl(0, 'Type', { fg = colors.yellow })

-- Less important (dimmer)
vim.api.nvim_set_hl(0, 'String', { fg = colors.green })
vim.api.nvim_set_hl(0, 'Constant', { fg = colors.cyan })
vim.api.nvim_set_hl(0, 'Number', { fg = colors.violet })

-- Neutral (same as regular text)
vim.api.nvim_set_hl(0, 'Identifier', { fg = colors.fg })  -- Variables
vim.api.nvim_set_hl(0, 'Operator', { fg = colors.fg })    -- =, +, -, etc.
```

## Does It Actually Work?

![Retina](/images/colorscheme.png)

Don't doubt it, this is still neovim 😏. I've been using this theme (I call it **Retina**) for two months now. Here's what I've noticed:

- **My eyes don't get tired anymore.** I can code for hours without that strained feeling.
- **Errors actually stand out.** That slight brightness bump makes all the difference.
- **I can see the code's structure immediately.** My eyes naturally follow the bright keywords.
- **It's... quiet.** With most variables staying neutral, there's way less visual noise.

## A Quick Reality Check

Look, vision is personal. This works for me, but your eyes might be different. Things that matter:

- **Your age** (older eyes often need more contrast)
- **Your monitor** (OLED vs LCD, different calibrations)
- **Your environment** (dark room vs bright office)
- **Your color vision** (about 8% of men see colors differently)

The beauty of this approach is you can adjust the *parameters* instead of guessing:

```lua
-- Need more contrast? Bump up the brightness:
colors.orange = oklab_to_srgb(0.70, 0.055, 0.065)  -- Was 0.68

-- Colors too strong? Tone down the saturation:
colors.orange = oklab_to_srgb(0.68, 0.044, 0.052)  -- 20% less saturation

-- Want different hues? Adjust the a,b ratio:
colors.orange = oklab_to_srgb(0.68, 0.050, 0.070)  -- More yellow
```

You're tuning a system, not just picking random colors.

The best theme really is the one you forget you're using. It just gets out of your way and lets you focus on the code.

---

## References & Further Reading

1. **Oklab color space:** https://bottosson.github.io/posts/oklab/
2. **Contrast Sensitivity Function:** Barten, P. G. J. (1999)
3. **Color Appearance Models:** Fairchild, M. D. (2013)
4. **Visual Fatigue Study:** Fan et al. (2024)
5. **Color Semantics:** Schloss, K. B. (2024)
6. **Vision and Aging:** Owsley, C. (2016)
7. **Syntax Highlighting Research:** Hannebauer et al. (2018)
8. **"Syntax Highlighting is a Waste of Time":** https://tonsky.me/blog/syntax-highlighting/

---

*You can find the complete theme [on GitHub](https://github.com/glepnir/nvim/blob/main/colors/retina.lua). Use it, tweak it, or just steal the ideas for your own theme. Either way, I hope it helps you break out of the endless theme-tweaking cycle.*
