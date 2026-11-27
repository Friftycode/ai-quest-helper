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

local LEFT, TOP, ROW, CONTROL_X = 20, -96, 28, 300

local function newPage(parent)
	local page = CreateFrame("Frame", nil, parent)
	page:SetPoint("TOPLEFT")
	page:SetPoint("BOTTOMRIGHT")
	page:Hide()
	page.y = TOP
	page.refresh = {}
	return page
end

local function heading(page, text)
	local h = page:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	h:SetPoint("TOPLEFT", LEFT, page.y)
	h:SetText(text)
	page.y = page.y - 24
end

local function check(page, label, get, set)
	local cb = CreateFrame("CheckButton", nil, page, "UICheckButtonTemplate")
	cb:SetSize(24, 24)
	cb:SetPoint("TOPLEFT", LEFT - 4, page.y + 2)
	local text = cb.Text or cb.text or cb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	text:ClearAllPoints()
	text:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	text:SetFontObject("GameFontHighlight")
	text:SetText(label)
	cb:SetScript("OnClick", function(self) set(self:GetChecked() and true or false) end)
	page.refresh[#page.refresh + 1] = function() cb:SetChecked(get() and true or false) end
	page.y = page.y - ROW
end

local function optionChecks(page, list)
	for _, item in ipairs(list) do
		local key = item[1]
		check(page, item[2], function() return ns.opt(key) end, function(v) ns.setOpt(key, v) end)
	end
	page.y = page.y - 8
end

-- A label with buttons to its right on the same line; returns the label.
local function controlRow(page, buttons)
	local l = page:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	l:SetPoint("TOPLEFT", LEFT, page.y - 4)
	local x = CONTROL_X
	for _, b in ipairs(buttons) do
		local btn = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
		btn:SetSize(b.width or 26, 22)
		btn:SetPoint("TOPLEFT", x, page.y)
		btn:SetText(b.text)
		btn:SetScript("OnClick", b.click)
		x = x + (b.width or 26) + 4
	end
	page.y = page.y - ROW - 4
	return l
end

local MARKERS = { [0] = "None", "Star", "Circle", "Diamond", "Triangle", "Moon", "Square", "Cross", "Skull" }

local function buildGeneral(page)
	heading(page, "General")
	check(page, "Minimap icon", function() return not ns.db().minimap.hide end, function(v)
		ns.db().minimap.hide = not v
		local icon = LibStub and LibStub("LibDBIcon-1.0", true)
		if icon then if v then icon:Show(ADDON_NAME) else icon:Hide(ADDON_NAME) end end
	end)
	page.y = page.y - 8
	heading(page, SECTIONS[5][1])
	optionChecks(page, SECTIONS[5][2])
	local hint = page:CreateFontString(nil, "OVERLAY", "GameFontDisable")
	hint:SetPoint("TOPLEFT", LEFT, page.y - 8)
	hint:SetText("/qc copies what is open. /qc help lists all commands.")
end

local function buildCopy(page)
	heading(page, SECTIONS[1][1])
	optionChecks(page, SECTIONS[1][2])
	heading(page, SECTIONS[3][1])
	optionChecks(page, SECTIONS[3][2])
end

local function buildMap(page)
	heading(page, SECTIONS[2][1])
	optionChecks(page, SECTIONS[2][2])
	local function resize(delta)
		return function()
			local v = math.max(0.6, math.min(2, (ns.opt("mapPinScale") or 1) + delta))
			ns.setOpt("mapPinScale", math.floor(v * 10 + 0.5) / 10)
			page.sizeText()
		end
	end
	local label = controlRow(page, { { text = "-", click = resize(-0.1) }, { text = "+", click = resize(0.1) } })
	page.sizeText = function()
		label:SetText(string.format("Map icon size: %d%%", math.floor((ns.opt("mapPinScale") or 1) * 100 + 0.5)))
	end
	page.refresh[#page.refresh + 1] = page.sizeText
end

local function buildQuests(page)
	heading(page, SECTIONS[4][1])
	optionChecks(page, SECTIONS[4][2])

	local icon = page:CreateTexture(nil, "OVERLAY")
	icon:SetSize(16, 16)
	local function marker(delta)
		return function()
			ns.setOpt("questTargetMarker", ((ns.opt("questTargetMarker") or 0) + delta) % 9)
			page.markerText()
		end
	end
	local label = controlRow(page, { { text = "<", click = marker(-1) }, { text = ">", click = marker(1) } })
	icon:SetPoint("LEFT", label, "RIGHT", 6, 0)
	page.markerText = function()
		local m = ns.opt("questTargetMarker") or 0
		label:SetText("Target marker: " .. MARKERS[m])
		if m > 0 then icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_" .. m); icon:Show() else icon:Hide() end
	end
	page.refresh[#page.refresh + 1] = page.markerText
	page.y = page.y - 8

	heading(page, "Key bindings")
	local function keyRow(text, party)
		local l = controlRow(page, { { text = "Set", width = 60, click = function() if ns.showBindPrompt then ns.showBindPrompt(party) end end } })
		return function() l:SetText(text .. ": " .. (ns.bindText and ns.bindText(party) or "Not set")) end
	end
	local mine, party = keyRow("Target mine", false), keyRow("Target party", true)
	local function keyText() mine(); party() end
	page.refresh[#page.refresh + 1] = keyText
	ns.onBindChange = function() if page:IsVisible() then keyText() end end
	page.y = page.y - 8

	local ready = CreateFrame("Button", nil, page, "UIPanelButtonTemplate")
	ready:SetSize(240, 24)
	ready:SetPoint("TOPLEFT", LEFT, page.y)
	ready:SetText("Quests ready to turn in")
	ready:SetScript("OnClick", function() ns.toggleReady() end)
end

local TABS = {
	{ "General", buildGeneral },
	{ "Copy", buildCopy },
	{ "Map", buildMap },
	{ "Quests", buildQuests },
}

local function build(f)
	local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
	title:SetPoint("TOPLEFT", LEFT, -16)
	title:SetText("AI Quest Helper")

	local pages, buttons, current = {}, {}, 1
	local function select(index)
		for k, page in ipairs(pages) do
			local on = k == index
			page:SetShown(on)
			buttons[k].label:SetTextColor(on and 1 or 0.6, on and 0.82 or 0.6, on and 0 or 0.6)
			buttons[k].underline:SetShown(on)
		end
		for _, fn in ipairs(pages[index].refresh) do fn() end
		current = index
	end

	local x = LEFT
	for k, tab in ipairs(TABS) do
		local b = CreateFrame("Button", nil, f)
		b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
		b.label:SetPoint("CENTER", 0, 2)
		b.label:SetText(tab[1])
		local w = math.max(70, b.label:GetStringWidth() + 32)
		b:SetSize(w, 30)
		b:SetPoint("BOTTOMLEFT", f, "TOPLEFT", x, -82)
		local hl = b:CreateTexture(nil, "HIGHLIGHT")
		hl:SetColorTexture(1, 1, 1, 0.06)
		hl:SetAllPoints()
		b.underline = b:CreateTexture(nil, "OVERLAY")
		b.underline:SetColorTexture(1, 0.82, 0, 1)
		b.underline:SetHeight(2)
		b.underline:SetPoint("BOTTOMLEFT", 6, 0)
		b.underline:SetPoint("BOTTOMRIGHT", -6, 0)
		b:SetScript("OnClick", function() select(k) end)
		buttons[k] = b
		x = x + w + 4
		local page = newPage(f)
		tab[2](page)
		pages[k] = page
	end

	local line = f:CreateTexture(nil, "ARTWORK")
	line:SetColorTexture(1, 1, 1, 0.15)
	line:SetHeight(1)
	line:SetPoint("TOPLEFT", LEFT, -82)
	line:SetPoint("TOPRIGHT", -LEFT, -82)

	f:HookScript("OnShow", function() select(current) end)
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
			root:CreateButton("Save snapshot (reload)", saveSnapshot)
			root:CreateButton("Settings", function() ns.toggleOptions() end)
		end)
		return
	end
	if not menu then
		menu = CreateFrame("Frame", "AIQuestHelperMinimapMenu", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
		menu:SetSize(170, 83)
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
		item(2, "Save snapshot (reload)", saveSnapshot)
		item(3, "Settings", function() ns.toggleOptions() end)
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
