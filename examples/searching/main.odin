package new_features

import orui "../../"
import "core:fmt"
import "core:log"
import "core:os"
import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

DemoItem :: struct {
	name:   string,
	status: string,
}

ITEMS :: []DemoItem{
	{"Moonfall Tactics", "Installed"},
	{"Signal Lost", "Ready to play"},
	{"Iron Orchard", "Updating"},
	{"Neon Circuit", "Installed"},
	{"Deep Current", "Queued"},
	{"Paper Kingdoms", "Installed"},
	{"Ashen Horizon", "Installed"},
	{"Starlight Foundry", "Ready to play"},
	{"Glass Harbor", "Updating"},
	{"Cinder Protocol", "Queued"},
	{"Velvet Comet", "Installed"},
	{"Echoes of Meridian", "Ready to play"},
	{"Solaris Drift", "Installed"},
	{"Winter Circuit", "Updating"},
	{"Obsidian Vale", "Queued"},
	{"Lunar Assembly", "Installed"},
	{"Copper Skies", "Ready to play"},
	{"Warden of Tides", "Installed"},
	{"Silent Atlas", "Updating"},
	{"Emberline", "Queued"},
	{"Aster Colony", "Installed"},
	{"Night Signal", "Ready to play"},
	{"Rift Garden", "Installed"},
	{"Marble Frontier", "Updating"},
}


ascii_lower :: proc(value: u8) -> u8 {
	if value >= 'A' && value <= 'Z' {
		return value + ('a' - 'A')
	}
	return value
}

contains_ascii_ci :: proc(value, query: string) -> bool {
	if len(query) == 0 {
		return true
	}
	if len(query) > len(value) {
		return false
	}
	for start := 0; start + len(query) <= len(value); start += 1 {
		matches := true
		for offset := 0; offset < len(query); offset += 1 {
			if ascii_lower(value[start + offset]) != ascii_lower(query[offset]) {
				matches = false
				break
			}
		}
		if matches {
			return true
		}
	}
	return false
}

search_filter :: proc(character: rune) -> bool {
	return(
		(character >= 'a' && character <= 'z') ||
		(character >= 'A' && character <= 'Z') ||
		(character >= '0' && character <= '9') ||
		character == ' ' || character == '-' || character == '_' \
	)
}

main :: proc() {
	// Keep framework input traces available after a GUI process crashes.
	logh, logh_err := os.open("log.txt", (os.O_CREATE | os.O_TRUNC | os.O_RDWR))
	if logh_err == os.ERROR_NONE {
		os.stdout = logh
		os.stderr = logh
	}
	context.logger = logh_err == os.ERROR_NONE ? log.create_file_logger(logh, allocator = context.allocator) : log.create_console_logger(allocator = context.allocator)

	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(1280, 800, "orui - New Features")
	defer rl.CloseWindow()

	ctx := new(orui.Context)
	defer free(ctx)
	orui.init(ctx)
	defer orui.destroy(ctx)

	font_path, _ := filepath.join(
		{#directory, "..", "..", "assets", "Inter-Regular.ttf"},
		context.temp_allocator,
	)
	ctx.default_font = rl.LoadFont(strings.clone_to_cstring(font_path, context.temp_allocator))
	defer rl.UnloadFont(ctx.default_font)

	theme := orui.default_theme()
	theme.metrics.touch_target = 48
	theme.metrics.control_height = 42
	theme.metrics.corner_radius = 6
	theme.button_background = {35, 45, 60, 255}
	theme.button_hover = {55, 80, 110, 255}
	theme.selected = {40, 120, 170, 255}
	theme.focus_border = {255, 220, 100, 255}
	theme.styles[int(orui.StyleRole.Button)].focused.background_color = theme.button_focused
	theme.styles[int(orui.StyleRole.Button)].focused.border_color = theme.focus_border
	orui.set_theme(ctx, theme)

	items := ITEMS
	search := strings.builder_make()
	defer strings.builder_destroy(&search)
	selected := 0
	menu_open := false
	modal_open := false
	status := "Touch, mouse, keyboard, or controller input"
	current_cursor := rl.MouseCursor.DEFAULT

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({18, 22, 30, 255})

		width := rl.GetScreenWidth()
		height := rl.GetScreenHeight()
		// The Raylib adapter includes mouse and touchscreen pointers. A custom
		// backend can populate the same InputState before this call.
		input := orui.input_from_raylib()
		orui.begin_responsive_with_input(ctx, width, height, input)

		cursor_hint := orui.cursor(ctx)
		next_cursor := cursor_hint == .Unspecified ? rl.MouseCursor.DEFAULT : rl.MouseCursor(cursor_hint)
		if next_cursor != current_cursor {
			rl.SetMouseCursor(next_cursor)
			current_cursor = next_cursor
		}

		query := strings.to_string(search)
		visible_items: [256]int
		visible_count := 0
		for item, index in items {
			if contains_ascii_ci(item.name, query) && visible_count < len(visible_items) {
				visible_items[visible_count] = index
				visible_count += 1
			}
		}
		if visible_count > 0 {
			selected = clamp(selected, 0, visible_count - 1)
		}

		{orui.container(orui.id("app"), {
				direction = .TopToBottom,
				width = orui.grow(), height = orui.grow(),
				padding = orui.padding(24), gap = theme.metrics.spacing_medium,
			})
			{orui.container(orui.id("header"), {
					direction = .LeftToRight,
					width = orui.grow(), height = orui.fit(),
					align_cross = .Center, align_main = .SpaceBetween,
				})
				orui.label(orui.id("title"), "ORUI FEATURE TOUR", {
					font_size = 28, color = theme.text,
				})
				orui.label(orui.id("status"), status, {
					font_size = 14, color = {170, 180, 195, 255},
				})
			}

			{orui.container(orui.id("toolbar"), {
					direction = .LeftToRight,
					width = orui.grow(), height = orui.fit(),
					align_cross = .Center, gap = theme.metrics.spacing_medium,
				})
				orui.text_input(orui.id("search"), &search, {
					width = orui.grow(), height = orui.fixed(48),
					font_size = 17, color = theme.text,
					placeholder = "Filter games...",
					text_filter = search_filter,
					background_color = {28, 34, 45, 255},
					border = orui.border(1),
					border_color = orui.focused() ? theme.focus_border : theme.border,
					padding = orui.padding(12),
					overflow = .Visible,
					clip = {.Intersect, {}},
					scroll = orui.scroll(.Horizontal),
				})
				if orui.button(orui.id("jump"), "Jump to row 3", {
					width = orui.fixed(160), height = orui.fixed(48),
				}) {
					orui.scroll_to_smooth(orui.to_id("results"), {0, 3 * 52})
					status = "Smooth-scrolling to row 3"
				}
				if orui.button(orui.id("menu"), "Menu", {
					width = orui.fixed(110), height = orui.fixed(48),
				}) {
					menu_open = !menu_open
				}
			}

			orui.label(orui.id("result count"), fmt.tprintf("Showing %d of %d games", visible_count, len(items)), {
				font_size = 14, color = {170, 180, 195, 255},
			})

			list := orui.begin_virtual_list(orui.id("results"), {
				width = orui.grow(), height = orui.grow(),
				scroll = orui.scroll(.Vertical),
				background_color = {24, 29, 39, 255},
				padding = orui.padding(6),
				clip = {.Self, {}},
			}, {
				direction = .Vertical,
				item_count = visible_count,
				item_extent = 52,
				overscan = 2,
			})
			for row := list.first; row < list.last; row += 1 {
				item_index := visible_items[row]
				item := items[item_index]
				row_color := row == selected ? theme.selected : theme.button_background
				if orui.button(orui.id(orui.virtual_list_item_id(list.id, item_index)),
					fmt.tprintf("%s    %s", item.name, item.status),
					orui.virtual_list_item_config(list, row, {
						width = orui.percent(1), height = orui.fixed(52),
						padding = orui.padding(14, 8),
						background_color = row_color,
						border = orui.border(1),
						border_color = row == selected ? theme.focus_border : theme.border,
						color = theme.text,
					})
				) {
					selected = row
					status = fmt.tprintf("Selected %s", item.name)
				}
			}
			orui.end_virtual_list()
		}

		if menu_open && orui.begin_popup(orui.id("menu popup"), true, {
			position = {.Fixed, {930, 105}},
			width = orui.fixed(220),
			padding = orui.padding(6),
			background_color = {35, 42, 55, 255},
			border = orui.border(1), border_color = theme.border,
		}) {
			if orui.button(orui.id("open details"), "Open details", {}) {
				menu_open = false
				modal_open = true
			}
			if orui.button(orui.id("close menu"), "Close menu", {}) {
				menu_open = false
			}
			orui.end_overlay()
		}

		if modal_open && orui.begin_modal(orui.id("details modal"), true, {
			background_color = {0, 0, 0, 150},
			layout = .Flex, align_main = .Center, align_cross = .Center,
		}) {
			{orui.container(orui.id("details panel"), {
					width = orui.fixed(520), height = orui.fit(),
					padding = orui.padding(24), gap = 12,
					background_color = theme.button_background,
					border = orui.border(1), border_color = theme.focus_border,
					direction = .TopToBottom,
				})
				orui.label(orui.id("details title"), "Managed modal overlay", {
					font_size = 22, color = theme.text,
				})
				orui.label(orui.id("details body"), "This overlay traps focus and consumes Back/Escape before the page.", {
					font_size = 16, color = theme.text, width = orui.grow(), overflow = .Wrap,
				})
				if orui.button(orui.id("close details"), "Close", {
					width = orui.fixed(140), height = orui.fixed(48),
				}) {
					modal_open = false
				}
			}
			orui.end_overlay()
		}
		if orui.back_pressed() {
			orui.consume_back()
			if menu_open { menu_open = false } else { modal_open = false }
		}

		for command in orui.end() {
			orui.render_command(command)
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
