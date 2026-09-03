package orui

import "core:c"
import "core:log"

import "core:math/linalg"
import "core:strings"
import "core:unicode/utf8"
import rl "vendor:raylib"

MAX_INPUT_KEYS :: 512
MAX_GAMEPADS :: 4
MAX_GAMEPAD_BUTTONS :: 16
MAX_GAMEPAD_AXES :: 8

ControllerButton :: enum u8 {
	South,
	East,
	West,
	North,
	Back,
	Guide,
	Start,
	Left_Stick,
	Right_Stick,
	Left_Shoulder,
	Right_Shoulder,
	DPad_Up,
	DPad_Right,
	DPad_Down,
	DPad_Left,
}

ControllerAxis :: enum u8 {
	Left_X,
	Left_Y,
	Right_X,
	Right_Y,
	Left_Trigger,
	Right_Trigger,
}

ControllerInput :: struct {
	connected:       bool,
	buttons_down:    [MAX_GAMEPAD_BUTTONS]bool,
	buttons_pressed: [MAX_GAMEPAD_BUTTONS]bool,
	buttons_released:[MAX_GAMEPAD_BUTTONS]bool,
	axes:            [MAX_GAMEPAD_AXES]f32,
}

InputState :: struct {
	mouse_position:       rl.Vector2,
	mouse_left_down:      bool,
	mouse_left_pressed:   bool,
	mouse_left_released:  bool,
	mouse_wheel:          rl.Vector2,
	keys_down:            [MAX_INPUT_KEYS]bool,
	keys_pressed:         [MAX_INPUT_KEYS]bool,
	keys_repeated:        [MAX_INPUT_KEYS]bool,
	characters:           [32]rune,
	character_count:      int,
	clipboard_text:       string,
	controllers:          [MAX_GAMEPADS]ControllerInput,
	pointer_count:        int,
	pointers:             [MAX_POINTERS]PointerInput
}

input_from_raylib :: proc() -> InputState {
	input: InputState
	input.mouse_position = rl.GetMousePosition()
	input.mouse_left_down = rl.IsMouseButtonDown(.LEFT)
	input.mouse_left_pressed = rl.IsMouseButtonPressed(.LEFT)
	input.mouse_left_released = rl.IsMouseButtonReleased(.LEFT)
	input.mouse_wheel = rl.GetMouseWheelMoveV()
	input.pointer_count = 1
	touch_count := rl.GetTouchPointCount()
	touch_active := touch_count > 0 || raylib_touch_was_down
	if touch_active {
		touch_position := input.mouse_position
		if touch_count > 0 {
			touch_position = rl.GetTouchPosition(0)
		}
		input.pointers[0] = {
			id = 0,
			kind = .Touch,
			position = touch_position,
			down = touch_count > 0,
			pressed = touch_count > 0 && !raylib_touch_was_down,
			released = touch_count == 0 && raylib_touch_was_down,
		}
		input.pointer_count = int(min(touch_count, i32(MAX_POINTERS)))
		for i in 1 ..< input.pointer_count {
			input.pointers[i] = {
				id = i,
				kind = .Touch,
				position = rl.GetTouchPosition(i32(i)),
				down = true,
			}
		}
		raylib_touch_was_down = touch_count > 0
	} else {
		input.pointers[0] = {
			id = 0,
			kind = .Mouse,
			position = input.mouse_position,
			down = input.mouse_left_down,
			pressed = input.mouse_left_pressed,
			released = input.mouse_left_released,
		}
	}

	for i in 0 ..< MAX_INPUT_KEYS {
		key := rl.KeyboardKey(i)
		input.keys_down[i] = rl.IsKeyDown(key)
		input.keys_pressed[i] = rl.IsKeyPressed(key)
		input.keys_repeated[i] = rl.IsKeyPressedRepeat(key)
	}

	for char := rl.GetCharPressed(); char != 0 && input.character_count < len(input.characters); char = rl.GetCharPressed() {
		input.characters[input.character_count] = char
		input.character_count += 1
	}

	for gamepad_index in 0 ..< MAX_GAMEPADS {
		gamepad := c.int(gamepad_index)
		controller := &input.controllers[gamepad_index]
		controller.connected = rl.IsGamepadAvailable(gamepad)
		if !controller.connected {
			continue
		}
		for button_index in 0 ..< MAX_GAMEPAD_BUTTONS {
			button := rl.GamepadButton(button_index)
			controller.buttons_down[button_index] = rl.IsGamepadButtonDown(gamepad, button)
			controller.buttons_pressed[button_index] = rl.IsGamepadButtonPressed(gamepad, button)
			controller.buttons_released[button_index] = rl.IsGamepadButtonReleased(gamepad, button)
		}
		for axis_index in 0 ..< MAX_GAMEPAD_AXES {
			controller.axes[axis_index] = rl.GetGamepadAxisMovement(gamepad, rl.GamepadAxis(axis_index))
		}
	}

	return input
}

controller_button_down :: proc(input: InputState, button: ControllerButton, gamepad := 0) -> bool {
	if gamepad < 0 || gamepad >= MAX_GAMEPADS do return false
	return input.controllers[gamepad].buttons_down[int(button)]
}

controller_button_pressed :: proc(input: InputState, button: ControllerButton, gamepad := 0) -> bool {
	if gamepad < 0 || gamepad >= MAX_GAMEPADS do return false
	return input.controllers[gamepad].buttons_pressed[int(button)]
}

controller_button_released :: proc(input: InputState, button: ControllerButton, gamepad := 0) -> bool {
	if gamepad < 0 || gamepad >= MAX_GAMEPADS do return false
	return input.controllers[gamepad].buttons_released[int(button)]
}

controller_axis :: proc(input: InputState, axis: ControllerAxis, gamepad := 0) -> f32 {
	if gamepad < 0 || gamepad >= MAX_GAMEPADS do return 0
	return input.controllers[gamepad].axes[int(axis)]
}

TEXT_MULTI_CLICK_TIME: f64 : 0.5
TEXT_MULTI_CLICK_DISTANCE: f32 : 6

@(thread_local)
raylib_touch_was_down: bool

@(private)
handle_input_state :: proc(ctx: ^Context) {
	current := current_buffer(ctx)
	previous := previous_buffer(ctx)
	// processing previous frame's elements
	// input runs at the start of the frame, before the current frame's elements are declared
	// previous elements are the latest available state of the elements
	elements := &ctx.elements[previous]

	sync_focus_element(ctx)

	// The primary pointer preserves the existing mouse API while allowing
	// applications to provide touch/pen input through InputState.
	if ctx.input.pointer_count > 0 {
		pointer := &ctx.input.pointers[0]
		ctx.input.mouse_position = pointer.position
		ctx.input.mouse_left_down = pointer.down
		ctx.input.mouse_left_pressed = pointer.pressed
		ctx.input.mouse_left_released = pointer.released
	}
	position := ctx.input.mouse_position
	mouse_down := ctx.input.mouse_left_down
	pressed := ctx.input.mouse_left_pressed
	released := ctx.input.mouse_left_released
	scroll := ctx.input.mouse_wheel
	pointer_kind := PointerKind.Mouse
	if ctx.input.pointer_count > 0 {
		pointer_kind = ctx.input.pointers[0].kind
	}

	ctx.prev_focus_id = ctx.focus_id
	ctx.hover[current].count = 0
	ctx.active[current].count = 0
	ctx.pointer_blocker_id = 0
	ctx.pointer_cursor = .Unspecified

	was_captured := ctx.pointer_capture != 0
	captured_index := ctx.pointer_capture
	if released {
		// Keep the capture alive through this release so click/drag state is
		// delivered to the owner even when the pointer left its bounds.
		if ctx.focus != 0 && ctx.caret_index == -1 {
			ctx.caret_index = text_caret_from_point(ctx, &elements[ctx.focus], position)
		}
	}

	// if ctx.pointer_capture != 0 && mouse_down {
	// 	el := &elements[ctx.pointer_capture]
	// 	count := ctx.active[current].count
	// 	ctx.active[current].ids[count] = el.id
	// 	ctx.active[current].count += 1
	// 	return
	// }

	scroll_consumed := false
	click_consumed := false

	for i := ctx.sorted_count - 1; i >= 0; i -= 1 {
		element := &elements[ctx.sorted[i]]

		if captured_index != 0 && captured_index != ctx.sorted[i] {
			continue
		}

		if element.disabled == .True {
			continue
		}

		// pointer capture owns the cursor even when the pointer leaves the capturing element
		if ctx.pointer_capture != 0 && element.cursor != .Inherit {
			ctx.pointer_cursor = element.cursor
		}

		if captured_index == 0 && !point_in_element(position, element) {
			continue
		}

		if !scroll_consumed {
			if scroll.x != 0 && scrolls_x(element) {
				old := get_scroll_offset(element).x
				element._scroll_target.x = old - scroll.x * SCROLL_FACTOR
				min_x, max_x := scroll_bounds_x(element)
				element._scroll_target.x = clamp(element._scroll_target.x, min_x, max_x)
				if element.block == .True && element._scroll_target.x != old {
					scroll_consumed = true
				}
			}
			if scroll.y != 0 && scrolls_y(element) {
				old := get_scroll_offset(element).y
				element._scroll_target.y = old - scroll.y * SCROLL_FACTOR
				min_y, max_y := scroll_bounds_y(element)
				element._scroll_target.y = clamp(element._scroll_target.y, min_y, max_y)
				if element.block == .True && element._scroll_target.y != old {
					scroll_consumed = true
				}
			}
		}

		if pointer_kind == .Touch && (scrolls_x(element) || scrolls_y(element)) {
			if pressed {
				ctx.pointer_dragging = false
				ctx.pointer_down_position = position
				element._scroll_dragging = true
				element._scroll_last_pointer = position
				ctx.pointer_capture = ctx.sorted[i]
				ctx.pointer_capture_id = element.id
				ctx.pointer_capture_kind = .Touch
			}
			if element._scroll_dragging && mouse_down {
				if linalg.distance(position, ctx.pointer_down_position) >= 6 {
					ctx.pointer_dragging = true
				}
				if !ctx.pointer_dragging {
					continue
				}
				delta := position - element._scroll_last_pointer
				scroll_offset := get_scroll_offset(element)
				if scrolls_x(element) { scroll_offset.x -= delta.x }
				if scrolls_y(element) { scroll_offset.y -= delta.y }
				element._scroll_velocity = -delta / max(ctx.dt, 0.001)
				min_x, max_x := scroll_bounds_x(element)
				min_y, max_y := scroll_bounds_y(element)
				scroll_offset.x = clamp(scroll_offset.x, min_x, max_x)
				scroll_offset.y = clamp(scroll_offset.y, min_y, max_y)
				element.scroll.offset = scroll_offset
				element._scroll_target = scroll_offset
				element._scroll_last_pointer = position
			}
			if released { element._scroll_dragging = false }
		}

		if !click_consumed {
			hover_count := ctx.hover[current].count
			ctx.hover[current].ids[hover_count] = element.id
			ctx.hover[current].count += 1

			if ctx.pointer_cursor == .Unspecified &&
			   element.cursor != .Inherit &&
			   element.cursor != .Unspecified {
				ctx.pointer_cursor = element.cursor
				if ctx.input_trace && (pressed || released) {
					log.infof(
						"[orui cursor] hit element_id=%v cursor=%v block=%v",
						element.id,
						element.cursor,
						element.block,
					)
				}
			}

			already_active := false
			for active_index: i32 = 0;
			    active_index < ctx.active[previous].count;
			    active_index += 1 {
				if ctx.active[previous].ids[active_index] == element.id {
					already_active = true
					break
				}
			}

			if mouse_down && (pressed || already_active) {
				active_count := ctx.active[current].count
				ctx.active[current].ids[active_count] = element.id
				ctx.active[current].count += 1

				if pressed {
					if element.focusable {
						ctx.focus = ctx.sorted[i]
						ctx.focus_id = element.id
					}
					if element.editable {
						if ctx.focus == ctx.sorted[i] &&
						   (ctx.selecting ||
							   key_down(ctx, .LEFT_SHIFT) ||
							   key_down(ctx, .RIGHT_SHIFT)) {
							// handle text selection with drag or shift click
							ctx.text_selection_mode = .Character
							ctx.text_selection.end = text_caret_from_point(ctx, element, position)
							ctx.caret_index = ctx.text_selection.end
							ctx.caret_time = 0
							ensure_caret_visible(ctx, element, ctx.caret_index)
						} else {
							ctx.focus = ctx.sorted[i]
							ctx.focus_id = element.id
							click_count := next_text_click_count(ctx, element.id, position)
							ctx.selecting = true
							start_text_click_selection(ctx, element, position, click_count)
						}
					} else if !element.focusable && ctx.focus != 0 {
						clear_focus(ctx)
					} else {
						clear_text_click_state(ctx)
					}
				}

				if element.capture == .True {
					ctx.pointer_capture = ctx.sorted[i]
					ctx.pointer_capture_id = element.id
				}
			}

			if element.block == .True {
				ctx.pointer_blocker_id = element.id
				click_consumed = true
			}
		}

		if scroll_consumed && click_consumed {
			break
		}
	}

	if ctx.selecting && mouse_down && ctx.focus != 0 {
		el := &elements[ctx.focus]
		update_text_drag_selection(ctx, el, position)
	}

	if ctx.input_trace && (pressed || released) {
		log.infof(
			"[orui cursor] pointer pressed=%v released=%v position=(%.1f, %.1f) cursor=%v focus_id=%v",
			pressed,
			released,
			position.x,
			position.y,
			ctx.pointer_cursor,
			ctx.focus_id,
		)
	}

	if released {
		ctx.selecting = false
		if was_captured {
			ctx.pointer_capture = 0
			ctx.pointer_capture_id = 0
			ctx.pointer_capture_kind = .Mouse
		}
	} else if !mouse_down {
		ctx.pointer_dragging = false
	}

	// Apply wheel targets and touch drag state before focus/navigation consumers
	// read the frame. The current tree will copy these runtime values when it is
	// declared.
	update_scroll_physics(ctx, elements)
	handle_focus_navigation(ctx, elements)
	if ctx.input_trace && ctx.input.character_count > 0 {
		log.infof(
			"[orui input] dispatch frame=%v focus_index=%v focus_id=%v chars=%v caret=%v",
			ctx.frame,
			ctx.focus,
			ctx.focus_id,
			ctx.input.character_count,
			ctx.caret_index,
		)
	}
	handle_keyboard_input(ctx)
}

@(private)
handle_focus_navigation :: proc(ctx: ^Context, elements: ^[MAX_ELEMENTS]Element) {
	if ctx.active_overlay_id != 0 {
		focused_in_scope := false
		if ctx.focus != 0 {
			focused_in_scope = overlay_contains(elements, ctx.focus, ctx.active_overlay_id)
		}
		if !focused_in_scope {
			for i: i32 = 1; i < ctx.element_count[previous_buffer(ctx)]; i += 1 {
				if elements[i].focusable && elements[i].disabled != .True &&
				   overlay_contains(elements, i, ctx.active_overlay_id) {
					ctx.focus = i
					ctx.focus_id = elements[i].id
					break
				}
			}
		}
	}
	ctx.back_requested =
		key_pressed(ctx, .ESCAPE) ||
		controller_button_pressed(ctx.input, .East)

		// Keyboard and controller navigation makes focus visible. Mouse focus is
		// still assigned above, so applications can style both consistently.
	tab := key_pressed(ctx, .TAB)
	shift := key_down(ctx, .LEFT_SHIFT) || key_down(ctx, .RIGHT_SHIFT)
	ctx.navigation_direction = 0
	if tab {
		move_focus_linear(ctx, elements, shift ? -1 : 1)
	} else {
		direction: i8 = 0
		axis_x := controller_axis(ctx.input, .Left_X)
		axis_y := controller_axis(ctx.input, .Left_Y)
		axis_pressed_left := axis_x < -0.6 && ctx.navigation_axis[0] >= -0.6
		axis_pressed_right := axis_x > 0.6 && ctx.navigation_axis[0] <= 0.6
		axis_pressed_up := axis_y < -0.6 && ctx.navigation_axis[1] >= -0.6
		axis_pressed_down := axis_y > 0.6 && ctx.navigation_axis[1] <= 0.6
		ctx.navigation_axis = {axis_x, axis_y}
		if key_pressed(ctx, .LEFT) || controller_button_pressed(ctx.input, .DPad_Left) || axis_pressed_left {
			direction = 1
		} else if key_pressed(ctx, .RIGHT) || controller_button_pressed(ctx.input, .DPad_Right) || axis_pressed_right {
			direction = 2
		} else if key_pressed(ctx, .UP) || controller_button_pressed(ctx.input, .DPad_Up) || axis_pressed_up {
			direction = 3
		} else if key_pressed(ctx, .DOWN) || controller_button_pressed(ctx.input, .DPad_Down) || axis_pressed_down {
			direction = 4
		}
		if direction != 0 {
			current_index, found := element_index_by_id(ctx, previous_buffer(ctx), ctx.focus_id)
			// Text fields own arrow keys for caret movement. In particular,
			// do not move focus away from a single-line input on Up/Down;
			// handle_keyboard_input will consume the keys below.
			if found && elements[current_index].editable {
				// Leave navigation_direction at zero for text editing.
			} else if found && elements[current_index].adjustable {
				ctx.navigation_direction = direction
			} else {
				move_focus_direction(ctx, elements, direction)
			}
		}
	}

	if (key_pressed(ctx, .ENTER) || key_pressed(ctx, .SPACE) ||
		controller_button_pressed(ctx.input, .South)) && ctx.focus_id != 0 {
		ctx.activated_id = ctx.focus_id
	}
}

@(private)
move_focus_linear :: proc(ctx: ^Context, elements: ^[MAX_ELEMENTS]Element, direction: int) {
	count := ctx.element_count[previous_buffer(ctx)]
	current_index: i32 = -1
	for i: i32 = 1; i < count; i += 1 {
		if elements[i].id == ctx.focus_id {
			current_index = i
			break
		}
	}

	if current_index < 0 {
		for i: i32 = 1; i < count; i += 1 {
			if elements[i].focusable && elements[i].disabled != .True &&
			   (ctx.active_overlay_id == 0 || overlay_contains(elements, i, ctx.active_overlay_id)) {
				ctx.focus = i
				ctx.focus_id = elements[i].id
				return
			}
		}
		return
	}

	for step := 1; step < int(count); step += 1 {
		candidate := int(current_index) + direction * step
		for candidate < 1 {
			candidate += int(count) - 1
		}
		for candidate >= int(count) {
			candidate -= int(count) - 1
		}
		item := &elements[candidate]
		if item.focusable && item.disabled != .True &&
		   (ctx.active_overlay_id == 0 || overlay_contains(elements, i32(candidate), ctx.active_overlay_id)) {
			ctx.focus = i32(candidate)
			ctx.focus_id = item.id
			return
		}
	}

}

@(private)
move_focus_direction :: proc(ctx: ^Context, elements: ^[MAX_ELEMENTS]Element, direction: i8) {
	count := ctx.element_count[previous_buffer(ctx)]
	current_index, found := element_index_by_id(ctx, previous_buffer(ctx), ctx.focus_id)
	if !found || current_index == 0 {
		move_focus_linear(ctx, elements, 1)
		return
	}

	current := &elements[current_index]
	current_center := current._position + current._size * 0.5
	best: i32 = -1
	best_score: f32 = 1e30
	for i: i32 = 1; i < count; i += 1 {
		candidate := &elements[i]
		if !candidate.focusable || candidate.disabled == .True || i == current_index ||
		   (ctx.active_overlay_id != 0 && !overlay_contains(elements, i, ctx.active_overlay_id)) {
			continue
		}
		center := candidate._position + candidate._size * 0.5
		dx := center.x - current_center.x
		dy := center.y - current_center.y
		primary: f32
		secondary: f32
		switch direction {
		case 1:
			if dx >= 0 do continue
			primary, secondary = -dx, abs(dy)
		case 2:
			if dx <= 0 do continue
			primary, secondary = dx, abs(dy)
		case 3:
			if dy >= 0 do continue
			primary, secondary = -dy, abs(dx)
		case 4:
			if dy <= 0 do continue
			primary, secondary = dy, abs(dx)
		}
		score := primary * 1000 + secondary
		if score < best_score {
			best_score = score
			best = i
		}
	}
	if best >= 0 {
		ctx.focus = best
		ctx.focus_id = elements[best].id
	}
}

@(private)
next_text_click_count :: proc(ctx: ^Context, id: Id, position: rl.Vector2) -> int {
	now := ctx.time
	within_distance :=
		linalg.distance(position, ctx.text_click_position) <= TEXT_MULTI_CLICK_DISTANCE
	within_time := now - ctx.text_click_time <= TEXT_MULTI_CLICK_TIME

	click_count := 1
	if ctx.text_click_id == id && within_time && within_distance {
		click_count = min(ctx.text_click_count + 1, 3)
	}

	ctx.text_click_id = id
	ctx.text_click_time = now
	ctx.text_click_position = position
	ctx.text_click_count = click_count
	return click_count
}

@(private)
clear_text_click_state :: proc(ctx: ^Context) {
	ctx.text_click_id = 0
	ctx.text_click_count = 0
	ctx.text_selection_mode = .Character
	ctx.text_selection_anchor = {}
}

@(private)
set_text_selection :: proc(
	ctx: ^Context,
	element: ^Element,
	selection: TextSelection,
	caret: int,
) {
	ctx.text_selection = selection
	ctx.caret_index = clamp(caret, 0, len(element.text_input.buf))
	ctx.caret_time = 0
	ensure_caret_visible(ctx, element, ctx.caret_index)
}

@(private)
start_text_click_selection :: proc(
	ctx: ^Context,
	element: ^Element,
	position: rl.Vector2,
	click_count: int,
) {
	if click_count <= 1 {
		caret := text_caret_from_point(ctx, element, position)
		selection := TextSelection{caret, caret}
		ctx.text_selection_mode = .Character
		ctx.text_selection_anchor = selection
		set_text_selection(ctx, element, selection, caret)
		return
	}

	index := text_index_from_point(ctx, element, position)
	selection: TextSelection
	if click_count == 2 {
		selection = text_word_range(element.text, index)
		ctx.text_selection_mode = .Word
	} else {
		selection = text_line_range(element.text, index)
		ctx.text_selection_mode = .Line
	}

	ctx.text_selection_anchor = selection
	set_text_selection(ctx, element, selection, selection.end)
}

@(private)
update_text_drag_selection :: proc(ctx: ^Context, element: ^Element, position: rl.Vector2) {
	switch ctx.text_selection_mode {
	case .Word:
		target := text_word_range(element.text, text_index_from_point(ctx, element, position))
		selection, caret := extend_text_selection(ctx.text_selection_anchor, target)
		set_text_selection(ctx, element, selection, caret)
	case .Line:
		target := text_line_range(element.text, text_index_from_point(ctx, element, position))
		selection, caret := extend_text_selection(ctx.text_selection_anchor, target)
		set_text_selection(ctx, element, selection, caret)
	case .Character:
		end := text_caret_from_point(ctx, element, position)
		ctx.text_selection.end = end
		ctx.caret_index = end
		ctx.caret_time = 0
		ensure_caret_visible(ctx, element, ctx.caret_index)
	}
}

@(private)
insert_input_character :: proc(ctx: ^Context, element: ^Element, char: rune) -> bool {
	if ctx.input_trace {
		input_length := element.text_input != nil ? len(element.text_input.buf) : -1
		log.infof(
			"[orui text] character begin id=%v rune=%v codepoint=%v caret=%v len=%v",
			element.id,
			char,
			int(char),
			ctx.caret_index,
			input_length,
		)
	}
	if element.text_input == nil {
		log.errorf("[orui text] character aborted id=%v: text_input builder is nil", element.id)
		return false
	}
	if char == '\r' {
		return true
	}
	if char == '\n' && element.overflow != .Wrap {
		return false
	}
	if char != '\n' && element.text_filter != nil {
		if ctx.input_trace {
			log.infof("[orui text] filter begin id=%v codepoint=%v", element.id, int(char))
		}
		accepted := element.text_filter(char)
		if ctx.input_trace {
			log.infof("[orui text] filter end id=%v accepted=%v", element.id, accepted)
		}
		if !accepted {
			return false
		}
	}
	if element.max_length > 0 {
		current_length := rune_count(element.text)
		if has_text_selection(ctx) {
			a, b := get_text_selection(ctx)
			current_length -= rune_count(element.text[a:b])
		}
		if current_length >= element.max_length {
			return false
		}
	}
	if ctx.input_trace {
		log.infof("[orui text] history begin id=%v", element.id)
	}
	record_text_edit(ctx, element)
	if ctx.input_trace {
		log.infof("[orui text] history end id=%v", element.id)
	}
	if has_text_selection(ctx) {
		ctx.caret_index = delete_text_selection(ctx, element)
	}
	char_bytes, char_len := utf8.encode_rune(char)
	bytes_inserted := insert_bytes(
		element.text_input,
		ctx.caret_index,
		string(char_bytes[:char_len]),
	)
	element.text = strings.to_string(element.text_input^)
	set_caret_index(ctx, element, ctx.caret_index + bytes_inserted)
	if ctx.input_trace {
		log.infof(
			"[orui text] character end id=%v inserted=%v caret=%v len=%v",
			element.id,
			bytes_inserted,
			ctx.caret_index,
			len(element.text_input.buf),
		)
	}
	return bytes_inserted > 0
}

@(private)
handle_keyboard_input :: proc(ctx: ^Context) {
	elements := &ctx.elements[previous_buffer(ctx)]
	if ctx.focus != 0 {
		element := &elements[ctx.focus]
		if key_pressed(ctx, .ESCAPE) {
			clear_focus(ctx)
		} else if element.editable && key_pressed(ctx, .ENTER) && element.overflow == .Visible {
			clear_focus(ctx)
		} else if element.editable {
			text_input := element.text_input
			if ctx.input_trace && ctx.input.character_count > 0 {
				buffer_length := text_input != nil ? len(text_input.buf) : -1
				buffer_capacity := text_input != nil ? cap(text_input.buf) : -1
				log.infof(
					"[orui text] keyboard focus=%v id=%v editable=%v input_nil=%v chars=%v caret=%v len=%v cap=%v",
					ctx.focus,
					element.id,
					element.editable,
					text_input == nil,
					ctx.input.character_count,
					ctx.caret_index,
					buffer_length,
					buffer_capacity,
				)
			}
			ctrl_down := key_down(ctx, .LEFT_CONTROL) || key_down(ctx, .RIGHT_CONTROL)
			cmd_down := key_down(ctx, .LEFT_SUPER) || key_down(ctx, .RIGHT_SUPER)
			shift_down := key_down(ctx, .LEFT_SHIFT) || key_down(ctx, .RIGHT_SHIFT)

			when ODIN_OS == .Darwin {
				word_modifier := key_down(ctx, .LEFT_ALT) || key_down(ctx, .RIGHT_ALT)
			} else {
				word_modifier := ctrl_down
			}

			if ctx.input.character_count > 0 {
				for i := 0; i < min(ctx.input.character_count, len(ctx.input.characters)); i += 1 {
					insert_input_character(ctx, element, ctx.input.characters[i])
				}
			}

			if key_pressed(ctx, .LEFT) {
				next :=
					word_modifier ? utf8_prev_word(text_input, ctx.caret_index) : utf8_prev(text_input, ctx.caret_index)
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next)
			}

			if key_pressed(ctx, .RIGHT) {
				next :=
					word_modifier ? utf8_next_word(text_input, ctx.caret_index) : utf8_next(text_input, ctx.caret_index)
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next)
			}

			if key_pressed(ctx, .HOME) {
				next_index := 0
				if ctrl_down || cmd_down || element.overflow == .Visible {
					next_index = 0
				} else {
					next_index = caret_index_start_of_line(ctx, element, ctx.caret_index)
				}
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next_index
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next_index)
			}

			if key_pressed(ctx, .END) {
				next_index := len(text_input.buf)
				if ctrl_down || cmd_down || element.overflow == .Visible {
					next_index = len(text_input.buf)
				} else {
					next_index = caret_index_end_of_line(ctx, element, ctx.caret_index)
				}
				if shift_down {
					if !has_text_selection(ctx) {
						ctx.text_selection.start = ctx.caret_index
					}
					ctx.text_selection.end = next_index
				} else {
					clear_text_selection(ctx)
				}
				set_caret_index(ctx, element, next_index)
			}

			if element.overflow == .Wrap {
				if key_pressed(ctx, .UP) {
					next := caret_index_up(ctx, element, ctx.caret_position)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}

				if key_pressed(ctx, .DOWN) {
					next := caret_index_down(ctx, element, ctx.caret_position)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}

				if key_pressed(ctx, .PAGE_UP) {
					next := caret_index_up(ctx, element, ctx.caret_position, 5)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}

				if key_pressed(ctx, .PAGE_DOWN) {
					next := caret_index_down(ctx, element, ctx.caret_position, 5)
					if shift_down {
						if !has_text_selection(ctx) {
							ctx.text_selection.start = ctx.caret_index
						}
						ctx.text_selection.end = next
					} else {
						clear_text_selection(ctx)
					}
					set_caret_index(ctx, element, next)
				}
			}

			if key_pressed(ctx, .Z) && (ctrl_down || cmd_down) {
				undo_text(ctx, element)
			}
			if key_pressed(ctx, .Y) && (ctrl_down || cmd_down) {
				redo_text(ctx, element)
			}

			if key_pressed(ctx, .BACKSPACE) {
				caret := ctx.caret_index
				if has_text_selection(ctx) {
					record_text_edit(ctx, element)
					caret = delete_text_selection(ctx, element)
				} else {
					prev := utf8_prev(text_input, ctx.caret_index)
					if prev != ctx.caret_index {
						record_text_edit(ctx, element)
					}
					delete_range(text_input, prev, ctx.caret_index)
					caret = prev
				}
				element.text = strings.to_string(text_input^)
				set_caret_index(ctx, element, caret)
			}

			if key_pressed(ctx, .DELETE) {
				if has_text_selection(ctx) {
					record_text_edit(ctx, element)
					caret := delete_text_selection(ctx, element)
					set_caret_index(ctx, element, caret)
				} else {
					next := utf8_next(text_input, ctx.caret_index)
					if next != ctx.caret_index {
						record_text_edit(ctx, element)
					}
					delete_range(text_input, ctx.caret_index, next)
				}
				element.text = strings.to_string(text_input^)
			}

			if key_pressed(ctx, .ENTER) && element.overflow == .Wrap {
				record_text_edit(ctx, element)
				caret := ctx.caret_index
				if has_text_selection(ctx) {
					caret = delete_text_selection(ctx, element)
				}
				char_bytes, char_len := utf8.encode_rune('\n')
				bytes_inserted := insert_bytes(text_input, caret, string(char_bytes[:char_len]))
				element.text = strings.to_string(text_input^)
				set_caret_index(ctx, element, caret + bytes_inserted)
			}

			if key_pressed(ctx, .A) && (ctrl_down || cmd_down) {
				ctx.text_selection.start = 0
				ctx.text_selection.end = len(text_input.buf)
				set_caret_index(ctx, element, len(text_input.buf))
			}

			if key_pressed(ctx, .C) && (ctrl_down || cmd_down) {
				if has_text_selection(ctx) {
					a, b := get_text_selection(ctx)
					selected_text := string(text_input.buf[a:b])
					rl.SetClipboardText(
						strings.clone_to_cstring(
							selected_text,
							ctx.allocator[current_buffer(ctx)],
						),
					)
				}
			}

			if key_pressed(ctx, .X) && (ctrl_down || cmd_down) {
				if has_text_selection(ctx) {
					a, b := get_text_selection(ctx)
					selected_text := string(text_input.buf[a:b])
					rl.SetClipboardText(
						strings.clone_to_cstring(
							selected_text,
							ctx.allocator[current_buffer(ctx)],
						),
					)
					record_text_edit(ctx, element)
					delete_range(text_input, a, b)
					element.text = strings.to_string(text_input^)
					set_caret_index(ctx, element, a)
					clear_text_selection(ctx)
				}
			}

			if key_pressed(ctx, .V) && (ctrl_down || cmd_down) {
				text := ctx.input.clipboard_text
				if len(text) == 0 {
					clipboard_text := rl.GetClipboardText()
					if clipboard_text != nil {
						text = string(clipboard_text)
					}
				}
				if len(text) > 0 {
					for i := 0; i < len(text); {
						character, size := utf8.decode_rune(text[i:])
						if size <= 0 { break }
						insert_input_character(ctx, element, character)
						i += size
					}
					element.text = strings.to_string(text_input^)
				}
			}
		}
	}
}

sync_focus_element :: proc(ctx: ^Context) {
	if ctx.focus_id == 0 {
		ctx.focus = 0
		return
	}

	focus_index, ok := element_index_by_id(ctx, previous_buffer(ctx), ctx.focus_id)
	if !ok {
		clear_focus(ctx)
		return
	}

	ctx.focus = focus_index

	element := &ctx.elements[previous_buffer(ctx)][focus_index]
	if !element.editable || element.text_input == nil {
		return
	}

	max_index := len(element.text_input.buf)
	caret_index := clamp(ctx.caret_index, 0, max_index)
	selection_start := clamp(ctx.text_selection.start, 0, max_index)
	selection_end := clamp(ctx.text_selection.end, 0, max_index)
	if caret_index != ctx.caret_index ||
	   selection_start != ctx.text_selection.start ||
	   selection_end != ctx.text_selection.end {
		ctx.caret_index = caret_index
		ctx.text_selection.start = selection_start
		ctx.text_selection.end = selection_end
		ctx.caret_time = 0
	}
}

@(private)
clear_focus :: proc(ctx: ^Context) {
	ctx.focus = 0
	ctx.focus_id = 0
	ctx.text_selection = {}
	ctx.selecting = false
	clear_text_click_state(ctx)
}

@(private)
point_in_rect :: proc(p: rl.Vector2, pos: rl.Vector2, size: rl.Vector2) -> bool {
	return p.x >= pos.x && p.y >= pos.y && p.x < pos.x + size.x && p.y < pos.y + size.y
}

@(private)
point_in_element :: proc(p: rl.Vector2, element: ^Element) -> bool {
	if !point_in_rect(p, element._position, element._size) {
		return false
	}

	if element._clip.width > 0 || element._clip.height > 0 {
		return point_in_rect(
			p,
			{f32(element._clip.x), f32(element._clip.y)},
			{f32(element._clip.width), f32(element._clip.height)},
		)
	}

	return true
}

@(private)
key_down :: proc(ctx: ^Context, key: rl.KeyboardKey) -> bool {
	index := int(key)
	return index >= 0 && index < MAX_INPUT_KEYS && ctx.input.keys_down[index]
}

key_pressed :: proc(ctx: ^Context, key: rl.KeyboardKey) -> bool {
	index := int(key)
	return index >= 0 && index < MAX_INPUT_KEYS &&
		(ctx.input.keys_pressed[index] || ctx.input.keys_repeated[index])
}

@(private)
set_caret_index :: proc(ctx: ^Context, element: ^Element, index: int) {
	ctx.caret_index = clamp(index, 0, len(element.text_input.buf))
	ctx.caret_time = 0
	ensure_caret_visible(ctx, element, ctx.caret_index)
}

@(private)
has_text_selection :: #force_inline proc(ctx: ^Context) -> bool {
	return ctx.text_selection.start != ctx.text_selection.end
}

@(private)
get_text_selection :: #force_inline proc(ctx: ^Context) -> (int, int) {
	a := min(ctx.text_selection.start, ctx.text_selection.end)
	b := max(ctx.text_selection.start, ctx.text_selection.end)
	return a, b
}

@(private)
clear_text_selection :: #force_inline proc(ctx: ^Context) {
	ctx.text_selection = {}
}

@(private)
delete_text_selection :: #force_inline proc(ctx: ^Context, element: ^Element) -> int {
	a, b := get_text_selection(ctx)
	delete_range(element.text_input, a, b)
	clear_text_selection(ctx)
	return a
}
