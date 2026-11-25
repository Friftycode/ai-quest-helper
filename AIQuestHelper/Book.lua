local _, ns = ...
local call, shown = ns.call, ns.shown

local pages, title = {}, nil

local function stripHtml(s)
	if type(s) ~= "string" then return s end
	s = s:gsub("<[Bb][Rr]%s*/?>", "\n"):gsub("</[Pp]>", "\n"):gsub("</?[Hh]%d[^>]*>", "\n")
	s = s:gsub("<[^>]->", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">"):gsub("&quot;", '"')
	return (s:gsub("\n\n\n+", "\n\n"))
end

local function cachePage()
	local page = call(ItemTextGetPage) or 1
	local text = call(ItemTextGetText)
	if text and text ~= "" then pages[page] = stripHtml(text) end
	title = call(ItemTextGetItem) or title
end

function ns.fromItemText()
	if not shown(ItemTextFrame) then return nil end
	cachePage()
	local maxPage = 0
	for p in pairs(pages) do if p > maxPage then maxPage = p end end
	local doc = ns.newDoc()
	doc.add(title)
	for p = 1, maxPage do
		if pages[p] then doc.add(pages[p], maxPage > 1 and ("Page " .. p .. ":") or nil) end
	end
	if call(ItemTextHasNextPage) then doc.add("(More pages: turn the page and they will be included.)") end
	return doc.result()
end

local events = CreateFrame("Frame")
events:RegisterEvent("ITEM_TEXT_BEGIN")
events:RegisterEvent("ITEM_TEXT_READY")
events:SetScript("OnEvent", function(_, event)
	if event == "ITEM_TEXT_BEGIN" then
		pages, title = {}, nil
	else
		cachePage()
	end
end)
