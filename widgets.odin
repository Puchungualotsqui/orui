package orui

import "core:log"
import "core:strings"
import rl "vendor:raylib"

@(deferred_none = end_element)
// An element that can contain children.
// Must have its own scope.
container :: proc(
	id: Id,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	for modifier in modifiers {
		modifier(element)
	}
	return true
}

// A text element that can be use to display text.
// This element cannot have children.
label :: proc(
	id: Id,
	text: string,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	element.layout = .None
	element.has_text = true
	element.text = text

	for modifier in modifiers {
		modifier(element)
	}

	if element.font == nil && current_context.default_font != {} {
		element.font = &current_context.default_font
	}

	end_element()

	return clicked()
}

// A text element that displays text and allows the user to edit it.
// This element cannot have children.
text_input :: proc(
	id: Id,
	text: ^strings.Builder,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	c := config
	if ctx.input_trace {
		log.infof(
			"[orui text] widget begin id=%v builder_nil=%v len=%v cap=%v focus_id=%v",
			id,
			text == nil,
			text != nil ? len(text.buf) : -1,
			text != nil ? cap(text.buf) : -1,
			ctx.focus_id,
		)
	}
	if text == nil {
		log.errorf("[orui text] widget aborted id=%v: text_input builder is nil", id)
		return false
	}
	c.style = c.style == .None ? .Text_Input : c.style
	if c.height.type == .Fit {
		c.height = fixed(max(ctx.theme.metrics.control_height, ctx.theme.metrics.touch_target))
	}
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, c)
	element.layout = .None
	element.has_text = true
	element.text_input = text
	element.text = string(text.buf[:])
	element.editable = true
	element.style = c.style
	element.focusable = true
	element.whitespace = .Preserve
	element.cursor = .IBeam

	for modifier in modifiers {
		modifier(element)
	}

	if element.font == nil && current_context.default_font != {} {
		element.font = &current_context.default_font
	}

	end_element()

	return current_context.prev_focus_id == id && current_context.focus_id != id
}

// An element that displays a texture.
// This element cannot have children.
image :: proc(
	id: Id,
	texture: ^rl.Texture2D,
	config: ElementConfig,
	modifiers: ..ElementModifier,
	loc := #caller_location,
) -> bool {
	ctx := current_context
	element, parent := begin_element(id, loc)
	configure_element(ctx, element, parent^, config)
	element.layout = .None
	element.texture = texture

	for modifier in modifiers {
		modifier(element)
	}

	end_element()

	return clicked()
}

scrollbar :: proc(
	parent: Id,
	config: ElementConfig,
	handle_config: ElementConfig,
	index := 0,
	loc := #caller_location,
) {
	ctx := current_context
	// Keep scrollbar IDs in their own namespace. Virtual-list items use
	// to_id(parent, item_index + 1), so deriving scrollbar IDs directly from
	// parent would collide with row 0/row 1 and corrupt their layout state.
	scrollbar_namespace := to_id("orui scrollbar", int(parent))
	background_id := to_id(scrollbar_namespace, (index * 2) + 1)
	handle_id := to_id(scrollbar_namespace, (index * 2) + 2)

	// scrollbar background
	background_element, background_parent := begin_element(id(background_id), loc)
	configure_element(ctx, background_element, background_parent^, config)
	background_element.clip = {.None, {}}
	background_element.capture = .True
	background_element.cursor = .Pointing_Hand

	scroll_percent, handle_percent := scrollbar_handle_params(parent)
	background_size := size(background_id)
	handle_size := handle_percent * background_size
	if ctx.input_trace {
		log.infof(
			"[orui scrollbar] parent=%v track=(%.1f, %.1f) percent=(%.3f, %.3f) handle=(%.1f, %.1f) handle_percent=(%.3f, %.3f)",
			parent,
			background_size.x,
			background_size.y,
			scroll_percent.x,
			scroll_percent.y,
			handle_size.x,
			handle_size.y,
			handle_percent.x,
			handle_percent.y,
		)
	}

	// scrollbar handle
	handle_element, handle_parent := begin_element(id(handle_id), loc)
	configure_element(ctx, handle_element, handle_parent^, handle_config)
	handle_element.layout = .None
	if handle_config.direction == .TopToBottom {
		handle_element.height = fixed(handle_size.y)
		y := scroll_percent.y * (background_size.y - handle_size.y)
		handle_element.position = {.Relative, {0, y}}
	} else {
		handle_element.width = fixed(handle_size.x)
		x := scroll_percent.x * (background_size.x - handle_size.x)
		handle_element.position = {.Relative, {x, 0}}
	}
	handle_element.block = .False
	handle_element.capture = .False
	end_element()

	// handle mouse events
	if captured(background_id) {
		scrollbar_background := get_element(background_id)
		scroll_container := get_element(parent)
		scroll_offset := scroll_container.scroll.offset

		if handle_config.direction == .TopToBottom {
			mouse_position := ctx.input.mouse_position.y
			relative_position :=
				mouse_position - scrollbar_background._position.y - handle_size.y / 2
			track_range := background_size.y - handle_size.y
			percent := track_range > 0 ? clamp(relative_position / track_range, 0, 1) : 0
			min_y, max_y := scroll_bounds_y(scroll_container)
			scroll_offset.y = min_y + percent * (max_y - min_y)
			set_scroll_offset(parent, scroll_offset)
		} else {
			mouse_position := ctx.input.mouse_position.x
			relative_position :=
				mouse_position - scrollbar_background._position.x - handle_size.x / 2
			track_range := background_size.x - handle_size.x
			percent := track_range > 0 ? clamp(relative_position / track_range, 0, 1) : 0
			min_x, max_x := scroll_bounds_x(scroll_container)
			scroll_offset.x = min_x + percent * (max_x - min_x)
			set_scroll_offset(parent, scroll_offset)
		}
	}

	end_element()
}

ThemeMetrics :: struct {
	control_height:     f32,
	touch_target:       f32,
	spacing_small:      f32,
	spacing_medium:     f32,
	spacing_large:      f32,
	corner_radius:      f32,
	focus_ring_width:   f32,
	scrollbar_width:    f32,
}

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
	// Typed role styles. The legacy color fields above remain supported and
	// are used to initialize these defaults.
	styles:            [7]StyleSet,
	metrics:           ThemeMetrics,
}

default_theme :: proc() -> Theme {
	theme: Theme = {
		button_background = {55, 65, 80, 255},
		button_hover = {75, 90, 110, 255},
		button_active = {40, 50, 65, 255},
		button_focused = {85, 105, 135, 255},
		button_disabled = {55, 55, 60, 180},
		selected = {55, 105, 155, 255},
		track = {45, 50, 60, 255},
		handle = {125, 170, 220, 255},
		text = rl.WHITE,
		text_disabled = {160, 160, 165, 255},
		border = {100, 110, 125, 255},
		focus_border = {150, 205, 255, 255},
		dialog_backdrop = {0, 0, 0, 150},
		metrics = {
			control_height = 38,
			touch_target = 44,
			spacing_small = 4,
			spacing_medium = 8,
			spacing_large = 16,
			corner_radius = 4,
			focus_ring_width = 2,
			scrollbar_width = 8,
		},
	}
	button_style: StyleSet = {
		normal = {color = theme.text, background_color = theme.button_background, border_color = theme.border},
		hovered = {color = theme.text, background_color = theme.button_hover, border_color = theme.border},
		active = {color = theme.text, background_color = theme.button_active, border_color = theme.border},
		focused = {color = theme.text, background_color = theme.button_focused, border_color = theme.focus_border},
		disabled = {color = theme.text_disabled, background_color = theme.button_disabled, border_color = theme.border},
		selected = {color = theme.text, background_color = theme.selected, border_color = theme.focus_border},
	}
	input_style: StyleSet = {
		normal = {color = theme.text, border_color = theme.border},
		focused = {color = theme.text, border_color = theme.focus_border},
		disabled = {color = theme.text_disabled, border_color = theme.border},
	}
	panel_style: StyleSet = {
		normal = {color = theme.text, background_color = theme.button_background, border_color = theme.border},
	}
	theme.styles[int(StyleRole.Button)] = button_style
	theme.styles[int(StyleRole.Text_Input)] = input_style
	theme.styles[int(StyleRole.List)] = panel_style
	theme.styles[int(StyleRole.Table)] = panel_style
	theme.styles[int(StyleRole.Popup)] = panel_style
	theme.styles[int(StyleRole.Dialog)] = panel_style
	return theme
}

set_theme :: proc(ctx: ^Context, theme: Theme) {
	ctx.theme = theme
}

// A focusable text button. It returns true for either a pointer click or a
// keyboard/controller activation.
button :: proc(
	widget_id: Id,
	text: string,
	config: ElementConfig,
	modifiers: ..ElementModifier,
) -> bool {
	ctx := current_context
	c := config
	c.focusable = true
	c.style = c.style == .None ? .Button : c.style
	if c.font_size == 0 {
		c.font_size = 16
	}
	if c.height.type == .Fit {
		c.height = fixed(max(ctx.theme.metrics.control_height, ctx.theme.metrics.touch_target))
	}
	if c.color == {} {
		c.color = (c.disabled == .True || is_disabled(widget_id)) ? ctx.theme.text_disabled : ctx.theme.text
	}
	if c.border == {} {
		c.border = border(1)
	}
	if c.border_color == {} {
		c.border_color = focused(widget_id) ? ctx.theme.focus_border : ctx.theme.border
	}
	if c.corner_radius == {} {
		c.corner_radius = corner(ctx.theme.metrics.corner_radius)
	}
	if c.cursor == .Inherit {
		c.cursor = .Pointing_Hand
	}
	if c.background_color == {} {
		if c.disabled == .True || is_disabled(widget_id) {
			c.background_color = ctx.theme.button_disabled
		} else if active(widget_id) {
			c.background_color = ctx.theme.button_active
		} else if focused(widget_id) {
			c.background_color = ctx.theme.button_focused
		} else if hovered(widget_id) {
			c.background_color = ctx.theme.button_hover
		} else {
			c.background_color = ctx.theme.button_background
		}
	}

	clicked := label(id(widget_id), text, c, ..modifiers)
	return clicked || activated(widget_id)
}

// A horizontal value slider. The value is clamped to [low, high].
slider :: proc(
	widget_id: Id,
	value: ^f32,
	low, high: f32,
	config: ElementConfig,
	modifiers: ..ElementModifier,
) -> bool {
	ctx := current_context
	c := config
	c.focusable = true
	c.adjustable = true
	c.capture = .True
	if c.width.type == .Fit {
		c.width = fixed(240)
	}
	if c.height.type == .Fit {
		c.height = fixed(max(ctx.theme.metrics.control_height * 0.65, ctx.theme.metrics.touch_target))
	}
	if c.background_color == {} {
		c.background_color = ctx.theme.track
	}
	if c.corner_radius == {} {
		c.corner_radius = corner(ctx.theme.metrics.corner_radius)
	}
	if c.cursor == .Inherit {
		c.cursor = .Resize_EW
	}
	if c.position.type == .Auto {
		c.position = {.Relative, {}}
	}

	old_value := value^
	minimum := min(low, high)
	maximum := max(low, high)
	if value^ < minimum {
		value^ = minimum
	}
	if value^ > maximum {
		value^ = maximum
	}

	id(widget_id)
	element(widget_id, c, ..modifiers)

	rect := bounding_rect(widget_id)
	if c.disabled != .True && !is_disabled(widget_id) && (captured(widget_id) ||
		(ctx.input.mouse_left_down && hovered(widget_id))) && rect.width > 0 {
		scale := ui_scale(ctx)
		logical_x := (ctx.input.mouse_position.x - rect.x) / scale
		logical_width := rect.width / scale
		t := clamp(logical_x / logical_width, 0, 1)
		value^ = minimum + (maximum - minimum) * t
	}
	if c.disabled != .True && !is_disabled(widget_id) && focused(widget_id) &&
		ctx.navigation_direction != 0 && maximum > minimum {
		step := (maximum - minimum) / 20
		if ctx.navigation_direction == 1 || ctx.navigation_direction == 3 {
			value^ = max(minimum, value^ - step)
		} else {
			value^ = min(maximum, value^ + step)
		}
	}

	t := maximum > minimum ? clamp((value^ - minimum) / (maximum - minimum), 0, 1) : 0
	logical_width := rect.width / ui_scale(ctx)
	handle_x := t * max(logical_width - 12, 0)
	{container(
			id(to_id(widget_id, 1)),
			{
				position = {.Absolute, {handle_x, 0}},
				width = fixed(12),
				height = grow(),
				background_color = focused(widget_id) ? ctx.theme.focus_border : ctx.theme.handle,
				corner_radius = corner(4),
				block = .False,
			},
		)}
	end_element()
	return value^ != old_value || activated(widget_id)
}

// A checkbox with a focusable row and a selected visual state.
checkbox :: proc(
	widget_id: Id,
	text: string,
	checked: ^bool,
	config: ElementConfig,
	modifiers: ..ElementModifier,
) -> bool {
	ctx := current_context
	c := config
	c.focusable = true
	c.width = c.width.type == .Fit ? fixed(220) : c.width
	c.height = c.height.type == .Fit ? fixed(max(ctx.theme.metrics.control_height, ctx.theme.metrics.touch_target)) : c.height
	c.cursor = c.cursor == .Inherit ? .Pointing_Hand : c.cursor
	changed := clicked(widget_id) || activated(widget_id)
	{container(id(widget_id), c, ..modifiers)
		{container(id(to_id(widget_id, 1)), {
				width = fixed(22), height = fixed(22),
				background_color = checked^ ? ctx.theme.selected : ctx.theme.button_background,
				border = border(1), border_color = ctx.theme.border,
				corner_radius = corner(4), disabled = .True,
			})
			label(id(to_id(widget_id, 2)), checked^ ? "✓" : "", {
				font_size = 16, color = ctx.theme.text, align = {.Center, .Center},
				width = grow(), height = grow(), disabled = .True,
			})
		}
		label(id(to_id(widget_id, 3)), text, {
				font_size = 16,
				color = c.disabled == .True ? ctx.theme.text_disabled : ctx.theme.text,
				width = grow(), height = grow(), align = {.Start, .Center}, disabled = .True,
			})
	}
	if changed && c.disabled != .True {
		checked^ = !checked^
		return true
	}
	return false
}

// A row of mutually exclusive tabs. Returns true when selected changes.
tabs :: proc(
	widget_id: Id,
	labels: []string,
	selected: ^int,
	config: ElementConfig,
) -> bool {
	ctx := current_context
	if len(labels) == 0 {
		return false
	}
	selected^ = clamp(selected^, 0, len(labels) - 1)
	changed := false
	c := config
	c.direction = .LeftToRight
	{container(id(widget_id), c)
		for label_text, i in labels {
			button_config: ElementConfig = {
				width = grow(), height = fit(), padding = padding(10, 6),
				background_color = i == selected^ ? ctx.theme.selected : {},
				color = ctx.theme.text,
			}
			if button(to_id(widget_id, i), label_text, button_config) {
				if selected^ != i {
					selected^ = i
					changed = true
				}
			}
		}
	}
	return changed
}

// A selectable popup list. It supports pointer, Tab/arrow focus navigation,
// Enter/controller activation, and Escape/B controller back.
dropdown :: proc(
	widget_id: Id,
	options: []string,
	selected: ^int,
	open: ^bool,
	config: ElementConfig,
) -> bool {
	ctx := current_context
	if len(options) == 0 {
		return false
	}
	selected^ = clamp(selected^, 0, len(options) - 1)
	changed := false
	was_open := open^
	label_text := options[selected^]
	outer_config := config
	outer_config.position = {.Relative, {}}
	outer_config.background_color = {}
	outer_config.border = {}
	outer_config.border_color = {}
	outer_config.height = fit()
	outer_id := to_id(widget_id, 0)
	popup_id := to_id(widget_id, 1)
	{container(id(outer_id), outer_config)
		if button(widget_id, label_text, config) {
			open^ = !open^
		}

		if open^ {
			if ctx.active_overlay_id != popup_id {
				ctx.overlay_previous_focus = ctx.focus_id
				ctx.active_overlay_id = popup_id
			}
		{container(id(popup_id), {
				position = {.Absolute, {}},
				overlay_kind = .Popup,
				placement = placement(.Bottom, .Top),
				bounds = {.Window, .Flip, 8},
				width = config.width.type == .Fixed ? config.width : fixed(240),
				layout = .Flex, direction = .TopToBottom, gap = 1,
				padding = padding(4), layer = 100,
			})
			for option, i in options {
				option_config: ElementConfig = {
					width = grow(), height = fit(),
					background_color = i == selected^ ? ctx.theme.selected : {},
				}
				if button(to_id(popup_id, i), option, option_config) {
					selected^ = i
					open^ = false
					changed = true
				}
			}
		}
	}
}
if was_open && back_pressed() {
		consume_back()
		open^ = false
	}
	if was_open && !back_pressed() && ctx.input.mouse_left_released &&
		!hovered(widget_id) && !hovered(popup_id) {
		open^ = false
	}
	return changed
}

DialogResult :: enum {
	None,
	Confirmed,
	Cancelled,
}

// A centered modal dialog. The caller owns the open state; the dialog consumes
// Escape/B and returns the action taken by its buttons.
dialog :: proc(
	widget_id: Id,
	title: string,
	message: string,
	open: ^bool,
	config: ElementConfig,
) -> DialogResult {
	if !open^ {
		return .None
	}
	ctx := current_context
	if ctx.active_overlay_id != widget_id {
		ctx.overlay_previous_focus = ctx.focus_id
		ctx.active_overlay_id = widget_id
	}
	result := DialogResult.None
	backdrop: ElementConfig = {
		position = {.Fixed, {}}, width = percent(1), height = percent(1),
		layout = .Flex, align_main = .Center, align_cross = .Center,
		background_color = ctx.theme.dialog_backdrop, layer = 1000,
		overlay_kind = .Modal,
		capture = .True,
	}
	{container(id(widget_id), backdrop)
		panel := config
		panel.position = {.Relative, {}}
		panel.width = panel.width.type == .Fit ? fixed(420) : panel.width
		panel.height = panel.height.type == .Fit ? fit() : panel.height
		panel.layout = .Flex
		panel.direction = .TopToBottom
		panel.padding = panel.padding == {} ? padding(20) : panel.padding
		panel.gap = panel.gap == 0 ? 12 : panel.gap
		panel.background_color = panel.background_color == {} ? ctx.theme.button_background : panel.background_color
		{container(id(to_id(widget_id, 1)), panel)
			label(id(to_id(widget_id, 2)), title, {font_size = 22, color = ctx.theme.text})
			label(id(to_id(widget_id, 3)), message, {
				font_size = 16, color = ctx.theme.text, width = grow(), overflow = .Wrap,
			})
			{container(id(to_id(widget_id, 4)), {
					direction = .LeftToRight, width = grow(), height = fit(),
					align_main = .End, gap = 8,
				})
				if button(to_id(widget_id, 5), "Cancel", {width = fit(), height = fit()}) {
					result = .Cancelled
				}
				if button(to_id(widget_id, 6), "OK", {
					width = fit(), height = fit(), background_color = ctx.theme.selected,
				}) {
					result = .Confirmed
				}
			}
		}
	}
	if back_pressed() {
		consume_back()
		result = .Cancelled
	}
	if result != .None {
		open^ = false
	}
	return result
}
