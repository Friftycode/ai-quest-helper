local ADDON_NAME, ns = ...
local ICON = ns.ICON

local panel

local SECTIONS = {
	{ "Icons", {
		{ "iconQuestMap", "Quest map and quest log" },
		{ "iconDialog", "Quest and NPC dialog" },
		{ "iconBags", "Bags" },
		{ "iconBook", "Books and notes" },
	} },
	{ "Map", {
		{ "mapZoneLevels", "Level per zone" },
		{ "mapDungeons", "Dungeon entrances" },
		{ "mapRaids", "Raid entrances" },
		{ "mapColors", "Colour by your level" },
		{ "mapSearch", "Dungeon/raid search box" },
	} },
	{ "Export", {
		{ "exportQuestie", "Questie data (giver, turn-in, locations)" },
		{ "exportBags", "Bag contents in quest export" },
		{ "learnItems", "Learn where quest items drop and quest mobs die" },
	} },
	{ "Quest arrow", {
		{ "questArrow", "Arrow to nearest unfinished quest" },
		{ "questArrowLock", "Lock arrow position" },
		{ "questTarget", "Target button for quest mobs (left mine, right party)" },
		{ "questTargetLock", "Lock target button" },
		{ "questTargetFullHp", "Orange flash when the mob is already hurt" },
	} },
	{ "Combat", {
		{ "threatPlates", "Threat % under nameplates" },
	} },
}

local COLUMN_W = 340

local function build(f)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("AI Quest Helper")

	f.checks = {}
	local x, y

	local function check(label, key)
		local cb = CreateFrame("CheckButton", nil, f, "UICheckButtonTemplate")
		cb:SetSize(24, 24)
		cb:SetPoint("TOPLEFT", x - 4, y)
		local text = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		text:ClearAllPoints()
		text:SetPoint("LEFT", cb, "RIGHT", 2, 0)
		text:SetFontObject("GameFontHighlight")
		text:SetText(label)
		y = y - 24
		return cb
	end

	local function section(name)
		local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
		h:SetPoint("TOPLEFT", x, y)
		h:SetText(name)
		y = y - 20
	end

	local function stepRow(width)
		local l = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
		l:SetPoint("TOPLEFT", x, y - 4)
		local function button(txt, offset, fn)
			local b = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
			b:SetSize(width or 24, 20)
			b:SetPoint("TOPLEFT", x + COLUMN_W - offset, y)
			b:SetText(txt)
			b:SetScript("OnClick", fn)
			return b
		end
		y = y - 28
		return l, button
	end

	local function sectionList(list)
		for _, sec in ipairs(list) do
			section(sec[1])
			for _, item in ipairs(sec[2]) do
				local cb = check(item[2])
				cb.key = item[1]
				cb:SetScript("OnClick", function(self) ns.setOpt(self.key, self:GetChecked() and true or false) end)
				f.checks[#f.checks + 1] = cb
			end
			y = y - 10
		end
	end

	x, y = 16, -52
	sectionList({ SECTIONS[1], SECTIONS[2], SECTIONS[3] })

	x, y = 16 + COLUMN_W + 40, -52
	sectionList({ SECTIONS[4], SECTIONS[5] })

	section("Display")
	local sizeLabel, sizeButton = stepRow()
	local function sizeText() sizeLabel:SetText(string.format("Map icon size: %d%%", math.floor((ns.opt("mapPinScale") or 1) * 100 + 0.5))) end
	local function resize(delta)
		return function()
			local v = math.max(0.6, math.min(2, (ns.opt("mapPinScale") or 1) + delta))
			ns.setOpt("mapPinScale", math.floor(v * 10 + 0.5) / 10)
			sizeText()
		end
	end
	sizeButton("-", 54, resize(-0.1))
	sizeButton("+", 26, resize(0.1))

	local MARKERS = { [0] = "None", "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }
	local mLabel, mButton = stepRow()
	local mIcon = f:CreateTexture(nil, "OVERLAY")
	mIcon:SetSize(16, 16)
	mIcon:SetPoint("LEFT", mLabel, "RIGHT", 6, 0)
	local function markerText()
		local m = ns.opt("questTargetMarker") or 0
		mLabel:SetText("Target marker: " .. MARKERS[m])
		if m > 0 then mIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. m); mIcon:Show() else mIcon:Hide() end
	end
	local function marker(delta)
		return function()
			ns.setOpt("questTargetMarker", ((ns.opt("questTargetMarker") or 0) + delta) % 9)
			markerText()
		end
	end
	mButton("<", 54, marker(-1))
	mButton(">", 26, marker(1))

	local mm = check("Minimap icon")
	mm:SetScript("OnClick", function(self)
		local d = ns.db().minimap
		d.hide = not self:GetChecked()
		local icon = LibStub and LibStub("LibDBIcon-1.0", true)
		if icon then if d.hide then icon:Hide(ADDON_NAME) else icon:Show(ADDON_NAME) end end
	end)
	y = y - 10

	section("Key bindings")
	local function keyRow(txt, party)
		local l, button = stepRow(60)
		button("Set", 60, function() if ns.showBindPrompt then ns.showBindPrompt(party) end end)
		return function() l:SetText(txt .. ": " .. (ns.bindText and ns.bindText(party) or "Not set")) end
	end
	local mineKey = keyRow("Target mine", false)
	local partyKey = keyRow("Target party", true)
	local function keyText() mineKey(); partyKey() end
	ns.onBindChange = function() if f:IsVisible() then keyText() end end
	y = y - 10

	local ready = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
	ready:SetSize(COLUMN_W, 24)
	ready:SetPoint("TOPLEFT", x, y)
	ready:SetText("Quests ready to turn in")
	ready:SetScript("OnClick", function() ns.toggleReady() end)
	y = y - 34

	local hint = f:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	hint:SetPoint("TOPLEFT", x, y)
	hint:SetText("/qc copies what is open. /qc help for all commands.")

	f:HookScript("OnShow", function()
		for _, cb in ipairs(f.checks) do cb:SetChecked(ns.opt(cb.key) and true or false) end
		mm:SetChecked(not ns.db().minimap.hide)
		sizeText()
		markerText()
		keyText()
	end)
end

local category

function ns.toggleOptions()
	if SettingsPanel and Settings and Settings.OpenToCategory and category then
		if SettingsPanel:IsShown() and panel and panel:IsVisible() then
			HideUIPanel(SettingsPanel)
		else
			Settings.OpenToCategory(category:GetID())
		end
	elseif InterfaceOptionsFrame_OpenToCategory and panel then
		InterfaceOptionsFrame_OpenToCategory(panel)
		InterfaceOptionsFrame_OpenToCategory(panel)
	end
end

local menu
local function saveSnapshot() if SlashCmdList.AIQUESTHELPER then SlashCmdList.AIQUESTHELPER("save") end end
function ns.showMinimapMenu(owner)
	if MenuUtil and MenuUtil.CreateContextMenu then
		MenuUtil.CreateContextMenu(owner, function(_, root)
			root:CreateTitle("AI Quest Helper")
			root:CreateButton("Ready to turn in", function() ns.toggleReady() end)
			root:CreateButton("Copy gear (Ctrl+C)", function() if AIQuestHelper_Gear then AIQuestHelper_Gear() end end)
			root:CreateButton("Save snapshot (reload)", saveSnapshot)
			root:CreateButton("Settings", function() ns.toggleOptions() end)
		end)
		return
	end
	if not menu then
		menu = CreateFrame("Frame", "AIQuestHelperMinimapMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		menu:SetSize(170, 108)
		menu:SetFrameStrata("DIALOG")
		menu:EnableMouse(true)
		if menu.SetBackdrop then
			menu:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8", edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
			menu:SetBackdropColor(0.05, 0.05, 0.07, 0.95)
			menu:SetBackdropBorderColor(0.3, 0.3, 0.35, 1)
		end
		local function item(i, text, fn)
			local b = CreateFrame("Button", nil, menu)
			b:SetSize(162, 24)
			b:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 25)
			local hl = b:CreateTexture(nil, "HIGHLIGHT"); hl:SetAllPoints(); hl:SetColorTexture(1, 1, 1, 0.1)
			local t = b:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
			t:SetPoint("LEFT", 8, 0); t:SetText(text)
			b:SetScript("OnClick", function() menu:Hide(); fn() end)
		end
		item(1, "Ready to turn in", function() ns.toggleReady() end)
		item(2, "Copy gear (Ctrl+C)", function() if AIQuestHelper_Gear then AIQuestHelper_Gear() end end)
		item(3, "Save snapshot (reload)", saveSnapshot)
		item(4, "Settings", function() ns.toggleOptions() end)
		tinsert(UISpecialFrames, "AIQuestHelperMinimapMenu")
		menu:SetScript("OnUpdate", function(self)
			if not self:IsMouseOver(20, -20, -20, 20) and not (owner and owner:IsMouseOver()) then
				self.away = (self.away or 0) + 1
				if self.away > 60 then self:Hide() end
			else
				self.away = 0
			end
		end)
	end
	menu:ClearAllPoints()
	menu:SetPoint("TOPRIGHT", owner or UIParent, "BOTTOMLEFT", 0, 0)
	menu.away = 0
	menu:SetShown(not menu:IsShown())
end

local function setupMinimap()
	local LDB = LibStub and LibStub("LibDataBroker-1.1", true)
	local icon = LibStub and LibStub("LibDBIcon-1.0", true)
	if not (LDB and icon) or icon:IsRegistered(ADDON_NAME) then return end
	local obj = LDB:NewDataObject(ADDON_NAME, {
		type = "launcher",
		text = "AI Quest Helper",
		icon = ICON,
		OnClick = function(_, button)
			if button == "RightButton" then
				ns.showMinimapMenu(_)
			else
				ns.toggleOptions()
			end
		end,
		OnTooltipShow = function(tt)
			tt:AddLine("AI Quest Helper")
			tt:AddLine("Left-click: settings", 1, 1, 1)
			tt:AddLine("Right-click: menu (ready to turn in, save snapshot, settings)", 1, 1, 1)
		end,
	})
	icon:Register(ADDON_NAME, obj, ns.db().minimap)
end

local function setupBlizzardPanel()
	panel = CreateFrame("Frame")
	panel.name = "AI Quest Helper"
	build(panel)
	if Settings and Settings.RegisterCanvasLayoutCategory then
		category = Settings.RegisterCanvasLayoutCategory(panel, "AI Quest Helper")
		Settings.RegisterAddOnCategory(category)
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	pcall(setupMinimap)
	pcall(setupBlizzardPanel)
end)
