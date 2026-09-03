package orui

// Begin an explicitly managed popup. The caller declares its contents and
// closes it with end_overlay(). Popup placement can use the existing absolute,
// anchor, and bounds configuration.
begin_popup :: proc(
	overlay_id: Id,
	open: bool,
	config: ElementConfig,
	loc := #caller_location,
) -> bool {
	if !open {
		return false
	}
	ctx := current_context
	c := config
	c.overlay_kind = .Popup
	c.layer = max(c.layer, 100)
	c.block = c.block == .Inherit ? .True : c.block
	if c.layout == .None {
		c.layout = .Flex
		c.direction = .TopToBottom
	}
	id(overlay_id)
	element, parent := begin_element(overlay_id, loc)
	configure_element(ctx, element, parent^, c)
	return true
}

// Begin a modal overlay. It creates a full-screen input barrier; content
// declared inside the scope is placed above the barrier and can use normal
// orui elements. The manager traps focus and prioritizes Back/Escape.
begin_modal :: proc(
	overlay_id: Id,
	open: bool,
	config: ElementConfig,
	loc := #caller_location,
) -> bool {
	if !open {
		return false
	}
	ctx := current_context
	if ctx.active_overlay_id != overlay_id {
		ctx.overlay_previous_focus = ctx.focus_id
		ctx.active_overlay_id = overlay_id
	}
	c := config
	c.overlay_kind = .Modal
	c.layer = max(c.layer, 1000)
	c.position = c.position.type == .Auto ? Position{.Fixed, {}} : c.position
	c.width = c.width.type == .Fit ? percent(1) : c.width
	c.height = c.height.type == .Fit ? percent(1) : c.height
	c.block = .True
	c.capture = .True
	if c.layout == .None {
		c.layout = .Flex
		c.direction = .TopToBottom
	}
	id(overlay_id)
	element, parent := begin_element(overlay_id, loc)
	configure_element(ctx, element, parent^, c)
	return true
}

end_overlay :: proc() {
	end_element()
}

@(private)
overlay_contains :: proc(elements: ^[MAX_ELEMENTS]Element, index: i32, overlay_id: Id) -> bool {
	for current := index; current != 0; current = elements[current].parent {
		if elements[current].id == overlay_id {
			return true
		}
	}
	return false
}

@(private)
sync_overlay_scope :: proc(ctx: ^Context) {
	previous := previous_buffer(ctx)
	elements := &ctx.elements[previous]
	count := ctx.element_count[previous]
	found_id: Id = 0
	found_layer: i32 = -1
	for i: i32 = 1; i < count; i += 1 {
		if elements[i]._overlay_kind != .None && elements[i]._layer >= found_layer {
			found_id = elements[i].id
			found_layer = elements[i]._layer
		}
	}
	if found_id == 0 {
		if ctx.active_overlay_id != 0 && ctx.overlay_previous_focus != 0 {
			ctx.focus_id = ctx.overlay_previous_focus
		}
		ctx.active_overlay_id = 0
		ctx.overlay_previous_focus = 0
	} else {
		ctx.active_overlay_id = found_id
	}
}
