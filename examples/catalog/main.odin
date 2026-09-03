package catalog

import orui "../../"
import "core:fmt"

import "core:path/filepath"
import "core:strings"
import rl "vendor:raylib"

Game :: struct {
	title:       string,
	genre:       string,
	description: string,
	price:       string,
}

GAMES :: []Game{
	{"Moonfall Tactics", "Strategy", "Turn-based tactics among forgotten lunar colonies.", "$19.99"},
	{"Signal Lost", "Adventure", "Explore a derelict station and reconstruct its last transmission.", "$14.99"},
	{"Iron Orchard", "Simulation", "Build an automated orchard and balance production with ecology.", "$24.99"},
	{"Neon Circuit", "Racing", "Arcade racing with handcrafted tracks and local split-screen.", "$9.99"},
	{"Deep Current", "RPG", "A compact underwater RPG about salvage, trade, and strange ruins.", "$29.99"},
	{"Paper Kingdoms", "Puzzle", "A relaxing puzzle game where every fold changes the world.", "$12.99"},
}

GENRES :: []string{"All games", "Strategy", "Adventure", "Simulation", "Racing", "RPG", "Puzzle"}

main :: proc() {
	rl.SetConfigFlags({.WINDOW_RESIZABLE, .VSYNC_HINT, .MSAA_4X_HINT})
	rl.InitWindow(1280, 800, "orui - Catalog")
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

	// The theme is context-owned, so this example can customize its controls
	// without changing the styling of any other Context.
	theme := orui.default_theme()
	theme.button_background = {35, 45, 60, 255}
	theme.button_hover = {50, 75, 100, 255}
	theme.selected = {40, 120, 170, 255}
	theme.focus_border = {255, 220, 100, 255}
	orui.set_theme(ctx, theme)

	games := GAMES
	selected_game := 0
	selected_page := 0
	selected_genre := 0
	genre_open := false
	wishlist_only := false
	rating := f32(0.75)
	search := strings.builder_make()
	defer strings.builder_destroy(&search)

	settings_open := false
	purchase_open := false
	status := "Ready to browse"
	initial_focus := true

	for !rl.WindowShouldClose() {
		rl.BeginDrawing()
		rl.ClearBackground({18, 22, 30, 255})

		width := rl.GetScreenWidth()
		height := rl.GetScreenHeight()

		// This is the input abstraction in action. Replace this snapshot with
		// SDL/custom input data and call the same begin function.
		input := orui.input_from_raylib()
		orui.begin_responsive_with_input(ctx, width, height, input)

		// F1/F2/F3 demonstrate programmatic activation and focus.
		if orui.shortcut_pressed(.F1) {
			orui.activate(ctx, orui.to_id("catalog tabs", 0))
		}
		if orui.shortcut_pressed(.F2) {
			orui.set_focus(ctx, orui.to_id("search"))
		}
		if orui.shortcut_pressed(.F3) {
			orui.activate(ctx, orui.to_id("game card", selected_game))
		}

		if initial_focus {
			orui.set_focus(ctx, orui.to_id("search"))
			initial_focus = false
		}

		{orui.container(orui.id("app"), {
				direction = .TopToBottom,
				width = orui.grow(), height = orui.grow(),
				padding = orui.padding(24), gap = 14,
			})
			{orui.container(orui.id("header"), {
					width = orui.grow(), height = orui.fit(),
					direction = .LeftToRight, align_cross = .Center,
					align_main = .SpaceBetween,
				})
				orui.label(orui.id("title"), "ORUI GAME CATALOG", {
					font_size = 28, color = theme.text,
				})
				orui.label(orui.id("status"), status, {
					font_size = 14, color = {170, 180, 195, 255},
				})
			}

			orui.tabs(orui.id("catalog tabs"), {"Library", "Discover", "Settings"}, &selected_page, {
				width = orui.grow(), height = orui.fit(), gap = 4,
			})

			if selected_page == 0 {
				{orui.container(orui.id("filters"), {
						direction = .LeftToRight,
						width = orui.grow(), height = orui.fit(),
						align_cross = .Center, gap = 10,
					})
					orui.text_input(orui.id("search"), &search, {
						width = orui.grow(), height = orui.fixed(38),
						font_size = 16, color = theme.text,
						background_color = {28, 34, 45, 255},
						border = orui.border(1),
						border_color = orui.focused() ? theme.focus_border : theme.border,
						padding = orui.padding(10),
						overflow = .Visible,
						clip = {.Intersect, {}},
						scroll = orui.scroll(.Horizontal),
					})
					orui.dropdown(orui.id("genre"), GENRES, &selected_genre, &genre_open, {
						width = orui.fixed(170), height = orui.fixed(38),
					})
					orui.checkbox(orui.id("wishlist"), "Wishlist", &wishlist_only, {
						width = orui.fixed(150), height = orui.fixed(38),
					})
				}

				{orui.container(orui.id("catalog grid"), {
						layout = .Grid, cols = 3, rows = 2,
						width = orui.grow(), height = orui.grow(),
						col_sizes = {orui.grow()}, row_sizes = {orui.grow()},
						col_gap = 12, row_gap = 12,
					})
					for game, i in games {
						card_color := i == selected_game ? theme.selected : theme.button_background
						if orui.button(orui.id("game card", i), game.title, {
							width = orui.grow(), height = orui.grow(),
							padding = orui.padding(16),
							background_color = card_color,
							border = orui.border(1),
							border_color = i == selected_game ? theme.focus_border : theme.border,
							corner_radius = orui.corner(8),
							align = {.Start, .Center},
						}) {
							selected_game = i
							status = fmt.tprintf("Selected %s", game.title)
						}
					}
				}

				{orui.container(orui.id("details"), {
						direction = .LeftToRight,
						width = orui.grow(), height = orui.fit(),
						align_cross = .Center, gap = 14,
					})
					game := games[selected_game]
					{orui.container(orui.id("game copy"), {
							width = orui.grow(), height = orui.fit(),
							direction = .TopToBottom, gap = 4,
						})
						orui.label(orui.id("game genre"), game.genre, {font_size = 13, color = {130, 190, 220, 255}})
						orui.label(orui.id("game description"), game.description, {
							font_size = 15, color = theme.text, width = orui.grow(), overflow = .Wrap,
						})
					}
					orui.slider(orui.id("rating"), &rating, 0, 1, {
						width = orui.fixed(180), height = orui.fixed(24),
					})
					orui.label(orui.id("price"), game.price, {font_size = 18, color = theme.text})
					if orui.button(orui.id("purchase"), "Purchase", {
						width = orui.fixed(120), height = orui.fixed(38),
						background_color = theme.selected,
					}) {
						purchase_open = true
					}
					if orui.button(orui.id("settings"), "Settings", {
						width = orui.fixed(120), height = orui.fixed(38),
					}) {
						settings_open = true
					}
				}
			} else {
				orui.label(orui.id("page placeholder"), selected_page == 1 ? "Discover coming soon" : "Settings are available from the gear button.", {
					width = orui.grow(), height = orui.grow(),
					font_size = 22, color = theme.text,
					align = {.Center, .Center},
				})
			}
		}

		if settings_open {
			if orui.dialog(orui.id("settings dialog"), "Catalog settings", "This modal demonstrates Escape/B cancellation and controller focus. Press OK or Back to close.", &settings_open, {}) == .Confirmed {
				status = "Settings saved"
			}
		}
		if purchase_open {
			if orui.dialog(orui.id("purchase dialog"), "Confirm purchase", fmt.tprintf("Purchase %s for %s?", games[selected_game].title, games[selected_game].price), &purchase_open, {}) == .Confirmed {
				status = "Purchase queued"
			}
		}

		// If no popup/dialog consumed Back, let the application handle it.
		if orui.back_pressed() {
			orui.consume_back()
			if selected_page != 0 {
				selected_page = 0
			} else {
				status = "Back pressed"
			}
		}

		render_commands := orui.end()
		for command in render_commands {
			orui.render_command(command)
		}
		rl.EndDrawing()
		free_all(context.temp_allocator)
	}
}
