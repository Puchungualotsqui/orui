package orui

import "core:hash"
import "core:strings"
import rl "vendor:raylib"

Id :: distinct u32

Edges :: struct {
	top:    f32,
	right:  f32,
	bottom: f32,
	left:   f32,
}

Corners :: struct {
	top_left:     f32,
	top_right:    f32,
	bottom_right: f32,
	bottom_left:  f32,
}

SizeType :: enum u8 {
	// Element uses its content size as its final size.
	// Only used by children of Flex and Grid layouts.
	Fit,
	// Element uses its content size as a preferred/base size,
	// then participates in flexible redistribution.
	// Only used by children of Flex and Grid layouts.
	Grow,
	// Element is a percentage of its parent's size.
	Percent,
	// Element is a fixed pixel size.
	Fixed,
}

Size :: struct {
	type:  SizeType,
	value: f32,
	min:   f32,
	max:   f32,
}

PositionType :: enum u8 {
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

Placement :: struct {
	// The anchor is the point on the parent that the element will be placed relative to.
	anchor: rl.Vector2,
	// The origin is the point on the element that will be placed at the specified position.
	origin: rl.Vector2,
}

BoundsTarget :: enum u8 {
	None,
	Window,
}

BoundsMode :: enum u8 {
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

Layout :: enum u8 {
	// Layout children next to each other
	Flex,
	// Layout children in columns and rows
	Grid,
	// Does not layout children
	None,
}

// Only used for Flex layout
LayoutDirection :: enum u8 {
	LeftToRight,
	TopToBottom,
}

MainAlignment :: enum u8 {
	// Align children to beginning of element
	Start,
	// Align children to end of element
	End,
	// Center the children
	Center,
	// Distribute children with equal space between them, no space at edges
	SpaceBetween,
	// Distribute children with equal space around each item
	SpaceAround,
	// Distribute children with equal space between them and edges
	SpaceEvenly,
}

CrossAlignment :: enum u8 {
	// Align children to beginning of element
	Start,
	// Align children to end of element
	End,
	// Center the children
	Center,
}

ContentAlignment :: enum u8 {
	Start,
	Center,
	End,
}

FlexWrap :: enum u8 {
	NoWrap,
	Wrap,
}

InheritedBool :: enum u8 {
	Inherit,
	False,
	True,
}

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

Overflow :: enum u8 {
	// Content will be wrapped to fit in the element.
	Wrap,
	// Content will be visible outside of the element.
	// You might want to combine this with clip and/or scroll.
	Visible,
}

WhitespaceMode :: enum u8 {
	// Collapse sequences of spaces; typical for display text.
	Collapse,
	// Preserve all whitespace; typical for text input.
	Preserve,
}

TextureFit :: enum u8 {
	// Image will be stretched or squashed to fill the container.
	Fill,
	// Keeps its aspect ratio, and resizes to fit the container.
	Contain,
	// Keeps its aspect ratio, and resizes to fill the container. Image may be clipped.
	Cover,
	// Image is not resized.
	None,
	// Same as contain but only scale down, never up.
	ScaleDown,
}

ClipType :: enum u8 {
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

ClipRectangle :: struct {
	x:      i32,
	y:      i32,
	width:  i32,
	height: i32,
}

Clip :: struct {
	type:      ClipType,
	rectangle: ClipRectangle,
}

ScrollDirection :: enum u8 {
	None,
	Auto,
	// Automatically handle mouse scroll events for vertical scrolling.
	Vertical,
	// Automatically handle mouse scroll events for horizontal scrolling.
	Horizontal,
	// Manually set scroll offset
	Manual,
}

ScrollConfig :: struct {
	direction: ScrollDirection,
	offset:    rl.Vector2,
}

ElementConfig :: struct {
	// Determines how child elements are sized and positioned.
	layout:           Layout,
	// Determines the direction of child elements for Grid and Flex layouts.
	direction:        LayoutDirection,
	// Position type of the element.
	position:         Position,
	// How the element is positioned relative to its parent or anchor element.
	// Used for non-auto position types.
	placement:        Placement,
	// How the element is kept within its bounds after placement.
	// Used for non-auto position types.
	bounds:           Bounds,
	// How the element width is sized.
	width:            Size,
	// How the element height is sized.
	height:           Size,
	// Padding in pixels.
	// Padding is the space inside the element's border.
	padding:          Edges,
	// Margin in pixels.
	// Margin is the space outside the element's border.
	margin:           Edges,
	// Border width in pixels.
	border:           Edges,
	// Gap between child elements in pixels.
	// Only used for Flex and Grid layouts.
	gap:              f32,
	// How child elements are aligned along the main axis.
	// Equivalent to justify-content in css.
	align_main:       MainAlignment,
	// How child elements are aligned along the cross axis.
	// Equivalent to align-items in css.
	align_cross:      CrossAlignment,
	// How wrapped lines/columns are distributed along the cross axis.
	// Equivalent to align-content in css. Used when flex_wrap = .Wrap.
	align_content:    MainAlignment,
	// How child elements are wrapped along the main axis.
	flex_wrap:        FlexWrap,
	// How the element handles overflowing text content.
	overflow:         Overflow,
	// Control the render order of the element.
	// Inherited from parent by default.
	layer:            int,
	// How the element is clipped.
	// Inherited from parent by default.
	clip:             Clip,

	// Number of columns.
	// Only used for Grid layout.
	cols:             i32,
	// Size of each column.
	// If the size of a column is not provided, the last provided size is used.
	col_sizes:        []Size,
	// Number of rows.
	// Only used for Grid layout.
	rows:             i32,
	// Size of each row.
	// If the size of a row is not provided, the last provided size is used.
	row_sizes:        []Size,
	// Gap between columns in pixels.
	// If not provided, falls back to `gap`.
	col_gap:          f32,
	// Gap between rows in pixels.
	// If not provided, falls back to `gap`.
	row_gap:          f32,
	// How many columns this element should span.
	// Only used for Grid layout children.
	col_span:         i32,
	// How many rows this element should span.
	// Only used for Grid layout children.
	row_span:         i32,

	// Foreground color.
	// Used for text color if there is text, and texture tint if there is a texture.
	color:            rl.Color,
	// Background color.
	// If the alpha is 0, nothing is drawn.
	// Default background color is invisible.
	background_color: rl.Color,
	// Border color.
	// If the alpha is 0, nothing is drawn.
	// Default border color is invisible.
	border_color:     rl.Color,
	// Corner radius.
	// Will be applied to both backgrounds and borders.
	// Does not apply to content (labels, images).
	corner_radius:    Corners,

	// Must be true if this element has text.
	has_text:         bool,
	// The string to render.
	text:             string,
	// The font family to use for the text.
	font:             ^rl.Font,
	// The font size to use for the text.
	font_size:        f32,
	// The space between letters in pixels.
	letter_spacing:   f32,
	// The line height multiplier. Default is 1.
	line_height:      f32,
	// How whitespace is handled when measuring and wrapping text.
	whitespace:       WhitespaceMode,
	text_input:       ^strings.Builder,

	// The texture to use for the element.
	texture:          ^rl.Texture2D,
	// The source rectangle of the texture that you want to draw.
	texture_source:   rl.Rectangle,
	// How the texture should be resized to fit the element size.
	texture_fit:      TextureFit,

	// How the content (text, image) should be aligned within the element.
	align:            [2]ContentAlignment,

	// Whether the element can be interacted with. Inherited from parent by default.
	disabled:         InheritedBool,
	// Whether keyboard/controller navigation may focus this element.
	focusable:        bool,
	// Whether directional navigation should be delivered to this element.
	adjustable:       bool,
	// Whether the element will consume mouse interactions, blocking elements below it from receiving them.
	// Inherited from parent by default.
	block:            InheritedBool,
	// Whether the element will consume interactions once they are activated.
	// Recommended to be set to True for things like sliders and draggable windows.
	// Inherited from parent by default.
	capture:          InheritedBool,
	// Pointer cursor intent for this element. Inherited from parent by default.
	// Unspecified means ORUI has no opinion about the pointer cursor.
	cursor:           CursorHint,
	editable:         bool,

	// Scroll configuration
	scroll:           ScrollConfig,

	// Emit a custom event in the render command array for this element.
	// Can be used to interleave your own rendering with orui's rendering.
	custom_event:     rawptr,
}

Element :: struct {
	id:                Id,
	parent:            i32,
	children:          i32,
	next:              i32,
	children_count:    i32,

	// layout
	layout:            Layout,
	direction:         LayoutDirection,
	position:          Position,
	placement:         Placement,
	bounds:            Bounds,
	width:             Size,
	height:            Size,
	padding:           Edges,
	margin:            Edges,
	border:            Edges,
	gap:               f32,
	align_main:        MainAlignment,
	align_cross:       CrossAlignment,
	align_content:     MainAlignment,
	flex_wrap:         FlexWrap,
	overflow:          Overflow,
	layer:             int,
	clip:              Clip,

	// grid
	cols:              i32,
	col_sizes:         []Size,
	rows:              i32,
	row_sizes:         []Size,
	col_gap:           f32,
	row_gap:           f32,
	col_span:          i32,
	row_span:          i32,

	// style
	color:             rl.Color,
	background_color:  rl.Color,
	border_color:      rl.Color,
	corner_radius:     Corners,

	// text
	has_text:          bool,
	text:              string,
	font:              ^rl.Font,
	font_size:         f32,
	letter_spacing:    f32,
	line_height:       f32,
	whitespace:        WhitespaceMode,
	text_input:        ^strings.Builder,

	// texture
	texture:           ^rl.Texture2D,
	texture_source:    rl.Rectangle,
	texture_fit:       TextureFit,

	// content layout
	align:             [2]ContentAlignment,

	// input
	disabled:          InheritedBool,
	focusable:         bool,
	adjustable:        bool,
	block:             InheritedBool,
	capture:           InheritedBool,
	cursor:            CursorHint,
	editable:          bool,

	// scroll
	scroll:            ScrollConfig,

	// custom event
	custom_event:      rawptr,

	// internal
	_position:         rl.Vector2,
	_size:             rl.Vector2, // border box size
	_content_size:     rl.Vector2,
	_layer:            i32,
	_text_width:       f32,
	_line_count:       i32,
	_line_height:      f32,
	_flex_child_count: i32,
	_flex_sum_width:   f32,
	_flex_sum_height:  f32,
	_flex_max_width:   f32,
	_flex_max_height:  f32,
	_flags:            Element_Flags,
	_subtree_flags:    Element_Flags,
	_line:             i32,
	_grid_state:       i32,
	_grid_col_index:   i32,
	_grid_row_index:   i32,
	_clip:             ClipRectangle,
}

@(private)
configure_element :: proc(
	ctx: ^Context,
	element: ^Element,
	parent: Element,
	config: ElementConfig,
) {
	allocator := ctx.allocator[current_buffer(ctx)]
	scale := ctx.scale > 0 ? ctx.scale : 1

	// layout
	element.layout = config.layout
	element.direction = config.direction
	element.position = scaled_position(config.position, scale)
	element.placement = config.placement
	element.bounds = scaled_bounds(config.bounds, scale)
	element.width = scaled_size(config.width, scale)
	element.height = scaled_size(config.height, scale)
	element.padding = scaled_edges(config.padding, scale)
	element.margin = scaled_edges(config.margin, scale)
	element.border = scaled_edges(config.border, scale)
	element.gap = config.gap * scale
	element.align_main = config.align_main
	element.align_cross = config.align_cross
	element.align_content = config.align_content
	element.flex_wrap = config.flex_wrap
	element.overflow = config.overflow
	element.layer = config.layer
	element.clip = scaled_clip(config.clip, scale)

	// grid
	if element.layout == .Grid {
		element.cols = config.cols
		element.rows = config.rows

		col_sizes := min(int(config.cols), len(config.col_sizes))
		if col_sizes > 0 {
			element.col_sizes = make([]Size, col_sizes, allocator)
			for i in 0 ..< col_sizes {
				element.col_sizes[i] = scaled_size(config.col_sizes[i], scale)
			}
		}

		row_sizes := min(int(config.rows), len(config.row_sizes))
		if row_sizes > 0 {
			element.row_sizes = make([]Size, row_sizes, allocator)
			for i in 0 ..< row_sizes {
				element.row_sizes[i] = scaled_size(config.row_sizes[i], scale)
			}
		}

		buffer := current_buffer(ctx)
		slot := i32(len(ctx.grid_states[buffer]))
		append(&ctx.grid_states[buffer], GridState{})
		element._grid_state = slot

		state := &ctx.grid_states[buffer][slot]
		state.occupied = make([]bool, int(element.cols * element.rows), allocator)
		state.col_sizes = make([]f32, int(element.cols), allocator)
		state.col_offsets = make([]f32, int(element.cols), allocator)
		state.row_sizes = make([]f32, int(element.rows), allocator)
		state.row_offsets = make([]f32, int(element.rows), allocator)
		grid_state_init(element, state)
	}

	element.col_gap = config.col_gap * scale
	element.row_gap = config.row_gap * scale
	element.col_span = config.col_span
	element.row_span = config.row_span

	// style
	element.color = config.color
	element.background_color = config.background_color
	element.border_color = config.border_color
	element.corner_radius = scaled_corners(config.corner_radius, scale)

	// text
	element.has_text = config.has_text
	element.text = config.text
	element.font = config.font
	element.font_size = config.font_size * scale
	element.letter_spacing = config.letter_spacing * scale
	element.line_height = config.line_height
	element.whitespace = config.whitespace
	element.text_input = config.text_input

	// texture
	element.texture = config.texture
	element.texture_source = config.texture_source
	element.texture_fit = config.texture_fit

	// content layout
	element.align = config.align

	// input
	element.disabled = config.disabled == .Inherit ? parent.disabled : config.disabled
	element.focusable = config.focusable
	element.adjustable = config.adjustable
	element.block = config.block == .Inherit ? parent.block : config.block
	element.capture = config.capture == .Inherit ? parent.capture : config.capture
	element.cursor = config.cursor == .Inherit ? parent.cursor : config.cursor
	element.editable = config.editable

	// scroll
	// Scroll offsets are runtime state and are already in viewport pixels.
	element.scroll = config.scroll

	element.custom_event = config.custom_event
}

@(private)
scaled_size :: proc(size: Size, scale: f32) -> Size {
	result := size
	if size.type == .Fixed {
		result.value *= scale
	}
	if size.min > 0 {
		result.min *= scale
	}
	if size.max > 0 {
		result.max *= scale
	}
	return result
}

@(private)
scaled_edges :: proc(edges: Edges, scale: f32) -> Edges {
	return {edges.top * scale, edges.right * scale, edges.bottom * scale, edges.left * scale}
}

@(private)
scaled_corners :: proc(corners: Corners, scale: f32) -> Corners {
	return {
		corners.top_left * scale,
		corners.top_right * scale,
		corners.bottom_right * scale,
		corners.bottom_left * scale,
	}
}

@(private)
scaled_position :: proc(position: Position, scale: f32) -> Position {
	result := position
	result.value *= scale
	return result
}

@(private)
scaled_bounds :: proc(bounds: Bounds, scale: f32) -> Bounds {
	result := bounds
	result.padding *= scale
	return result
}

@(private)
scaled_clip :: proc(clip: Clip, scale: f32) -> Clip {
	result := clip
	if clip.type == .Manual {
		result.rectangle.x = i32(f32(clip.rectangle.x) * scale)
		result.rectangle.y = i32(f32(clip.rectangle.y) * scale)
		result.rectangle.width = i32(f32(clip.rectangle.width) * scale)
		result.rectangle.height = i32(f32(clip.rectangle.height) * scale)
	}
	return result
}

to_id :: proc {
	to_id_compiled,
	to_id_compiled_index,
	to_id_runtime,
	to_id_int,
	to_id_string_index,
	to_id_id_index,
}

to_id_compiled :: proc($S: string) -> Id {
	return Id(#hash(S, "fnv32a"))
}

to_id_compiled_index :: proc($S: string, #any_int index: int) -> Id {
	return Id(hash.fnv32a(transmute([]u8)S, u32(index)))
}

to_id_runtime :: proc(str: string) -> Id {
	return Id(hash.fnv32a(transmute([]u8)str))
}

to_id_string_index :: proc(str: string, #any_int index: int) -> Id {
	return Id(hash.fnv32a(transmute([]u8)str, u32(index)))
}

to_id_int :: proc(#any_int id: int) -> Id {
	return Id(id)
}

to_id_id_index :: proc(id: Id, #any_int index: int) -> Id {
	id_bytes := transmute([4]u8)id
	return Id(hash.fnv32a(id_bytes[:], u32(index)))
}
