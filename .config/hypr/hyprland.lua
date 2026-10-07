-- # Special Character translation
-- # https://wiki.linuxquestions.org/wiki/List_of_keysyms
--
-- source = ./programs/chatterino.conf

---@param text unknown
---@param icon "warn" | "ok" | nil
local function notify(text, icon)
	hl.notification.create({ text = tostring(text), icon = icon or "ok", timeout = 2000 })
end

hl.config({
	-- debug = {
	-- 	disable_logs = false,
	-- },
})

hl.monitor({
	output = "eDP-1",
	mode = "preferred",
	position = "auto",
	scale = 1.67,
})

hl.monitor({
	output = "DP-4",
	mode = "preferred",
	position = "auto-up",
	scale = 1,
})

hl.on("config.reloaded", function()
	local ENV_NAME = "HYPRLAND_CONFIG_RELOAD_COUNT"
	local reloadedCount = tonumber(os.getenv(ENV_NAME) or "0")
	reloadedCount = reloadedCount + 1
	hl.notification.create({ text = "hyprland config reloaded (" .. reloadedCount .. ")", icon = "ok", timeout = 2000 })
	hl.env(ENV_NAME, reloadedCount)
end)

local altWorkspaceName = "alt"
local altWorkspace = "special:" .. altWorkspaceName

local slopWorkspaceName = "slop"
local slopWorkspace = "special:" .. slopWorkspaceName

local terminal = "kitty"
local hyprlauncher = "insnlauncher"

hl.on("hyprland.start", function()
	hl.exec_cmd("waybar")
	hl.exec_cmd("hypridle")
	hl.exec_cmd("systemctl --user start hyprpolkitagent")
	hl.exec_cmd("systemctl --user start insane-notify-receive")
	hl.exec_cmd("playerctld daemon")
	hl.exec_cmd(hyprlauncher .. " -d")

	hl.exec_cmd("zen-browser", { workspace = 1 .. " silent" })
	hl.exec_cmd(terminal .. " tmux new-session -A -s main", { workspace = 2 .. " silent" })
	hl.exec_cmd(terminal .. " tmux new-session -A -s alt", {
		workspace = altWorkspace .. " silent",
	})
	hl.exec_cmd("gnome-text-editor", { workspace = 10 .. " silent" })
end)

hl.on("config.reloaded", function()
	hl.env("XDG_CONFIG_HOME", os.getenv("HOME") .. "/.config")
	hl.env("XDG_STATE_HOME", os.getenv("HOME") .. "/.local/state")
	hl.env("XDG_DATA_HOME", os.getenv("HOME") .. "/.local/share")
	-- hl.env("GDK_SCALE", "2")
	hl.env("XCURSOR_SIZE", "24")
	hl.env("HYPRCURSOR_SIZE", "24")
end)

hl.config({
	general = {
		gaps_in = 1,
		gaps_out = { top = 2, left = 8, right = 8, bottom = 8 },

		border_size = 1,

		col = {
			active_border = {
				colors = { "rgba(33ccffee)", "rgba(00ff99ee)" },
				angle = 45,
			},
			inactive_border = "rgba(595959aa)",
		},

		resize_on_border = false,

		layout = "dwindle",
	},

	decoration = {
		rounding = 4,
		rounding_power = 10,

		active_opacity = 1.0,
		inactive_opacity = 1.0,

		-- shadow = { enabled = false },
		-- blur = { enabled = false },
	},

	animations = { enabled = false },

	misc = {
		force_default_wallpaper = 2,
		vrr = 1,
		initial_workspace_tracking = 0,
	},

	input = {
		kb_layout = "se",
		follow_mouse = 1,
		sensitivity = 0.4,
		accel_profile = "flat",
		kb_options = "caps:escape", -- caps:escape_shifted_capslock

		touchpad = {
			natural_scroll = true,
			scroll_factor = 0.4,
			tap_to_click = false,
			clickfinger_behavior = true,
		},
	},

	xwayland = {
		enabled = true,
		force_zero_scaling = true,
	},
})

hl.device({
	name = "logitech-usb-receiver",
	sensitivity = 0,
	scroll_factor = 1,
})

hl.device({
	name = "telink-wireless-receiver-mouse",
	sensitivity = -0.5,
	scroll_factor = 1,
})

hl.device({
	name = "logitech-pro-x-1",
	sensitivity = 0,
	scroll_factor = 1,
})

hl.device({
	name = "at-translated-set-2-keyboard",
	kb_layout = "se,us",
})

hl.config({
	dwindle = {
		-- force_split = 2,
		preserve_split = true,
	},

	scrolling = {
		column_width = 1.0,
		direction = "down",
	},
})

hl.workspace_rule({
	workspace = altWorkspace,
	layout = "scrolling",
})

local mainMod = "SUPER"

hl.bind(mainMod .. " + Q", hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + C", hl.dsp.window.close())
hl.bind(mainMod .. " + M", hl.dsp.exec_cmd("hyprshutdown-with-options"))
hl.bind(mainMod .. " + F", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + SHIFT + F", hl.dsp.window.fullscreen({ action = "toggle" }))
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(hyprlauncher .. " -t"))
hl.bind(mainMod .. " + SHIFT + R", hl.dsp.exec_cmd("epic-command-menu"))
hl.bind(mainMod .. " + W", hl.dsp.exec_cmd(terminal .. " --class waybar-tui impala"))

for _, direction in ipairs({ "left", "right", "up", "down" }) do
	hl.bind(mainMod .. " + " .. direction, hl.dsp.focus({ direction = direction }))
	hl.bind(mainMod .. " + CTRL + " .. direction, function()
		local function safe_active_monitor()
			local monitor = hl.get_active_monitor()
			if monitor == nil then
				error("monitor nil")
			end
			return monitor
		end

		local ok, result = pcall(function()
			local current = safe_active_monitor()
			hl.dispatch(hl.dsp.focus({ direction = direction }))
			local other = safe_active_monitor()
			hl.dispatch(hl.dsp.focus({ monitor = current }))

			if current.id == other.name then
				return
			end

			hl.dispatch(hl.dsp.workspace.swap_monitors({
				monitor1 = current.id,
				monitor2 = other.id,
			}))
			hl.dispatch(hl.dsp.focus({ monitor = other }))
		end)

		if not ok then
			notify(result, "warn")
		end
	end)
end

for i = 1, 10 do
	local key = i % 10
	hl.bind(mainMod .. " + " .. key, hl.dsp.focus({ workspace = i }))
	hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

hl.bind(mainMod .. " + D", hl.dsp.workspace.toggle_special(altWorkspaceName))
hl.bind(mainMod .. " + SHIFT + D", hl.dsp.window.move({ workspace = altWorkspace }))

hl.bind(mainMod .. " + A", hl.dsp.workspace.toggle_special(slopWorkspaceName))
hl.bind(mainMod .. " + SHIFT + A", hl.dsp.window.move({ workspace = slopWorkspace }))

hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

hl.bind(
	"XF86AudioRaiseVolume",
	hl.dsp.exec_cmd("wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioLowerVolume",
	hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86AudioMute",
	hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),
	{ locked = true, repeating = true }
)

-- Brightness
local percentPerPress = 5
local file = io.open("/sys/class/backlight/amdgpu_bl1/max_brightness", "r")
local maxBrightnessText = file and file:read("*a") and file:close()
local maxBrightness = tonumber(maxBrightnessText) or 65535
local brightnessDelta = maxBrightness / (100 / percentPerPress)

hl.bind(
	"XF86MonBrightnessUp",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set " .. brightnessDelta .. "+"),
	{ locked = true, repeating = true }
)
hl.bind(
	"XF86MonBrightnessDown",
	hl.dsp.exec_cmd("brightnessctl -e4 -n2 set " .. brightnessDelta .. "-"),
	{ locked = true, repeating = true }
)
hl.bind("SHIFT + XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 100%"), { locked = true })
hl.bind("SHIFT + XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -e4 -n2 set 1%"), { locked = true })

-- Window Opacity Setters
hl.bind(mainMod .. " + XF86MonBrightnessUp", hl.dsp.window.set_prop({ prop = "opacity", value = 1.0 }))
hl.bind(mainMod .. " + XF86MonBrightnessDown", hl.dsp.window.set_prop({ prop = "opacity", value = 0.8 }))

-- Media Controls
hl.bind("XF86AudioNext", hl.dsp.exec_cmd("playerctl next"), { locked = true })
hl.bind("XF86AudioPause", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPlay", hl.dsp.exec_cmd("playerctl play-pause"), { locked = true })
hl.bind("XF86AudioPrev", hl.dsp.exec_cmd("playerctl previous"), { locked = true })

-- Lock screen
hl.bind(mainMod .. " + L", hl.dsp.exec_cmd("hyprlock"))

-- Screenshot
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.exec_cmd("hyprshot -m region --clipboard-only"))

-- Waybar
hl.bind(mainMod .. " + aring", hl.dsp.exec_cmd("pkill -SIGUSR1 waybar"))
hl.bind(mainMod .. " + SHIFT + aring", hl.dsp.exec_cmd("pkill -SIGUSR2 waybar"))

-- Notification Center
hl.bind(mainMod .. " + N", hl.dsp.exec_cmd("swaync-client -t -sw"))

hl.window_rule({
	name = "desktop portal gtk",
	size = { 1450, 850 },
	center = true,
	match = {
		class = "xdg-desktop-portal-gtk",
	},
})

-- Helium Browser
hl.window_rule({
	name = "helium-browser",
	scroll_touchpad = 0.2,
	match = {
		class = "helium",
	},
})

-- Zen Browser
hl.window_rule({
	name = "zen-browser",
	scroll_touchpad = 0.2,
	match = {
		class = "zen",
	},
})

-- Smaller window in special workspaces (mod + d/a)
hl.workspace_rule({
	workspace = altWorkspace,
	gaps_out = 40,
})
hl.workspace_rule({
	workspace = slopWorkspace,
	gaps_out = 40,
})

-- hyprland-share-picker
hl.window_rule({
	name = "hyprland-share-picker",
	size = { 600, 400 },
	match = {
		class = "hyprland-share-picker",
	},
})

-- Firefox
hl.window_rule({
	name = "firefox-history",
	size = { 1450, 850 },
	float = true,
	center = true,
	match = {
		title = "Library",
	},
})

hl.window_rule({
	name = "firefox-pip",
	size = { 560, 315 },
	-- position = { 1130, 140 },
	float = true,
	keep_aspect_ratio = true,
	pin = true,
	match = {
		title = "Picture-in-Picture",
	},
})

hl.window_rule({
	name = "binary-ninja-start-window",
	size = { 600, 500 },
	float = true,
	match = {
		title = "Binary Ninja Free",
	},
})

-- Prismlauncher
hl.window_rule({
	name = "prismlauncher-float",
	float = true,
	center = true,
	match = {
		class = "org.prismlauncher.PrismLauncher",
	},
})

hl.window_rule({
	name = "prismlauncher-main",
	size = { 1450, 850 },
	match = {
		class = "org.prismlauncher.PrismLauncher",
		title = "Prism Launcher.*",
	},
})

-- waybar-tui | Class used for centering any TUIs launched through waybar
hl.window_rule({
	name = "waybar-tui",
	size = { "monitor_w * 0.75", "monitor_h * 0.75" },
	float = true,
	center = true,
	match = {
		class = "waybar-tui",
	},
})

hl.window_rule({
	name = "ff-center",
	size = { "monitor_w * 0.65", "monitor_h * 0.65" },
	float = true,
	center = true,
	match = {
		class = "ff-center",
	},
})

-- Legcord
hl.window_rule({
	name = "legcord",
	workspace = altWorkspace .. " silent",
	scroll_touchpad = 0.1,
	match = {
		class = "legcord",
	},
})

hl.window_rule({
	name = "legcord-loading",
	workspace = altWorkspace,
	match = {
		class = "legcord",
		title = "Legcord",
	},
})

hl.window_rule({
	name = "waydroid",
	pseudo = true,
	size = { 610, 1080 },
	match = {
		class = "Waydroid|waydroid.*",
	},
})

hl.window_rule({
	name = "thunderbird",
	workspace = altWorkspace,
	match = {
		class = "org.mozilla.Thunderbird",
	},
})

hl.window_rule({
	name = "thunderbird-write",
	float = true,
	center = true,
	size = { "monitor_w * 0.75", "monitor_h * 0.75" },
	match = {
		class = "org.mozilla.Thunderbird",
		title = "Write.*",
	},
})

hl.window_rule({
	name = "suppress-maximize-events",
	match = { class = ".*" },

	suppress_event = "maximize",
})

hl.window_rule({
	name = "fix-xwayland-drags",
	match = {
		class = "^$",
		title = "^$",
		xwayland = true,
		float = true,
		fullscreen = false,
		pin = false,
	},

	no_focus = true,
})
