/// The deep fryer pings after this long, letting people know it's "perfect"
#define DEEPFRYER_COOKTIME 50
/// The deep fryer pings after this long, reminding people that there's a very burnt object inside
#define DEEPFRYER_BURNTIME 120

/// Global typecache of things which should never be fried.
GLOBAL_LIST_INIT(oilfry_blacklisted_items, typecacheof(list(
	/obj/item/reagent_containers/cup,
	/obj/item/reagent_containers/syringe,
	/obj/item/reagent_containers/condiment,
	/obj/item/delivery,
	/obj/item/his_grace,
	/obj/item/bodybag/bluespace,
	/obj/item/mod/control,
	/obj/machinery/power/apc, //i cant believe im doing this
)))

/obj/machinery/deepfryer
	name = "deep fryer"
	desc = "Deep fried <i>everything</i>."
	icon = 'icons/obj/kitchen.dmi'
	icon_state = "fryer_off"
	density = TRUE
	pass_flags_self = PASSMACHINE | LETPASSTHROW
	idle_power_usage = BASE_MACHINE_IDLE_CONSUMPTION * 0.05
	layer = BELOW_OBJ_LAYER
	circuit = /obj/item/circuitboard/machine/deep_fryer

	/// What's being fried RIGHT NOW?
	var/frying = FALSE
	/// How long the current object has been cooking for
	var/cook_time = 0
	/// How much cooking oil is used per process
	var/oil_use = 0.025
	/// How quickly we fry food - modifier applied per process tick
	var/fry_speed = 1
	/// Has our currently frying object been fried?
	var/frying_fried = FALSE
	/// Has our currently frying object been burnt?
	var/frying_burnt = FALSE

	/// Our sound loop for the frying sounde effect.
	var/datum/looping_sound/deep_fryer/fry_loop
	/// Static typecache of things we can't fry.
	var/static/list/deepfry_blacklisted_items = typecacheof(list(
		/obj/item/screwdriver,
		/obj/item/crowbar,
		/obj/item/wrench,
		/obj/item/wirecutters,
		/obj/item/multitool,
		/obj/item/weldingtool,
	))

/obj/machinery/deepfryer/Initialize(mapload)
	. = ..()
	basket = new(src)
	create_reagents(50, OPENCONTAINER)
	reagents.add_reagent(/datum/reagent/consumable/cooking_oil, 25)
	fry_loop = new(src, FALSE)

/obj/machinery/deepfryer/Destroy()
	QDEL_NULL(fry_loop)
	return ..()

/obj/machinery/deepfryer/RefreshParts()
	. = ..()
	var/oil_efficiency = 0
	for(var/datum/stock_part/micro_laser/laser in component_parts)
		oil_efficiency += laser.tier
	oil_use = initial(oil_use) - (oil_efficiency * 0.00475)
	fry_speed = oil_efficiency

/obj/machinery/deepfryer/examine(mob/user)
	. = ..()
	if(in_range(user, src) || isobserver(user))
		. += span_notice("The status display reads: Frying at <b>[fry_speed*100]%</b> speed.<br>Using <b>[oil_use]</b> units of oil per second.")

/obj/machinery/deepfryer/wrench_act(mob/living/user, obj/item/tool)
	. = ..()
	default_unfasten_wrench(user, tool)
	return TOOL_ACT_TOOLTYPE_SUCCESS

/obj/machinery/deepfryer/attackby(obj/item/weapon, mob/user, params)
	// Dissolving pills into the frier
	if(istype(weapon, /obj/item/reagent_containers/pill))
		if(!reagents.total_volume)
			to_chat(user, span_warning("There's nothing to dissolve [weapon] in!"))
			return
		user.visible_message(span_notice("[user] drops [weapon] into [src]."), span_notice("You dissolve [weapon] in [src]."))
		weapon.reagents.trans_to(src, weapon.reagents.total_volume, transfered_by = user)
		qdel(weapon)
		return
	// Make sure we have cooking oil
	if(!reagents.has_reagent(/datum/reagent/consumable/cooking_oil))
		to_chat(user, span_warning("[src] has no cooking oil to fry with!"))
		return
	// Don't deep fry indestructible things, for sanity reasons
	if(weapon.resistance_flags & INDESTRUCTIBLE)
		to_chat(user, span_warning("You don't feel it would be wise to fry [weapon]..."))
		return
	// No fractal frying
	if(HAS_TRAIT(weapon, TRAIT_FOOD_FRIED))
		to_chat(user, span_userdanger("Your cooking skills are not up to the legendary Doublefry technique."))
		return
	// Handle opening up the fryer with tools
	var/fryer_icon = "fryer_off"
	if(!basket)
		fryer_icon = "fryer"
	if(default_deconstruction_screwdriver(user, fryer_icon, fryer_icon, weapon)) //where's the open maint panel icon?!
		return
	else
		// So we skip the attack animation
		if(weapon.is_drainable())
			return
		// Check for stuff we certainly shouldn't fry
		else if(is_type_in_typecache(weapon, deepfry_blacklisted_items) \
			|| is_type_in_typecache(weapon, GLOB.oilfry_blacklisted_items) \
			|| weapon.atom_storage \
			|| HAS_TRAIT(weapon, TRAIT_NODROP) \
			|| (weapon.item_flags & (ABSTRACT|DROPDEL|HAND_ITEM)))
			return ..()

	return ..()

/*
/obj/machinery/deepfryer/process(seconds_per_tick)
	..()
	var/datum/reagent/consumable/cooking_oil/frying_oil = reagents.has_reagent(/datum/reagent/consumable/cooking_oil)
	if(!frying_oil)
		return
	reagents.chem_temp = frying_oil.fry_temperature
	if(!frying)
		return

	reagents.trans_to(frying, oil_use * seconds_per_tick, multiplier = fry_speed * 3) //Fried foods gain more of the reagent thanks to space magic
	cook_time += fry_speed * seconds_per_tick
	if(cook_time >= DEEPFRYER_COOKTIME && !frying_fried)
		frying_fried = TRUE //frying... frying... fried
		playsound(src.loc, 'sound/machines/ding.ogg', 50, TRUE)
		audible_message(span_notice("[src] dings!"))
	else if (cook_time >= DEEPFRYER_BURNTIME && !frying_burnt)
		frying_burnt = TRUE
		visible_message(span_warning("[src] emits an acrid smell!"))

	use_power(active_power_usage)
*/

/obj/machinery/deepfryer/proc/blow_up()
	visible_message(span_userdanger("[src] blows up from the entropic reaction!"))
	explosion(src, devastation_range = 1, heavy_impact_range = 3, light_impact_range = 5, flame_range = 7)
	deconstruct(FALSE)

/obj/machinery/deepfryer/attack_ai(mob/user)
	return

/obj/machinery/deepfryer/attack_hand(mob/living/user, list/modifiers)
	if(frying)
		frying = FALSE
		reset_frying(user)
		if(Adjacent(user) && !issilicon(user) && basket)
			user.put_in_hands(basket)
			basket = null
			icon_state = "fryer"
		return

	else if(user.pulling && iscarbon(user.pulling) && reagents.total_volume)
		if(user.grab_state < GRAB_AGGRESSIVE)
			to_chat(user, span_warning("You need a better grip to do that!"))
			return
		var/mob/living/carbon/dunking_target = user.pulling
		log_combat(user, dunking_target, "dunked", null, "into [src]")
		user.visible_message(span_danger("[user] dunks [dunking_target]'s face in [src]!"))
		reagents.expose(dunking_target, TOUCH)
		var/bio_multiplier = dunking_target.getarmor(BODY_ZONE_HEAD, BIO) * 0.01
		var/target_temp = dunking_target.bodytemperature
		var/cold_multiplier = 1
		if(target_temp < TCMB + 10) // a tiny bit of leeway
			dunking_target.visible_message(span_userdanger("[dunking_target] explodes from the entropic difference! Holy fuck!"))
			dunking_target.investigate_log("has been gibbed by entropic difference (being dunked into [src]).", INVESTIGATE_DEATHS)
			dunking_target.gib()
			log_combat(user, dunking_target, "blew up", null, "by dunking them into [src]")
			return

		else if(target_temp < T0C)
			cold_multiplier += round(target_temp * 1.5 / T0C, 0.01)
		dunking_target.apply_damage(min(30 * bio_multiplier * cold_multiplier, reagents.total_volume), BURN, BODY_ZONE_HEAD)
		if(reagents.reagent_list) //This can runtime if reagents has nothing in it.
			reagents.remove_all((reagents.total_volume/2))
		dunking_target.Paralyze(60)
		user.changeNext_move(CLICK_CD_MELEE)
	if(Adjacent(user) && !issilicon(user) && basket)
		user.put_in_hands(basket)
		basket = null
		icon_state = "fryer"

	return ..()

#undef DEEPFRYER_COOKTIME
#undef DEEPFRYER_BURNTIME
