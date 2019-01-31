-- HUD HUD HUD

local surface = surface
local draw = draw
local math = math
local string = string
local GetLang = LANG.GetUnsafeLanguageTable
local interp = string.Interp
local util = util
local IsValid = IsValid
local hook = hook

local hudWidth = CreateClientConVar("ttt2_base_hud_width", "0")
local hudTeamicon = CreateClientConVar("ttt2_base_hud_teamicon", "1")

-- Fonts
surface.CreateFont("TraitorState", {font = "Trebuchet24", size = 28, weight = 1000})
surface.CreateFont("TimeLeft", {font = "Trebuchet24", size = 24, weight = 800})
surface.CreateFont("HealthAmmo", {font = "Trebuchet24", size = 24, weight = 750})

-- Color presets
local bg_colors = {
	background_main = Color(0, 0, 10, 200),
	noround = Color(100, 100, 100, 200)
}

local health_colors = {
	border = COLOR_WHITE,
	background = Color(100, 25, 25, 222),
	fill = Color(200, 50, 50, 250)
}

local ammo_colors = {
	border = COLOR_WHITE,
	background = Color(20, 20, 5, 222),
	fill = Color(205, 155, 0, 255)
}

-- Modified RoundedBox
local Tex_Corner8 = surface.GetTextureID("gui/corner8")

local function RoundedMeter(bs, x, y, w, h, color)
	surface.SetDrawColor(clr(color))

	surface.DrawRect(x + bs, y, w - bs * 2, h)
	surface.DrawRect(x, y + bs, bs, h - bs * 2)

	surface.SetTexture(Tex_Corner8)
	surface.DrawTexturedRectRotated(x + bs * 0.5, y + bs * 0.5, bs, bs, 0)
	surface.DrawTexturedRectRotated(x + bs * 0.5, y + h - bs * 0.5, bs, bs, 90)

	if w > 14 then
		surface.DrawRect(x + w - bs, y + bs, bs, h - bs * 2)
		surface.DrawTexturedRectRotated(x + w - bs * 0.5, y + bs * 0.5, bs, bs, 270)
		surface.DrawTexturedRectRotated(x + w - bs * 0.5, y + h - bs * 0.5, bs, bs, 180)
	else
		surface.DrawRect(x + math.max(w - bs, bs), y, bs * 0.5, h)
	end
end

---- The bar painting is loosely based on:
---- http://wiki.garrysmod.com/?title=Creating_a_HUD

-- Paints a graphical meter bar
local function PaintBar(x, y, w, h, colors, value)
	-- Background
	-- slightly enlarged to make a subtle border
	draw.RoundedBox(8, x - 1, y - 1, w + 2, h + 2, colors.background)

	-- Fill
	local width = w * math.Clamp(value, 0, 1)

	if width > 0 then
		RoundedMeter(8, x, y, width, h, colors.fill)
	end
end

local roundstate_string = {
	[ROUND_WAIT] = "round_wait",
	[ROUND_PREP] = "round_prep",
	[ROUND_ACTIVE] = "round_active",
	[ROUND_POST] = "round_post"
}

local margin = 10
local dmargin = margin * 2
local smargin = 2
local maxheight = 90
local maxwidth = hudWidth:GetInt() + maxheight + margin + 170
local hastewidth = 80
local bgheight = 30

-- Returns player's ammo information
local function GetAmmo(ply)
	local weap = ply:GetActiveWeapon()

	if not weap or not ply:Alive() then
		return - 1
	end

	local ammo_inv = weap.Ammo1 and weap:Ammo1() or 0
	local ammo_clip = weap:Clip1() or 0
	local ammo_max = weap.Primary.ClipSize or 0

	return ammo_clip, ammo_max, ammo_inv
end

local function DrawBg(x, y, width, height, client)
	-- Traitor area sizes
	local th = bgheight
	local tw = width - hastewidth - (hudTeamicon:GetBool() and bgheight or 0) - smargin * 2 -- bgheight = team icon

	-- Adjust for these
	y = y - th
	height = height + th

	-- main bg area, invariant
	-- encompasses entire area
	draw.RoundedBox(8, x, y, width, height, bg_colors.background_main)

	-- main border, role based
	local col = INNOCENT.color

	if GAMEMODE.round_state ~= ROUND_ACTIVE then
		col = bg_colors.noround
	elseif client:IsSpecial() then
		col = client:GetRoleColor()
	end

	draw.RoundedBox(8, x, y, tw, th, col)
end

local dr = draw

local function ShadowedText(text, font, x, y, color, xalign, yalign)
	dr.SimpleText(text, font, x + 2, y + 2, COLOR_BLACK, xalign, yalign)
	dr.SimpleText(text, font, x, y, color, xalign, yalign)
end

-- Paint punch-o-meter
local function PunchPaint(client)
	local L = GetLang()
	local punch = client:GetNWFloat("specpunches", 0)
	local width, height = 200, 25
	local x = ScrW() * 0.5 - width * 0.5
	local y = margin * 0.5 + height

	PaintBar(x, y, width, height, ammo_colors, punch)

	local color = bg_colors.background_main

	dr.SimpleText(L.punch_title, "HealthAmmo", ScrW() * 0.5, y, color, TEXT_ALIGN_CENTER)
	dr.SimpleText(L.punch_help, "TabLarge", ScrW() * 0.5, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)

	local bonus = client:GetNWInt("bonuspunches", 0)
	if bonus ~= 0 then
		local text

		if bonus < 0 then
			text = interp(L.punch_bonus, {num = bonus})
		else
			text = interp(L.punch_malus, {num = bonus})
		end

		dr.SimpleText(text, "TabLarge", ScrW() * 0.5, y * 2, COLOR_WHITE, TEXT_ALIGN_CENTER)
	end
end

local key_params = {usekey = Key("+use", "USE")}

local function SpecHUDPaint(client)
	local L = GetLang() -- for fast direct table lookups

	-- Draw round state
	local x = margin
	local height = bgheight
	local width = maxwidth
	local round_y = ScrH() - height - margin

	-- move up a little on low resolutions to allow space for spectator hints
	if ScrW() < 1000 then
		round_y = round_y - 15
	end

	local time_x = width - hastewidth
	local time_y = round_y + 4

	dr.RoundedBox(8, x, round_y, width, height, bg_colors.background_main)
	dr.RoundedBox(8, x, round_y, time_x, height, bg_colors.noround)

	-- Draw current round state
	local text = L[roundstate_string[GAMEMODE.round_state]]
	ShadowedText(text, "TraitorState", x + (width - hastewidth) * 0.5, round_y, COLOR_WHITE, TEXT_ALIGN_CENTER)

	-- Draw round/prep/post time remaining
	text = util.SimpleTime(math.max(0, GetGlobalFloat("ttt_round_end", 0) - CurTime()), "%02i:%02i")
	ShadowedText(text, "TimeLeft", x + time_x + smargin + hastewidth * 0.5, time_y, COLOR_WHITE, TEXT_ALIGN_CENTER)

	local tgt = client:GetObserverTarget()

	if IsValid(tgt) and tgt:IsPlayer() then
		ShadowedText(tgt:Nick(), "TimeLeft", ScrW() * 0.5, margin, COLOR_WHITE, TEXT_ALIGN_CENTER) -- draw name of the spectators target
	elseif IsValid(tgt) and tgt:GetNWEntity("spec_owner", nil) == client then
		PunchPaint(client) -- punch bar if you are spectator and inside of an entity
	else
		ShadowedText(interp(L.spec_help, key_params), "TabLarge", ScrW() * 0.5, margin, COLOR_WHITE, TEXT_ALIGN_CENTER)
	end
end

local ttt_health_label = CreateClientConVar("ttt_health_label", "0", true)

function DrawHudIcon(x, y, w, h, icon, color)
	local base = Material("vgui/ttt/dynamic/base")
	local base_overlay = Material("vgui/ttt/dynamic/base_overlay")

	surface.SetDrawColor(color.r, color.g, color.b, color.a)
	surface.SetMaterial(base)
	surface.DrawTexturedRect(x, y, w, h)

	surface.SetDrawColor(color.r, color.g, color.b, color.a)
	surface.SetMaterial(base_overlay)
	surface.DrawTexturedRect(x, y, w, h)

	surface.SetDrawColor(255, 255, 255, 255)
	surface.SetMaterial(icon)
	surface.DrawTexturedRect(x, y, w, h)
end

local function InfoPaint(client)
	local L = GetLang()
	local width = maxwidth
	local height = maxheight
	local x = margin
	local y = ScrH() - margin - height

	DrawBg(x, y, width, height, client)

	local bar_height = 25
	local bar_width = width - dmargin

	-- Draw health
	local health = math.max(0, client:Health())
	local health_y = y + margin

	PaintBar(x + margin, health_y, bar_width, bar_height, health_colors, health / client:GetMaxHealth())
	ShadowedText(tostring(health), "HealthAmmo", bar_width, health_y, COLOR_WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT)

	if ttt_health_label:GetBool() then
		local health_status = util.HealthToString(health, client:GetMaxHealth())

		draw.SimpleText(L[health_status], "TabLarge", x + margin * 2, health_y + bar_height * 0.5, COLOR_WHITE, TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end

	-- Draw ammo
	if client:GetActiveWeapon().Primary then
		local ammo_clip, ammo_max, ammo_inv = GetAmmo(client)
		if ammo_clip ~= -1 then
			local ammo_y = health_y + bar_height + margin
			local text = string.format("%i + %02i", ammo_clip, ammo_inv)

			PaintBar(x + margin, ammo_y, bar_width, bar_height, ammo_colors, ammo_clip / ammo_max)
			ShadowedText(text, "HealthAmmo", bar_width, ammo_y, COLOR_WHITE, TEXT_ALIGN_RIGHT, TEXT_ALIGN_RIGHT)
		end
	end

	local tmp = width - hastewidth - (hudTeamicon:GetBool() and bgheight or 0) - smargin * 2

	-- Draw the current role
	local round_state = GAMEMODE.round_state
	local traitor_y = y - 30
	local text

	if round_state == ROUND_ACTIVE then
		text = L[client:GetSubRoleData().name]
	else
		text = L[roundstate_string[round_state]]
	end

	ShadowedText(text, "TraitorState", x + tmp * 0.5, traitor_y, COLOR_WHITE, TEXT_ALIGN_CENTER)

	-- Draw team icon
	if hudTeamicon:GetBool() then
		local team = client:GetTeam()

		if team ~= TEAM_NONE and round_state == ROUND_ACTIVE and not TEAMS[team].alone then
			local t = TEAMS[team]
			local icon = Material(t.icon)

			if icon then
				local c = t.color or Color(0, 0, 0, 255)
				local tx = x + tmp + smargin

				DrawHudIcon(tx, traitor_y, bgheight, bgheight, icon, c)
			end
		end
	end

	-- Draw round time
	local is_haste = HasteMode() and round_state == ROUND_ACTIVE
	local is_traitor = client:IsActive() and client:HasTeam(TEAM_TRAITOR)
	local endtime = GetGlobalFloat("ttt_round_end", 0) - CurTime()
	local font = "TimeLeft"
	local color = COLOR_WHITE

	tmp = width + x - hastewidth + smargin + hastewidth * 0.5

	local rx = tmp
	local ry = traitor_y + 3

	-- Time displays differently depending on whether haste mode is on,
	-- whether the player is traitor or not, and whether it is overtime.
	if is_haste then
		local hastetime = GetGlobalFloat("ttt_haste_end", 0) - CurTime()
		if hastetime < 0 then
			if not is_traitor or math.ceil(CurTime()) % 7 <= 2 then

				-- innocent or blinking "overtime"
				text = L.overtime
				font = "Trebuchet18"

				-- need to hack the position a little because of the font switch
				ry = ry + 5
				rx = rx - 3
			else
				-- traitor and not blinking "overtime" right now, so standard endtime display
				text = util.SimpleTime(math.max(0, endtime), "%02i:%02i")
				color = COLOR_RED
			end
		else
			-- still in starting period
			local t = hastetime

			if is_traitor and math.ceil(CurTime()) % 6 < 2 then
				t = endtime
				color = COLOR_RED
			end

			text = util.SimpleTime(math.max(0, t), "%02i:%02i")
		end
	else
		-- bog standard time when haste mode is off (or round not active)
		text = util.SimpleTime(math.max(0, endtime), "%02i:%02i")
	end

	ShadowedText(text, font, rx, ry, color, TEXT_ALIGN_CENTER)

	if is_haste then
		dr.SimpleText(L.hastemode, "TabLarge", tmp, traitor_y - 8, COLOR_WHITE, TEXT_ALIGN_CENTER)
	end
end

-- item info
local defaultY = ScrH() * 0.5 + 20

local function ItemInfo(client)
	local y = defaultY
	local itms = client:GetEquipmentItems()

	-- at first, calculate old items because they doesn't take care of the new ones
	for _, itemCls in ipairs(itms) do
		local item = items.GetStored(itemCls)
		if item and item.oldHud then
			y = y - 80
		end
	end

	-- now draw our new items automatically
	for _, itemCls in ipairs(itms) do
		local item = items.GetStored(itemCls)
		if item and item.hud then
			surface.SetMaterial(item.hud)
			surface.SetDrawColor(255, 255, 255, 255)
			surface.DrawTexturedRect(20, y, 64, 64)

			y = y - 80
		end
	end
end

-- Paints player status HUD element in the bottom left
function GM:HUDPaint()
	local client = LocalPlayer()

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTTargetID") then
		hook.Call("HUDDrawTargetID", GAMEMODE)
	end

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTMStack") then
		MSTACK:Draw(client)
	end

	if not client:Alive() or client:Team() == TEAM_SPEC then
		if hook.Call("HUDShouldDraw", GAMEMODE, "TTTSpecHUD") then
			SpecHUDPaint(client)
		end

		return
	end

	-- Draw owned Item info
	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTItemHUDDisplay") then
		ItemInfo(client)
	end

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTRadar") then
		RADAR:Draw(client)
	end

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTTButton") then
		TBHUD:Draw(client)
	end

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTWSwitch") then
		WSWITCH:Draw(client)
	end

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTVoice") then
		VOICE.Draw(client)
	end

	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTPickupHistory") then
		hook.Call("HUDDrawPickupHistory", GAMEMODE)
	end

	-- Draw bottom left info panel
	if hook.Call("HUDShouldDraw", GAMEMODE, "TTTInfoPanel") then
		InfoPaint(client)
	end
end

-- Hide the standard HUD stuff
local hud = {
	["CHudHealth"] = true,
	["CHudBattery"] = true,
	["CHudAmmo"] = true,
	["CHudSecondaryAmmo"] = true
}

function GM:HUDShouldDraw(name)
	if hud[name] then
		return false
	end

	return self.BaseClass.HUDShouldDraw(self, name)
end

hook.Add("TTTSettingsTabs", "TTT2HudSettings", function(dtabs)
	local settings_panel = vgui.Create("DPanelList", dtabs)
	settings_panel:StretchToParent(0, 0, dtabs:GetPadding() * 2, 0)
	settings_panel:EnableVerticalScrollbar(true)
	settings_panel:SetPadding(10)
	settings_panel:SetSpacing(10)
	dtabs:AddSheet("HUD Settings", settings_panel, "icon16/user_red.png", false, false, "The HUD settings")

	local list = vgui.Create("DIconLayout", settings_panel)
	list:SetSpaceX(5)
	list:SetSpaceY(5)
	list:Dock(FILL)
	list:DockMargin(5, 5, 5, 5)
	list:DockPadding(10, 10, 10, 10)

	local settings_tab = vgui.Create("DForm")
	settings_tab:SetSpacing(10)
	settings_tab:SetName("HUD Position")
	settings_tab:SetWide(settings_panel:GetWide() - 30)

	settings_tab:NumSlider("HUD width", "ttt2_base_hud_width", 0, ScrW(), 2)
	settings_tab:CheckBox("Team icon", "ttt2_base_hud_teamicon", 0, ScrW(), 2)

	settings_panel:AddItem(settings_tab)

	settings_tab:SizeToContents()
end)

cvars.AddChangeCallback(hudWidth:GetName(), function(name, old, new)
	maxwidth = tonumber(new) + maxheight + margin + 170
end)