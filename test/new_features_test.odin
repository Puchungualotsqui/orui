package orui_test

import orui "../"
import "core:testing"

@(test)
virtual_list_declares_only_visible_rows_after_measurement :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	item_count := 100
	orui.begin(ctx, 240, 120, 0.016)
	list := orui.begin_virtual_list(orui.id("virtual rows"), {
		width = orui.percent(1),
		height = orui.percent(1),
		scroll = orui.scroll(.Vertical),
	}, {
		direction = .Vertical,
		item_count = item_count,
		item_extent = 24,
		overscan = 1,
	})
	for i := list.first; i < list.last; i += 1 {
		orui.label(
			orui.id(orui.virtual_list_item_id(list.id, i)),
			"row",
			orui.virtual_list_item_config(list, i, {width = orui.percent(1), height = orui.fixed(24)}),
		)
	}
	orui.end_virtual_list()
	orui.end()

	orui.scroll_to(orui.to_id("virtual rows"), {0, 1200})
	orui.begin(ctx, 240, 120, 0.016)
	list = orui.begin_virtual_list(orui.id("virtual rows"), {
		width = orui.percent(1),
		height = orui.percent(1),
		scroll = orui.scroll(.Vertical),
	}, {
		direction = .Vertical,
		item_count = item_count,
		item_extent = 24,
		overscan = 1,
	})
	visible_count := list.last - list.first
	for i := list.first; i < list.last; i += 1 {
		orui.label(
			orui.id(orui.virtual_list_item_id(list.id, i)),
			"row",
			orui.virtual_list_item_config(list, i, {width = orui.percent(1), height = orui.fixed(24)}),
		)
	}
	orui.end_virtual_list()
	orui.end()

	testing.expect(t, visible_count < item_count)
	testing.expect(t, visible_count > 0)
}

@(test)
primary_touch_pointer_drives_legacy_mouse_fields :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	input: orui.InputState
	input.pointer_count = 1
	input.pointers[0] = {
		id = 7,
		kind = .Touch,
		position = {40, 50},
		down = true,
		pressed = true,
	}
	orui.begin_with_input(ctx, 100, 100, input, 0.016)
	orui.end()

	testing.expect_value(t, ctx.input.mouse_position.x, 40)
	testing.expect_value(t, ctx.input.mouse_position.y, 50)
	testing.expect(t, ctx.input.mouse_left_down)
	testing.expect(t, ctx.input.mouse_left_pressed)
}
