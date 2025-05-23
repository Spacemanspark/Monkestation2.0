
////////////////////////////////////////////EGGS////////////////////////////////////////////

/obj/item/food/chocolateegg
	name = "chocolate egg"
	desc = "Such, sweet, fattening food."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "chocolateegg"
	food_reagents = list(/datum/reagent/consumable/nutriment = 5, /datum/reagent/consumable/sugar = 2, /datum/reagent/consumable/coco = 2, /datum/reagent/consumable/nutriment/vitamin = 1)
	tastes = list("chocolate" = 4, "sweetness" = 1)
	foodtypes = JUNKFOOD | SUGAR
	food_flags = FOOD_FINGER_FOOD
	w_class = WEIGHT_CLASS_TINY

/// Counter for number of chicks hatched by throwing eggs, minecraft style. Chicks will not emerge from thrown eggs if this value exceeds the MAX_CHICKENS define.
GLOBAL_VAR_INIT(chicks_from_eggs, 0)

/obj/item/food/egg
	name = "egg"
	desc = "An egg!"
	icon_state = "chicken"
	icon = 'monkestation/icons/obj/ranching/eggs.dmi'
	inhand_icon_state = "egg"
	food_reagents = list(/datum/reagent/consumable/eggyolk = 2, /datum/reagent/consumable/eggwhite = 4)
	foodtypes = MEAT | RAW
	w_class = WEIGHT_CLASS_TINY
	ant_attracting = FALSE
	decomp_type = /obj/item/food/egg/rotten
	decomp_req_handle = TRUE //so laid eggs can actually become chickens
	var/chick_throw_prob = 13
	bite_consumption = 100 // whole ass egg all at once
	food_buffs = STATUS_EFFECT_FOOD_STAM_TINY

/obj/item/food/egg/Initialize(mapload)
	. = ..()
	RegisterSignal(src, COMSIG_FOOD_EATEN, PROC_REF(consumed_egg))

/obj/item/food/egg/proc/consumed_egg(datum/source, mob/living/eater, mob/living/feeder)
	SIGNAL_HANDLER
	return

/obj/item/food/egg/make_bakeable()
	AddComponent(/datum/component/bakeable, /obj/item/food/boiledegg, rand(15 SECONDS, 20 SECONDS), TRUE, TRUE)

/obj/item/food/egg/make_microwaveable()
	AddElement(/datum/element/microwavable, /obj/item/food/boiledegg)

/obj/item/food/egg/rotten
	food_reagents = list(/datum/reagent/consumable/eggrot = 10, /datum/reagent/consumable/mold = 10)
	foodtypes = GROSS
	preserved_food = TRUE

/obj/item/food/egg/rotten/make_bakeable()
	AddComponent(/datum/component/bakeable, /obj/item/food/boiledegg/rotten, rand(15 SECONDS, 20 SECONDS), TRUE, TRUE)

/obj/item/food/egg/rotten/make_microwaveable()
	AddElement(/datum/element/microwavable, /obj/item/food/boiledegg/rotten)

/obj/item/food/egg/gland
	desc = "An egg! It looks weird..."

/obj/item/food/egg/gland/Initialize(mapload)
	. = ..()
	reagents.add_reagent(get_random_reagent_id(), 15)

	var/color = mix_color_from_reagents(reagents.reagent_list)
	add_atom_colour(color, FIXED_COLOUR_PRIORITY)

/obj/item/food/egg/throw_impact(atom/hit_atom, datum/thrownthing/throwingdatum)
	if (..()) // was it caught by a mob?
		return

	var/turf/hit_turf = get_turf(hit_atom)
	new /obj/effect/decal/cleanable/food/egg_smudge(hit_turf)
	//Chicken code uses this MAX_CHICKENS variable, so I figured that I'd use it again here. Even this check and the check in chicken code both use the MAX_CHICKENS variable, they use independent counter variables and thus are independent of each other.
	if(prob(chick_throw_prob) && GLOB.chicks_from_eggs < MAX_CHICKENS) //Roughly a 1/8 (12.5%) chance to make a chick, as in Minecraft. I decided not to include the chances for the creation of multiple chicks from the impact of one egg, since that'd probably require nested prob()s or something (and people might think that it was a bug, anyway).
		pre_hatch()
		GLOB.chicks_from_eggs++

	reagents?.expose(hit_atom, TOUCH)
	if(!QDELETED(src))
		qdel(src)

/obj/item/food/egg/attackby(obj/item/item, mob/user, params)
	if(istype(item, /obj/item/toy/crayon))
		var/obj/item/toy/crayon/crayon = item
		var/clr = crayon.crayon_color

		if(!(clr in list("blue", "green", "mime", "orange", "purple", "rainbow", "red", "yellow")))
			to_chat(usr, span_notice("[src] refuses to take on this colour!"))
			return

		to_chat(usr, span_notice("You colour [src] with [item]."))
		icon_state = "egg-[clr]"

	else if(istype(item, /obj/item/stamp/clown))
		var/clowntype = pick("grock", "grimaldi", "rainbow", "chaos", "joker", "sexy", "standard", "bobble",
			"krusty", "bozo", "pennywise", "ronald", "jacobs", "kelly", "popov", "cluwne")
		icon_state = "egg-clown-[clowntype]"
		desc = "An egg that has been decorated with the grotesque, robustable likeness of a clown's face. "
		to_chat(usr, span_notice("You stamp [src] with [item], creating an artistic and not remotely horrifying likeness of clown makeup."))

	else if(is_reagent_container(item))
		var/obj/item/reagent_containers/dunk_test_container = item
		if (!dunk_test_container.is_drainable() || !dunk_test_container.reagents.has_reagent(/datum/reagent/water))
			return

		to_chat(user, span_notice("You check if [src] is rotten."))
		if(istype(src, /obj/item/food/egg/rotten))
			to_chat(user, span_warning("[src] floats in the [dunk_test_container]!"))
		else
			to_chat(user, span_notice("[src] sinks into the [dunk_test_container]!"))
	else
		..()

/obj/item/food/egg/afterattack_secondary(atom/target, mob/user, proximity_flag, click_parameters)
	. = ..()
	if(. == SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN)
		return

	if(!istype(target, /obj/machinery/griddle))
		return SECONDARY_ATTACK_CALL_NORMAL

	var/atom/broken_egg = new /obj/item/food/rawegg(target.loc)
	broken_egg.pixel_x = pixel_x
	broken_egg.pixel_y = pixel_y
	playsound(get_turf(user), 'sound/items/sheath.ogg', 40, TRUE)
	reagents.copy_to(broken_egg,reagents.total_volume)

	var/obj/machinery/griddle/hit_griddle = target
	hit_griddle.AddToGrill(broken_egg, user)
	target.balloon_alert(user, "cracks [src] open")

	qdel(src)
	return SECONDARY_ATTACK_CANCEL_ATTACK_CHAIN

/obj/item/food/egg/blue
	icon_state = "egg-blue"
	inhand_icon_state = "egg-blue"
/obj/item/food/egg/green
	icon_state = "egg-green"
	inhand_icon_state = "egg-green"
/obj/item/food/egg/mime
	icon_state = "egg-mime"
	inhand_icon_state = "egg-mime"
/obj/item/food/egg/orange
	icon_state = "egg-orange"
	inhand_icon_state = "egg-orange"

/obj/item/food/egg/purple
	icon_state = "egg-purple"
	inhand_icon_state = "egg-purple"

/obj/item/food/egg/rainbow
	icon_state = "chicken"

/obj/item/food/egg/red
	icon_state = "egg-red"
	inhand_icon_state = "egg-red"

/obj/item/food/egg/yellow
	icon_state = "egg-yellow"
	inhand_icon_state = "egg-yellow"

/obj/item/food/egg/penguin_egg
	icon = 'icons/mob/simple/penguins.dmi'
	icon_state = "penguin_egg"

/obj/item/food/egg/fertile
	name = "fertile-looking egg"
	desc = "An egg! It looks fertilized.\nQuite how you can tell this just by looking at it is a mystery."
	chick_throw_prob = 100

/obj/item/food/egg/fertile/Initialize(mapload, loc)
	. = ..()

	AddComponent(/datum/component/fertile_egg,\
		embryo_type = /mob/living/basic/chick,\
		minimum_growth_rate = 1,\
		maximum_growth_rate = 2,\
		total_growth_required = 200,\
		current_growth = 0,\
		location_allowlist = typecacheof(list(/turf)),\
		spoilable = FALSE,\
	)

/obj/item/food/friedegg
	name = "fried egg"
	desc = "A fried egg. Would go well with a touch of salt and pepper."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "friedegg"
	food_reagents = list(
		/datum/reagent/consumable/nutriment/protein = 3,
		/datum/reagent/consumable/eggyolk = 1,
		/datum/reagent/consumable/nutriment/vitamin = 1,
	)
	bite_consumption = 1
	tastes = list("egg" = 4)
	foodtypes = MEAT | FRIED | BREAKFAST
	w_class = WEIGHT_CLASS_SMALL
	burns_on_grill = TRUE

/obj/item/food/rawegg
	name = "raw egg"
	desc = "Supposedly good for you, if you can stomach it. Better fried."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "rawegg"
	food_reagents = list() //Recieves all reagents from its whole egg counterpart
	bite_consumption = 1
	tastes = list("raw egg" = 6, "sliminess" = 1)
	eatverbs = list("gulp down")
	foodtypes = MEAT | RAW
	w_class = WEIGHT_CLASS_SMALL

/obj/item/food/rawegg/make_grillable()
	AddComponent(/datum/component/grillable, /obj/item/food/friedegg, rand(20 SECONDS, 35 SECONDS), TRUE, FALSE)

/obj/item/food/boiledegg
	name = "boiled egg"
	desc = "A hard boiled egg."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "egg"
	inhand_icon_state = "egg"
	food_reagents = list(
		/datum/reagent/consumable/nutriment/protein = 3,
		/datum/reagent/consumable/nutriment/vitamin = 1,
	)
	tastes = list("egg" = 1)
	foodtypes = MEAT | BREAKFAST
	food_flags = FOOD_FINGER_FOOD
	w_class = WEIGHT_CLASS_SMALL
	ant_attracting = FALSE
	decomp_type = /obj/item/food/boiledegg/rotten
	food_buffs = STATUS_EFFECT_FOOD_STAM_TINY

/obj/item/food/eggsausage
	name = "egg with sausage"
	desc = "A good egg with a side of sausages."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "eggsausage"
	food_reagents = list(/datum/reagent/consumable/nutriment/protein = 8, /datum/reagent/consumable/nutriment/vitamin = 2, /datum/reagent/consumable/nutriment = 4)
	foodtypes = MEAT | FRIED | BREAKFAST
	tastes = list("egg" = 4, "meat" = 4)
	venue_value = FOOD_PRICE_NORMAL

/obj/item/food/boiledegg/rotten
	food_reagents = list(/datum/reagent/consumable/eggrot = 10)
	tastes = list("rotten egg" = 1)
	foodtypes = GROSS
	preserved_food = TRUE

/obj/item/food/omelette //FUCK THIS
	name = "omelette du fromage"
	desc = "That's all you can say!"
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "omelette"
	food_reagents = list(
		/datum/reagent/consumable/nutriment/protein = 10,
		/datum/reagent/consumable/nutriment/vitamin = 3,
	)
	bite_consumption = 1
	w_class = WEIGHT_CLASS_SMALL
	tastes = list("egg" = 1, "cheese" = 1)
	foodtypes = MEAT | BREAKFAST | DAIRY
	venue_value = FOOD_PRICE_CHEAP
	food_buffs = STATUS_EFFECT_FOOD_STAM_MEDIUM

/obj/item/food/omelette/attackby(obj/item/item, mob/user, params)
	if(istype(item, /obj/item/kitchen/fork))
		var/obj/item/kitchen/fork/fork = item
		if(fork.forkload)
			to_chat(user, span_warning("You already have omelette on your fork!"))
		else
			fork.icon_state = "forkloaded"
			user.visible_message(span_notice("[user] takes a piece of omelette with [user.p_their()] fork!"), \
				span_notice("You take a piece of omelette with your fork."))

			var/datum/reagent/reagent = pick(reagents.reagent_list)
			reagents.remove_reagent(reagent.type, 1)
			fork.forkload = reagent
			if(reagents.total_volume <= 0)
				qdel(src)
		return
	..()

/obj/item/food/benedict
	name = "eggs benedict"
	desc = "There is only one egg on this, how rude."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "benedict"
	food_reagents = list(
		/datum/reagent/consumable/nutriment/vitamin = 6,
		/datum/reagent/consumable/nutriment/protein = 6,
		/datum/reagent/consumable/nutriment = 3,
	)
	w_class = WEIGHT_CLASS_SMALL
	tastes = list("egg" = 1, "bacon" = 1, "bun" = 1)
	foodtypes = MEAT | BREAKFAST | GRAIN
	venue_value = FOOD_PRICE_NORMAL
	food_buffs = STATUS_EFFECT_STAM_REGEN_MEDIUM

/obj/item/food/eggwrap
	name = "egg wrap"
	desc = "The precursor to Pigs in a Blanket."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "eggwrap"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 6,
		/datum/reagent/consumable/nutriment/protein = 2,
		/datum/reagent/consumable/nutriment/vitamin = 3,
	)
	tastes = list("egg" = 1)
	foodtypes = MEAT | VEGETABLES
	w_class = WEIGHT_CLASS_TINY

/obj/item/food/chawanmushi
	name = "chawanmushi"
	desc = "A legendary egg custard that makes friends out of enemies. Probably too hot for a cat to eat."
	icon = 'icons/obj/food/egg.dmi'
	icon_state = "chawanmushi"
	food_reagents = list(
		/datum/reagent/consumable/nutriment = 4,
		/datum/reagent/consumable/nutriment/protein = 3,
		/datum/reagent/consumable/nutriment/vitamin = 1,
	)
	tastes = list("custard" = 1)
	foodtypes = MEAT | VEGETABLES
