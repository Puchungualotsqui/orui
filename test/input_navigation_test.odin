package orui_test

import orui "../"
import "core:testing"

@(test)
controller_input_snapshot :: proc(t: ^testing.T) {
	input: orui.InputState
	input.controllers[0].buttons_pressed[int(orui.ControllerButton.South)] = true
	input.controllers[0].buttons_down[int(orui.ControllerButton.DPad_Right)] = true
	input.controllers[0].axes[int(orui.ControllerAxis.Left_X)] = 0.75

	testing.expect(t, orui.controller_button_pressed(input, .South))
	testing.expect(t, orui.controller_button_down(input, .DPad_Right))
	testing.expect_value(t, orui.controller_axis(input, .Left_X), 0.75)
}

@(test)
programmatic_focus_and_activation :: proc(t: ^testing.T) {
	ctx := new(orui.Context)
	defer free(ctx)

	focus_id := orui.to_id("focus target")
	activate_id := orui.to_id("activate target")
	orui.set_focus(ctx, focus_id)
	orui.activate(ctx, activate_id)

	testing.expect_value(t, ctx.focus_id, focus_id)
	testing.expect_value(t, ctx.requested_focus_id, focus_id)
	testing.expect_value(t, ctx.activated_id, activate_id)
	testing.expect_value(t, ctx.requested_activation_id, activate_id)
}
