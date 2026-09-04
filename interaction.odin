package orui

import "core:log"
import "core:math"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

// PointerKind lets applications distinguish mouse, touch, pen, and synthesized
// pointer input while normal widgets continue to use the primary pointer.
PointerKind :: enum u8 {
	Mouse,
	Touch,
	Pen,
	Virtual,
}

PointerInput :: struct {
	id:        int,
	kind:      PointerKind,
	position:  rl.Vector2,
	delta:     rl.Vector2,
	pressure:  f32,
	down:      bool,
	pressed:   bool,
	released:  bool,
}

OverlayKind :: enum u8 {
	None,
	Popup,
	Modal,
}

OverlayState :: struct {
	id:              Id,
	kind:            OverlayKind,
	previous_focus:  Id,
}

Style :: struct {
	color:            rl.Color,
	background_color: rl.Color,
	border_color:     rl.Color,
	border:           Edges,
	corner_radius:    Corners,
	padding:          Edges,
}

StyleSet :: struct {
	normal:   Style,
	hovered:  Style,
	active:   Style,
	focused:  Style,
	disabled: Style,
	selected: Style,
}

TextEditSnapshot :: struct {
	length:    int,
	bytes:     [TEXT_UNDO_BYTES]u8,
	caret:     int,
	selection: TextSelection,
}

TextHistory :: struct {
	id:          Id,
	undo:        [MAX_TEXT_HISTORY_ENTRIES]TextEditSnapshot,
	undo_count:  int,
	redo:        [MAX_TEXT_HISTORY_ENTRIES]TextEditSnapshot,
	redo_count:  int,
	last_buffer: ^strings.Builder,
}

MAX_TEXT_HISTORY_ENTRIES :: 64

ScrollAlignment :: enum u8 {
	Nearest,
	Start,
	Center,
	End,
}

VirtualListDirection :: enum u8 {
	Vertical,
	Horizontal,
}

VirtualListConfig :: struct {
	direction:       VirtualListDirection,
	item_count:      int,
	item_extent:     f32,
	overscan:        int,
}

VirtualList :: struct {
	id:          Id,
	direction:   VirtualListDirection,
	item_count:  int,
	item_extent: f32,
	overscan:    int,
	first:       int,
	last:        int,
	viewport:    ^Element,
}

TableColumn :: struct {
	width: f32,
	title: string,
}

VirtualTable :: struct {
	list:    VirtualList,
	columns: []TableColumn,
}

// Returns the persistent history slot for an input ID. The fixed-size storage
// keeps undo state out of the per-frame arenas and avoids allocations while
// editing. Entries larger than TEXT_UNDO_BYTES are not recorded.
@(private)
text_history :: proc(ctx: ^Context, id: Id) -> ^TextHistory {
	if ctx.input_trace {
		log.infof("[orui text] history scan begin id=%v slots=%v", id, len(ctx.text_histories))
	}
	free_slot: ^TextHistory = nil
	for i in 0 ..< len(ctx.text_histories) {
		history := &ctx.text_histories[i]
		if ctx.input_trace && i == 0 {
			log.infof("[orui text] history slot zero address reached id=%v", id)
		}
		if history.id == id {
			return history
		}
		if history.id == 0 && free_slot == nil {
			free_slot = history
		}
	}
	if free_slot != nil {
		if ctx.input_trace {
			log.infof("[orui text] history assign free slot id=%v", id)
		}
		// Do not assign `{id = id}` to the whole history here. TextHistory
		// contains two large fixed snapshot arrays, and that struct literal
		// creates a large temporary on the stack during the first edit.
		free_slot.id = id
	}
	if ctx.input_trace {
		log.infof("[orui text] history scan end id=%v found=%v", id, free_slot != nil)
	}
	return free_slot
}

@(private)
copy_text_snapshot :: proc(snapshot: ^TextEditSnapshot, element: ^Element, ctx: ^Context) -> bool {
	if element.text_input == nil || len(element.text_input.buf) > TEXT_UNDO_BYTES {
		return false
	}
	snapshot^ = {}
	snapshot.length = len(element.text_input.buf)
	if snapshot.length > 0 {
		for i := 0; i < snapshot.length; i += 1 {
			snapshot.bytes[i] = element.text_input.buf[i]
		}
	}
	snapshot.caret = ctx.caret_index
	snapshot.selection = ctx.text_selection
	return true
}

@(private)
record_text_edit :: proc(ctx: ^Context, element: ^Element) {
	if ctx.input_trace {
		log.infof("[orui text] history lookup id=%v", element.id)
	}
	history := text_history(ctx, element.id)
	if history == nil || element.text_input == nil {
		return
	}
	if history.undo_count == MAX_TEXT_HISTORY_ENTRIES {
		for i := 1; i < MAX_TEXT_HISTORY_ENTRIES; i += 1 {
			history.undo[i - 1] = history.undo[i]
		}
		history.undo_count -= 1
	}
	if ctx.input_trace {
		log.infof("[orui text] snapshot begin id=%v undo_count=%v len=%v", element.id, history.undo_count, len(element.text_input.buf))
	}
	if !copy_text_snapshot(&history.undo[history.undo_count], element, ctx) {
		if ctx.input_trace {
			log.infof("[orui text] snapshot skipped id=%v", element.id)
		}
		return
	}
	if ctx.input_trace {
		log.infof("[orui text] snapshot end id=%v", element.id)
	}
	history.undo_count += 1
	history.redo_count = 0
	history.last_buffer = element.text_input
}

@(private)
restore_text_snapshot :: proc(ctx: ^Context, element: ^Element, snapshot: ^TextEditSnapshot) {
	if element.text_input == nil {
		return
	}
	delete_range(element.text_input, 0, len(element.text_input.buf))
	if snapshot.length > 0 {
		insert_bytes(element.text_input, 0, string(snapshot.bytes[:snapshot.length]))
	}
	element.text = strings.to_string(element.text_input^)
	ctx.caret_index = clamp(snapshot.caret, 0, len(element.text_input.buf))
	ctx.text_selection = snapshot.selection
	ctx.caret_time = 0
	ensure_caret_visible(ctx, element, ctx.caret_index)
}

undo_text :: proc(ctx: ^Context, element: ^Element) -> bool {
	history := text_history(ctx, element.id)
	if history == nil || history.undo_count <= 0 {
		return false
	}
	current: TextEditSnapshot
	if !copy_text_snapshot(&current, element, ctx) {
		return false
	}
	if history.redo_count < MAX_TEXT_HISTORY_ENTRIES {
		history.redo[history.redo_count] = current
		history.redo_count += 1
	}
	history.undo_count -= 1
	restore_text_snapshot(ctx, element, &history.undo[history.undo_count])
	return true
}

redo_text :: proc(ctx: ^Context, element: ^Element) -> bool {
	history := text_history(ctx, element.id)
	if history == nil || history.redo_count <= 0 {
		return false
	}
	current: TextEditSnapshot
	if !copy_text_snapshot(&current, element, ctx) {
		return false
	}
	if history.undo_count < MAX_TEXT_HISTORY_ENTRIES {
		history.undo[history.undo_count] = current
		history.undo_count += 1
	}
	history.redo_count -= 1
	restore_text_snapshot(ctx, element, &history.redo[history.redo_count])
	return true
}

@(private)
rune_count :: proc(text: string) -> int {
	count := 0
	index := 0
	for index < len(text) {
		_, size := utf8.decode_rune(text[index:])
		index += max(size, 1)
		count += 1
	}
	return count
}

text_filter_accepts :: proc(element: ^Element, character: rune) -> bool {
	if element.text_filter != nil && !element.text_filter(character) {
		return false
	}
	if element.max_length > 0 && rune_count(element.text) >= element.max_length {
		return false
	}
	return true
}

// Begins a fixed-estimate virtual list. Only the returned [first, last) range
// should be declared by the caller. Rows are ordinary orui elements and can
// contain any existing widget.
begin_virtual_list :: proc(
	list_id: Id,
	config: ElementConfig,
	list: VirtualListConfig,
	loc := #caller_location,
) -> VirtualList {
	ctx := current_context
	element, parent := begin_element(list_id, loc)
	configure_element(ctx, element, parent^, config)
	element._virtualized = true
	element._virtual_item_count = i32(max(list.item_count, 0))
	element._virtual_item_extent = list.direction == .Vertical ? {0, list.item_extent} : {list.item_extent, 0}
	element._virtual_overscan = i32(max(list.overscan, 0))
	element.layout = .None
	if element.position.type == .Auto {
		element.position = {.Relative, {}}
	}
	if element.clip.type == .Inherit {
		element.clip = {.Self, {}}
	}
	if element.scroll.direction == .None {
		element.scroll.direction = list.direction == .Vertical ? .Vertical : .Horizontal
	}

	extent := max(list.item_extent, 1)
	scroll_offset := get_scroll_offset(element)
	viewport := list.direction == .Vertical ? element._size.y : element._size.x
	if viewport <= 0 {
		if previous := get_element(list_id); previous != nil {
			viewport = list.direction == .Vertical ? previous._size.y : previous._size.x
			scroll_offset = get_scroll_offset(previous)
		}
	}
	start_offset := list.direction == .Vertical ? scroll_offset.y : scroll_offset.x
	first := int(math.floor(max(start_offset, 0) / extent)) - max(list.overscan, 0)
	first = clamp(first, 0, max(list.item_count, 0))
	last := int(math.ceil((max(start_offset, 0) + max(viewport, 0)) / extent)) + max(list.overscan, 0)
	last = clamp(last, first, max(list.item_count, 0))
	if viewport <= 0 {
		// The first frame may not have resolved a grow/percent viewport yet.
		// Render all rows once so the next frame has a usable measurement.
		first, last = 0, max(list.item_count, 0)
	}

	if list.direction == .Vertical {
		element._virtual_content_size = {max(element._size.x, 0), extent * f32(max(list.item_count, 0))}
	} else {
		element._virtual_content_size = {extent * f32(max(list.item_count, 0)), max(element._size.y, 0)}
	}
	if ctx.input_trace {
		log.infof(
			"[orui virtual] frame=%v id=%v viewport=(%.1f, %.1f) content=(%.1f, %.1f) offset=(%.1f, %.1f) target=(%.1f, %.1f) range=[%v,%v)",
			ctx.frame,
			list_id,
			element._size.x,
			element._size.y,
			element._virtual_content_size.x,
			element._virtual_content_size.y,
			scroll_offset.x,
			scroll_offset.y,
			element._scroll_target.x,
			element._scroll_target.y,
			first,
			last,
		)
	}

	return {
		id = list_id,
		direction = list.direction,
		item_count = list.item_count,
		item_extent = extent,
		overscan = max(list.overscan, 0),
		first = first,
		last = last,
		viewport = element,
	}
}

end_virtual_list :: proc() {
	end_element()
}

// A table is a virtualized vertical list with explicit column geometry. The
// caller can declare visible rows with virtual_list_item_config and cells with
// virtual_table_cell_config. Keeping columns separate from row elements makes
// headers and horizontal scrolling inexpensive.
begin_virtual_table :: proc(
	table_id: Id,
	config: ElementConfig,
	item_count: int,
	row_height: f32,
	columns: []TableColumn,
	overscan := 2,
	loc := #caller_location,
) -> VirtualTable {
	list := begin_virtual_list(table_id, config, {
		direction = .Vertical,
		item_count = item_count,
		item_extent = row_height,
		overscan = overscan,
	}, loc)
	list.viewport.style = .Table
	return {list = list, columns = columns}
}

virtual_table_cell_config :: proc(
	table: VirtualTable,
	row: int,
	column: int,
	config: ElementConfig,
) -> ElementConfig {
	result := config
	result.virtual_item = {enabled = true, index = row}
	result.position = {.Absolute, {}}
	x: f32 = 0
	for i := 0; i < column && i < len(table.columns); i += 1 {
		x += table.columns[i].width
	}
	result.position.value = {x, f32(row) * table.list.item_extent}
	if column >= 0 && column < len(table.columns) {
		result.width = fixed(table.columns[column].width)
	}
	result.height = fixed(table.list.item_extent)
	return result
}

virtual_list_item_config :: proc(list: VirtualList, index: int, config: ElementConfig) -> ElementConfig {
	result := config
	result.virtual_item = {enabled = true, index = index}
	result.position = {.Absolute, {}}
	if list.direction == .Vertical {
		result.position.value.y = f32(index) * list.item_extent
		result.width = result.width.type == .Fit ? percent(1) : result.width
		result.height = fixed(list.item_extent)
	} else {
		result.position.value.x = f32(index) * list.item_extent
		result.width = fixed(list.item_extent)
		result.height = result.height.type == .Fit ? percent(1) : result.height
	}
	return result
}

virtual_list_item_id :: proc(list_id: Id, index: int) -> Id {
	return to_id(list_id, index + 1)
}

@(private)
update_scroll_physics :: proc(ctx: ^Context, elements: ^[MAX_ELEMENTS]Element) {
	dt := clamp(ctx.dt, 0.001, 0.1)
	for i: i32 = 1; i < ctx.element_count[previous_buffer(ctx)]; i += 1 {
		element := &elements[i]
		if element.scroll.direction == .None {
			continue
		}

		min_x, max_x := scroll_bounds_x(element)
		min_y, max_y := scroll_bounds_y(element)
		if element._scroll_target == {} && element.scroll.offset != {} {
			element._scroll_target = element.scroll.offset
		}
		element._scroll_target.x = clamp(element._scroll_target.x, min_x, max_x)
		element._scroll_target.y = clamp(element._scroll_target.y, min_y, max_y)

		if element._scroll_dragging {
			continue
		}

		if element._scroll_velocity != {} {
			element._scroll_target += element._scroll_velocity * 0.18
			element._scroll_velocity *= math.exp(-12 * dt)
			if abs(element._scroll_velocity.x) < 1 { element._scroll_velocity.x = 0 }
			if abs(element._scroll_velocity.y) < 1 { element._scroll_velocity.y = 0 }
		}
		element._scroll_target.x = clamp(element._scroll_target.x, min_x, max_x)
		element._scroll_target.y = clamp(element._scroll_target.y, min_y, max_y)

		factor := 1 - math.exp(-18 * dt)
		scroll := get_scroll_offset(element)
		scroll.x += (element._scroll_target.x - scroll.x) * factor
		scroll.y += (element._scroll_target.y - scroll.y) * factor
		if abs(element._scroll_target.x - scroll.x) < 0.05 { scroll.x = element._scroll_target.x }
		if abs(element._scroll_target.y - scroll.y) < 0.05 { scroll.y = element._scroll_target.y }
		element.scroll.offset = scroll
	}
}

// Requests a scroll position for an existing viewport. The request is
// clamped during layout and is applied immediately; use scroll_to_smooth for
// animated movement.
scroll_to :: proc(id: Id, offset: rl.Vector2) {
	_set_scroll_offset_id(id, offset)
}

@(private)
theme_style_for :: proc(ctx: ^Context, role: StyleRole, id: Id, disabled: bool) -> Style {
	if role == .None {
		return {}
	}
	style_set := ctx.theme.styles[int(role)]
	if disabled {
		return style_set.disabled
	}
	if active(id) {
		return style_set.active
	}
	if focused(id) {
		return style_set.focused
	}
	if hovered(id) {
		return style_set.hovered
	}
	return style_set.normal
}

scroll_to_item :: proc(list_id: Id, index: int, alignment: ScrollAlignment = .Nearest) {
	ctx := current_context
	if ctx.input_trace {
		log.infof(
			"[orui scroll] item request frame=%v list_id=%v index=%v alignment=%v",
			ctx.frame,
			list_id,
			index,
			alignment,
		)
	}
	for buffer in 0 ..< 2 {
		count := ctx.element_count[buffer]
		for i in 0 ..< count {
			element := &ctx.elements[buffer][i]
			if element.id != list_id || !element._virtualized {
				continue
			}
			if element._virtual_item_extent.y > 0 {
				viewport := inner_height(element)
				top := f32(index) * element._virtual_item_extent.y
				bottom := top + element._virtual_item_extent.y
				offset := get_scroll_offset(element)
				old_offset := offset
				switch alignment {
				case .Start:
					offset.y = top
				case .Center:
					offset.y = (top + bottom - viewport) / 2
				case .End:
					offset.y = bottom - viewport
				case .Nearest:
					if top < offset.y { offset.y = top }
					if bottom > offset.y + viewport { offset.y = bottom - viewport }
				}
				_set_scroll_offset_id(list_id, offset)
				if ctx.input_trace {
					log.infof(
						"[orui scroll] item vertical buffer=%v element=%v old=(%.1f,%.1f) new=(%.1f,%.1f) viewport=%.1f bounds=(%.1f,%.1f)",
						buffer,
						i,
						old_offset.x,
						old_offset.y,
						offset.x,
						offset.y,
						viewport,
						top,
						bottom,
					)
				}
			} else {
				viewport := inner_width(element)
				left := f32(index) * element._virtual_item_extent.x
				right := left + element._virtual_item_extent.x
				offset := get_scroll_offset(element)
				old_offset := offset
				switch alignment {
				case .Start:
					offset.x = left
				case .Center:
					offset.x = (left + right - viewport) / 2
				case .End:
					offset.x = right - viewport
				case .Nearest:
					if left < offset.x { offset.x = left }
					if right > offset.x + viewport { offset.x = right - viewport }
				}
				_set_scroll_offset_id(list_id, offset)
				if ctx.input_trace {
					log.infof(
						"[orui scroll] item horizontal buffer=%v element=%v old=(%.1f,%.1f) new=(%.1f,%.1f) viewport=%.1f bounds=(%.1f,%.1f)",
						buffer,
						i,
						old_offset.x,
						old_offset.y,
						offset.x,
						offset.y,
						viewport,
						left,
						right,
					)
				}
			}
			return
		}
	}
	if ctx.input_trace {
		log.infof("[orui scroll] item list not found frame=%v list_id=%v", ctx.frame, list_id)
	}
}

scroll_to_smooth :: proc(id: Id, offset: rl.Vector2) {
	ctx := current_context
	for buffer in 0 ..< 2 {
		count := ctx.element_count[buffer]
		for i in 0 ..< count {
			if ctx.elements[buffer][i].id == id {
				ctx.elements[buffer][i]._scroll_target = offset
				return
			}
		}
	}
}
