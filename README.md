# orui

![](icon.png)

orui is an immediate mode UI library for odin and raylib, with support for flex and grid layouts.

**Requires odin 2026-03 release or newer!**

The controller-oriented catalog example can be run with:

```sh
odin run examples/catalog
```

<img src="examples/assets.png" width="48%" /><img src="examples/profiler.png" width="43%" />
<img src="examples/skinning/screenshot.gif" width="45%" /><img src="examples/window/screenshot.gif" width="42%" />
<img src="demo/test_scroll.gif" width="40%" /><img src="demo/test_animation.gif" width="44%">
<img src="examples/text_decoration/text_decoration.gif" width="90%" />

Features:

- Flex layout
  - Fit (shrink) and grow
  - Justify and align
  - Child gap
  - Flex wrap (horizontal wrap only)
- Grid layout
  - Auto rows/columns
  - Fixed rows/columns
  - Flow direction
  - Column/row gaps, spans, sizes
- Absolute, relative and fixed positioning
- Layers (z-index)
- Padding, margin, borders, rounded corners, overflow, clipping
- Scrolling
  - Mouse wheel, touch drag, momentum, and smooth scrolling
  - Horizontal/vertical scrollbars
  - Programmatic smooth scroll and scroll-to-focus
- Virtualized lists and tables
  - Fixed-estimate rows with overscan
  - Stable item IDs and controller navigation
  - Virtualized table columns and cells
- Input abstraction
  - Raylib mouse, touch, keyboard and gamepad polling
  - Application-provided input snapshots for other backends and tests
  - Generalized mouse/touch/pen pointers with capture
  - Keyboard and controller focus navigation
  - Programmatic focus and activation
  - Escape/B back handling and keyboard shortcut queries
- Built-in widgets
  - Button, slider, checkbox, tabs, dropdown and modal dialog
  - Focused, disabled, hovered, active and selected states
- Responsive scaling
  - Design-viewport scaling with 1280x800 as the default
- Images (textures)
  - Alignment
  - Content fit (fill, contain, cover, none, scale-down)
- Text
  - Line height, letter spacing, wrapping, alignment
- Text inputs
  - Single line and multi line
  - Click, move with arrow keys, home+end, insert, backspace, select all
  - Double click, triple click
  - Mouse and keyboard text selection
  - Copy/cut/paste
  - Placeholder, rune filtering, maximum length, undo/redo
- Theme and style roles
  - State-aware typed styles and per-context themes
  - Deck-friendly touch-target and focus metrics
- Custom render events
  - Interleave your own rendering with the UI
- Animation helpers

To do:

- 9-slice scaling
- Grid justify/align
- Text input composition/IME support
- Variable-height virtualized rows
- Table sorting and cell-level editing
- Scroll bounce and platform-specific overscroll

## Table of Contents

- [Usage](#usage)
- [Declaring UI](#declaring-ui)
  - [element](#elementid-config-modifiers)
  - [container](#containerid-config-modifiers)
  - [label](#labelid-text-config-modifiers)
  - [text_input](#text_inputid-buffer-config-modifiers)
  - [image](#imageid-config-modifiers)
  - [scrollbar](#scrollbarparent_id-background_config-handle_config-index--0)
- [Input and controller support](#input-and-controller-support)
- [Focus, activation and navigation](#focus-activation-and-navigation)
- [Virtualized lists and tables](#virtualized-lists-and-tables)
- [Touch and pointer input](#touch-and-pointer-input)
- [Built-in widgets](#built-in-widgets)
- [Theme and visual states](#theme-and-visual-states)
- [Responsive scaling](#responsive-scaling)
- [Other functions](#other-functions)
  - [hovered()](#hovered)
  - [active()](#active)
  - [clicked()](#clicked)
  - [focused()](#focused)
  - [cursor()](#cursor)
- [Animation](#animation)
- [Element config](#element-config)
  - [Config helpers](#config-helpers)
  - [Config modifiers](#config-modifiers)
- [Custom render events](#custom-render-events)

## Usage

Allocate the orui Context up front and initialize:

```odin
ctx := new(orui.Context)
orui.init(ctx)
defer orui.destroy(ctx)
```

(Optional) Set a default font:

```odin
ctx.default_font = rl.GetFontDefault()
```

If you don't set a default font, you must pass a font to each element that displays text. The default font is a fallback for when the element font is missing.

In your render loop:

```odin
for !rl.WindowShouldClose() {
	rl.BeginDrawing()
	orui.begin_responsive(ctx, rl.GetScreenWidth(), rl.GetScreenHeight())

	// Declare UI here

	render_commands := orui.end()

	for render_command in render_commands {
		// optional: use orui's built-in helper
		orui.render_command(render_command)
		// important: the built-in renderer uses the temp allocator when rendering strings!
		// remember to free the temp allocator at the end of each frame
	}

	rl.EndDrawing()
	free_all(ctx.temp_allocator)
}
```

For a non-Raylib backend, fill an `InputState` and use `begin_with_input`. To
use controller/keyboard navigation, widgets should be declared with the
built-in focusable widgets or with `focusable = true` in their config:

```odin
orui.begin_responsive_with_input(ctx, width, height, input)
if orui.button(orui.id("save"), "Save", {}) {
	save()
}
if orui.back_pressed() {
	close_current_screen()
}
```

Call `set_focus(ctx, id)` or `activate(ctx, id)` before the frame to control
focus or trigger a widget programmatically. `shortcut_pressed(key)` and
`shortcut_down(key)` expose the current keyboard snapshot.

Text-input tracing is enabled after `init` and writes through the current Odin
logger. Use `set_input_trace(ctx, false)` to disable it. The trace records the
focused element, caret, builder length/capacity, character, and each insertion
stage.

## Input and controller support

orui represents input as an `InputState` snapshot. The normal `begin` and
`begin_responsive` functions create this snapshot by polling Raylib:

```odin
input := orui.input_from_raylib()
orui.begin_responsive_with_input(ctx, width, height, input)
```

This makes the UI input path independent from the backend. Applications can
fill an `InputState` themselves for SDL, a custom platform layer, or tests.
The snapshot contains mouse position/buttons/wheel, up to `MAX_POINTERS`
generalized pointers, keyboard down/pressed/repeat state, text characters,
clipboard text, and up to four controllers. The first pointer is the primary
pointer used by normal widgets.

```odin
input: orui.InputState
input.mouse_position = {100, 80}
input.mouse_left_pressed = true
input.pointer_count = 1
input.pointers[0] = {
    id = 0, kind = .Touch, position = {100, 80}, pressed = true, down = true,
}
input.controllers[0].connected = true
input.controllers[0].buttons_pressed[int(orui.ControllerButton.South)] = true
input.characters[0] = 'A'
input.character_count = 1

orui.begin_with_input(ctx, 1280, 800, input)
```

Use `input_from_raylib()` once per frame, not once per widget. The built-in
Raylib adapter maps the semantic controller buttons as follows:

| orui button | Typical Xbox/Steam Deck meaning |
|---|---|
| `South` | A / confirm |
| `East` | B / back |
| `West` | X |
| `North` | Y |
| `Left_Shoulder`, `Right_Shoulder` | LB/RB |
| `DPad_Up`, `DPad_Right`, `DPad_Down`, `DPad_Left` | D-pad |

The semantic axis values are available through `controller_axis`, including
`Left_X`, `Left_Y`, `Right_X`, `Right_Y`, `Left_Trigger`, and `Right_Trigger`.
Raylib gamepad polling is provided; Steam Input action sets and Steam-specific
glyph APIs are outside orui's scope.

`begin_with_input` preserves the current pixel coordinate behavior. The
responsive variant is described below.

## Focus, activation and navigation

Any custom control that should be reachable from a keyboard or controller
must set:

```odin
focusable = true
```

Built-in interactive widgets set this automatically. Focus is identified by
the element's stable `Id` and is retained across immediate-mode frames.

Navigation behavior:

- `Tab` and `Shift+Tab` move through focusable elements in declaration order.
- Arrow keys and the controller D-pad use spatial navigation.
- The left stick produces directional navigation when it crosses its deadzone.
- `Enter`, `Space`, and controller `South` activate the focused element.
- Disabled elements are skipped.
- Set `adjustable = true` for controls such as sliders that should receive
  directional input instead of moving focus.

A custom control can detect activation with:

```odin
orui.element(orui.id("custom"), {
    focusable = true,
})
if orui.activated() {
    perform_action()
}
orui.end_element()
```

The ID overloads are useful when the check is outside the declaration:

```odin
if orui.activated("custom") {
    perform_action()
}
```

Programmatic focus and activation are available through:

```odin
orui.set_focus(ctx, orui.to_id("search"))
orui.set_focus_string(ctx, "search")

orui.activate(ctx, orui.to_id("default button"))
orui.activate_string(ctx, "default button")
```

These calls can be made before `begin` to request an operation for the next
frame, or during the current frame before the target widget is declared.
A missing focus target is cleared when the next input snapshot is processed.

Escape and controller `East` generate one back request per frame:

```odin
if orui.back_pressed() {
    close_current_screen()
}
```

A nested widget can consume the request so that it does not reach the parent:

```odin
if orui.back_pressed() {
    orui.consume_back()
    popup_open = false
}
```

Keyboard shortcuts use the current input snapshot and are independent of
widget focus:

```odin
if orui.shortcut_pressed(.F5) {
    reload_data()
}
if orui.shortcut_down(.LEFT_CONTROL) && orui.shortcut_pressed(.S) {
    save()
}
```

## Declaring UI

### Element IDs

Every element should have a unique ID. You can create the ID in 3 ways:

```odin
// String:
orui.id("container") // String literals will be hashed at compile time.
orui.id(string_var)

// String + index:
orui.id("row", i)

// Int (fastest, no hashing):
orui.id(1000000)
```

`orui.id` should ALWAYS be called inside element declarations, because it has side effects. If you only want to generate an ID, use `to_id` instead:

```odin
orui.to_id("row", i)
```

### element(id, config, ..modifiers)

`element` is the basic building block of orui. It can be used to build anything that orui can render.

All elements declared after will be attached as children, until `end_element()` is called:

```odin
orui.element(orui.id("container"), config)

// children declared here

orui.end_element()
```

You can use this to build your own elements:

```odin
my_element :: proc(id: string) {
  orui.element(orui.id(id), {...})
  orui.label(orui.id(id, 1), ...)
  orui.end_element()
}

@(deferred_none=orui.end_element)
my_container :: proc(id: string) {
  orui.element(orui.id(id), {...})
}

{my_container("test")
  my_element("element 1")
}
```

### container(id, config, ..modifiers)

`container` is exactly like `element` except it automatically ends the element when it goes out of scope. You should not manually call `end_element()` for containers.

This means you must use curly braces to define the scope of the container:

```odin
{orui.container(orui.id("element ID"), config)
  // declare children inside curly brackets
}
```

Or if you prefer another style:
```odin
if (orui.container(orui.id("element ID"), config)) {
  // declare children
}
```

Make sure containers always have their own scope. In the following example, label 2's parent is container B, not container A.

```odin
{
  orui.container(orui.id("container A"), config)
  orui.label(orui.id("label 1"), label1, {}) // child of container A
  orui.container(orui.id("container B"), config) // new container is child of container A
  // all elements from here to end of scope will be children of container B
  orui.label(orui.id("label 2"), label1, {}) // child of container B
}
```

### label(id, text, config, ...modifiers)

A label element displays text.

Text will wrap by default. Set the `overflow` option if you want change this behaviour.

Make sure you define the font and font size in the element config.
If the font is not defined, it will fallback to the `default_font` on the orui context.

This element does not need the surrounding curly braces because it cannot hold child elements.

```odin
orui.label(orui.id("label"), "Hello world!", {
	font = &your_font,
	font_size = 16,
})
```

A label element can also be used as a button by changing its style when the user interacts with it:

```odin
if orui.label(orui.id("button"), "Button text", {
  background_color = orui.active() ? {100, 100, 100, 255} : orui.hovered() ? {120, 120, 120, 255} : {30, 30, 30, 255},
}) {
  // handle button click
}
```

### text_input(id, buffer, config, ...modifiers)

This element displays text, and also allows the user to click into it to focus on it, and edit the text.

A blinking caret is drawn using the element's `color`.

You must define a [`strings.Builder`](https://pkg.odin-lang.org/core/strings/#Builder) to hold the user input.

Text inputs can be single-line:

```odin
orui.text_input(orui.id("input"), &buffer, {
	overflow = .Visible,
	clip = {.Intersect, {}},
	scroll = orui.scroll(.Horizontal),
})
```

Or multi-line:

```odin
orui.text_input(orui.id("input"), &buffer, {
	overflow = .Wrap,
	scroll = orui.scroll(.Vertical),
})
```

For single-line text inputs, the Enter key will unfocus the input.

For multi-line text inputs, the Enter key will add a new line to the text.

You can use the `focused()` function to change styles when the element is focused.

```odin
orui.text_input(orui.id("input"), &buffer, {
	background_color = orui.focused() ? rl.WHITE : rl.LIGHTGRAY,
})
```

Text inputs also support a visual placeholder, a rune filter, a maximum rune
length, and Ctrl/Cmd undo/redo. Filtering applies to typed and pasted text.
The filter is an insertion filter, not whole-value validation, so applications
can still validate the completed value separately. `max_length` counts Unicode
runes. The application still owns the `strings.Builder`.

Undo history is kept per input ID in the context, stores caret and selection
state, and is cleared when a new edit is made after undo. Each low-level edit
currently creates an undo entry; history is capped at 64 entries and buffers
larger than 8192 bytes are not recorded. External mutations to the builder are
accepted as the new visible value but should be treated as a new application
baseline rather than an undoable edit.

```odin
only_digits :: proc(character: rune) -> bool {
	return character >= '0' && character <= '9'
}

orui.text_input(orui.id("pin"), &pin, {
	placeholder = "PIN",
	placeholder_color = {140, 145, 155, 255},
	text_filter = only_digits,
	max_length = 6,
})
```

### image(id, config, ...modifiers)

Display an image. Takes a pointer to a raylib Texture2D.

This element does not need the surrounding curly braces because it cannot hold child elements.

```odin
orui.image(orui.id("image"), &texture, {
	color = rl.WHITE, // optional tint
	texture_source = rl.Rectangle{}, // optional, draw part of the texture
	texture_fit = .Contain,
	align = .Center,
})
```

### scrollbar(parent_id, background_config, handle_config, index := 0)

Display a scrollbar for a scrolling container.

Note that this element takes very different parameters from the other widgets:

- parent_id: this should be the ID of the scrolling container that you want to draw a scrollbar for.
- background_config : this is the element config for the scrollbar background.
- handle_config: this is the element config for the scrollbar handle. The scrollbar handle will be a child of the scrollbar background and positioned relatively. The `direction` field will control the direction of the scrollbar.
- index: required if you have more than 1 scrollbar for a single container. Each scrollbar for the same container must have a unique index.

I recommend setting the scrolling container to be relatively positioned, the scrollbar to be an absolutely positioned child, and using the `placement` config to place the scrollbar.

For horizontal scrollbars, you MUST set a handle height. For vertical scrollbars, you MUST set a handle width.

orui will overwrite the handle width and relative x position if it's a horizontal scrollbar and vice versa for vertical scrollbars.

```odin
orui.scrollbar(orui.to_id("container id"), {
  position = {.Absolute, {-5, 0}},
  placement = placement(.Right, .Right),
  width = orui.fixed(6),
  height = orui.percent(0.9),
  corner_radius = corner(4),
  background_color = rl.BLACK,
}, {
  width = orui.percent(1),
  background_color = rl.LIGHTGRAY,
  corner_radius = corner(4),
})
```

### Smooth scrolling

Scrollable elements continue to use `scroll(.Vertical)`, `scroll(.Horizontal)`,
or `scroll(.Auto)`. Mouse-wheel input moves toward a target using
frame-rate-independent smoothing. Touch input follows the pointer after a
small movement threshold and carries velocity into inertial scrolling after
release. Pointer capture allows the gesture to continue outside the viewport.

```odin
{orui.container(orui.id("feed"), {
    width = orui.grow(), height = orui.grow(),
    scroll = orui.scroll(.Vertical),
    clip = {.Self, {}},
})}
```

Use these procedures for programmatic movement:

```odin
orui.scroll_to(orui.to_id("feed"), {0, 480})
// Keep the current position and animate toward the requested offset.
orui.scroll_to_smooth(orui.to_id("feed"), {0, 960})
// For a virtual list, reveal an item using the requested alignment.
orui.scroll_to_item(orui.to_id("feed"), 42, .Nearest)
```

`scroll_to` is immediate. `scroll_to_smooth` uses the same scroll physics as
wheel input. `scroll_to_item` accepts `.Nearest`, `.Start`, `.Center`, or
`.End`; `.Nearest` avoids moving an item that is already visible.

## Virtualized lists and tables

Virtualized views only require the caller to declare visible rows. The first
version uses a fixed row estimate, which is fast and predictable for controller
navigation. Declare rows with `virtual_list_item_config` so they receive their
virtual position and scroll with the viewport:

```odin
view := orui.begin_virtual_list(orui.id("games"), {
	width = orui.grow(), height = orui.grow(),
	scroll = orui.scroll(.Vertical),
}, {
	direction = .Vertical,
	item_count = len(games),
	item_extent = 52,
	overscan = 2,
})
for i := view.first; i < view.last; i += 1 {
	orui.label(orui.id(orui.virtual_list_item_id(view.id, i)), games[i].title,
		orui.virtual_list_item_config(view, i, {font_size = 18}))
}
orui.end_virtual_list()
```

`begin_virtual_table` uses the same visible-row model and provides explicit
column geometry through `virtual_table_cell_config`. The table primitive does
not create a header, sorting behavior, or cell contents automatically; declare
a header separately and use the returned column definitions when declaring
visible cells. Close a table with `end_virtual_list()`.

```odin
columns := []orui.TableColumn{
    {width = 96, title = "Name"},
    {width = 120, title = "Status"},
}
table := orui.begin_virtual_table(orui.id("processes"), {
    width = orui.grow(), height = orui.grow(),
    scroll = orui.scroll(.Vertical),
}, len(processes), 44, columns)
for row := table.list.first; row < table.list.last; row += 1 {
    orui.label(orui.id("name cell", row), processes[row].name,
        orui.virtual_table_cell_config(table, row, 0, {}))
    orui.label(orui.id("status cell", row), processes[row].status,
        orui.virtual_table_cell_config(table, row, 1, {}))
}
orui.end_virtual_list()
```

`virtual_list_item_id` is an index-based convenience ID. For data that can be
sorted, inserted, or filtered, use an application-owned stable ID for the row
and preserve selection/focus in the application model. `scroll_to` changes
position immediately, `scroll_to_smooth` animates toward an offset, and
`scroll_to_item` reveals a virtual row.

## Built-in widgets

The built-in widgets are immediate-mode procedures. Their application state
is passed by pointer and remains owned by the application:

```odin
orui.button(orui.id("save"), "Save", {})
orui.slider(orui.id("volume"), &volume, 0, 1, {})
orui.checkbox(orui.id("fullscreen"), "Fullscreen", &fullscreen, {})
orui.tabs(orui.id("pages"), {"Home", "Settings"}, &page, {})
orui.dropdown(orui.id("quality"), {"Low", "High"}, &quality, &quality_open, {})

if orui.dialog(orui.id("confirm"), "Delete file?", "This cannot be undone.", &dialog_open, {}) == .Confirmed {
    delete_file()
}
```

All widget calls take an `ElementConfig` before any optional modifiers. Pass
`{}` to use the theme and widget defaults.

### button(id, text, config, ..modifiers)

A focusable text button. It returns `true` for either a mouse click or
keyboard/controller activation. Its default appearance uses the theme's
normal, hover, active, focused, and disabled colors. Explicit colors in
`config` override those theme defaults.

```odin
if orui.button(orui.id("save"), "Save", {
    width = orui.fixed(120),
    height = orui.fixed(38),
}) {
    save()
}
```

### slider(id, value, low, high, config, ..modifiers)

A horizontal slider with a mouse-captured handle. `value` is clamped to the
provided range. When focused, left/right keys, D-pad, and left-stick
navigation adjust the value instead of moving focus.

```odin
if orui.slider(orui.id("volume"), &volume, 0, 1, {}) {
    audio_set_volume(volume)
}
```

### checkbox(id, text, checked, config, ..modifiers)

A focusable row containing a checkbox and label. It returns `true` when the
checked state changes. The checked state is rendered using the theme's
`selected` color.

```odin
if orui.checkbox(orui.id("fullscreen"), "Fullscreen", &fullscreen, {}) {
    set_fullscreen(fullscreen)
}
```

### tabs(id, labels, selected, config)

Creates a row of mutually exclusive, focusable buttons. `selected` is the
selected label index and the procedure returns `true` when it changes.

```odin
if orui.tabs(orui.id("pages"), {"Library", "Settings"}, &page, {}) {
    reload_page(page)
}
```

### dropdown(id, options, selected, open, config)

Creates a button and a relatively anchored popup list. It supports keyboard
and controller activation, click-outside closing, and Escape/controller-B
closing.

```odin
if orui.dropdown(
    orui.id("quality"),
    {"Low", "Medium", "High"},
    &quality,
    &quality_open,
    {},
) {
    set_quality(quality)
}
```

### dialog(id, title, message, open, config)

Creates a centered application-rendered modal with a backdrop, Cancel button,
and OK button. It returns `DialogResult.None`, `.Confirmed`, or `.Cancelled`.
The caller owns the `open` state; the dialog sets it to `false` after a button
or Escape/controller-B result.

```odin
switch orui.dialog(
    orui.id("confirm"),
    "Delete file?",
    "This cannot be undone.",
    &dialog_open,
    {},
) {
case .Confirmed:
    delete_file()
case .Cancelled:
    log_cancel()
}
```

For custom overlays, use `begin_popup` or `begin_modal`, declare normal
orui contents in the scope, and finish with `end_overlay()`. Modal overlays
block pointer input behind them, trap keyboard/controller focus, restore the
focus target when they close, and prioritize Escape/controller-B. Popups can
use the existing absolute placement and window-bounds configuration. The
existing `dropdown` and `dialog` helpers remain available for common cases.

```odin
if orui.begin_modal(orui.id("confirm modal"), modal_open, {}) {
	orui.label(orui.id("confirm title"), "Delete file?", {})
	if orui.button(orui.id("confirm yes"), "Delete", {}) {
		delete_file()
		modal_open = false
	}
	orui.end_overlay()
}
```

A popup uses the same scope API. It can be anchored to an existing element
with `position`, `placement`, and `bounds`:

```odin
if orui.begin_popup(orui.id("context menu"), menu_open, {
    position = {.Absolute, {}},
    placement = orui.placement(.BottomLeft, .TopLeft),
    bounds = {.Window, .Flip, 8},
    width = orui.fixed(220),
    layer = 100,
}) {
    if orui.button(orui.id("rename"), "Rename", {}) {
        rename_selected()
        menu_open = false
    }
    if orui.button(orui.id("delete"), "Delete", {}) {
        delete_selected()
        menu_open = false
    }
    orui.end_overlay()
}
```

Widgets are compositions of normal orui elements rather than separate
retained objects: buttons are labels, checkboxes are containers with child
labels, sliders contain a track and handle, and dialogs contain a backdrop,
panel, labels, and buttons.

## Theme and visual states

Themes are stored per `Context` rather than globally. This allows multiple UI
contexts to use different styles and keeps theme state isolated in tests and
separate screens.

```odin
Theme :: struct {
    button_background: rl.Color,
    button_hover:      rl.Color,
    button_active:     rl.Color,
    button_focused:    rl.Color,
    button_disabled:   rl.Color,
    selected:          rl.Color,
    track:             rl.Color,
    handle:            rl.Color,
    text:              rl.Color,
    text_disabled:     rl.Color,
    border:            rl.Color,
    focus_border:      rl.Color,
    dialog_backdrop:   rl.Color,
}
```

`orui.init(ctx)` installs `default_theme()`. Customize a copy and assign it
to the context:

```odin
theme := orui.default_theme()
theme.button_background = {35, 45, 60, 255}
theme.selected = {40, 120, 170, 255}
theme.focus_border = {255, 220, 100, 255}
orui.set_theme(ctx, theme)
```

The theme also exposes typed `StyleSet` role styles for buttons, text inputs,
lists, tables, popups, and dialogs. Set `style = .Button` (or another
`StyleRole`) on a custom element to use the corresponding state-aware style.
Legacy theme color fields remain supported. Explicit values in
`ElementConfig` override values supplied by a role style.

```odin
theme := orui.default_theme()
theme.metrics.touch_target = 48
theme.metrics.corner_radius = 6
theme.styles[int(orui.StyleRole.Button)].focused.background_color = {70, 110, 160, 255}
theme.styles[int(orui.StyleRole.Button)].focused.border_color = {255, 220, 100, 255}
orui.set_theme(ctx, theme)

orui.element(orui.id("custom control"), {
    style = .Button,
    width = orui.fixed(220), height = orui.fixed(48),
})
orui.end_element()
```

`ThemeMetrics.touch_target` is used as the minimum default size for built-in
controls. It does not force the size of custom elements that specify their own
dimensions.

The theme supplies defaults for built-in widgets. An explicit value in an
`ElementConfig` takes precedence. For example, setting
`background_color = rl.RED` prevents a button from selecting its theme
background for hover/focus states. This keeps custom controls possible while
making the default widgets consistent.

The built-in widgets use these states:

- **Hovered**: pointer is over the element.
- **Active**: pointer button is held on the element.
- **Focused**: element is the keyboard/controller focus target.
- **Disabled**: element is skipped by input and navigation.
- **Selected**: used by checkboxes, tabs, dropdown options, and selected UI.

For custom elements, use `hovered()`, `active()`, `focused()`,
`is_disabled(id)`, and your own selected state to resolve styles.

## Touch and pointer input

`InputState` keeps the existing mouse fields for compatibility and also accepts
up to `MAX_POINTERS` generalized pointers. The primary pointer drives normal
widgets; touch pointers additionally support tap, drag, pointer capture, and
inertial scrolling. `input_from_raylib()` populates the primary mouse/touch
pointer, while SDL or custom backends can fill `InputState.pointers` directly.

A touch release is treated as a click only when movement stays below the drag
threshold, preventing a list swipe from activating the row underneath it.
The primary pointer is used by normal widgets; additional active pointers are
available for application-specific gestures. `PointerInput` contains an ID,
kind (`.Mouse`, `.Touch`, `.Pen`, or `.Virtual`), position, delta, pressure,
and down/pressed/released transitions.

```odin
input: orui.InputState
input.pointer_count = 1
input.pointers[0] = {
    id = 0,
    kind = .Touch,
    position = touch_position,
    delta = touch_delta,
    pressure = 1,
    down = touch_down,
    pressed = touch_pressed,
    released = touch_released,
}
orui.begin_with_input(ctx, width, height, input)
```

Raylib touch points are converted by `input_from_raylib()`. Custom backends
must provide the transition fields themselves. Normal widgets currently use
the primary pointer; multi-touch gesture interpretation remains application
specific.

## Responsive scaling

`begin_responsive` uses a design viewport to scale declarative UI values for
different window sizes. The default design viewport is `1280x800`, which
matches the Steam Deck's logical resolution:

```odin
orui.begin_responsive(ctx, rl.GetScreenWidth(), rl.GetScreenHeight())
```

The scale is calculated as:

```text
min(actual_width / design_width, actual_height / design_height)
```

A custom design viewport can be supplied:

```odin
orui.begin_responsive(ctx, width, height, 1280, 800)
```

The input-injection equivalent is:

```odin
orui.begin_responsive_with_input(ctx, width, height, input, 1280, 800)
```

The responsive transform applies to declarative fixed values including:

- Fixed widths and heights
- Minimum and maximum sizes
- Padding, margin, borders, and gaps
- Corner radii
- Absolute and relative positions
- Manual clip rectangles
- Font sizes and letter spacing
- Grid track sizes

Percent, fit, and grow sizes keep their normal layout behavior. Runtime scroll
offsets are not rescaled because they are already stored in viewport pixels.
The original `begin(...)` API remains available and uses a scale of `1`.

The current renderer and scissor commands use logical screen coordinates. For
that reason, the catalog example does not enable Raylib's
`.WINDOW_HIGHDPI` flag. If an application enables HighDPI rendering, it must
also convert orui's logical clip rectangles to the physical render surface
when issuing scissor commands.

## Other functions

### hovered()

Returns true if the mouse is hovering over the current element. Should be used inside element declarations only:

```odin
orui.label(orui.id("label"), "Test", {
  background_color = orui.hovered() ? rl.RED : rl.BLACK
})
```

If you want to check the hover state of an element oustide of the element declaration, you can pass the element ID into the hovered function:

```odin
if orui.hovered("label") {
  // mouse is over the element
}
```

### active()

Returns true if the element is active (mouse down on the element). If the mouse moves off the element while the mouse is down, the element will become inactive.

```odin
orui.label(orui.id("label"), "Test", {
  background_color = orui.active() ? rl.RED : rl.BLACK
})
```

Same as the hover function, you can ask about a specific element by passing in the ID:

```odin
if orui.active("label") {
  // label is active
}
```

### clicked()

Returns true if the element has been clicked. A click is only triggered if the element was both hovered and active when the mouse was released. This means dragging the mouse off an element will cancel the click.

```odin
orui.label(orui.id("label"), "Test", {
  background_color = orui.clicked() ? rl.RED : rl.BLACK
})
```

You can ask about a specific element by passing in the ID:

```odin
if orui.clicked("label") {
  // label was clicked
}
```

### activated()

Returns true when the current element was activated by Enter, Space, or the
controller's `South` button. Unlike `clicked()`, activation does not require
pointer input.

```odin
if orui.activated() {
    submit_form()
}
```

The ID overloads are also available:

```odin
if orui.activated("submit") {
    submit_form()
}
```

### focused()

Returns true if the current element is currently focused and receives keyboard/controller input.

Only one element can be focused at a time.

Clicking outside of the element or focusing another element will unfocus the element.

You can ask about a specific element by passing in the ID:

```odin
if orui.focused("input element") {
  // is focused
}
```

### is_disabled(id)

Returns the resolved disabled state of an element from the previous frame.
This is useful when custom widgets need to choose their disabled appearance.

```odin
if orui.is_disabled(orui.to_id("save")) {
    // draw the disabled state
}
```

### captured()

Returns true if an element has captured mouse input. This means the left mouse button is currently held down, and until it's released, only the capturing element will handle mouse input.

This is useful for scrollbar/slider handles, moveable windows/dialogs, etc.

You can ask about a specific element by passing in the ID:

```odin
if orui.captured("some element") {
  // is capturing input
}
```

### cursor()

Returns a pointer cursor suggestion for the current mouse position. The suggestion uses the same disabled, layer, and blocking rules as hover.

If an element has pointer capture, that element's cursor remains the suggestion even when the pointer leaves its bounds.

Cursor hints must be assigned explicitly to each element.

The returned `Cursor` matches Raylib's `rl.MouseCursor` values. `.Unspecified` means orui has no opinion, while `.Default` is an explicit request for the platform's default cursor:

```odin
current_cursor := rl.MouseCursor.DEFAULT

// Each frame, after orui.begin():
cursor_hint := orui.cursor(ctx)
next_cursor := cursor_hint == .Unspecified ? rl.MouseCursor.DEFAULT : rl.MouseCursor(cursor_hint)
if next_cursor != current_cursor {
	rl.SetMouseCursor(next_cursor)
	current_cursor = next_cursor
}
```

You can ignore `.Unspecified`, map the suggestion to custom cursors, or combine it with world interaction, dragging, targeting, and other non-UI systems. The built-in text input and scrollbar widgets explicitly suggest `.IBeam` and `.Pointing_Hand`.

## Animation

Use `transition` when you have a boolean trigger:

```odin
orui.label(orui.id("button"), "Button", {
	// background transitions from white to light gray when hovered over
	background_color = orui.transition("background", orui.hovered(), rl.WHITE, rl.LIGHTGRAY),

	// border transitions from 1px to 3px when input is active
	border = orui.transition("border", orui.active(), orui.border(1), orui.border(3)),
})
```

You can also get only the transition factor and use it for multiple values:

```odin
// Be careful: this transition is owned by the surrounding element, NOT the label below it.
// Animation IDs should be unique within an element.
hover_t := orui.transition("button1 hover", orui.hovered())

orui.label(orui.id("button1"), "Button", {
	background_color = orui.lerp(rl.WHITE, rl.LIGHTGRAY, hover_t),
	padding = orui.lerp(orui.padding(8), orui.padding(12), hover_t),
})
```

`transition` is best for simple on/off animations: one trigger, one start/end value.

Use `animate` when a value has one final target, but that target might come from several states. Think of it as: choose where the value should end up, and let orui handle getting there smoothly.

This keeps multi-state styles easy. You can use normal logic to decide which state wins, then pass the final target to `animate`:

```odin
target_bg := rl.WHITE
if selected {
	target_bg = {210, 230, 255, 255}
}
if orui.hovered() {
	target_bg = rl.LIGHTGRAY
}

orui.label(orui.id("row", i), text, {
	background_color = orui.animate("background", target_bg),
})
```

You can customise the duration and easing for both `transition` and `animate`:

```odin
background_color = orui.animate("background", target_bg, 0.2, .Cubic_Out)
```

The easing is the Ease enum from odin's core:math/ease package.

Animation state is stored in the orui context and scoped to the current element ID. This means animation IDs only need to be unique inside the element where they are used.

You cannot use transition() and animate() outside of element declarations (for now).

## Element config

Each element can be configured with these fields:

### layout
```odin
Layout :: enum {
	Flex,  // Default. Automatically positions children.
	Grid,  // Position children within a grid with fixed number of columns and/or rows.
	None,  // Does not affect children positioning.
}
```

### direction

Set flex/grid layout direction, and scrollbar direction.

```odin
LayoutDirection :: enum {
	LeftToRight,  // Default
	TopToBottom,
}
```

### position

```odin
PositionType :: enum {
	// Default. Positioned by flex/grid parent. Don't use this if parent is not flex or grid.
	Auto,
	// Positioned relative to the closest ancestor with a non-auto position.
	Absolute,
	// Positioned relative to its parent's position.
	// When used in a flex/grid container, it will be relative to its Auto position.
	Relative,
	// Positioned relative to the root element (the screen).
	Fixed,
}

Position :: struct {
	type:  PositionType,
	value: rl.Vector2,
}
```

### placement

Placement controls how an element is positioned relative to its anchor element.

Values are between 0 and 1 where 0,0 is the top left and 1,1 is the bottom right of the element (no matter its size).

This only applies to non-auto positioned elements.

This is useful when you want to align a particular side of an element to a particular side of its parent or anchor element (eg. tooltips, dropdowns).

The anchor element of a relative element is its direct parent.

The anchor element of an absolute element is the closest ancestor with a non-auto position.

The anchor element of a fixed element is the root element.

```odin
Placement :: struct {
	// The anchor is the point on the parent that the element will be placed relative to.
	anchor: rl.Vector2,
	// The origin is the point on the element that will be placed at the specified position.
	origin: rl.Vector2,
}
```

### bounds

Control how a non-auto positioned element is kept within the window after placement.

Useful for keeping popovers within view (dropdowns, tooltips, etc).

```odin
BoundsTarget :: enum {
	None,
	Window,
}

BoundsMode :: enum {
	None,
	Shift,
	Squish,
	Flip,
}

Bounds :: struct {
	target:  BoundsTarget,
	mode:    BoundsMode,
	padding: f32,
}
```

- **Shift**: clamp the element inside the window bounds.
- **Squish**: limit the element size to the window bounds (only for flex elements), then clamp it if needed.
- **Flip**: flip the element to the opposite side on overflowing axes, then clamp it if needed.

### width and height

```odin
SizeType :: enum {
	Fit,      // Element will try to fit its children
	Grow,     // Element will try to take up all extra space
	Percent,  // Element will be a percentage size of its parent
	Fixed,    // Element size will be a fixed number of pixels
}
Size :: struct {
	type:  SizeType,
	value: f32,
	min:   f32,
	max:   f32,
}
```

### padding and margin

Define pixel padding/margin for each side of the element.

```odin
Edges :: struct {
	top:    f32,
	right:  f32,
	bottom: f32,
	left:   f32,
}
```

### border

Define the border width for each side of the element.

```odin
Edges :: struct {
	top:    f32,
	right:  f32,
	bottom: f32,
	left:   f32,
}
```

### gap

The space between child elements in pixels. Only used for elements with a flex or grid layout.

### align_main

Flex alignment along the main axis. Same as justify-content in css.

Main axis is the axis following the direction of the flex element.
If direction is `LeftToRight`, main axis is horizontal.
If direction is `TopToBottom`, main axis is vertical.

```odin
MainAlignment :: enum {
	Start,         // Align children to beginning of element
	End,           // Align children to end of element
	Center,        // Center the children
	SpaceBetween,  // Distribute children with equal space between them, no space at edges
	SpaceAround,   // Distribute children with equal space around each item
	SpaceEvenly,   // Distribute children with equal space between them and edges
}
```

### align_cross

Flex alignment along the cross axis. Same as align-items in css.

```odin
CrossAlignment :: enum {
	Start,   // Align children to beginning of element
	End,     // Align children to end of element
	Center,  // Center the children
}
```

### align_content

How wrapped lines/columns are distributed along the cross axis.
Same as align-content in css. Used when flex_wrap = .Wrap.

`gap` is applied between lines/columns.

Takes the same options as `align_main`.

### flex_wrap

Control how a flex container handles its child elements overflowing its size.

- **NoWrap**: child elements will not wrap, they will overflow the container and render outside of it. This is the default.
- **Wrap**: child elements will wrap to the next line/column.

**flex_wrap will only apply to LeftToRight flex elements.**

```odin
FlexWrap :: enum {
	NoWrap,
	Wrap,
}
```

### overflow

Control how an element handles its text overflowing its size.

- **Wrap**: overflowing text will wrap to the next line. This is the default.
- **Visible**: text will not wrap, it will overflow the container and render outside of it.

```odin
Overflow :: enum {
	Wrap,
	Visible,
}
```

### layer

Layer controls the render order of elements. Set this to ensure an element renders on top of or below other elements.

The root layer starts at layer 1. If you don't define the element's layer, it will be placed in the same layer as its parent.

Elements in the same layer are drawn in the order in which the elements were declared.

### clip

Control an element's clipping when being rendered.

Any content or children outside of an element's clip rectangle will be cut off and not rendered.

Set it to `Self` or `Intersect` to set a clip rectangle automatically using the element's size and position. The `rectangle` field is ignored.

Set it to `Manual` if you want to pass in a custom clip rectangle.

Set it to `None` to break out of an ancestor element's clip. The `rectangle` field is ignored.

```odin
Clip :: struct {
	type:      ClipType,
	rectangle: ClipRectangle,
}

ClipType :: enum {
	// Use parent clip
	Inherit,
	// Set clip to element position and size
	Self,
	// Set clip to element position and size, and intersect with parent clip
	Intersect,
	// Set clip to the provided rectangle
	Manual,
	// Do not clip the element
	None,
}
```

### cols, rows

Set the number of columns and rows for a grid layout. Only used if the layout is set to `.Grid`.

Both are REQUIRED for grid layouts.

### col_sizes, row_sizes

Defines the size of each column (width) and row (height). This is passed in as a slice of Size structs.

The slice length does not need to match your grid size. Any columns or rows that don't have a defined size will use the size of the last column/row.

This means if you want equal widths for all columns/rows, you only need to set the first column's size. For example:

```odin
orui.container(orui.id("grid"), {
	layout = .Grid,
	cols = 5,
	rows = 5,
	col_sizes = {orui.grow()},
	row_sizes = {orui.fixed(250)},
})
```

### col_gap, row_gap

Set the gap between columns and rows. If missing, defaults to the `gap` option.

### col_span, row_span

Set a cell to span multiple rows and columns.

### color

Foreground color given as a raylib Color. Used for text color if there is text, and texture tint if there is a texture.

### background_color

The background color of the element, given as a raylib Color.

If the alpha is 0, nothing is drawn. Default background color is invisible.

### border_color

The color of the border, given as a raylib Color.

If the alpha is 0, nothing is drawn. Default border color is invisible.

### corner_radius

The radius of each corner. Will be applied to both backgrounds and borders.

Does not apply to content (labels, images).

```odin
Corners :: struct {
	top_left:     f32,
	top_right:    f32,
	bottom_right: f32,
	bottom_left:  f32,
}
```

### has_text and text

If `text` is set, `has_text` should be set to true. The label element does this automatically.

If `text` is set, a raylib font must also be defined, and a font size.

### font

This is a raylib Font pointer. orui does not manage your fonts for you. It's up to you to pass the correct font pointer for your font size.

### font_size

Font size in pixels.

### letter_spacing and line_height

Control the letter spacing (pixels) and line height (multiplier) of the text.

Default value is 1 for both.

### texture

`texture` is a raylib Texture2D pointer.

### texture_source

Set this to draw a portion of the texture instead of the whole texture.

### texture_fit

Controls how the texture resizes to fit its container.

```odin
TextureFit :: enum {
	Fill,       // Image will be stretched or squashed to fill the container.
	Contain,    // Keeps its aspect ratio, and resizes to fit the container.
	Cover,      // Keeps its aspect ratio, and resizes to fill the container. Image may be clipped.
	None,       // Image is not resized.
	ScaleDown,  // Same as contain but only scales down, never up.
}
```

### align

Controls how the content is aligned. Only relevant for elements with an image or text. Does not affect children.

An array of two alignment values. The first value is the horizontal alignment, second value is vertical alignment.

```odin
ContentAlignment :: enum {
	Start,   // Align left/top
	Center,  // Align center
	End,     // Align right/bottom
}
```

### disabled, block, capture, cursor

These are mouse input options. If omitted, the element will inherit the values from its parent element.

Disabled: whether the element can be interacted with. If disabled, it won't ever receive the hovered or active states. Default value is False.

Block: whether the element will consume mouse interactions, block elements below it from receiving them. Default value is True.

Capture: whether the element will consume interactions once they are activated. Recommended to be set to True for things like sliders and draggable windows. Default value is False.

```odin
InheritedBool :: enum {
	Inherit,
	False,
	True,
}
```

Set `focusable = true` for custom controls that should participate in Tab,
arrow-key, D-pad, or left-stick navigation. Set `adjustable = true` when a
control should receive directional navigation instead of moving focus; the
built-in slider uses this behavior.

Cursor hint: the element's desired pointer cursor. It inherits from the parent by default, so a button container can set `.Pointing_Hand` and its label and icon will use the same suggestion. Set `.Unspecified` to override an inherited cursor with no opinion.

```odin
CursorHint :: enum u8 {
	Inherit,
	Unspecified,
	Default,
	Pointing_Hand,
	IBeam,
	Crosshair,
	Resize_EW,
	Resize_NS,
	Resize_NWSE,
	Resize_NESW,
	Resize_All,
	Not_Allowed,
}
```

### scroll

Control how an element scrolls if its content is larger than its size. Text, flex child elements and grid columns/rows count towards content size. Images and grid column/row child elements do not.

You probably want to pair this together with the `clip` option.

The offset can be managed by orui or passed in manually. If you want to use the orui scroll position, call `scroll_offset()` to get the element's scroll position.

```odin
ScrollDirection :: enum {
	None,
	Auto,
	Vertical,   // Automatically handle mouse scroll events for vertical scrolling.
	Horizontal, // Automatically handle mouse scroll events for horizontal scrolling.
	Manual,     // Manually set scroll offset
}

ScrollConfig :: struct {
	direction: ScrollDirection,
	offset:    rl.Vector2,
}
```

### custom_event

Pass a pointer to your own custom event. See the `Custom render events` section.

### Config helpers

Config helpers can be used in the element config as a shortcut for common values:

```odin
orui.container(orui.id("container"), {
	// equal padding on all sides, equivalent to {5, 5, 5, 5}
	padding = orui.padding(5),
	// horizontal padding of 10, vertical padding of 5, equivalent to {5, 10, 5, 10}
	padding = orui.padding(10, 5),

	// equal margin on all sides, equivalent to {5, 5, 5, 5}
	margin = orui.margin(5),
	// horizontal margin of 10, vertical margin of 5, equivalent to {5, 10, 5, 10}
	margin = orui.margin(10, 5),

	// equal border width on all sides, equivalent to {2, 2, 2, 2}
	border = orui.border(2),

	// equal radius on all corners, equivalent to {5, 5, 5, 5}
	corner_radius = orui.corner(5),

	// fixed pixel size, equivalent to {.Fixed, 500, 0, 0}
	width/height = orui.fixed(500),

	// percent size, equivalent to {.Percent, 0.5, 0, 0}
	width/height = orui.percent(0.5),

	// fit size, equivalent to {.Fit, 0, 0, 0}
	width/height = orui.fit(),

	// grow size, equivalent to {.Grow, weight, 0, 0}. Weight is optional
	width/height = orui.grow(weight),

  // anchor/origin, equivalent to {{0, 0}, {1, 1}}
	// aligns the bottom right of the element to the top left of its parent
	placement = orui.placement(.TopLeft, .BottomRight),

  // scroll managed by orui, equivalent to {.Vertical, scroll_offset()}
	scroll = orui.scroll(.Vertical),
})
```

### Config modifiers

The container and label also take optional config modifiers, which are functions with this signature:

```odin
ElementModifier :: proc(element: ^Element)
```

The modifiers will be called to configure the element further.

This can be useful for reusable styles:

```odin
error_style :: proc(element: ^Element) {
  element.background_color = rl.RED
  element.color = rl.WHITE
}

standard_sizing :: proc(element: ^Element) {
  element.padding = {5, 10, 5, 10}
  element.margin = {5, 10, 5, 10}
}

{
  orui.container(orui.id("container"), {}, error_style, standard_sizing)
  orui.label(orui.id("label"), "Something went wrong!", {}, error_style)
}
```

## Custom render events

This feature allows you to insert custom events into the render command queue, allowing you to run code when specific parts of the UI are rendered.

You can do this by setting the `custom_event` field on any element.

When that element gets rendered, it will emit a `RenderCommandDataCustom` after emitting other render commands for that element.

```odin
RenderCommandDataCustom :: struct {
	rectangle:    rl.Rectangle, // computed position/size of the element
	custom_event: rawptr,       // the custom event that you originally passed in
}
```

See `demo/window` for an example of custom render events.
