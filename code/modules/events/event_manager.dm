var/datum/controller/event/events

/datum/controller/event
	var/list/control = list()	//list of all datum/round_event_control. Used for selecting events based on weight and occurrences.
	var/list/running = list()	//list of all existing /datum/round_event
	var/list/queue = list()		//list of all queued events to fire when a candidate is available
	var/list/finished = list()  //list of all ended events.
	var/list/last_events = list() //last 3 events

	var/scheduled = 0			//The next world.time that a naturally occuring random event can be selected.
	var/queue_scheduled = 0			//The next world.time that a queued event can fire
	var/frequency_lower = 3000	//5 minutes lower bound.
	var/frequency_upper = 9000	//15 minutes upper bound. Basically an event will happen every 15 to 30 minutes.
	var/phase = 0				//how many times the event scheduler has scheduled itself

	//configs
	var/focus = 0.25
	var/queue_ghost_events = 1

//Initial controller setup.
/datum/controller/event/New()
	//There can be only one events manager. Out with the old and in with the new.
	if(events != src)
		if(istype(events))
			del(events)
		events = src

	//configs
	if(config)
		focus = config.events_focus
		queue_ghost_events = config.events_queue_ghost_events

	for(var/type in typesof(/datum/round_event_control))
		var/datum/round_event_control/E = new type()
		if(!E.typepath)
			continue				//don't want this one! leave it for the garbage collector
		control += E				//add it to the list of all events (controls)

	reschedule()
	handleSchedule(holiday)

/*
*				  Added by Drache~
*	Added so you can independently change something based
*	on the holiday it currently is.
*/

/datum/controller/event/proc/handleSchedule(var/_holiday)
	if(_holiday == "Halloween")
		//Make sure Halloween starts after 5 minutes exactly.
		scheduled = 3000
	if(_holiday == "Valentine's Day")
		//Make sure Valentine's Day starts after 3 minutes exactly.
		scheduled = 1500

//This is called by the MC every MC-tick (*neatfreak*).
/datum/controller/event/proc/process()
	checkEvent()
	var/i = 1
	while(i<=running.len)
		var/datum/round_event/Event = running[i]
		if(Event)
			Event.process()
			i++
			continue
		running.Cut(i,i+1)
	//pick one lovely event from the queue to possibly unqueue
	if(queue_scheduled <= world.time)
		for(var/datum/round_event/Event in shuffle(queue))
			Event.tick_queue()
			break
		queue_scheduled = world.time + rand(frequency_lower, max(frequency_lower,frequency_upper))

//checks if we should select a random event yet, and reschedules if necessary
/datum/controller/event/proc/checkEvent()
	if(scheduled <= world.time)
		var/datum/round_event_control/event_to_run = spawnEvent()
		if(event_to_run)
			add2timeline("[event_to_run.name]",1)
			log_game("EVENTS: [event_to_run.name] fired")
			phase++
			reschedule()
		else
			reschedule(1) // quick reschedule if no event was fired

//decides which world.time we should select another random event at.
/datum/controller/event/proc/reschedule(var/quick=0)
	if(quick)
		scheduled = world.time + 600
		return
	scheduled = world.time + rand(frequency_lower, max(frequency_lower,frequency_upper))


/datum/controller/event/proc/possible_events()
	var/list/possible = list()

	for(var/datum/round_event_control/E in control)
		if(E.occurrences >= E.max_occurrences)	continue
		if(E.earliest_start >= world.time)		continue
		if(E.holidayID)
			if(E.holidayID != holiday)			continue
		if(E.needs_ghosts)
			var/ghosts = 0
			for(var/client/C in clients)
				if(istype(C.mob,/mob/dead/observer))
					ghosts++
			if(!ghosts && !queue_ghost_events)
				continue

		possible.Add(E)
	return possible

//selects a random event based on whether it can occur and it's 'weight'(probability)
/datum/controller/event/proc/spawnEvent()
	if(!config.allow_random_events)
		return

	var/list/possible = possible_events()

	var/sum_of_weights = 0
	for(var/datum/round_event_control/E in possible)
		if(E.weight < 0)						//for round-start events etc.
			if(E.runEvent() == PROCESS_KILL)
				E.max_occurrences = 0
				continue
			return E
		sum_of_weights += E.weight

	sum_of_weights = rand(0,sum_of_weights)	//reusing this variable. It now represents the 'weight' we want to select

	for(var/datum/round_event_control/E in possible)
		sum_of_weights -= E.weight

		if(sum_of_weights <= 0)				//we've hit our goal
			if(E.runEvent() == PROCESS_KILL)//we couldn't run this event for some reason, set its max_occurrences to 0
				E.max_occurrences = 0
				continue
			return E

/datum/round_event/proc/findEventArea() //Here's a nice proc to use to find an area for your event to land in!
	var/list/safe_areas = list(
	/area/turret_protected/ai,
	/area/turret_protected/ai_upload,
	/area/engine,
	/area/solar,
	/area/holodeck,
	/area/shuttle/arrival,
	/area/shuttle/escape/station,
	/area/shuttle/escape_pod1/station,
	/area/shuttle/escape_pod2/station,
	/area/shuttle/escape_pod3/station,
	/area/shuttle/escape_pod4/station,
	/area/shuttle/mining/station,
	/area/shuttle/transport1/station,
	/area/shuttle/specops/station,
	/area/security/perseus/,
	/area/security/perseus/mycenae_centcom,
	/area/security/perseus/mycenaeiii)

	//These are needed because /area/engine has to be removed from the list, but we still want these areas to get fucked up.
	var/list/danger_areas = list(
	/area/engine/break_room,
	/area/engine/chiefs_office)

	//Need to locate() as it's just a list of paths.
	return locate(pick((the_station_areas - safe_areas) + danger_areas))



//allows a client to trigger an event (For Debugging Purposes)
/client/proc/forceEvent(var/datum/round_event_control/E in events.control)
	set name = "Trigger Event (Debug Only)"
	set category = "Debug"

	if(!holder)
		return

	if(istype(E))
		E.runEvent()
		message_admins("[key_name_admin(usr)] has triggered an event. ([E.name])", 1)

/*
//////////////
// HOLIDAYS //
//////////////
//Uncommenting ALLOW_HOLIDAYS in config.txt will enable holidays

//It's easy to add stuff. Just modify getHoliday to set holiday to something using the switch for DD(#day) MM(#month) YY(#year).
//You can then check if it's a special day in any code in the game by doing if(events.holiday == "MyHolidayID")

//You can also make holiday random events easily thanks to Pete/Gia's system.
//simply make a random event normally, then assign it a holidayID string which matches the one you gave it in getHolday.
//Anything with a holidayID, which does not match the holiday string, will never occur.

//Please, Don't spam stuff up with stupid stuff (key example being april-fools Pooh/ERP/etc),
//And don't forget: CHECK YOUR CODE!!!! We don't want any zero-day bugs which happen only on holidays and never get found/fixed!

//////////////////////////////////////////////////////////////////////////////////////////////////////////
//ALSO, MOST IMPORTANTLY: Don't add stupid stuff! Discuss bonus content with Project-Heads first please!//
//////////////////////////////////////////////////////////////////////////////////////////////////////////
~Carn */

//sets up the holiday string in the events manager.
/proc/getHoliday()
	if(!config.allow_holidays)	return		// Holiday stuff was not enabled in the config!
	holiday = null

	var/YY	=	text2num(time2text(world.timeofday, "YY")) 	// get the current year
	var/MM	=	text2num(time2text(world.timeofday, "MM")) 	// get the current month
	var/DD	=	text2num(time2text(world.timeofday, "DD")) 	// get the current day

	//Main switch. If any of these are too dumb/inappropriate, or you have better ones, feel free to change whatever
	switch(MM)
		if(1)	//Jan
			switch(DD)
				if(1)							holiday = "New Year"

		if(2)	//Feb
			switch(DD)
				if(2)							holiday = "Groundhog Day"
				if(14)							holiday = "Valentine's Day"
				if(17)							holiday = "Random Acts of Kindness Day"

		if(3)	//Mar
			switch(DD)
				if(14)							holiday = "Pi Day"
				if(17)							holiday = "St. Patrick's Day"
				if(27)
					if(YY == 16)
						holiday = "Easter"
				if(31)
					if(YY == 13)
						holiday = "Easter"

		if(4)	//Apr
			switch(DD)
				if(1)
					holiday = "April Fool's Day"
					if(YY == 18 && prob(50)) 	holiday = "Easter"
				if(5)
					if(YY == 15)				holiday = "Easter"
				if(16)
					if(YY == 17)				holiday = "Easter"
				if(20)
					holiday = "Four-Twenty"
					if(YY == 14 && prob(50))	holiday = "Easter"
				if(22)							holiday = "Earth Day"

		if(5)	//May
			switch(DD)
				if(1)							holiday = "Labour Day"
				if(4)							holiday = "FireFighter's Day"
				if(12)							holiday = "Owl and Pussycat Day"	//what a dumb day of observence...but we -do- have costumes already :3

		if(6)	//Jun

		if(7)	//Jul
			switch(DD)
				if(1)							holiday = "Doctor's Day"
				if(2)							holiday = "UFO Day"
				if(8)							holiday = "Writer's Day"
				if(30)							holiday = "Friendship Day"

		if(8)	//Aug
			switch(DD)
				if(5)							holiday = "Beer Day"

		if(9)	//Sep
			switch(DD)
				if(19)							holiday = "Talk-Like-a-Pirate Day"
				if(28)							holiday = "Stupid-Questions Day"

		if(10)	//Oct
			switch(DD)
				if(4)							holiday = "Animal's Day"
				if(7)							holiday = "Smiling Day"
				if(16)							holiday = "Boss' Day"
				if(31)							holiday = "Halloween"

		if(11)	//Nov
			switch(DD)
				if(1)							holiday = "Vegan Day"
				if(13)							holiday = "Kindness Day"
				if(19)							holiday = "Flowers Day"
				if(21)							holiday = "Saying-'Hello' Day"

		if(12)	//Dec
			switch(DD)
				if(10)							holiday = "Human-Rights Day"
				if(14)							holiday = "Monkey Day"
				if(21)							holiday = "Mayan Doomsday Anniversary"
				if(22)							holiday = "Orgasming Day"		//lol. These all actually exist
				if(24)							holiday = "Xmas"
				if(25)							holiday = "Xmas"
				if(26)							holiday = "Boxing Day"
				if(31)							holiday = "New Year"

	if(!holiday)
		//Friday the 13th
		if(DD == 13)
			if(time2text(world.timeofday, "DDD") == "Fri")
				holiday = "Friday the 13th"

	world.update_status()


/*
//Below is commented out code from the newer rating based event system.
//shouldn't really apply to how events are run now since events that are worth this system are now progressive events

//decides the ratings
/datum/controller/event/proc/adjust_ratings()
	//no players? don't run this
	var/PlayerC = 0
	for(var/client/C in clients)
		if(istype(C.mob,/mob/new_player/)) //lobby players dont count
			continue
		PlayerC++
	if(!autoratings || !PlayerC)
		return
	var/low = 5
	var/high = 20
	if(IsMultiple(phase,3))
		low = 15 // every 3 rounds give a boost maybe.
		gameplay_offset = 0
		gameplay_offset = pick(-1,0,1)
	events.rating["Dangerous"] += rand(low,high)
	events.rating["Gameplay"] += (rand(5,15) * gameplay_offset)
	//if gameplay has reached its max, revert it back to the middle
	if(events.rating["Gameplay"] > 75 || events.rating["Gameplay"] < 25)
		events.rating["Gameplay"] = 50
	//wrap around dangerous
	events.rating["Dangerous"] = Wrap(events.rating["Dangerous"], 0, 100)

/datum/controller/event/proc/getDistance(var/datum/round_event_control/E)
	var/distance = 0
	for(var/X in rating)
		if(rating[X] < 0) continue
		distance += abs(rating[X] - E.rating[X])
	if(true_random)
		distance = 1 //ALL HELL BREAKS LOOSE
	return Clamp(distance,1,200)

/*
/datum/controller/event/proc/getWeight(var/datum/round_event_control/E)
	var/distance = 0
	for(var/X in rating)
		if(rating[X] < 0) continue
		distance += abs(rating[X] - E.rating[X])
	if(distance <= 0)
		return 300 //just so events that hit the dot arent in the THOUSANDS PLACE
	return round((1 / distance)*1000)
*/

//Spoffy code below. Thank you based spoffy
/*
Gets the event list, organised into lists of a events of a specific difficulty.
I.e, the following is valid:
	events_list[distance_from_difficulty] = list(event1, event2)
*/
/datum/controller/event/proc/createEventListByDistance(var/test=0)
	var/list/events_by_weight = list()
	//addition by flavo
	events_by_weight.len = 200 //Highest difference for events, should probably be a DEFINE
	//gather player count
	var/PlayerC = 0
	for(var/client/C in clients)
		if(istype(C.mob,/mob/new_player/)) //lobby players dont count
			continue
		PlayerC++
	//end gather player count
	for(var/datum/round_event_control/event in control)
		if(event.occurrences >= event.max_occurrences)	continue //ran too much
		if(timelocks)
			if(event.phases_required > phase)		continue  //time locked
		if(event.holidayID) 							//holiday
			if(event.holidayID != holiday)			continue
		if(event.players_needed > PlayerC)
			continue
		if(last_events.len) //previously ran, ignore it.
			var/already_ran = 0
			for(var/datum/round_event_control/previous in last_events)
				if(event == previous)
					already_ran = 1
			if(already_ran)
				continue
		if(event.needs_ghosts)
			var/ghosts = 0
			for(var/client/C in clients)
				if(istype(C.mob,/mob/dead/observer))
					ghosts++
			if(!ghosts && !queue_ghost_events)
				continue
		if(event.phases_required < 0 && !test)				//for round-start events etc.
			if(event.runEvent() == PROCESS_KILL)
				event.max_occurrences = 0
				continue
			add2timeline("[event.name]",1)
			return

		var/distance = getDistance(event)
		if(events_by_weight[distance])
			var/list/events_at_current_weight = events_by_weight[distance]
		//addition end
			events_at_current_weight += event
		else
			events_by_weight[distance] = list(event)

	//addition by flavo to even out lists
	//Even out the list
	var/list/events_by_weight_even = list()
	for(var/i=1 , i<=events_by_weight.len , i++)
		var/list/E = events_by_weight[i]
		if(E)
			events_by_weight_even += list(E)
	//addition end.

	return events_by_weight_even

/datum/controller/event/proc/pickEvent(var/test=0)
	var/list/event_list = createEventListByDistance(test)
	var/chosen_probability = gaussian(0, event_list.len * focus) //Mean, stddev
	//We have our probability, and events organised by difference.
	//Difference is between 0 and 500 (as 5 ratings, with a range of 100 each).

	//Convert our random number (which is a decimal, with a 98% chance of being between -3 and 3 for mean = 0, stddev = 1)
	//into something we can use, so multiply by 100.

	var/chosen_difference = chosen_probability

	//Hurray, we now have an integer between -infinity and infinity, with a 98% chance of being between -75 and 75.
	//But fuck negatives, let's make it positive!

	chosen_difference = Ceiling(abs(chosen_difference))
	//world.log << chosen_difference

	//Cool, now it has a 98% chance of being between 0 and 300, a 95% chance of being between 0 and 200, and a 68% chance of being between 0 and 100.
	//That seems rather high... so perhaps go back and change the stddev to something lower. Maybe 0.1?
	//Moving on, so we have our chosen difference, as something useful. Let's find out which event set it's closest to*!
	//
	//* In the most inefficient way possible!

	//Nice and simple, we loop through all the possible event differences in the event_list,
	//And calculate how far it is from the difference we've chosen.
	//We'll call this the distance from the difference.
	//And we select the difference with the lowest distance,
	//I.e, the list of events that have their difficulty closest to our randomly selected one.
	//(Remembering that our randomly selected difficulty is more likely to throw out certain values)
	var/selected_event_difference = event_list.len //Highest difference for a given event, currently.
	if(!selected_event_difference) // just some sanity
		log_game("EVENTS: No event was fired because the possible event list was empty")
		return
	var/selected_distance_from_difference = event_list.len
	chosen_difference = Clamp(chosen_difference,0,event_list.len)
	for(var/difference in event_list)
		//addition by flavo
		if(!difference) continue
		difference = event_list.Find(difference)
		//world.log << "[difference]: [list2text(event_list[difference],", ")]"
		//addition end
		var/distance_from_chosen_difference = abs(chosen_difference - difference)
		if(distance_from_chosen_difference < selected_distance_from_difference)
			selected_event_difference = difference
			selected_distance_from_difference = distance_from_chosen_difference

	var/list/selected_events = event_list[selected_event_difference]
	//addition by flavo
	if(!selected_events)
		return
	if(test)
		return "[list2text(selected_events,", ")]<br>chosen diff: [chosen_difference]" //only a test, return the event
	else
		for(var/i=0, i<10, i++) // try at least 10 times before deciding "fuck it"
			var/datum/round_event_control/E = safepick(selected_events)
			if(E)
				if(E.runEvent() == PROCESS_KILL)//we couldn't run this event for some reason, set its max_occurrences to 0
					E.max_occurrences = 0
					continue
				add2timeline("[E.name]",1)
				log_game("EVENTS: [E.name] (dist:[getDistance(E)]/gmply:[E.rating["Gameplay"]]/dnger:[E.rating["Dangerous"]]) was fired | Chosen Difference: [chosen_difference] | Gameplay: [rating["Gameplay"]] | Dangerous: [rating["Dangerous"]]")
				return E //Yes, boom, the event fired.. your work here is done big ol calculator
			else
				return //err.. E was null so the list is clearly empty or something. fuck it.
	//addition end
//spoffy code above
*/