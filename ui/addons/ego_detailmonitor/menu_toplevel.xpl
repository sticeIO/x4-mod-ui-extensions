-- ffi setup
local ffi = require("ffi")
local C = ffi.C
ffi.cdef[[
	void SetTrackedMenuFullscreen(const char* menu, bool fullscreen);
]]

local menu = {
	name = "TopLevelMenu",
	mouseOutBox = {},
}

local config = {
	width = Helper.sidebarWidth,
	height = Helper.sidebarWidth,
	offsetY = 0,
	layer = 2,
	mouseOutRange = 100,
}

-- kuertee start:
menu.callbacks = {}
-- end

local function init()
	Menus = Menus or { }
	table.insert(Menus, menu)
	if Helper then
		Helper.registerMenu(menu)
	end

	menu.init = true
	registerForEvent("gameplanchange", getElement("Scene.UIContract"), menu.onGamePlanChange)
	RegisterEvent("playerUndocked", menu.playerUndocked)

	-- kuertee start:
	menu.init_kuertee()
	kHUD.init()
	-- kuertee end
end

-- kuertee start:
function menu.init_kuertee ()
	menu.loadModLuas()
	-- if Helper.modLuas[menu.name] then
	-- 	if not next(Helper.modLuas[menu.name].failedByExtension) then
	-- 		DebugError("uix init success: " .. tostring(debug.getinfo(1).source))
	-- 	else
	-- 		for extension, modLua in pairs(Helper.modLuas[menu.name].failedByExtension) do
	-- 			DebugError("uix init failed: " .. tostring(debug.getinfo(modLua.init).source):gsub("@.\\", ""))
	-- 		end
	-- 	end
	-- else
		DebugError("uix load success: " .. tostring(debug.getinfo(1).source))
	-- end
end
-- kuertee end

function menu.onGamePlanChange(_, mode)
	if menu.init then
		if (mode == "cockpit") or (mode == "external") then
			local occupiedship = ConvertStringTo64Bit(tostring(C.GetPlayerOccupiedShipID()))
			if (occupiedship ~= 0) and (not GetComponentData(occupiedship, "isdocked")) then
				OpenMenu("TopLevelMenu", { 0, 0 }, nil)
			end
			menu.init = nil
		elseif (mode == "firstperson") or (mode == "externalfirstperson") then
			menu.init = nil
		end
	else
		if (mode == "firstperson") or (mode == "externalfirstperson") then
			if menu.shown then
				menu.close()
			end
		end
	end
end

function menu.playerUndocked()
	local occupiedship = ConvertStringTo64Bit(tostring(C.GetPlayerOccupiedShipID()))
	if (occupiedship ~= 0) and (not GetComponentData(occupiedship, "isdocked")) then
		OpenMenu("TopLevelMenu", { 0, 0 }, nil)
	end
end

function menu.cleanup()
	menu.infoFrame = nil

	menu.showTabs = nil
	menu.over = nil
	menu.mouseOutBox = {}

	if menu.hasRegistered then
		unregisterForEvent("inputModeChanged", getElement("Scene.UIContract"), menu.onInputModeChanged)
		menu.hasRegistered = nil
	end

	-- kuertee start: callback
	if menu.callbacks ["cleanup"] then
		for _, callback in ipairs (menu.callbacks ["cleanup"]) do
			callback()
		end
	end
	-- kuertee end: callback
end

function menu.buttonShowTopLevel()
	menu.showTabs = true
	menu.refresh = getElapsedTime()
end

-- Menu member functions

function menu.onShowMenu()
	C.SetTrackedMenuFullscreen(menu.name, false)
	menu.width = Helper.scaleX(config.width)
	menu.height = Helper.scaleX(config.height)

	-- display info
	menu.createInfoFrame()
end

function menu.createInfoFrame()
	-- remove old data
	Helper.clearDataForRefresh(menu, config.infoLayer)

	local frameProperties = {
		standardButtons = {},
		width = menu.width + 2 * Helper.borderSize,
		x = (Helper.viewWidth - menu.width) / 2,
		y = Helper.scaleY(config.offsetY),
		layer = config.layer,
		startAnimation = false,
		playerControls = true,
		useMiniWidgetSystem = (not menu.showTabs) and (not menu.over),
		enableDefaultInteractions = false,
	}

	menu.infoFrame = Helper.createFrameHandle(menu, frameProperties)

	-- kuertee start: callback
	if menu.callbacks ["createInfoFrame_on_create_frame"] then
		for _, callback in ipairs (menu.callbacks ["createInfoFrame_on_create_frame"]) do
			callback (menu.infoFrame)
		end
	end
	-- kuertee end: callback

	local tableProperties = {
		width = menu.width,
		x = Helper.borderSize,
		y = Helper.borderSize,
	}
	
	if menu.showTabs then
		if not menu.hasRegistered then
			menu.hasRegistered = true
			Helper.setTabScrollCallback(menu, menu.onTabScroll)
			registerForEvent("inputModeChanged", getElement("Scene.UIContract"), menu.onInputModeChanged)
		end

		menu.infoFrame.properties.width = Helper.viewWidth
		menu.infoFrame.properties.x = 0
		menu.topLevelHeight, menu.topLevelWidth = Helper.createTopLevelTab(menu, "", menu.infoFrame, "", nil, nil, true)
		menu.infoFrame.properties.height = menu.topLevelHeight + Helper.borderSize

		menu.mouseOutBox = {
			x1 = - menu.topLevelWidth / 2                    - config.mouseOutRange,
			x2 =   menu.topLevelWidth / 2                    + config.mouseOutRange,
			y1 = Helper.viewHeight / 2,
			y2 = Helper.viewHeight / 2 - menu.topLevelHeight - config.mouseOutRange
		}
	else
		if menu.hasRegistered then
			Helper.removeAllTabScrollCallbacks(menu)
			unregisterForEvent("inputModeChanged", getElement("Scene.UIContract"), menu.onInputModeChanged)
			menu.hasRegistered = nil
		end
		local ftable = menu.createTable(menu.infoFrame, tableProperties)
		menu.infoFrame.properties.height = ftable.properties.y + ftable:getVisibleHeight() + Helper.borderSize

		-- kuertee start: callback
		if menu.callbacks ["createInfoFrame_on_add_table"] then
			for _, callback in ipairs (menu.callbacks ["createInfoFrame_on_add_table"]) do
				callback (menu.infoFrame, ftable)
			end
		end
		-- kuertee end: callback
	end

	-- kuertee start: callback
	if menu.callbacks ["createInfoFrame_on_before_frame_display"] then
		for _, callback in ipairs (menu.callbacks ["createInfoFrame_on_before_frame_display"]) do
			callback (menu.infoFrame)
		end
	end
	-- kuertee end: callback

	menu.infoFrame:display()

	-- kuertee start: callback
	if menu.callbacks ["createInfoFrame_on_display_frame"] then
		for _, callback in ipairs (menu.callbacks ["createInfoFrame_on_display_frame"]) do
			callback (menu.infoFrame)
		end
	end
	-- kuertee end: callback
end


function menu.createTable(frame, tableProperties)
	local ftable = frame:addTable(1, { tabOrder = menu.over and 1 or 0, width = tableProperties.width, x = tableProperties.x, y = tableProperties.y })

	if menu.over then
		local row = ftable:addRow(true, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:createButton({ width = config.width, height = config.height, bgColor = Helper.color.transparent, highlightColor = Helper.color.transparent }):setText("\27[tlt_arrow]", { color = { r = 128, g = 196, b = 255, a = 100 }, halign = "center", fontsize = 18, x = 0, y = 5 })
		row[1].handlers.onClick = menu.buttonShowTopLevel
	else
		local row = ftable:addRow(false, { fixed = true, bgColor = Helper.color.transparent })
		row[1]:createText("\27[tlt_arrow]", { width = config.width, height = config.height, color = { r = 64, g = 98, b = 128, a = 100 }, halign = "center", fontsize = 18, x = 0, y = 0 })
	end

	return ftable
end

function menu.onTabScroll(direction)
	Helper.scrollTopLevel(menu, "playerinfo", 1)
end

function menu.onInputModeChanged(_, mode)
	menu.createInfoFrame()
end

function menu.viewCreated(layer, ...)
end

-- update
menu.updateInterval = 0.1

function menu.onUpdate()
	if menu.showTabs and next(menu.mouseOutBox) then
		if (GetControllerInfo() ~= "gamepad") or (C.IsMouseEmulationActive()) then
			local curpos = table.pack(GetLocalMousePosition())
			if curpos[1] and ((curpos[1] < menu.mouseOutBox.x1) or (curpos[1] > menu.mouseOutBox.x2)) then
				menu.closeTabs()
			elseif curpos[2] and ((curpos[2] > menu.mouseOutBox.y1) or (curpos[2] < menu.mouseOutBox.y2)) then
				menu.closeTabs()
			end
		end
	end

	local curtime = getElapsedTime()

	-- kuertee start: callback
	if menu.callbacks ["onUpdate_start"] then
		for _, callback in ipairs (menu.callbacks ["onUpdate_start"]) do
			callback(curtime)
		end
	end
	-- kuertee end: callback

	if menu.lock and (menu.lock + 0.11 < curtime) then
		menu.lock = nil
	end

	if menu.over and (not menu.lock) then
		if (GetControllerInfo() ~= "gamepad") or (C.IsMouseEmulationActive()) then
			local mouseOutBox = {
				x1 = - menu.width / 2,
				x2 =   menu.width / 2,
				y1 = Helper.viewHeight / 2,
				y2 = Helper.viewHeight / 2 - menu.infoFrame.properties.height,
			}

			local curpos = table.pack(GetLocalMousePosition())
			if curpos[1] and ((curpos[1] < mouseOutBox.x1) or (curpos[1] > mouseOutBox.x2)) then
				menu.over = false
				menu.lock = getElapsedTime()
				menu.createInfoFrame()
				return
			elseif curpos[2] and ((curpos[2] > mouseOutBox.y1) or (curpos[2] < mouseOutBox.y2)) then
				menu.over = false
				menu.lock = getElapsedTime()
				menu.createInfoFrame()
				return
			end
		end
	end

	if menu.refresh and menu.refresh <= curtime then
		menu.createInfoFrame()
		menu.refresh = nil
		return
	end

	-- kuertee start: callback
	if menu.callbacks ["onUpdate_before_frame_update"] then
		for _, callback in ipairs (menu.callbacks ["onUpdate_before_frame_update"]) do
			callback (menu.infoFrame)
		end
	end
	-- kuertee end: callback

	menu.infoFrame:update()

	-- kuertee start: callback
	if menu.callbacks ["onUpdate"] then
		for _, callback in ipairs (menu.callbacks ["onUpdate"]) do
			callback (menu.infoFrame)
		end
	end
	-- kuertee end: callback
end

function menu.onTableMouseOut(uitable, row)
	Helper.debugText_forced("menu.onTableMouseOut")
	if (not menu.showTabs) and (not menu.lock) then
		menu.over = false
		menu.lock = getElapsedTime()
		menu.createInfoFrame()
	end
end

function menu.onTableMouseOver(uitable, row)
	Helper.debugText_forced("menu.onTableMouseOver")
	if (not menu.showTabs) and (not menu.lock) then
		menu.over = true
		menu.lock = getElapsedTime()
		menu.createInfoFrame()
	end
end

function menu.onRowChanged(row, rowdata, uitable)
end

function menu.onSelectElement(uitable, modified, row)
end

function menu.close()
	Helper.closeMenu(menu, "close")
	menu.cleanup()
end

function menu.closeTabs()
	menu.showTabs = nil
	menu.over = nil
	menu.lock = getElapsedTime()
	menu.refresh = getElapsedTime()
end

function menu.onCloseElement(dueToClose, layer)
	if menu.showTabs then
		menu.closeTabs()
	elseif layer == nil then
		Helper.closeMenu(menu, dueToClose)
		menu.cleanup()
	else
		Helper.closeMenuAndOpenNewMenu(menu, "OptionsMenu", nil)
		menu.cleanup()
	end
end

-- menu helpers

-- kuertee custom HUD start:
-- note that custom HUD elements are only shown when the TopLevelMenu is collapsed.
-- to add custom HUD elements, add these in your lua file:
-- as an example, review "ui\menu_toplevel_uix.lua" of the kuertee_alternatives_to_death mod
-- 1. topLevelMenu.registerCallback("kHUD_get_is_create_HUD_frame", YourMenu.kHUD_get_is_create_HUD_frame)
-- 2. function YourMenu.kHUD_get_is_create_HUD_frame() return true|false depending on whether your custom HUD should be shown or not end
-- 3. topLevelMenu.registerCallback("kHUD_add_HUD_tables", YourMenu.kHUD_add_HUD_tables)
-- 4. function YourMenu.kHUD_add_HUD_tables(frame) local ftable = frame:addTable(); local row = ftable:addRow(); etc.; end
kHUD = {
	name = "kHUD",
	refresh = 0,
}

function kHUD.init()
    Menus = Menus or {}
    table.insert(Menus, kHUD)
    if Helper then
        Helper.registerMenu(kHUD)
    end
	menu.registerCallback ("createInfoFrame_on_display_frame", kHUD.OpenOrClose)
end

function kHUD.getIsOpenOrClose()
	local isCreateHUDFrame
	if isCreateHUDFrame ~= true then
		if menu.callbacks["kHUD_get_is_create_HUD_frame"] and #menu.callbacks["kHUD_get_is_create_HUD_frame"] > 0 then
			for i, callback in ipairs (menu.callbacks ["kHUD_get_is_create_HUD_frame"]) do
				isCreateHUDFrame = callback ()
				if isCreateHUDFrame == true then
					break
				end
			end
		end
	end
	Helper.debugText_forced("kHUD.getIsOpenOrClose isCreateHUDFrame", isCreateHUDFrame)
	return isCreateHUDFrame
end

function kHUD.OpenOrClose()
	if kHUD.getIsOpenOrClose() then
		if not kHUD.frame then
			Helper.debugText_forced("kHUD.OpenOrClose OpenMenu")
			OpenMenu("kHUD", { 0, 0 }, nil)
		end
	elseif kHUD.frame then
		Helper.debugText_forced("kHUD.OpenOrClose onCloseElement")
		kHUD.onCloseElement("close")
	end
end

function kHUD.cleanup()
	Helper.debugText_forced("kHUD.cleanUp")
	kHUD.frame = nil
end

function kHUD.onShowMenu()
	Helper.debugText_forced("kHUD.onShowMenu")
	kHUD.display()
end

function kHUD.onCloseElement(dueToClose, allowAutoMenu)
	if kHUD.frame then
		Helper.debugText_forced("kHUD.onCloseElement")
		Helper.closeMenu(kHUD, dueToClose)
		kHUD.cleanup()
	end
end

function kHUD.onUpdate()
	if kHUD.frame then
		Helper.debugText("kHUD.onUpdate")
		local curtime = getElapsedTime()
		if kHUD.refresh and kHUD.refresh <= curtime then
			if kHUD.getIsOpenOrClose() then
				kHUD.display()
			else
				kHUD.onCloseElement("close")
			end
			kHUD.refresh = nil
			return
		end

		kHUD.frame:update()
	end
end

function kHUD.display()
	Helper.debugText_forced("kHUD.display")
	kHUD.createFrame()
	kHUD.createTables()
	kHUD.frame:display()
end

function kHUD.createFrame()
	Helper.debugText_forced("createFrame menu.infoFrame", tostring(menu.infoFrame))
	Helper.clearDataForRefresh(kHUD, kHUD.layer)
	-- value names from Helper.defaultWidgetProperties.frame
	local frameProperties = {
		x = 0,
		y = config.offsetY + 50,
		exclusiveInteractions = false,
		-- backgroundColor = "solid",
		-- backgroundColor = Helper.color.white,
		standardButtons = {},
		autoFrameHeight = true,
		playerControls = true,
		startAnimation = false,
		enableDefaultInteractions = false,
		useMiniWidgetSystem = false,
	}
	kHUD.frame = Helper.createFrameHandle(kHUD, frameProperties)
	-- Helper.debugText_forced("display kHUD.frame.properties", kHUD.frame.properties)
end

function kHUD.createTables()
	local frame_useThis = kHUD.frame
	-- local frame_useThis = menu.infoFrame
	if frame_useThis then
		-- if frame_useThis == kHUD.frame then
		-- 	frame_useThis.properties.y = menu.infoFrame.properties.y + menu.infoFrame.properties.height
		-- end
		local ftables_created = {}
		if menu.callbacks["kHUD_add_HUD_tables"] and #menu.callbacks["kHUD_add_HUD_tables"] > 0 then
			for i, callback in ipairs (menu.callbacks ["kHUD_add_HUD_tables"]) do
				local ftables = callback (frame_useThis)
				if ftables and type(ftables) == "table" and #ftables > 0 then
					for j, ftable in ipairs(ftables) do
						table.insert(ftables_created, ftable)
					end
				end
			end
		end
		if false and #ftables_created < 1 then
			-- set to true to force a row for testing
			local ftable = frame_useThis:addTable(1)
			local row = ftable:addRow()
			row[1]:createText("kHUD")
		end
		-- kHUD.updateFrameHeight(frame_useThis)
	end
end

function kHUD.updateFrameHeight (frame)
	local y_tableBottom = 0
	local ftable
	local y_max = 0
	for i = 1, #frame.content do
		if frame.content [i].type == "table" then
			ftable = frame.content [i]
			local visibleHeight = ftable:getVisibleHeight ()
			Helper.debugText_forced("visibleHeight", visibleHeight)
			y_tableBottom = ftable.properties.y + visibleHeight
			if y_tableBottom > y_max then
				y_max = y_tableBottom
			end
		end
	end
	Helper.debugText_forced("updateFrameHeight frame.properties.y", frame.properties.y)
	Helper.debugText_forced("updateFrameHeight y_max", y_max)
	Helper.debugText_forced("updateFrameHeight frame.properties.height (pre set)", frame.properties.height)
	if frame.properties.height ~= y_max then
		frame.properties.height = y_max
	end
	Helper.debugText_forced("updateFrameHeight frame.properties.height", frame.properties.height)
end
-- kuertee custom HUD end

-- kuertee start:
function menu.requestUpdate (adj)
	if adj == nil then
		adj = 0
	end
	if menu.refresh == nil then
		menu.refresh = getElapsedTime () + adj
	end
	if kHUD.frame then
		if kHUD.refresh == nil then
			kHUD.refresh = getElapsedTime () + adj
		end
	end
end

function menu.registerCallback (callbackName, callbackFunction)
	-- note 1: format is generally [function name]_[action]. e.g.: in kuertee_menu_transporter, "display_on_set_room_active" overrides the room's active property with the return of the callback.
	-- note 2: events have the word "_on_" followed by a PRESET TENSE verb. e.g.: in kuertee_menu_transporter, "display_on_set_buttontable" is called after all of the rows of buttontable are set.
	-- note 3: new callbacks can be added or existing callbacks can be edited. but commit your additions/changes to the mod's GIT repository.
	-- note 4: search for the callback names to see where they are executed.
	-- note 5: if a callback requires a return value, return it in an object var. e.g. "display_on_set_room_active" requires a return of {active = true | false}.

	-- to find callbacks available for this menu,
	-- reg-ex search for callbacks.*\[\".*\]

	if menu.callbacks [callbackName] == nil then
		menu.callbacks [callbackName] = {}
	end
	table.insert (menu.callbacks [callbackName], callbackFunction)
end

function menu.deregisterCallback(callbackName, callbackFunction)
	-- for i, callback in ipairs(callbacks[callbackName]) do
	if callbacks[callbackName] and #callbacks[callbackName] > 0 then
		for i = #callbacks[callbackName], 1, -1 do
			if callbacks[callbackName][1] == callbackFunction then
				table.remove(callbacks[callbackName], i)
			end
		end
	end
end

function menu.loadModLuas()
	if Helper then
		Helper.loadModLuas(menu.name, "menu_toplevel_uix")
	end
end
-- kuertee end

init()
