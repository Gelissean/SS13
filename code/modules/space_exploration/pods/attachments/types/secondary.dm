/obj/item/weapon/pod_attachment/secondary
	hardpoint_slot = P_HARDPOINT_SECONDARY_ATTACHMENT
	keybind = P_ATTACHMENT_KEYBIND_MIDDLE

	GetAvailableKeybinds()
		return list(P_ATTACHMENT_KEYBIND_SHIFT, P_ATTACHMENT_KEYBIND_CTRL, P_ATTACHMENT_KEYBIND_ALT,
					P_ATTACHMENT_KEYBIND_MIDDLE, P_ATTACHMENT_KEYBIND_CTRLSHIFT)

	gimbal/
		name = "gimbal mount"
		overlay_icon_state = "gimbal"
		power_usage = 1
		power_usage_condition = P_ATTACHMENT_USAGE_ONTICK
		construction_cost = list("metal" = 500, "uranium" = 800)
		origin_tech = "engineering=4;materials=4;combat=3"
		minimum_pod_size = list(2, 2)

	autoloader/
		name = "autoloader"
		power_usage = 20
		cooldown = 5
		construction_cost = list("metal" = 500)
		origin_tech = "engineering=2"

		Use(var/atom/target, var/mob/user)
			if(!(..(target, user)))
				return 0

			if(!(target in bounds(attached_to, 1)))
				return 0

			var/obj/item/weapon/pod_attachment/cargo/cargo_hold = attached_to.GetAttachmentOnHardpoint(P_HARDPOINT_CARGO_HOLD)
			if(!cargo_hold)
				return 0

			if(istype(target, /obj/item))
				var/obj/item/I = target
				var/result = cargo_hold.PlaceInto(I)
				if(result != P_CARGOERROR_CLEAR)
					attached_to.PrintSystemAlert("\The [src] couldn't load \the [I], because [cargo_hold.TranslateError(result)]")

	bluespace_ripple/
		name = "outward bluespace ripple generator"
		overlay_icon_state = "ripple_generator"
		use_sound = 'sound/effects/phasein.ogg'
		power_usage = 3000
		cooldown = 300
		construction_cost = list("metal" = 1500, "uranium" = 1500, "silver" = 1500, "diamond" = 1500)
		origin_tech = "bluespace=4;magnets=4;programming=4;combat=4"
		minimum_pod_size = list(2, 2)
		var/range = 3
		var/inward = 0

		Use(var/atom/target, var/mob/user)
			if(!(..(target, user)))
				return 0

			var/turf/pod_turf = get_turf(attached_to)

			var/list/ranges = list()
			if(inward)
				for(var/i = range; i > 0; i--)
					ranges += i
			else
				for(var/i = 1; i <= range, i++)
					ranges += i

			for(var/i = 1; i <= range; i++)
				var/list/turfs = list()
				for(var/turf/T in attached_to.GetTurfsUnderPod())
					turfs += (turfs ^ circlerange(T, ranges[i]))

				for(var/turf/T in turfs)
					for(var/atom/movable/M in T)
						if(M.anchored)
							continue
						if(inward)
							step(M, get_dir(M, pod_turf))
						else
							step(M, get_dir(pod_turf, M))

				sleep(1)

		inward/
			name = "inward bluespace ripple generator"
			inward = 1

	smoke_screen/
		name = "smoke synthesizer"
		use_sound = 'sound/weapons/grenadelaunch.ogg'
		power_usage = 1000
		cooldown = 1200
		origin_tech = "engineering=2;materials=2"
		construction_cost = list("metal" = 1000, "silver" = 400)

		Use(var/atom/target, var/mob/user)
			if(!(..(target, user)))
				return 0

			var/_x = attached_to.x, _y = attached_to.y, _z = attached_to.z, size = attached_to.size[1]
			var/list/corner_turfs = list(locate(_x - 1, _y + size, _z),
										locate(_x + size, _y + size, _z),
										locate(_x - 1, _y - 1, _z),
										locate(_x + size, _y - 1, _z))

			for(var/turf/T in corner_turfs)
				var/datum/effect/effect/system/harmless_smoke_spread/spread = new()
				spread.set_up(5, 0, T, 0)
				spread.start()

	wormhhole_generator/
		name = "wormhole generator"
		power_usage = 2000
		cooldown = 100
		construction_cost = list("metal" = 1000, "uranium" = 800, "diamond" = 800)

		Use(var/atom/target, var/mob/user)
			if(!(..(target, user)))
				return 0

			return 0

		proc/CreateWormhole(var/obj/item/device/radio/beacon/beacon)
			return 0

	ore_collector/
		name = "ore collector"
		power_usage = 1
		power_usage_condition = P_ATTACHMENT_USAGE_ONTICK
		construction_cost = list("metal" = 500)
		origin_tech = "engineering=1"

		GetAvailableKeybinds()
			return list()

		PodProcess(var/obj/pod/pod)
			if(!..())
				return 0

			var/obj/item/weapon/pod_attachment/cargo/cargo = pod.GetAttachmentOnHardpoint(P_HARDPOINT_CARGO_HOLD)
			if(!cargo)
				return 0

			var/list/turfs_below_pod = pod.GetTurfsUnderPod()
			for(var/turf/T in turfs_below_pod)
				for(var/obj/item/weapon/ore/ore in T)
					if(cargo.HasRoom())
						var/result = cargo.PlaceInto(ore)
						if(result != P_CARGOERROR_CLEAR)
							pod.PrintSystemAlert("\The [src] reports: [cargo.TranslateError(result)]. Shutting off.")
							active = P_ATTACHMENT_INACTIVE
							return 0
