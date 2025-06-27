local script_author = "ruene"
-- local script_version = "0.1.0"
local mod_name = "ruene_static_and_dynamic_movement_range"

local mct = get_mct()
local mct_mod = mct:register_mod(mod_name)

mct_mod:set_title("Dynamic Movement x Minus Base Reduction")
mct_mod:set_author(script_author)
mct_mod:set_description("Reduce Base Movement by [value], before applying dymanic movement range multipliers")


local base_reduction_percent_option = mct_mod:add_new_option("base_reduction_percent_slider", "slider")
base_reduction_percent_option:slider_set_min_max(0, 50)
base_reduction_percent_option:slider_set_step_size(5)
base_reduction_percent_option:set_default_value(40)
base_reduction_percent_option:set_text("Baseline Movement Reduction")
base_reduction_percent_option:set_tooltip_text(
    "Percentage by which movement range is reduced before dynamic adjustments based on army weight are applied.")


local dynamic_modifier_tuner_option = mct_mod:add_new_option("dynamic_modifier_tuner_slider", "slider")
dynamic_modifier_tuner_option:slider_set_min_max(5, 20)
dynamic_modifier_tuner_option:slider_set_step_size(1)
dynamic_modifier_tuner_option:set_default_value(10)
dynamic_modifier_tuner_option:set_text("Army Size Sensitivity")
dynamic_modifier_tuner_option:set_tooltip_text(
    "Defines the sensitivity of the movement range adjustments based on the army weight. [5] halves the effects caused by dynamic army weight, [10] keeps the defaults, and [20] doubles them.")
