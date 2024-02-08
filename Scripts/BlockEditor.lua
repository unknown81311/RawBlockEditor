dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_constants.lua" )

--[[

trying to write the most optimal code we can.

]]--

blockEditor = class()


-- animation
local renderables = {
	"$CONTENT_DATA/Animations/Char_Tools/Char_connecttool/char_connecttool.rend"
}

local renderablesTp = {
	"$CONTENT_DATA/Animations/Char_Male/Animations/char_male_tp_connecttool.rend",
	"$CONTENT_DATA/Animations/Char_Tools/Char_connecttool/char_connecttool_tp_animlist.rend"
}
local renderablesFp = {
	"$CONTENT_DATA/Animations/Char_Tools/Char_connecttool/char_connecttool_fp_animlist.rend"
}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )


--vars
local localPlayer = sm.localPlayer

local multiSelectTime = 0.5
local bodySelectTime = 1.5

local commentC = 	"#A6ACB9"
local stringTextC = "#99C794"
local defaultC = 	"#eeeeee"
local numC = 		"#6699CC"
local boolC = 		"#EC6066"
local toolColor = 	"0079FF"

local PlasticBLK = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")

local jointType = "joint"
local bodyType = "body"

local selectText = "<p textShadow='true' bg='gui_keybinds_bg' color='#ffffff' spacing='5'>" .. sm.gui.getKeyBinding( "Create", true ) .. "To edit selected</p>"
local multiSelectText = "<p textShadow='true' bg='gui_keybinds_bg' color='#ffffff' spacing='5'> Hold" .. sm.gui.getKeyBinding( "Create", true ) .. "To multiselect</p>"
local repeateText = "<p textShadow='true' bg='gui_keybinds_bg' color='#ffffff' spacing='5'>" .. sm.gui.getKeyBinding( "ForceBuild", true ) .. "To execute last change</p>"

local A = stringTextC .. '"'
local B = '"' .. defaultC .. ': ' .. stringTextC .. '"'
local C = '"' .. defaultC ..  ': '
local D = '"' .. defaultC ..  ': ' .. stringTextC ..'"'
local E = stringTextC .. '"' .. stringTextC
local F = defaultC ..  ",\n"
local G = stringTextC .. '"\n'
local H = C .. numC
local I = '"' .. F
local J = " ".. commentC .. "// SHAPE "
local K = " ".. commentC .. "// JOINT "

local ___shapeIndex = 0

-- functions
function beatifyTable(Json, index, shapeIndex)
	if index == 1 then
		___shapeIndex = 0
	end
    local len = #Json
    local str = (len == 0 and "{" or "[")

    local keys = {}
    for key, _ in pairs(Json) do
      table.insert(keys, key)
    end
    table.sort(keys)

	if Json["shapeId"] then
    	___shapeIndex = ___shapeIndex + 1
    	if Json["childA"] then
    		str = str .. K .. tostring(___shapeIndex)
    	else
    		str = str .. J .. tostring(___shapeIndex)
    	end
    end
	str = str .. "\n"

    for _,i in ipairs(keys) do
      local v = Json[i]
        if type(v) == "table" then
            if type(i) == "number" then
                if next(keys, _) == nil then
                    str = str ..  ("\t"):rep(index) .. beatifyTable(v,index+1,shapeIndex)  .. "\n"
                else
                    str = str ..  ("\t"):rep(index) .. beatifyTable(v,index+1,shapeIndex)  .. F
                end
            else
                if next(keys, _) == nil then
                    str = str .. ("\t"):rep(index) .. E .. i .. C .. beatifyTable(v,index+1,shapeIndex)  .. "\n"
                else
                    str = str .. ("\t"):rep(index) .. E .. i .. C .. beatifyTable(v,index+1,shapeIndex)  .. ",\n"
                end
            end
        else
            if next(keys, _) == nil then
                if type(v) == "number" then
                    str = str .. ("\t"):rep(index) .. A .. i .. H .. tostring(v) .. "\n"
                else
                    str = str .. ("\t"):rep(index) .. A .. i .. D .. tostring(v) .. G
                end
            else
                if type(v) == "number" then
                    str = str .. ("\t"):rep(index) .. A .. i .. H .. tostring(v) .. F
                else
                    str = str .. ("\t"):rep(index) .. A .. i .. B .. tostring(v) .. I
                end
            end
        end
    end
    str = str .. ("\t"):rep(index-1) .. defaultC .. (len == 0 and "}" or "]")
    return str
end

function lineTo(p1, p2, effect)
	local width, height = sm.gui.getScreenSize()
	local factor = width / 16 --just an offset for the effect to actually show up 
	local x1, y1 = sm.render.getScreenCoordinatesFromWorldPosition(p1, width, height)
	local x2, y2 = sm.render.getScreenCoordinatesFromWorldPosition(p2, width, height)
	    
	x1=x1/factor
	x2=x2/factor

	y1=(height/factor)-(y1/factor)
	y2=(height/factor)-(y2/factor)

	local dist = sm.vec3.new(x1, 0, y1) - sm.vec3.new(x2, 0, y2)
	effect:setRotation(sm.vec3.getRotation(sm.vec3.new(0, 0, 1), dist))
	effect:setScale(sm.vec3.new(0.02, 0.1, dist:length()))
	effect:setPosition(sm.vec3.new(x1, 0, y1) - dist * 0.5)
end

local function raycast()
	local camP = sm.camera.getPosition()
	return sm.physics.raycast(camP, camP + sm.camera.getDirection() * 7.5, localPlayer.getPlayer().character, 4099)
end

function getShapeIndex( shape, body )
	local shapes = body:getShapes()
	for i,v in ipairs(shapes) do
		if v.id == shape.id then
			return i
		end
	end
	return 0
end

function getJointIndex( joint, body )
	local joints = body:getCreationJoints()
	local function compareTables(joint1, joint2)
		return joint1.id < joint2.id
	end

	table.sort(joints, compareTables)

	for i,v in ipairs(joints) do
		if v.id == joint.id then return i end
	end
end

function partOf(table, item)	
	for i, k in pairs(table) do
		if k == item then
			return true, i
		end
	end
	return false
end


local function splitString(input, size)
    local parts = {}
    local length = string.len(input)

    local start = 1
    while start <= length do
        local chunk = string.sub(input, start, start + size - 1)
        table.insert(parts, chunk)
        start = start + size
    end

    return parts
end


-- stripped from brench blueprint editor, converted to lua
function SetBlueprintRotation(xaxis, zaxis)
    local xAbs = math.abs(xaxis)
    local zAbs = math.abs(zaxis)
    local xSign = xaxis > 0 and 1 or -1
    local zSign = zaxis > 0 and 1 or -1

    local right = sm.vec3.new(xAbs == 1 and xSign or 0, xAbs == 3 and xSign or 0, xAbs == 2 and xSign or 0)
    local up = sm.vec3.new(zAbs == 1 and zSign or 0, zAbs == 3 and zSign or 0, zAbs == 2 and zSign or 0)

    local forward = right:cross(up)

    gameObject.transform.rotation = sm.quat.LookRotation(forward, up)
end

function findDifferences(table1, table2)
	if not table2 or not table1 then return end 
    local diff = {}
    
    for key, value in pairs(table2) do
        if type(value) == "table" and type(table1[key]) == "table" then
            local sub_diff = findDifferences(table1[key], value)
            if next(sub_diff) ~= nil then
                diff[key] = sub_diff
            end
        elseif table1[key] ~= value then
            diff[key] = value
        end
    end
    
    return diff
end
-- Convert RGB to HSL
function rgb_to_hsl(rgb)
    local r, g, b = rgb.r, rgb.g, rgb.b
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, s, l = 0, 0, ((max + min) / 2)

    if max == min then
        h, s = 0, 0 -- achromatic
    else
        local d = max - min
        s = l > 0.5 and d / (2 - max - min) or d / (max + min)
        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return { h = h, s = s, l = l }
end

-- Convert HSL to RGB
function hsl_to_rgb(hsl)
    local h, s, l = hsl.h, hsl.s, hsl.l
    local r, g, b

    if s == 0 then
        r, g, b = l, l, l -- achromatic
    else
        local function hue_to_rgb(p, q, t)
            if t < 0 then t = t + 1 end
            if t > 1 then t = t - 1 end
            if t < 1/6 then return p + (q - p) * 6 * t end
            if t < 1/2 then return q end
            if t < 2/3 then return p + (q - p) * (2/3 - t) * 6 end
            return p
        end

        local q = l < 0.5 and l * (1 + s) or l + s - l * s
        local p = 2 * l - q
        r = hue_to_rgb(p, q, h + 1/3)
        g = hue_to_rgb(p, q, h)
        b = hue_to_rgb(p, q, h - 1/3)
    end

    return { r = r, g = g, b = b }
end

-- Convert RGB to HWB
function rgb_to_hwb(rgb)
    local r, g, b = rgb.r, rgb.g, rgb.b
    local max, min = math.max(r, g, b), math.min(r, g, b)
    local h, w, bk = 0, 0, 0

    local function calc_whiteness_blackness()
        local w = 1 - max
        local bk = 1 - min
        return w, bk
    end

    if max == min then
        w, bk = calc_whiteness_blackness()
    else
        local d = max - min
        w = 1 - max
        bk = 1 - min

        if max == r then
            h = (g - b) / d + (g < b and 6 or 0)
        elseif max == g then
            h = (b - r) / d + 2
        else
            h = (r - g) / d + 4
        end
        h = h / 6
    end

    return { h = h, w = w, b = bk }
end

-- Convert HWB to RGB
function hwb_to_rgb(hwb)
    local h, w, bk = hwb.h, hwb.w, hwb.b
    local r, g, b

    if w == 1 and bk == 1 then
        r, g, b = 0, 0, 0
    else
        local ratio = 1 - w - bk
        local i = math.floor(h * 6)
        local f = h * 6 - i
        local p = 1 - bk
        local q = 1 - (bk * f)
        local t = 1 - (bk * (1 - f))

        if i % 6 == 0 then
            r, g, b = p, t, 1 - bk
        elseif i % 6 == 1 then
            r, g, b = q, 1 - bk, p
        elseif i % 6 == 2 then
            r, g, b = 1 - bk, p, t
        elseif i % 6 == 3 then
            r, g, b = 1 - bk, q, p
        elseif i % 6 == 4 then
            r, g, b = t, 1 - bk, q
        else
            r, g, b = p, 1 - bk, t
        end
    end

    return { r = r, g = g, b = b }
end


function getRaycastItem()
	local hit, result = raycast()
	local type_ = result.type
	local isShape = type_ == "body"
	local isValid = isShape or type_ == "joint"
	if not isValid then return false end
	return isShape and result:getShape() or result:getJoint(), isShape
end


function blockEditor.loadAnimations( self )
	self.cl.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "connecttool_idle" },
			pickup = { "connecttool_pickup", { nextAnimation = "idle" } },
			putdown = { "connecttool_putdown" },
		}
	)
	local movementAnimations = {
		idle = "connecttool_idle",
		idleRelaxed = "connecttool_idle_relaxed",

		sprint = "connecttool_sprint",
		runFwd = "connecttool_run_fwd",
		runBwd = "connecttool_run_bwd",

		jump = "connecttool_jump",
		jumpUp = "connecttool_jump_up",
		jumpDown = "connecttool_jump_down",

		land = "connecttool_jump_land",
		landFwd = "connecttool_jump_land_fwd",
		landBwd = "connecttool_jump_land_bwd",

		crouchIdle = "connecttool_crouch_idle",
		crouchFwd = "connecttool_crouch_fwd",
		crouchBwd = "connecttool_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.cl.tpAnimations, "idle", 5.0 )

	if self.tool:isLocal() then
		self.cl.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "connecttool_pickup", { nextAnimation = "idle" } },
				unequip = { "connecttool_putdown" },

				idle = { "connecttool_idle", { looping = true } },
				idleFlip = { "connecttool_idle_flip", { nextAnimation = "idle", blendNext = 1 } },
				idleUse = { "connecttool_use_idle"},

				sprintInto = { "connecttool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 5.0 } },
				sprintExit = { "connecttool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "connecttool_sprint_idle", { looping = true } },

				rotateIn = { "connecttool_rotate_in", { nextAnimation = "rotateRight",  blendNext = 0.1 } },
				rotateOut = { "connecttool_rotate_out", { nextAnimation = "idle",  blendNext = 0.2 } },
				rotateRight = { "connecttool_rotate_right", { nextAnimation = "rotateOut",  blendNext = 0.5 } },
				rotateLeft = { "connecttool_rotate_left", { nextAnimation = "rotateOut",  blendNext = 0.5 } },
			}
		)
	end
	self.cl.blendTime = 0.2
end



function blockEditor.server_onCreate( self )
	self.sv = {
		splitStrings = {},
		lastJsons = {},
		liftLevels = {},
		queue = {}
	}
end

function blockEditor.client_onCreate( self )
	self.cl = {
		gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/editor.layout"),
		oldJson = nil,
		json = "",
		jsonText = "",
		exportData = {
			lifted = false,
			shapes = {},
			joints = {},
			list = {}
		},
		effect = {
			visualization = sm.effect.createEffect("ShapeRenderable"),
			effectTableShapes = {},
			effectTableJoints = {},
			compareTableShapes = {},
			compareTableJoints = {}
		},
		textEffects = {sm.gui.createNameTagGui()},
		raycast = {},
		hasMode = 0,
		lastActionType = 0,
		lastMoveType = nil,
		colorType = 0,
		sldierType = 1,
		toolColorValue = sm.color.new(0),
		editAllowed = true,
		countEditTimes = 1
	}

	self:loadAnimations()

	self.cl.gui:setOnCloseCallback("cl_onClose")
	self.cl.gui:setButtonCallback( "submit", "cl_editBlockAccept" )
	self.cl.gui:setTextChangedCallback( "TextBox", "cl_editBlockChange" )
	self.cl.effect.visualization:setParameter("visualization", true)

	self.cl.gui:setButtonCallback( "button1", "cl_moveItems" )
	self.cl.gui:setButtonCallback( "button2", "cl_moveItems" )
	self.cl.gui:setButtonCallback( "button3", "cl_moveItems" )
	self.cl.gui:setButtonCallback( "button4", "cl_moveItems" )
	self.cl.gui:setButtonCallback( "button5", "cl_moveItems" )
	self.cl.gui:setButtonCallback( "button6", "cl_moveItems" )

	self.cl.gui:setButtonCallback( "ToolButton", "cl_editColor" )

	self.cl.gui:setButtonCallback( "ApplyButton",  "cl_applyColor" )

	self.cl.gui:createHorizontalSlider("R_Slider", 256, 0, "client_onRedSliderCallback")
	self.cl.gui:createHorizontalSlider("G_Slider", 256, 0, "client_onGreenSliderCallback")
	self.cl.gui:createHorizontalSlider("B_Slider", 256, 0, "client_onBlueSliderCallback")

	self.cl.gui:setButtonCallback( "closeColorPicker", "cl_closeColorPicker" )

	self.cl.gui:setTextChangedCallback("ColorInput", "client_onTextColorInputCallback")

	self.cl.gui:setButtonCallback( "paintBucket", "cl_openPaintMenu" )


	self.cl.gui:createHorizontalSlider("Slider1", 256, 0, "client_onSlider1Callback")
	self.cl.gui:createHorizontalSlider("Slider2", 256, 0, "client_onSlider2Callback")
	self.cl.gui:createHorizontalSlider("Slider3", 256, 0, "client_onSlider3Callback")
	self.cl.gui:setTextChangedCallback("Input1", "cl_editHex")


	self.cl.gui:createDropDown( "color_type", "cl_changeColorType", {"set all items","only uuids of item 1","only colors of item 1"} )
	self.cl.gui:createDropDown( "slider_type", "cl_changeSliderType", {"R G B", "H S L", "H W B"} )
	self.cl.gui:setButtonCallback( "applyColorTool", "cl_applyColorTool" )

    self.cl.gui:setColor( "previewColor_icon", sm.color.new("000000") )
    self.cl.gui:setButtonCallback( "previewColor", "cl_doNth" )

	for button_id, color in pairs( PAINT_COLORS ) do
        local base = "ColorBtn_"..button_id
        self.cl.gui:setButtonCallback( base, "cl_pickColor" )
        self.cl.gui:setColor( base.."_icon", sm.color.new(color) )
    end
end

function blockEditor.cl_doNth( self )
	self.cl.gui:setButtonState("previewColor", true)
end

function blockEditor.cl_editHex( self, name, text )
	if #text ~= 6 then return end
	local c = sm.color.new(text)
	if tostring(c):sub(1,6):upper()==text:sub(1,6):upper() then
		self:setColorToolValues(c,true)
	end
end

function blockEditor.client_onSlider1Callback( self, value )
	local color = self.cl.toolColorValue
	if self.cl.sldierType == 1 then -- red
		color.r = value/255
		self:setColorToolValues(color)
	elseif self.cl.sldierType == 2 then -- H S L
		local hsl = rgb_to_hsl(color)
		hsl.h=value/255
		local rgb = hsl_to_rgb(hsl)
		self:setColorToolValues(sm.color.new(rgb.r,rgb.g,rgb.b))
	else -- hwb
		local hwb = rgb_to_hwb(color)
		hwb.h=value/255
		local rgb = hwb_to_rgb(hwb)
		self:setColorToolValues(sm.color.new(rgb.r,rgb.g,rgb.b))
	end
end
function blockEditor.client_onSlider2Callback( self, value )
	local color = self.cl.toolColorValue
	if self.cl.sldierType == 1 then
		color.g = value/255
		self:setColorToolValues(color)
	elseif self.cl.sldierType == 2 then
		local hsl = rgb_to_hsl(color)
		hsl.s=value/255
		local rgb = hsl_to_rgb(hsl)
		self:setColorToolValues(sm.color.new(rgb.r,rgb.g,rgb.b))
	else
		local hwb = rgb_to_hwb(color)
		hwb.w=value/255
		local rgb = hwb_to_rgb(hwb)
		self:setColorToolValues(sm.color.new(rgb.r,rgb.g,rgb.b))
	end
end
function blockEditor.client_onSlider3Callback( self, value )
	local color = self.cl.toolColorValue
	if self.cl.sldierType == 1 then
		color.b = value/255
		self:setColorToolValues(color)
	elseif self.cl.sldierType == 2 then
		local hsl = rgb_to_hsl(color)
		hsl.l=value/255
		local rgb = hsl_to_rgb(hsl)
		self:setColorToolValues(sm.color.new(rgb.r,rgb.g,rgb.b))
	else
		local hwb = rgb_to_hwb(color)
		hwb.b=value/255
		local rgb = hwb_to_rgb(hwb)
		self:setColorToolValues(sm.color.new(rgb.r,rgb.g,rgb.b))
	end
end

function blockEditor.cl_changeSliderType( self, option )
	if option == "R G B" then
		self.cl.sldierType = 1
	elseif option == "H S L" then
		self.cl.sldierType = 2
	else
		self.cl.sldierType = 3
	end
	self:setColorToolValues(self.cl.toolColorValue,true)
end
local color_id = 0

function blockEditor.cl_pickColor( self, btn )
	color_id = tonumber(btn:sub(10, 11))
	self.cl.gui:setButtonState("ColorBtn_"..color_id, false)
	self.cl.gui:setButtonState("previewColor", true)

	self:setColorToolValues(sm.color.new(PAINT_COLORS[color_id]),true)
end

function blockEditor.setColorToolValues( self, color, slider )
	self.cl.toolColorValue = color

	self.cl.gui:setText("Input1", tostring(self.cl.toolColorValue):sub(1,6):upper())
    self.cl.gui:setColor( "previewColor_icon", self.cl.toolColorValue )

	if self.cl.sldierType == 1 then
		local r = self.cl.toolColorValue.r*255
		local g = self.cl.toolColorValue.g*255
		local b = self.cl.toolColorValue.b*255

		if slider then
			self.cl.gui:setSliderPosition("Slider1", r)
			self.cl.gui:setSliderPosition("Slider2", g)
			self.cl.gui:setSliderPosition("Slider3", b)
		end

		self.cl.gui:setText("Value1", ("#ff0000R#ffffff: #ffff00%s#ffffff"):format(math.ceil(r)))
		self.cl.gui:setText("Value2", ("#00ff00G#ffffff: #ffff00%s#ffffff"):format(math.ceil(g)))
		self.cl.gui:setText("Value3", ("#0000ffB#ffffff: #ffff00%s#ffffff"):format(math.ceil(b)))
	elseif self.cl.sldierType == 2 then
		local hsl = rgb_to_hsl(self.cl.toolColorValue)

		if slider then
			self.cl.gui:setSliderPosition("Slider1", hsl.h)
			self.cl.gui:setSliderPosition("Slider2", hsl.s)
			self.cl.gui:setSliderPosition("Slider3", hsl.l)
		end

		self.cl.gui:setText("Value1", ("#ff0000H#ffffff: #ffff00%s#ffffff"):format(math.ceil(hsl.h*360)))
		self.cl.gui:setText("Value2", ("#00ff00S#ffffff: #ffff00%s#ffffff"):format(math.ceil(hsl.s*100)))
		self.cl.gui:setText("Value3", ("#0000ffL#ffffff: #ffff00%s#ffffff"):format(math.ceil(hsl.l*100)))
	else
		local hwb = rgb_to_hwb(self.cl.toolColorValue)
		if slider then
			self.cl.gui:setSliderPosition("Slider1", hwb.h*255)
			self.cl.gui:setSliderPosition("Slider2", hwb.w*255)
			self.cl.gui:setSliderPosition("Slider3", hwb.b*255)
		end

		self.cl.gui:setText("Value1", ("#ff0000H#ffffff: #ffff00%s#ffffff"):format(math.ceil(hwb.h*360)))
		self.cl.gui:setText("Value2", ("#00ff00W#ffffff: #ffff00%s#ffffff"):format(math.ceil(hwb.w*100)))
		self.cl.gui:setText("Value3", ("#0000ffB#ffffff: #ffff00%s#ffffff"):format(math.ceil(hwb.b*100)))
	end
end

function blockEditor.cl_applyColorTool( self )
	if self.cl.colorType==0 then return end

	local json = self.cl.jsonText:gsub("#(%x%x%x%x%x%x)", "")
	local jsonTable = sm.json.parseJsonString(json)
	json = nil

	local Color = tostring(self.cl.toolColorValue):sub(1,6):upper()

	if self.cl.colorType == 1 or #jsonTable == 1 then -- all
		for i,v in pairs(jsonTable) do
			jsonTable[i].color=Color
		end
	elseif self.cl.colorType == 2 then -- uuid

		local base = sm.uuid.new(jsonTable[1].shapeId)
			jsonTable[1].color = Color

		for i,v in pairs(jsonTable) do
			if i ~= 1 and base == sm.uuid.new(v.shapeId) then
				jsonTable[i].color = Color
			end
		end
	else -- of color
		local base = sm.color.new(jsonTable[1].color)
			jsonTable[1].color = Color

		for i,v in pairs(jsonTable) do
			if i ~= 1 and base == sm.color.new(v.color) then
				jsonTable[i].color = Color
			end
		end
	end
	self.cl.jsonText = beatifyTable(jsonTable, 1)
	self.cl.gui:setText( "TextBox", self.cl.jsonText)
end

function blockEditor.cl_changeColorType( self, option )
	if option == "set all items" then
		self.cl.colorType = 1
	elseif option == "only uuids of item 1" then
		self.cl.colorType = 2
	else
		self.cl.colorType = 3
	end
end

function blockEditor.cl_closeColorPicker( self )
	self.cl.gui:setVisible( "panel_color_a", false )
	self.cl.gui:setVisible( "panel_color_a", false )
end


function blockEditor.cl_openPaintMenu( self )
	self.cl.colorType = 1
	self.cl.gui:setVisible( "panel_color_a", true )
end

function blockEditor.cl_moveItems( self, btn )
	self.cl.lastActionType = 1
	self.cl.lastMoveType = btn
	local json = self.cl.jsonText:gsub("#(%x%x%x%x%x%x)", "")
	local jsonTable = sm.json.parseJsonString(json)
	json = nil

	if #jsonTable == 0 then -- single shape
		if btn == "button1" then 	 -- +x
			if jsonTable.posA then
		 		jsonTable.posA.x = jsonTable.posA.x + self.cl.countEditTimes
		 		jsonTable.posB.x = jsonTable.posB.x + self.cl.countEditTimes
			else
	 			jsonTable.pos.x = jsonTable.pos.x + self.cl.countEditTimes
			end
		elseif btn == "button2" then -- -x
			if jsonTable.posA then
		 		jsonTable.posA.x = jsonTable.posA.x - self.cl.countEditTimes
		 		jsonTable.posB.x = jsonTable.posB.x - self.cl.countEditTimes
			else
	 			jsonTable.pos.x = jsonTable.pos.x - self.cl.countEditTimes
			end
		elseif btn == "button3" then -- +y
			if jsonTable.posA then
		 		jsonTable.posA.y = jsonTable.posA.y + self.cl.countEditTimes
		 		jsonTable.posB.y = jsonTable.posB.y + self.cl.countEditTimes
			else
	 			jsonTable.pos.y = jsonTable.pos.y + self.cl.countEditTimes
			end
		elseif btn == "button4" then -- -y
			if jsonTable.posA then
		 		jsonTable.posA.y = jsonTable.posA.y - self.cl.countEditTimes
		 		jsonTable.posB.y = jsonTable.posB.y - self.cl.countEditTimes
			else
	 			jsonTable.pos.y = jsonTable.pos.y - self.cl.countEditTimes
			end
		elseif btn == "button6" then -- +z
			if jsonTable.posA then
		 		jsonTable.posA.z = jsonTable.posA.z + self.cl.countEditTimes
		 		jsonTable.posB.z = jsonTable.posB.z + self.cl.countEditTimes
			else
	 			jsonTable.pos.z = jsonTable.pos.z + self.cl.countEditTimes
			end
		else 						 -- -z
			if jsonTable.posA then
		 		jsonTable.posA.z = jsonTable.posA.z - self.cl.countEditTimes
		 		jsonTable.posB.z = jsonTable.posB.z - self.cl.countEditTimes
			else
	 			jsonTable.pos.z = jsonTable.pos.z - self.cl.countEditTimes
			end
		end
	else
		if btn == "button1" then 	 -- +x
			for i,v in pairs(jsonTable) do

				if jsonTable[i].posA then
			 		jsonTable[i].posA.x = jsonTable[i].posA.x + self.cl.countEditTimes
			 		jsonTable[i].posB.x = jsonTable[i].posB.x + self.cl.countEditTimes
				else
		 			jsonTable[i].pos.x = jsonTable[i].pos.x + self.cl.countEditTimes
				end
			end
		elseif btn == "button2" then -- -x
			for i,v in pairs(jsonTable) do
				if jsonTable[i].posA then
			 		jsonTable[i].posA.x = jsonTable[i].posA.x - self.cl.countEditTimes
			 		jsonTable[i].posB.x = jsonTable[i].posB.x - self.cl.countEditTimes
				else
		 			jsonTable[i].pos.x = jsonTable[i].pos.x - self.cl.countEditTimes
				end
			end
		elseif btn == "button3" then -- +y
			for i,v in pairs(jsonTable) do
				if jsonTable[i].posA then
			 		jsonTable[i].posA.y = jsonTable[i].posA.y + self.cl.countEditTimes
			 		jsonTable[i].posB.y = jsonTable[i].posB.y + self.cl.countEditTimes
				else
		 			jsonTable[i].pos.y = jsonTable[i].pos.y + self.cl.countEditTimes
				end
			end
		elseif btn == "button4" then -- -y
			for i,v in pairs(jsonTable) do
				if jsonTable[i].posA then
			 		jsonTable[i].posA.y = jsonTable[i].posA.y - self.cl.countEditTimes
			 		jsonTable[i].posB.y = jsonTable[i].posB.y - self.cl.countEditTimes
				else
		 			jsonTable[i].pos.y = jsonTable[i].pos.y - self.cl.countEditTimes
				end
			end
		elseif btn == "button6" then -- +z
			for i,v in pairs(jsonTable) do
				if jsonTable[i].posA then
			 		jsonTable[i].posA.z = jsonTable[i].posA.z + self.cl.countEditTimes
			 		jsonTable[i].posB.z = jsonTable[i].posB.z + self.cl.countEditTimes
				else
		 			jsonTable[i].pos.z = jsonTable[i].pos.z + self.cl.countEditTimes
				end
			end
		else 						 -- -z
			for i,v in pairs(jsonTable) do
				if jsonTable[i].posA then
			 		jsonTable[i].posA.z = jsonTable[i].posA.z - self.cl.countEditTimes
			 		jsonTable[i].posB.z = jsonTable[i].posB.z - self.cl.countEditTimes
				else
		 			jsonTable[i].pos.z = jsonTable[i].pos.z - self.cl.countEditTimes
				end
			end
		end
	end

	local strings = splitString(sm.json.writeJsonString(jsonTable), 65300)

	for i,v in ipairs(strings) do
		self.network:sendToServer("sv_reassembleSplit",{i=i,m=#strings,str=v,params={list=self.cl.exportData.list}})
	end
end

function blockEditor.client_onDestroy( self )
	self:cl_onClose()
end

local liftLevel = 0
local oldForceBuild = false
function blockEditor.client_onEquippedUpdate( self, primaryState, secondaryState, forceBuild )
	if self.cl.stopAnimation and (self.cl.stopAnimation+15 <= sm.game.getCurrentTick()) then
		self.cl.stopAnimation = nil
		setTpAnimation( self.cl.fpAnimations, "idle", 0.2 )
	end

	local hit, result = self.cl.raycast.hit, self.cl.raycast.result
	if not hit then return false, false end

	local clock = os.clock()
	local isBody = result.type == "body"
	local isValid = isBody or result.type == "joint"
	if not isValid then return false, false end

	local bodyA = isBody and self.cl.raycast.resultShape.body or self.cl.raycast.resultShape.shapeA.body
	sm.gui.setInteractionText(selectText, multiSelectText)
	if self.cl.lastChanged and self.cl.lastActionType~=0 then
		sm.gui.setInteractionText(repeateText)
	end

	self.cl.exportData.multiSelect = #self.cl.exportData.shapes + #self.cl.exportData.joints > 1
	-- if primaryState == 
	if primaryState == 1 then
		self.cl.exportData.shapes = {}
		self.cl.exportData.joints = {}
		self.cl.exportData.list = {}

		self.cl.exportData.timeOnSelect = clock
		self.cl.exportData.dirOnSelect = sm.camera.getDirection()
	elseif primaryState == 2 then
		local isSame = sm.camera.getDirection() == self.cl.exportData.dirOnSelect
		
		local g = math.abs(clock - self.cl.exportData.timeOnSelect) / multiSelectTime
		if g < 1 then
			self.cl.time = g
		elseif isSame then
			self.cl.time = math.abs(clock - self.cl.exportData.timeOnSelect - multiSelectTime) / (bodySelectTime - multiSelectTime)
		else
			self.cl.time = 0
		end

		sm.gui.setProgressFraction(self.cl.time)
		if clock > self.cl.exportData.timeOnSelect + multiSelectTime and not isSame and self.cl.hasMode ~= 2 then
			self.cl.hasMode = 1
			sm.gui.displayAlertText("Multi", 1)  -- Multi select
			if secondaryState == 0 then
				if not self.cl.compareBody then
					self.cl.compareBody = isBody and self.cl.raycast.resultShape.body or self.cl.raycast.resultShape.shapeA.body
				end

				local isPartOf = false
				for i, k in pairs(self.cl.compareBody:getCreationBodies()) do
					if k.id == bodyA.id then
						isPartOf = true
						break
					end
				end

				if isPartOf then
					if isBody then
						local bool, index = partOf(self.cl.exportData.shapes, self.cl.raycast.resultShape)
						if not bool then
							table.insert(self.cl.exportData.shapes, self.cl.raycast.resultShape)
							table.insert(self.cl.exportData.list,self.cl.raycast.resultShape)
							setTpAnimation( self.cl.fpAnimations, "rotateIn", 0.2 )
						end
					else
						local bool, index = partOf(self.cl.exportData.joints, self.cl.raycast.resultShape)
						if not bool then
							table.insert(self.cl.exportData.joints, self.cl.raycast.resultShape)
							table.insert(self.cl.exportData.list,self.cl.raycast.resultShape)
							setTpAnimation( self.cl.fpAnimations, "rotateIn", 0.2 )
						end
					end
				end
			end
		elseif (clock > self.cl.exportData.timeOnSelect + bodySelectTime and self.cl.hasMode ~= 1 and isSame) or self.cl.hasMode == 2 then
			self.cl.hasMode = 2
			sm.gui.displayAlertText("Body", 1)  -- Body select
			if secondaryState == 0 then
				if not self.cl.compareBody then
					self.cl.compareBody = isBody and self.cl.raycast.resultShape.body or self.cl.raycast.resultShape.shapeA.body
				end

				local isPartOf = false
				for i, k in pairs(self.cl.compareBody:getCreationBodies()) do
					if k.id == bodyA.id then
						isPartOf = true
						break
					end
				end

				if isPartOf then
					for i, shape in pairs(bodyA:getShapes()) do
						local bool, index = partOf(self.cl.exportData.shapes, shape)
						if not bool then
							table.insert(self.cl.exportData.shapes, shape)
							table.insert(self.cl.exportData.list, shape)
							setTpAnimation( self.cl.fpAnimations, "rotateIn", 0.2 )
						end
					end

					for i, joint in pairs(bodyA:getJoints()) do
						local bool, index = partOf(self.cl.exportData.joints, joint)
						if not bool then
							table.insert(self.cl.exportData.joints, joint)
							table.insert(self.cl.exportData.list, joint)
							setTpAnimation( self.cl.fpAnimations, "rotateIn", 0.2 )
						end
					end
				end
			end
		else
			self.cl.compareBody = nil
			self.cl.hasMode = 0  -- 0 for no mode
		end
	elseif primaryState == 3 then
		if self.cl.hasMode == 0 then
			setTpAnimation( self.cl.fpAnimations, "rotateIn", 0.2 )
			self.cl.hasMode = 3  -- 3 for "Single"
			if isBody then
				self.cl.exportData.shapes[1] = self.cl.raycast.resultShape
			else
				self.cl.exportData.joints[1] = self.cl.raycast.resultShape
			end
			self.cl.exportData.list = {self.cl.raycast.resultShape}
		end
		--self.cl.hasMode = 0  -- 0 for no mode
		self.cl.gui:setText("TextBox","")
		self.network:sendToServer("sv_getJson", {shapes = self.cl.exportData.shapes, joints = self.cl.exportData.joints})
	end
	local lift = localPlayer.getOwnedLift()
	if lift and lift.level ~= liftLevel then
		liftLevel = lift.level
		self.network:sendToServer("sv_setTrueLiftLevel", liftLevel)
	end

	if forceBuild ~= oldForceBuild then
		oldForceBuild = forceBuild
		if forceBuild and self.cl.lastActionType~=0 then
			if self.cl.lastActionType==2 and self.cl.editAllowed then
				self.cl.countEditTimes = 1

				if #self.cl.exportData.list == 0 then
					local raycast, isShape = getRaycastItem()
					if not raycast then return false, false end
					if self.cl.lastActionType == 2 then
						self.network:sendToServer("sv_changeJson",{shapes = {isShape and raycast}, joints = {(not isShape) and raycast or nil}, list = {raycast}, id = self.cl.lastChanged})
					else
						self.network:sendToServer("sv_moveItems",{multiple = self.cl.countEditTimes, list = {raycast}, dir = self.cl.lastMoveType})
					end
				else
					if self.cl.lastActionType == 2 then
						self.network:sendToServer("sv_changeJson",{shapes = self.cl.exportData.shapes, joints = self.cl.exportData.joints, list = self.cl.exportData.list, id = self.cl.lastChanged})
					else
						self.network:sendToServer("sv_moveItems",{multiple = self.cl.countEditTimes, list = self.cl.exportData.list, dir = self.cl.lastMoveType})
					end
				end
				self.cl.editAllowed = false
			else
				self.cl.countEditTimes = self.cl.countEditTimes + 1
			end
		end
	elseif self.cl.countEditTimes > 1 and self.cl.editAllowed then
		if self.cl.lastActionType ~= 2 then
			if #self.cl.exportData.list == 0 then
				local raycast, isShape = getRaycastItem()
				if not raycast then return false, false end
				self.network:sendToServer("sv_moveItems",{multiple = self.cl.countEditTimes, list = {raycast}, dir = self.cl.lastMoveType})
			else
				self.network:sendToServer("sv_moveItems",{multiple = self.cl.countEditTimes, list = self.cl.exportData.list, dir = self.cl.lastMoveType})
			end
				
			self.cl.editAllowed = false
			self.cl.countEditTimes = 1
		end
	end

	return false, false
end

function blockEditor:sv_seatChar()
	if sm.exists(self.sv.seat) then
		self.sv.seat:setSeatCharacter(self.sv.testChar)
	end
end

function blockEditor:sv_setSeat(seat)
	self.sv.seat = seat
end


function blockEditor.client_onEquip( self )
	sm.audio.play("ConnectTool - Equip")
	self.cl.wantEquipped = true

	currentRenderablesTp = {}
	currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	self.tool:setTpRenderables( currentRenderablesTp )

	self:loadAnimations()

	setTpAnimation( self.cl.tpAnimations, "pickup", 0.0001 )

	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
		pcall(setFpAnimation, self.cl.fpAnimations, "equip", 0.2 )

		self.tool:setFpColor(sm.color.new(toolColor))
		self.tool:setTpColor(sm.color.new(toolColor))
	end
	for i,v in pairs(self.cl.exportData.list) do
		if sm.exists(self.cl.textEffects[i]) then
			self.cl.textEffects[i]:open()
		end
	end
end

function blockEditor.client_onUnequip( self )
	sm.audio.play("ConnectTool - Unequip")
	if sm.exists( self.tool ) then
		setTpAnimation( self.cl.tpAnimations, "putdown" )
		if self.tool:isLocal() then
			pcall(setFpAnimation, self.cl.fpAnimations, "unequip", 0.2 )
		end
	end

	destroyEffectTable(self.cl.effect.effectTableJoints)
	destroyEffectTable(self.cl.effect.effectTableShapes)
	self.cl.effect.effectTableJoints = {}
	self.cl.effect.effectTableShapes = {}

	self.cl.exportData.shapes = {}
	self.cl.exportData.joints = {}
	self.cl.exportData.list = {}

	for i,v in pairs(self.cl.textEffects) do
		if sm.exists(v) then
			v:close()
		end
	end

	if self.cl.effect.visualization:isPlaying() then self.cl.effect.visualization:stop() end
end

function blockEditor.sv_setTrueLiftLevel(self, level, caller)
	self.sv.liftLevels[caller.id] = level
end

function blockEditor.cl_editBlockChange( self, name, text, b )
	self.cl.jsonText = text
end

function blockEditor.cl_editBlockAccept( self )
	local json = self.cl.jsonText:gsub("#(%x%x%x%x%x%x)", "")
	local strings = splitString(json, 65300)

	self.cl.lastActionType = 2

	for i,v in ipairs(strings) do
		local m = #strings
		if i == m then
			self.network:sendToServer("sv_reassembleSplit",{i=i, m=m, str=v, params = {list = self.cl.exportData.list, id = self.cl.lastChanged}})
		else
			self.network:sendToServer("sv_reassembleSplit",{i=i,m=#strings,str=v})
		end
	end
end

function blockEditor.sv_moveItems( self, data, caller )
	local btn = data.dir
	local list = data.list
	local multiple = data.multiple or 1
	local isShape = type(list[1]) == "Shape"
	local creation
	local anyBody
	local lifted

	local shapeColors = {}
	local jointColors = {}

	local seatColors = {}
	
	local color2json = {}
	local c2jIndexs = {}

	local hasColoredShapes = false
	local hasColoredJoints = false
	local hasColoredSeat = false


	if not sm.exists(list[1]) then return end -- weird thing were it becomes nil for no reason
	
	if isShape then
		anyBody = list[1].body
	else
		anyBody = list[1].shapeA.body
	end

	lifted = anyBody:isOnLift()

	local function setDifferences(table1, table2)
	    for key, value in pairs(table2) do
	        if type(value) == "table" then
	        	if type(table1[key]) == "table" then
	            	table1[key] = setDifferences(table1[key], value)
	        	end
	        else
	            table1[key] = value
	        end
	    end
	    return table1
	end

	for i,item in ipairs(list) do
		local newColor = sm.color.new(math.random()*0xffffff00)
		local colorHex = tostring(newColor):sub(1,6):lower()
		
		if type(item) == "Shape" then
			shapeColors[colorHex] = tostring(item.color):sub(1,6):lower()
			hasColoredShapes = true
		else
			jointColors[colorHex] = tostring(item.color):sub(1,6):lower()
			hasColoredJoints = true
		end
		item:setColor(newColor)
		table.insert(c2jIndexs,colorHex)
		color2json[colorHex] = jsonItem
	end

	--[[for i, interactable in pairs(Interactables) do
		local oldColorHex = tostring(interactable.shape.color):sub(1,6):lower()
		local theNewColor = shapeColors[oldColorHex]
        if theNewColor then

        	print("is being edited")
        else
        	print("is not being edited")
        end
	end]]

	--set json
	creation = sm.creation.exportToTable(anyBody, true, lifted)

	if hasColoredShapes then
		for bodyI, body in pairs(creation.bodies) do
			for shapeI, shape in pairs(body.childs) do
				local colorHex = shape.color:lower()
				if shapeColors[colorHex] then
					if btn == "button1" then 	 -- +x
			 			shape.pos.x = shape.pos.x + multiple
					elseif btn == "button2" then -- -x
						shape.pos.x=shape.pos.x-multiple
					elseif btn == "button3" then -- +y
						shape.pos.y=shape.pos.y+multiple
					elseif btn == "button4" then -- -y
						shape.pos.y=shape.pos.y-multiple
					elseif btn == "button6" then -- +z
						shape.pos.z=shape.pos.z+multiple
					else 						 -- -z
						shape.pos.z=shape.pos.z-multiple
					end

					shape.color = colorHex
					creation.bodies[bodyI].childs[shapeI] = shape
				end
			end
		end
	end

	if hasColoredJoints then
		for jointI, joint in pairs(creation.joints) do
			local colorHex = joint.color:lower()
			if jointColors[colorHex] then
				if btn == "button1" then 	 -- +x
			 		joint.posA.x = joint.posA.x + 1
			 		joint.posB.x = joint.posB.x + 1
				elseif btn == "button2" then -- -x
			 		joint.posA.x=joint.posA.x-1
			 		joint.posB.x=joint.posB.x-1
				elseif btn == "button3" then -- +y
		 			joint.posA.y=joint.posA.y+1
			 		joint.posB.y=joint.posB.y+1
				elseif btn == "button4" then -- -y
			 		joint.posA.y=joint.posA.y-1
			 		joint.posB.y=joint.posB.y-1
				elseif btn == "button6" then -- +z
			 		joint.posA.z=joint.posA.z+1
			 		joint.posB.z=joint.posB.z+1
				else 						 -- -z
			 		joint.posA.z=joint.posA.z-1
			 		joint.posB.z=joint.posB.z-1
				end
				joint.color = colorHex
				creation.joints[jointI] = joint
			end
		end
	end

	local status, err = pcall(function()
		if lifted then
			local templateA,templateB = self:sv_getOffsetPosition(anyBody, caller)
			local id = #creation.bodies
			table.insert(creation.bodies[id].childs,templateA)
			table.insert(creation.bodies[id].childs,templateB)
		end

		local seatedChars = #anyBody:getAllSeatedCharacter()
		local charCount = 0
		local seatTbl = {}

		if charCount ~= seatedChars then
			for i, shape in pairs(anyBody:getCreationShapes()) do
				local interactable = shape.interactable
				if interactable then
					if interactable:hasSeat() then
						local char = interactable:getSeatCharacter()
						if char then
							charCount = charCount + 1
							table.insert(seatTbl, {col = interactable.shape.color, char = char})
						end
					end
				end
			end
		end

		local newCreation = sm.creation.importFromString( sm.world.getCurrentWorld(), sm.json.writeJsonString(creation), nil, nil, true, true )

		self.sv.queue.bodies = newCreation
		
		if newCreation ~= nil then

			local allShapes = newCreation[1]:getCreationShapes()
			if seatTbl ~= {} then
				for i, seatData in pairs(seatTbl) do
					for j, shape in pairs(allShapes) do
						if shape.color.r == seatData.col.r and shape.color.g == seatData.col.g and shape.color.b == seatData.col.b then
							shape.interactable:setSeatCharacter(seatData.char)
						end
					end
				end
			end

			if lifted then
				local liftData = _G.__lifts[caller.id]
				sm.player.placeLift( caller, newCreation, liftData.position, liftData.level, liftData.rotation )
			end

			for i,shape in pairs(anyBody:getCreationShapes()) do
				shape:destroyShape()
			end

			local newShapes = {}
			local newJoints = {}
			local newList = {}

			if hasColoredShapes then
				
				for i,shape in pairs(allShapes) do
					local oldColorHex = tostring(shape.color):sub(1,6):lower()
					local theNewColor = shapeColors[oldColorHex]
			        if theNewColor then
			        	table.insert(newShapes,shape)
						shape:setColor(sm.color.new(theNewColor))
						shapeColors[oldColorHex] = nil
						for j,v in ipairs(c2jIndexs) do
							if v == oldColorHex then
								newList[j] = shape
								break
							end
						end
			        end
				end
			end

			if hasColoredJoints then
				local allJoints = newCreation[1]:getCreationJoints()
				for i,joint in pairs(allJoints) do
					local oldColorHex = tostring(joint.color):sub(1,6):lower()
					local theNewColor = jointColors[oldColorHex]
			        if theNewColor then
			        	table.insert(newJoints,joint)
						joint:setColor(sm.color.new(theNewColor))
						jointColors[oldColorHex] = nil
						for j,v in ipairs(c2jIndexs) do
							if v == oldColorHex then
								newList[j] = joint
								break
							end
						end
			        end
				end
			end
		end

		if newCreation == nil then
			--reset colors
			if hasColoredShapes then
				local allShapes = anyBody:getCreationShapes()
				for i,shape in pairs(allShapes) do
					local oldColorHex = tostring(shape.color):sub(1,6):lower()
					local theNewColor = shapeColors[oldColorHex]
			        if theNewColor then
						shape:setColor(sm.color.new(theNewColor))
						shapeColors[oldColorHex] = nil
			        end
				end
			end

			if hasColoredJoints then
				local allJoints = anyBody:getCreationJoints()
				for i,joint in pairs(allJoints) do
					local oldColorHex = tostring(joint.color):sub(1,6):lower()
					local theNewColor = jointColors[oldColorHex]
			        if theNewColor then
						joint:setColor(sm.color.new(theNewColor))
						jointColors[oldColorHex] = nil
			        end
				end
			end
		end
	end)
end

function blockEditor.sv_reassembleSplit( self, data, caller )
	if data.i == 1 then
		self.sv.splitStrings[caller.id] = data.str
	else
		self.sv.splitStrings[caller.id] = self.sv.splitStrings[caller.id] .. data.str
	end
	if i == m then
		self:sv_setJson(data.params, caller)
	end
end

function blockEditor.sv_changeJson( self, data, caller )
	local list = data.list
	local diff = self.sv.lastJsons[caller.id][data.id]

	self:sv_setJson(data,caller,diff)
end

function blockEditor.sv_setJson( self, data, caller, diff )
	if #data.list==0 then
		self.sv.splitStrings[caller.id] = nil -- save some memory or smth
		return
	end
	local json
	if not diff then
		json = sm.json.parseJsonString(self.sv.splitStrings[caller.id])
	end
	local list = data.list

	if not sm.exists(list[1]) then
		return
	end

	local isShape = type(list[1]) == "Shape"
	local creation
	local anyBody
	local lifted

	local shapeColors = {}
	local jointColors = {}
	
	local color2json = {}
	local c2jIndexs = {}

	local hasColoredShapes = false
	local hasColoredJoints = false
	local hasColoredSeat = false

	local seatColors = {}

	if isShape then
		anyBody = list[1].body
	else
		anyBody = list[1].shapeA.body
	end

	lifted = anyBody:isOnLift()
	if #list == 0 then
		json = {json}
	end

	local function setDifferences(table1, table2)
	    for key, value in pairs(table2) do
	        if type(value) == "table" then
	        	if type(table1[key]) == "table" then
	            	table1[key] = setDifferences(table1[key], value)
	        	end
	        else
	            table1[key] = value
	        end
	    end
	    return table1
	end

	if not diff and #json == 1 and data.id then
		if self.sv.lastJsons[caller.id][data.id] then
			self.sv.lastJsons[caller.id] = {[data.id] = findDifferences(self.sv.lastJsons[caller.id][data.id],sm.json.parseJsonString(self.sv.splitStrings[caller.id]))[1]}
		end
	end

	if diff then
		for i,item in ipairs(list) do
			local newColor = sm.color.new(math.random()*0xffffff00)
			local colorHex = tostring(newColor):sub(1,6):lower()
			if type(item) == "Shape" then
				hasColoredShapes = true
				shapeColors[colorHex] = diff.color or tostring(item.color):sub(1,6):lower()
			else
				hasColoredJoints = true
				jointColors[colorHex] = diff.color or tostring(item.color):sub(1,6):lower()
			end
			item:setColor(newColor)
			table.insert(c2jIndexs,colorHex)
		end
	else
		for i,item in ipairs(list) do
			local newColor = sm.color.new(math.random()*0xffffff00)
			local colorHex = tostring(newColor):sub(1,6):lower()
			
			local jsonItem = json[i]
			if type(item) == "Shape" then
				shapeColors[colorHex] = jsonItem.color
				hasColoredShapes = true
			else
				jointColors[colorHex] = jsonItem.color
				hasColoredJoints = true
			end
			item:setColor(newColor)
			table.insert(c2jIndexs,colorHex)
			color2json[colorHex] = jsonItem
		end
	end

	--set json
	creation = sm.creation.exportToTable(anyBody, true, lifted)

	if hasColoredShapes then
		if diff then
			for bodyI, body in pairs(creation.bodies) do
				for shapeI, shape in pairs(body.childs) do
					local colorHex = shape.color:lower()
					if shapeColors[colorHex] then
						shape = setDifferences(shape, diff)
						shape.color = colorHex
						creation.bodies[bodyI].childs[shapeI] = shape
					end
				end
			end
		else
			for bodyI, body in pairs(creation.bodies) do
				for shapeI, shape in pairs(body.childs) do
					local colorHex = shape.color:lower()
					if shapeColors[colorHex] then
						local newJson = color2json[colorHex]
						newJson.color = colorHex
						creation.bodies[bodyI].childs[shapeI] = newJson
					end
				end
			end
		end
	end

	if hasColoredJoints then
		if diff then
			for jointI, joint in pairs(creation.joints) do
				local colorHex = joint.color:lower()
				if jointColors[colorHex] then
					joint = setDifferences(joint, diff)
					joint.color = colorHex
					creation.joints[jointI] = joint
				end
			end
		else
			for jointI, joint in pairs(creation.joints) do
				local colorHex = joint.color:lower()
				if jointColors[colorHex] then
					local newJson = color2json[colorHex]
					newJson.color = colorHex
					creation.joints[jointI] = newJson
				end
			end
		end
	end

	json = nil
	self.sv.splitStrings[caller.id] = nil

	local newCreation

	local status, err = pcall(function()
		if lifted then
			local templateA,templateB = self:sv_getOffsetPosition(anyBody, caller)
			local id = #creation.bodies
			table.insert(creation.bodies[id].childs,templateA)
			table.insert(creation.bodies[id].childs,templateB)
		end

		local seatedChars = #anyBody:getAllSeatedCharacter()

		local charCount = 0
		local seatTbl = {}

		if charCount ~= seatedChars then
			for i, shape in pairs(anyBody:getCreationShapes()) do
				local interactable = shape.interactable
				if interactable then
					if interactable:hasSeat() then
						local char = interactable:getSeatCharacter()
						if char then
							charCount = charCount + 1
							table.insert(seatTbl, {col = interactable.shape.color, char = char})
						end
					end
				end
			end
		end

		newCreation = sm.creation.importFromString( sm.world.getCurrentWorld(), sm.json.writeJsonString(creation), nil, nil, true, true )

		self.sv.queue.bodies = newCreation
		
		if newCreation ~= nil then
			local allShapes = newCreation[1]:getCreationShapes()
			if seatTbl ~= {} then
				for i, seatData in pairs(seatTbl) do
					for j, shape in pairs(allShapes) do
						if shape.color.r == seatData.col.r and shape.color.g == seatData.col.g and shape.color.b == seatData.col.b then
							shape.interactable:setSeatCharacter(seatData.char)
						end
					end
				end
			end
			
			if lifted then
				local liftData = _G.__lifts[caller.id]
				sm.player.placeLift( caller, newCreation, liftData.position, liftData.level, liftData.rotation )
			end

			for i,shape in pairs(anyBody:getCreationShapes()) do
				shape:destroyShape()
			end

			local newShapes = {}
			local newJoints = {}
			local newList = {}

			if hasColoredShapes then
				
				for i,shape in pairs(allShapes) do
					local oldColorHex = tostring(shape.color):sub(1,6):lower()
					local theNewColor = shapeColors[oldColorHex]
			        if theNewColor then
			        	table.insert(newShapes,shape)
						shape:setColor(sm.color.new(theNewColor))
						shapeColors[oldColorHex] = nil
						for j,v in ipairs(c2jIndexs) do
							if v == oldColorHex then
								newList[j] = shape
								break
							end
						end
			        end
				end
			end

			if hasColoredJoints then
				local allJoints = newCreation[1]:getCreationJoints()
				for i,joint in pairs(allJoints) do
					local oldColorHex = tostring(joint.color):sub(1,6):lower()
					local theNewColor = jointColors[oldColorHex]
			        if theNewColor then
			        	table.insert(newJoints,joint)
						joint:setColor(sm.color.new(theNewColor))
						jointColors[oldColorHex] = nil
						for j,v in ipairs(c2jIndexs) do
							if v == oldColorHex then
								newList[j] = joint
								break
							end
						end
			        end
				end
			end

			self.sv.queue = {
				bodies = newCreation,
				newShapes = newShapes,
				newJoints = newJoints,
				newList = newList,
				caller = caller,
				regrab = true
			}

		end
	end)

	if newCreation == nil then
		--reset colors
		if hasColoredShapes then
			local allShapes = anyBody:getCreationShapes()
			for i,shape in pairs(allShapes) do
				local oldColorHex = tostring(shape.color):sub(1,6):lower()
				local theNewColor = shapeColors[oldColorHex]
		        if theNewColor then
					shape:setColor(sm.color.new(theNewColor))
					shapeColors[oldColorHex] = nil
		        end

			end
		end

		if hasColoredJoints then
			local allJoints = anyBody:getCreationJoints()
			for i,joint in pairs(allJoints) do
				local oldColorHex = tostring(joint.color):sub(1,6):lower()
				local theNewColor = jointColors[oldColorHex]
		        if theNewColor then
					joint:setColor(sm.color.new(theNewColor))
					jointColors[oldColorHex] = nil
		        end
			end
		end
	end

	if not status then
		self.network:sendToClient(caller, "cl_error", err)
	end
end

function blockEditor.server_onFixedUpdate( self, dt )
	local bodies = self.sv.queue.bodies

	if bodies then
		local changed = false
		local tick = sm.game.getCurrentTick()

		local data = 0
		for i, body in pairs(bodies) do
			data = data + #body:getInteractables()
		end
		
		for i, body in pairs(bodies) do
			if body:hasChanged(tick - math.max(data / 100, 7)) then
				changed = true
				break
			end
		end

		if not changed then
			if self.sv.queue.regrab then
				self:sv_getJson(
					{
						shapes = self.sv.queue.newShapes, 
						joints = self.sv.queue.newJoints,
						list = self.sv.queue.newList
					},
					self.sv.queue.caller,
					true
				)
			end

			self.cl.editAllowed = true
			self.sv.queue = {}
		end
	end
end


function blockEditor.cl_error( self, error )
	setTpAnimation( self.cl.fpAnimations, "idleUse", 0.1 )
	self.cl.stopAnimation = sm.game.getCurrentTick()
	sm.log.error("RawBlockEditor error: ", error)
	sm.gui.chatMessage("#EEAF5CERROR:#D02525"..error)
	sm.gui.chatMessage("report here:#0A3EE2https://discord.gg/6r46PkYr9s")
end

function blockEditor.cl_newCreation( self, data ) -- do flip animation
	local returnShape = data.shape
	local list = data.list

	local creationBodies = returnShape.body:getCreationBodies()
	local joints = returnShape.body:getCreationJoints()
	table.sort(joints, function(jA,jB)return jA.id<jB.id end)

	

	self.cl.exportData.shapes = {}
	self.cl.exportData.joints = {}
	self.cl.exportData.list = {}

	for i,v in ipairs(list) do
		local eqShape
		if v.type == "Shape" then
			eqShape = creationBodies[v.bIndex]:getShapes()[v.index]
			table.insert(self.cl.exportData.shapes, eqShape )
		else
			eqShape = joints[v.index]
			table.insert(self.cl.exportData.joints, eqShape )
		end
		table.insert(self.cl.exportData.list, eqShape )
	end

	setTpAnimation( self.cl.fpAnimations, "idleFlip", 0.1 )
end

function blockEditor:sv_getOffsetPosition( oldBody, caller )
	local oldMin = sm.vec3.one()*100000
	local oldMax = sm.vec3.zero()

	for i,body in pairs(oldBody:getCreationBodies()) do
		local aa,bb = body:getWorldAabb()
	    oldMin = oldMin:min(aa)
	    oldMax = oldMax:max(bb)
	end


	local bb = oldMax-oldMin

	local center = (bb/2)+oldMin

	local dist = center - _G.__lifts[caller.id].position/4 - sm.vec3.new(0,0,0.625)

	for i,x in pairs({"x","y","z"}) do 
	    if dist[x] < 0 and bb[x] >= 0 then
	        bb[x] = -bb[x]
	    end
	end

	local newPos = _G.__lifts[caller.id].position/4 - (bb/2 + dist)
	newPos.z = 0

	local offset =  ((newPos-oldBody:transformPoint( sm.vec3.zero() ))*4)
	local offsetB = offset + ((bb/2 + dist)*8)

    return {
        shapeId = "10a0792f-cb10-44b2-b26c-72cb8a1d5a42",
        xaxis = 1,
        zaxis = 3,
        pos = {
			x = math.floor(offset.x),
			y = math.floor(offset.y),
			z = math.floor(oldMin.z+5)
		}
    }, {
        shapeId = "10a0792f-cb10-44b2-b26c-72cb8a1d5a42",
        xaxis = 1,
        zaxis = 3,
        pos = {
			x = math.floor(offsetB.x),
			y = math.floor(offsetB.y),
			z = math.floor(offsetB.z+5)
		}
    }
end

function blockEditor.cl_animate( self, dt )
	local isSprinting =  self.tool:isSprinting()
	if self.tool:isLocal() then

		if self.equipped then
			if self.cl.fpAnimations.currentAnimation ~= "idleFlip" then
				if isSprinting and self.cl.fpAnimations.currentAnimation ~= "sprintInto" and self.cl.fpAnimations.currentAnimation ~= "sprintIdle" then
					swapFpAnimation( self.cl.fpAnimations, "sprintExit", "sprintInto", 0.0 )
				elseif not self.tool:isSprinting() and ( self.cl.fpAnimations.currentAnimation == "sprintIdle" or self.cl.fpAnimations.currentAnimation == "sprintInto" ) then
					swapFpAnimation( self.cl.fpAnimations, "sprintInto", "sprintExit", 0.0 )
				end
			end
		end

		updateFpAnimations( self.cl.fpAnimations, true, dt )
	end

	if not self.cl.equipped then
		if self.cl.wantEquipped then
			self.cl.wantEquipped = false
			self.cl.equipped = true
		end
		return
	end

	for name, animation in pairs( self.cl.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.cl.tpAnimations.currentAnimation then
			if animation.time >= animation.info.duration - self.cl.blendTime then
				if name == "pickup" then
					setTpAnimation( self.cl.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.cl.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		end
	end
end

function blockEditor.client_onUpdate( self, dt )
	self:cl_animate(dt)

	if self.tool:isEquipped() and self.tool:isLocal() then
		local hit, result = raycast()

		self.cl.raycast.hit = hit
		self.cl.raycast.result = result

		local type_ = result.type
		local isShape = type_ == "body"
		local isValid = isShape or type_ == "joint"
		if not isValid then
			if self.cl.effect.visualization:isPlaying() then 
				self.cl.effect.visualization:stop() 
			end
		else
			local resultShape = isShape and result:getShape() or result:getJoint()
			self.cl.raycast.resultShape = resultShape

			if not self.cl.gui:isActive() then
				self.cl.effect.effectShape = self.cl.raycast.resultShape
			end

			if sm.exists(self.cl.effect.effectShape) then
				if self.cl.hasMode == 1 or self.cl.hasMode == 2 then
					if self.cl.effect.visualization:isPlaying() then 
						self.cl.effect.visualization:stop() 
					end
				else
					if self.cl.effect.visualization:isPlaying() then
						self.cl.effect.visualization:stop()
					end

					local pos, rot, scale, uuid = getEffectData(self.cl.effect.effectShape, dt)
					self.cl.effect.visualization:setPosition(pos)
					self.cl.effect.visualization:setRotation(rot)
					self.cl.effect.visualization:setScale(scale)
					self.cl.effect.visualization:setParameter("uuid", uuid)
					self.cl.effect.visualization:start()
				end
			else
				if self.cl.effect.visualization:isPlaying() then 
					self.cl.effect.visualization:stop() 
				end
			end
		end

		local shapeLength =  #self.cl.exportData.shapes
		local jointLength = #self.cl.exportData.joints

		if shapeLength >= 1 then
			for i, shape in pairs(self.cl.exportData.shapes) do
				if sm.exists(shape) then
					local effect = self.cl.effect.effectTableShapes[i]
					if not effect then
						effect = sm.effect.createEffect("ShapeRenderable")
						effect:setParameter("visualization", true)

						self.cl.effect.compareTableShapes[i] = {
							pos = sm.vec3.zero(), 
							rot = sm.quat.identity(),
							scale = sm.vec3.zero(),
							uuid = ""
						}

					else
						if effect:isPlaying() then 
							effect:stop() 
						end
					end

					local pos, rot, scale, uuid = getEffectData(shape, dt)
					local compare = self.cl.effect.compareTableShapes[i]
					if compare.pos ~= pos then
						effect:setPosition(pos)
						self.cl.effect.compareTableShapes[i].pos = pos
					end
					if compare.rot ~= rot then
						effect:setRotation(rot)
						self.cl.effect.compareTableShapes[i].rot = rot
					end
					if compare.scale ~= scale then
						effect:setScale(scale)
						self.cl.effect.compareTableShapes[i].scale = scale
					end
					if compare.uuid ~= tostring(uuid) then
						effect:setParameter("uuid", uuid)
						self.cl.effect.compareTableShapes[i].uuid = tostring(uuid)
					end

					self.cl.effect.effectTableShapes[i] = effect
					self.cl.effect.effectTableShapes[i]:start()
				end
			end
		end

		if jointLength >= 1 then
			for i, joint in pairs(self.cl.exportData.joints) do
				if sm.exists(joint) then
					local effect = self.cl.effect.effectTableJoints[i]

					if not effect then
						effect = sm.effect.createEffect("ShapeRenderable")
						effect:setParameter("visualization", true)

						self.cl.effect.compareTableJoints[i] = {
							pos = sm.vec3.zero(), 
							rot = sm.quat.identity(),
							scale = sm.vec3.zero(),
							uuid = ""
						}

					else
						if effect:isPlaying() then effect:stop() end
					end

					local pos, rot, scale, uuid = getEffectData(joint, dt)
					local compare = self.cl.effect.compareTableJoints[i]
					if compare.pos ~= pos then
						effect:setPosition(pos)
						self.cl.effect.compareTableJoints[i].pos = pos
					end
					if compare.rot ~= rot then
						effect:setRotation(rot)
						self.cl.effect.compareTableJoints[i].rot = rot
					end
					if compare.scale ~= scale then
						effect:setScale(scale)
						self.cl.effect.compareTableJoints[i].scale = scale
					end
					if compare.uuid ~= tostring(uuid) then
						effect:setParameter("uuid", uuid)
						self.cl.effect.compareTableJoints[i].uuid = tostring(uuid)
					end

					self.cl.effect.effectTableJoints[i] = effect
					self.cl.effect.effectTableJoints[i]:start()
				end
			end
		end

		if #self.cl.exportData.list > 0 then
			for i,effect in ipairs(self.cl.textEffects) do
				if sm.exists(effect) then
					local shape = self.cl.exportData.list[i]
					local isShape = type(shape) == "Shape"
					if sm.exists(shape) then
						if isShape then
							effect:setWorldPosition(shape:getInterpolatedWorldPosition())
						else
							local effectPos = shape:getWorldPosition()
							local bb = shape:getBoundingBox()
							local offset = math.abs(bb.z) / 2 - 0.125

							local rot = sm.quat.getAt(shape:getWorldRotation())

							effectPos = effectPos + rot * offset

							effect:setWorldPosition(effectPos)
						end
					end
				end
			end
		end
	end
end

local __extraBuffer = sm.vec3.one()*0.01

function getEffectData(object, dt)
	local isShape = type(object) == "Shape"
	local effectScale = sm.vec3.one() / 4
	local uuid = object.uuid

	local lifted = isShape and object.body:isOnLift() or not isShape and object.shapeA.body:isOnLift()

	local objWorldPosition = object.worldPosition
    local objWorldRotation = object:getWorldRotation()
	local bb = object:getBoundingBox()

    local effectPos
    local jointType

	if isShape then
		effectScale = object.isBlock and bb + __extraBuffer or effectScale
		
		if object.isBlock then uuid = PlasticBLK end

	    effectPos = object:getInterpolatedWorldPosition() + object.velocity * dt
	else
		effectPos = objWorldPosition
		jointType = object:getType()

		local isPiston = jointType == "piston"
		local pistonLength = isPiston and object:getLength()
		
		local rot = sm.quat.getAt(objWorldRotation)

		if jointType == "unknown" then
			local len = math.max(math.abs(bb.x),  math.abs(bb.y), math.abs(bb.z))
			local offset = len / 2 - 0.125

			effectPos = objWorldPosition + rot * offset
		elseif isPiston and pistonLength > 1.05 and not lifted then
			uuid = PlasticBLK

			effectScale = sm.vec3.new(0.25, 0.25, pistonLength / 4)
			
			local fake = objWorldPosition + rot * pistonLength / 4
			local dir = fake - objWorldPosition

			effectPos = objWorldPosition + dir / 2 - (rot * 0.125)
		end
	end

	if isShape then
		local interpAt = object:getInterpolatedAt()
		local interpRight = object:getInterpolatedRight()
		local interpUp = object:getInterpolatedUp()
		local angularVelocity = object.body.angularVelocity

		local at = (interpAt + angularVelocity:rotate(-math.rad(90), interpAt) * dt):normalize()
		local right = (interpRight + angularVelocity:rotate(-math.rad(90), interpRight) * dt):normalize()
		local up = (interpUp + angularVelocity:rotate(-math.rad(90), interpUp) * dt):normalize()
		
		objWorldRotation = better_quat_rotation(at, right, up)
	end

	return effectPos, objWorldRotation, effectScale, uuid
end

function destroyEffectTable(effects)
	for i, v in pairs(effects) do
		v:destroy()
	end
end

function blockEditor.client_onToggle( self )
	return false
end

function blockEditor.sv_getJson( self, data, caller, regrab )
	local body
	if #data.shapes > 0 then 
		body = data.shapes[1].body 
	elseif #data.joints > 0 then 
		body = data.joints[1].shapeA.body 
	else
		return
	end

	if not body then return end

	local lifted = body:isOnLift()

	local shapeColors = {}
	local jointColors = {}
	
	local hasColoredShapes = false
	local hasColoredJoints = false

	local creation = sm.creation.exportToTable( body, true, lifted )

	local json = {}

		function setColors( list )
			for i,item in ipairs(list) do
				if sm.exists(item) then
					local newColor = sm.color.new(math.random()*0xffffff00)
					local colorHex = tostring(newColor):sub(1,6):lower()
					if type(item) == "Shape" then
						hasColoredShapes = true
						shapeColors[colorHex] = item.color
					else
						hasColoredJoints = true
						jointColors[colorHex] = item.color
					end
					item:setColor(newColor)
				end
			end
		end

		setColors(data.shapes)
		setColors(data.joints)

		creation = sm.creation.exportToTable(body, true, lifted)
			
		for bodyI, body in pairs(creation.bodies) do
			for shapeI, shape in pairs(body.childs) do
				local colorHex = shape.color:lower()
				if shapeColors[colorHex] then
					creation.bodies[bodyI].childs[shapeI].color = tostring(shapeColors[colorHex]):sub(1,6):lower()
					json[#json+1] = creation.bodies[bodyI].childs[shapeI]
				end
			end
		end
		if creation.joints then
			for jointI, joint in pairs(creation.joints) do
				local colorHex = joint.color:lower()
				if jointColors[colorHex] then
					creation.joints[jointI].color = tostring(jointColors[colorHex]):sub(1,6):lower()
					json[#json+1] = creation.joints[jointI]
				end
			end
		end

		--reset colors
		if hasColoredShapes then
			local allShapes = body:getCreationShapes()
			for i,shape in pairs(allShapes) do
				local oldColorHex = tostring(shape.color):sub(1,6):lower()
				local theNewColor = shapeColors[oldColorHex]
		        if theNewColor then
					shape:setColor(theNewColor)
					shapeColors[oldColorHex] = nil
		        end

			end
		end

		if hasColoredJoints then
			local allJoints = body:getCreationJoints()
			for i,joint in pairs(allJoints) do
				local oldColorHex = tostring(joint.color):sub(1,6):lower()
				local theNewColor = jointColors[oldColorHex]
		        if theNewColor then
					joint:setColor(theNewColor)
					jointColors[oldColorHex] = nil
		        end
			end
		end
	-- end
	if caller then
		local tick = sm.game.getCurrentTick()
		if not regrab then
			self.sv.lastJsons[caller.id] = {[tick] = json}
		end
		local strings = splitString(sm.json.writeJsonString(json), 65374)

		for i,v in ipairs(strings) do
			self.network:sendToClient(caller,"cl_reassembleSplit",{i=i,m=#strings,str=v})
		end
		if not regrab then
			data.id = tick
		end
		data.regrab = regrab
		self.network:sendToClient(caller, "cl_setJsonText",data)
	else
		return json
	end
end

function blockEditor.cl_reassembleSplit( self, data )
	if data.m == 1 then
		self.cl.json = data.str
	elseif data.i == 1 then
		self.cl.json = data.str
	elseif data.i == data.m then
		self.cl.json = self.cl.json .. data.str
	else
		self.cl.json = self.cl.json .. data.str
	end

end

function blockEditor.cl_setJsonText( self, data )
	if data.list then
		self.cl.exportData.shapes = data.shapes
		self.cl.exportData.joints = data.joints
		self.cl.exportData.list = 	data.list
	end
	if data.id then
		self.cl.lastChanged = data.id
	end
	if self.cl.json then
		self.cl.jsonText = beatifyTable(sm.json.parseJsonString(self.cl.json), 1)
		self.cl.gui:setText( "TextBox", self.cl.jsonText)
		
		if not data.regrab then
			self.cl.gui:open()
			self.cl.countEditTimes = 1
		end

		for i,v in ipairs(self.cl.exportData.list) do
			local effect = self.cl.textEffects[i]
			if not sm.exists(effect) then
				effect = sm.gui.createNameTagGui()
				self.cl.textEffects[i] = effect 
			end
			effect:setText("Text", tostring(i))
			effect:open()
		end
	else
		--if here then packet was too big
	end
end

function blockEditor.cl_onClose(self)
	self.cl.json = ""
	self.cl.hasMode = 0

	destroyEffectTable(self.cl.effect.effectTableJoints)
	destroyEffectTable(self.cl.effect.effectTableShapes)
	self.cl.effect.effectTableJoints = {}
	self.cl.effect.effectTableShapes = {}

	self.cl.exportData.shapes = {}
	self.cl.exportData.joints = {}
	self.cl.exportData.list = {}

	for i,v in pairs(self.cl.textEffects) do
		if sm.exists(v) then v:destroy() end
	end
	setTpAnimation( self.cl.fpAnimations, "rotateOut", 0.2 )
end

function better_quat_rotation(forward, right, up)
    forward = forward:safeNormalize(sm.vec3.new(1, 0, 0))
    right   = right:safeNormalize(sm.vec3.new(0, 0, 1))
    up      = up:safeNormalize(sm.vec3.new(0, 1, 0))

    local m11 = right.x; local m12 = right.y; local m13 = right.z
    local m21 = forward.x; local m22 = forward.y; local m23 = forward.z
    local m31 = up.x; local m32 = up.y; local m33 = up.z

    local biggestIndex = 0
    local fourBiggestSquaredMinus1 = m11 + m22 + m33

    local fourXSquaredMinus1 = m11 - m22 - m33
    if fourXSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourXSquaredMinus1
        biggestIndex = 1
    end

    local fourYSquaredMinus1 = m22 - m11 - m33
    if fourYSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourYSquaredMinus1
        biggestIndex = 2
    end

    local fourZSquaredMinus1 = m33 - m11 - m22
    if fourZSquaredMinus1 > fourBiggestSquaredMinus1 then
        fourBiggestSquaredMinus1 = fourZSquaredMinus1
        biggestIndex = 3
    end

    local biggestVal = math.sqrt(fourBiggestSquaredMinus1 + 1.0) * 0.5
    local mult = 0.25 / biggestVal

    if biggestIndex == 1 then
        return sm.quat.new(biggestVal, (m12 + m21) * mult, (m31 + m13) * mult, (m23 - m32) * mult)
    elseif biggestIndex == 2 then
        return sm.quat.new((m12 + m21) * mult, biggestVal, (m23 + m32) * mult, (m31 - m13) * mult)
    elseif biggestIndex == 3 then
        return sm.quat.new((m31 + m13) * mult, (m23 + m32) * mult, biggestVal, (m12 - m21) * mult)
    end

    return sm.quat.new((m23 - m32) * mult, (m31 - m13) * mult, (m12 - m21) * mult, biggestVal)
end