import <zlib.ash>

setvar("FamiliarDrops_Enabled", true);
setvar("FamiliarDrops_MinMpa", 0.0);
setvar("FamiliarDrops_MinMpaItem", "none");
setvar("FamiliarDrops_AssumeWorst", false);
setvar("FamiliarDrops_Banned", "none");
setvar("FamiliarDrops_DefaultFam", "none");

// Spading
// http://kolspading.com/forums/viewtopic.php?f=3&t=261#p4577

record _familiarItem {
	item itemDrop;
	string pref;
	item forceEquipment;
	int[int] absoluteDropMin;
	int[int] absoluteDropMax;
	float[int] percentDropRate;
	float percentIncrease;
	boolean repeating;
};

record _mpa {
	familiar fam;
	float mpa;
};

_familiarItem[familiar] familiarItems;

file_to_map("familiar_drops.txt", familiarItems);

// Return the turn where we have 100% drop rate for that specific turn
int worseCaseDrop(float baseDrop, float percentIncrease)
{
	if (percentIncrease <= 0.0)
	{
		// HACK: If the percentage does not increase, return some value I guess
		return 2.0 / baseDrop;
	}

	int turns = 0;
	float chance = baseDrop;
	while (baseDrop < 1.0)
	{
		turns = turns + 1;
		baseDrop = baseDrop + percentIncrease;
	}

	return turns + 1;
}

// Returns the turn where we have at least a 50% chance to have gotten the item to drop
// Note: This is not the drop rate, probability isn't that straighforward!
int medianDrop(float baseDrop, float percentIncrease)
{
	float totalChance = 0.0;
	int turns = 0;

	float worseCase = worseCaseDrop(baseDrop, percentIncrease);

	while (totalChance < 0.5 && turns < worseCase)
	{
		float chance = 0.0;
		float turnChance = 1.0;

		for i from 1 to turns
		{
			turnChance = turnChance * (1.0 - (i / worseCase));
		}

		chance = turnChance * (baseDrop + (percentIncrease * turns));
		totalChance = totalChance + chance;
		turns = turns + 1;
	}

	return turns;
}

int mall_value(item i)
{
	vprint("Checking " + i + "...", 9);
	if (historical_age(i) < 7 && historical_price(i) > 0) return historical_price(i);

	return mall_price(i);
}

int item_price(item i)
{
	// psychoanalytic jars aren't mallable, so use the price of the most expensive one
	// that isn't Jick's Jar
	if (i == $item[psychoanalytic jar])
	{
		int best = 0;
		for index from 5898 to 5904
		{
			int price = mall_value(index.to_item());
			if (price > best && price > 0)
			{
				best = price;
			}
		}

		return best;
	}

	// Return the least expensive of all the boot pastes
	if (i == $item[gooey paste])
	{
		int best = 999999999;
		for index from 5198 to 5219
		{
			int price = mall_value(index.to_item());
			if (price < best && price > 0)
			{
				best = price;
			}
		}

		return best;
	}

	// Return the least expensive of all the grinder pies
	if (i == $item[liver and let pie])
	{
		int best = 999999999;
		for index from 4722 to 4729
		{
			int price = mall_value(index.to_item());
			if (price < best && price > 0)
			{
				best = price;
			}
		}

		return best;
	}

	// Return the least expensive of all the red happy medium drinks
	if (i == $item[Shot of the Living Dead])
	{
		int best = 999999999;
		for index from 5575 to 5638 by 3
		{
			int price = mall_value(index.to_item());
			if (price < best && price > 0)
			{
				best = price;
			}
		}

		return best;
	}

	// Return the correct turkey drink for your level
	if (i == $item[Ambitious Turkey])
	{
		if (my_level() <= 4)
		{
			return mall_value($item[Friendly Turkey]);
		}
		else if (my_level() <= 7)
		{
			return mall_value($item[Agitated Turkey]);
		}
	}

	// Look at this fukkin hipster
	if (i == $item[ironic knit cap])
	{
		int best = 999999999;
		for index from 4652 to 4656
		{
			int price = mall_value(index.to_item());
			if (price < best && price > 0)
			{
				best = price;
			}
		}

		return best;
	}

	// XO Skeleton (average price of Xs and Os)
	if (i == $item[X])
	{
		return (mall_value($item[X]) + mall_value($item[O])) / 2;
	}

	return mall_value(i);
}

familiar familiar_swap()
{
	boolean[familiar] banned;

	foreach i,s in getvar("FamiliarDrops_Banned").split_string(",")
	{
		banned[s.to_familiar()] = true;
	}

	_mpa[int] mpa;
	foreach f in familiarItems
	{
		if (!f.have_familiar() || banned[f] == true)
		{
			continue;
		}

		// Don't allow _hipsterAdv familiars if not adventuring at adventure.php
		if (familiarItems[f].pref == "_hipsterAdv")
		{
			if (!contains_text(to_url(my_location()), "adventure.php"))
			{
				continue;
			}
			switch (my_location())
			{
			case $location[The X-32-F Combat Training Snowman]:
			case $location[Investigating a Plaintive Telegram]:
			{
				continue;
			}
			default: break;
			}
		}

		// Don't allow Green Pixie if we already have absinthe-minded - bottles will not drop
		if (familiarItems[f].pref == "_absintheDrops" && $effect[Absinthe-Minded].have_effect() > 0)
		{
			continue;
		}
		
		int i = 0;
		if (familiarItems[f].pref != "")
		{
			i = get_property(familiarItems[f].pref).to_int();
		}
		else
		{
			i = f.drops_today;
		}

		if (f.drops_limit > 0 && i >= f.drops_limit)
		{
			continue;
		}

		if (familiarItems[f].repeating == true)
		{
			i = 0;
		}

		if (familiarItems[f].percentDropRate[i] > 0.0)
		{
			int worst = worseCaseDrop(familiarItems[f].percentDropRate[i], familiarItems[f].percentIncrease);
			int median = medianDrop(familiarItems[f].percentDropRate[i], familiarItems[f].percentIncrease);
			int price = item_price(familiarItems[f].itemDrop);

			_mpa fmpa;
			fmpa.fam = f;
			if (!getvar("FamiliarDrops_AssumeWorst").to_boolean())
			{
				fmpa.mpa = price / (median * 1.0);
			}
			else
			{
				fmpa.mpa = price / (worst * 1.0);
			}

			vprint(f + " drop " + (f.drops_today+1) + " " + price + ": median(" + median + ") worst(" + worst + ")", 7);

			if (getvar("FamiliarDrops_AssumeWorst").to_boolean() && my_adventures() < worst)
			{
				continue;
			}
			if (!getvar("FamiliarDrops_AssumeWorst").to_boolean() && my_adventures() < median)
			{
				continue;
			}
			
			mpa[count(mpa)] = fmpa;
		}
		if (familiarItems[f].absoluteDropMax[i] > 0.0)
		{
			_mpa fmpa;
			fmpa.fam = f;
			int worst = familiarItems[f].absoluteDropMax[i];
			int median = worst;
			int price = item_price(familiarItems[f].itemDrop);

			if (familiarItems[f].absoluteDropMin[i] > 0)
			{
				median = ((familiarItems[f].absoluteDropMin[i] + familiarItems[f].absoluteDropMax[i]) / 2.0);
			}

			if (familiarItems[f].absoluteDropMin[i] > 0 || !getvar("FamiliarDrops_AssumeWorst").to_boolean())
			{
				fmpa.mpa = price / median;
			}
			else
			{
				fmpa.mpa = price / worst;
			}

			if (getvar("FamiliarDrops_AssumeWorst").to_boolean() && my_adventures() < worst)
			{
				continue;
			}
			if (!getvar("FamiliarDrops_AssumeWorst").to_boolean() && my_adventures() < median)
			{
				continue;
			}

			vprint(f + " drop " + (i+1) + " " + item_price(familiarItems[f].itemDrop) + ": median(" + median + ") worst(" + worst + ")", 7);
			
			mpa[count(mpa)] = fmpa;
		}
	}

	sort mpa by -value.mpa;
	foreach i in mpa
	{
		vprint(mpa[i].fam + ": " + mpa[i].mpa + " mpa", 5);
	}

	float minmpa = 0.0;
	if (getvar("FamiliarDrops_MinMpaItem").to_item() != $item[none])
	{
		minmpa = item_price(getvar("FamiliarDrops_MinMpaItem").to_item());
	}
	else
	{
		minmpa = getvar("FamiliarDrops_MinMpa").to_float();
	}

	if (count(mpa) > 0 && mpa[0].mpa >= minmpa)
	{
		return mpa[0].fam;
	}

	return getvar("FamiliarDrops_DefaultFam").to_familiar();
}

// TODO: Snow suit?
item familiar_swap_equipment(familiar fam)
{
	foreach f in familiarItems
	{
		if (f == fam)
		{
			return familiarItems[f].forceEquipment;
		}
	}

	return $item[none];
}

void main()
{
	if (!getvar("FamiliarDrops_Enabled").to_boolean())
	{
		return;
	}

	familiar best = familiar_swap();

	if (best != $familiar[none] && my_familiar() != best)
	{
		vprint("Changing item drop familiar to " + best + "...", "blue", 3);
		use_familiar(best);
		item fam_equip = familiar_swap_equipment(best);
		if (fam_equip != $item[none])
		{
			equip(fam_equip);
		}
	}
}
