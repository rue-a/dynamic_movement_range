-- og author etc.
-- local script_author = "8 Hertz WAN IP"
-- local script_version = "1.11"
-- local mod_name = "hertz_dynamic_movement_range"
local script_author = "ruene"
local mod_name = "ruene_static_and_dynamic_movement_range"


-- mct
local settings = {
	base_reduction_modifier = 0.5,
	dynamic_modifier_tuner = 1
};

core:add_listener(mod_name .. "_MctInitialized", "MctInitialized", true, function(context)
	local mct = context:mct()
	local my_mod = mct:get_mod_by_key(mod_name)

	local base_reduction_percent_option = my_mod:get_option_by_key("base_reduction_percent_slider")
	base_reduction_percent_option:set_read_only(true)
	settings.base_reduction_modifier = math.abs(100 - base_reduction_percent_option:get_finalized_setting()) / 100

	local dynamic_modifier_tuner_option = my_mod:get_option_by_key("dynamic_modifier_tuner_slider")
	dynamic_modifier_tuner_option:set_read_only(true)
	settings.dynamic_modifier_tuner = dynamic_modifier_tuner_option:get_finalized_setting() / 10
end, false)



-- Register event listeners
function create_ruene_dynamic_movement_range_modification_listeners()
	out("##### ADDING ruene_dynamic_movement_range LISTENERS #####")

	local function manage_character_movement(char)
		remove_ruene_dmr_bundle_from_character(char)
		local movement_range_modifier_percent = calculate_dynamic_movement_range_modifier(char)
		apply_ruene_dmr_bundle_to_character(char, movement_range_modifier_percent)
	end

	core:add_listener(mod_name .. "_FactionBeginTurnPhaseNormal", "FactionBeginTurnPhaseNormal", true,
		function(context)
			local faction = context:faction()
			for i = 0, faction:character_list():num_items() - 1 do
				local char = faction:character_list():item_at(i)
				if cm:character_is_army_commander(char) then
					manage_character_movement(char)
				end
			end
		end, true)

	core:add_listener(mod_name .. "_UnitDisbanded", "UnitDisbanded", true, function(context)
		local commander = context:unit():force_commander()
		manage_character_movement(commander)
	end, true)

	core:add_listener(mod_name .. "_CharacterSelected", "CharacterSelected", true, function(context)
		local char = context:character()

		if cm:character_is_army_commander(char) then
			manage_character_movement(char)
		end
	end, true)
end

-- Utility: round function
function math.round(n)
	return math.floor(n + 0.5)
end

-- Calculates movement modifier based on army composition and settings
--- @param character CHARACTER_SCRIPT_INTERFACE
function calculate_dynamic_movement_range_modifier(character)
	local dynamic_movement_modifiers = { 0.12, 0.11, 0.09, 0.07, 0.05, 0.03, 0.02, 0.01, 0,
		-0.01, -0.02, -0.03, -0.04, -0.06, -0.08, -0.10, -0.12, -0.15,
		-0.18, -0.21, -0.23, -0.26, -0.29, -0.32, -0.35, -0.38,
		-0.41, -0.44, -0.47, -0.50 };

	local unit_list = character:military_force():unit_list()
	local counts = {
		cav = 0,
		art = 0,
		spc = 0,
		other = 0
	}
	for i = 0, unit_list:num_items() - 1 do
		local unit = unit_list:item_at(i)
		local unit_class = unit:unit_class()
		if unit_class:find("^cav_") or unit_class == "chariot" then
			counts.cav = counts.cav + 1
		elseif unit_class:find("^art_") then
			counts.art = counts.art + 1
		elseif unit_class == "spcl" or unit_class == "com" or unit_class == "inf_mis" then
			counts.spc = counts.spc + 1
		else
			counts.other = counts.other + 1
		end
	end

	local cav_w = math.floor(counts.cav / 2 + 1)
	local art_w = math.floor(counts.art * 2.3)
	local spc_w = math.floor(counts.spc / 1.5 + 1)
	local army_weight = cav_w + art_w + spc_w + counts.other
	if army_weight > 30 then
		army_weight = 30
	end


	-- apply army_weight senistivity tuner
	local dynamic_movement_modifier = settings.dynamic_modifier_tuner *
		dynamic_movement_modifiers[army_weight]
	-- Convert to percent and round
	local dynamic_movement_modifier_percent = math.round((dynamic_movement_modifier) * 100)

	-- set movement modification limits
	if dynamic_movement_modifier_percent > 25 then
		dynamic_movement_modifier_percent = 25;
	end
	if dynamic_movement_modifier_percent < -50 then
		dynamic_movement_modifier_percent = -50;
	end

	-- apply base reduction modifier (if we reduce base movemnt by 50,
	-- we only want to reduce dymanic movement by max 25, not 50 again)
	local dynamic_movement_modifier_percent_static_adjusted = math.round(settings.base_reduction_modifier *
		dynamic_movement_modifier_percent)

	-- outputs if this is the player's army
	if character:faction():is_human() then
		out("[RUENE DEBUG] Army weight: " .. army_weight)
		out("[RUENE DEBUG] Cav weight: " .. cav_w)
		out("[RUENE DEBUG] Art weight: " .. art_w)
		out("[RUENE DEBUG] Spc weight: " .. spc_w)
		out("[RUENE DEBUG] Other weight: " .. counts.other)
		out("[RUENE DEBUG] Dynamic modifier: " .. dynamic_movement_modifier)
		out("[RUENE DEBUG] Dynamic percent modifier: " .. dynamic_movement_modifier_percent)
		out("[RUENE DEBUG] Final percent reduction: " .. dynamic_movement_modifier_percent_static_adjusted)
	end

	return dynamic_movement_modifier_percent
end

--- remove old bundle
--- @param character CHARACTER_SCRIPT_INTERFACE
function remove_ruene_dmr_bundle_from_character(character)
	local cqi = character:command_queue_index()
	cm:remove_effect_bundle_from_characters_force("ruene_dmr_bundle", cqi)
end

--- Applies movement range modifier to character's army
--- @param character CHARACTER_SCRIPT_INTERFACE
--- @param movement_modifier number Positive increases range, negative decreases
function apply_ruene_dmr_bundle_to_character(character, movement_modifier)
	if not character or not character:has_military_force() then
		return
	end

	-- Base effect bundle key, from the effect_bundles table
	local bundle_name = "ruene_dmr_bundle"

	-- Creating new bundle
	local movement_bundle = cm:create_new_custom_effect_bundle(bundle_name)
	movement_bundle:set_duration(0) -- Lasts forever
	movement_bundle:add_effect(
		"wh_main_effect_force_all_campaign_movement_range",
		"force_to_force_own",
		movement_modifier
	)

	--Applying it to the military force
	cm:apply_custom_effect_bundle_to_characters_force(movement_bundle, character)
end

function apply_ruene_static_movement_range_reduction()
	local bundle_name = "ruene_smr_bundle"
	local faction_list = cm:model():world():faction_list()
	local static_percent_movement_modifier = -1 * math.round((1 - settings.base_reduction_modifier) * 100)
	out("[RUENE DEBUG] Base reduction: " .. static_percent_movement_modifier)


	for i = 0, faction_list:num_items() - 1 do
		local faction = faction_list:item_at(i)

		-- Safety check is still recommended!
		if faction and not faction:is_dead() then
			cm:remove_effect_bundle(bundle_name, faction:name())
			local movement_bundle = cm:create_new_custom_effect_bundle(bundle_name)
			movement_bundle:set_duration(0)
			movement_bundle:add_effect(
				"wh_main_effect_force_all_campaign_movement_range",
				"faction_to_force_own",
				static_percent_movement_modifier
			)

			cm:apply_custom_effect_bundle_to_faction(movement_bundle, faction)
		end
	end
end

-- Initialize on first tick
cm:add_first_tick_callback(function()
	create_ruene_dynamic_movement_range_modification_listeners();
	apply_ruene_static_movement_range_reduction();
end)
