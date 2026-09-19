package orui_test

import orui "../"
import "core:strings"
import "core:testing"

@(test)
rebind_focus_to_element :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	ctx.frame = 1

	focused_id := orui.to_id("id")
	ctx.focus = 7
	ctx.focus_id = focused_id
	ctx.element_count[orui.previous_buffer(ctx)] = 4
	ctx.elements[orui.previous_buffer(ctx)][3].id = focused_id
	ctx.elements[orui.previous_buffer(ctx)][3].editable = true

	orui.sync_focus_element(ctx)

	testing.expect_value(t, ctx.focus, 3)
	testing.expect_value(t, ctx.focus_id, focused_id)
}

@(test)
clear_focus_when_element_is_missing :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	ctx.frame = 1

	ctx.focus = 7
	ctx.focus_id = orui.to_id("id")

	orui.sync_focus_element(ctx)

	testing.expect_value(t, ctx.focus, 0)
	testing.expect_value(t, ctx.focus_id, orui.Id(0))
}

make_scroll_input :: proc(wheel_y: f32) -> orui.InputState {
	input: orui.InputState
	input.mouse_position = {50, 50}
	input.mouse_wheel = {0, wheel_y}
	input.pointer_count = 1
	input.pointers[0].kind = .Mouse
	input.pointers[0].position = {50, 50}
	return input
}

declare_scroll_test_view :: proc() {
	{orui.container(
			orui.id("wheel-viewport"),
			{
				width = orui.fixed(100),
				height = orui.fixed(100),
				scroll = orui.scroll(.Vertical),
				clip = {.Self, {}},
			},
		)
		{orui.container(
			orui.id("wheel-content"),
			{width = orui.fixed(100), height = orui.fixed(500)},
		)
		}
	}
}

@(test)
fast_wheel_events_accumulate_against_pending_target :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	orui.begin_with_input(ctx, 100, 100, make_scroll_input(0), 0.016)
	declare_scroll_test_view()
	orui.end()

	orui.begin_with_input(ctx, 100, 100, make_scroll_input(-1), 0.016)
	declare_scroll_test_view()
	orui.end()

	orui.begin_with_input(ctx, 100, 100, make_scroll_input(-1), 0.016)
	declare_scroll_test_view()
	orui.end()

	viewport_id := orui.to_id("wheel-viewport")
	viewport := find_element(ctx, viewport_id)
	testing.expect(t, viewport != nil)
	expect_f32(t, viewport._scroll_target.y, 80, "consecutive wheel target")

	// Move the pending target exactly to the top while the visual offset is
	// still catching up, then verify the next event starts at zero.
	orui.begin_with_input(ctx, 100, 100, make_scroll_input(2), 0.016)
	declare_scroll_test_view()
	orui.end()
	viewport = find_element(ctx, viewport_id)
	testing.expect(t, viewport != nil)
	expect_f32(t, viewport._scroll_target.y, 0, "wheel target at top")

	orui.begin_with_input(ctx, 100, 100, make_scroll_input(-1), 0.016)
	declare_scroll_test_view()
	orui.end()
	viewport = find_element(ctx, viewport_id)
	testing.expect(t, viewport != nil)
	expect_f32(t, viewport._scroll_target.y, 40, "wheel target resumes from top")
}

@(test)
clamp_caret_position :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)

	builder: strings.Builder
	strings.builder_init(&builder, context.allocator)
	defer strings.builder_destroy(&builder)
	strings.write_string(&builder, "1")

	focused_id := orui.to_id("id")
	ctx.frame = 1
	ctx.focus_id = focused_id
	ctx.caret_index = 2
	ctx.text_selection = {2, 2}
	ctx.element_count[orui.previous_buffer(ctx)] = 4
	ctx.elements[orui.previous_buffer(ctx)][3].id = focused_id
	ctx.elements[orui.previous_buffer(ctx)][3].editable = true
	ctx.elements[orui.previous_buffer(ctx)][3].text_input = &builder

	orui.sync_focus_element(ctx)

	testing.expect_value(t, ctx.focus, 3)
	testing.expect_value(t, ctx.caret_index, 1)
	testing.expect_value(t, ctx.text_selection.start, 1)
	testing.expect_value(t, ctx.text_selection.end, 1)
}
