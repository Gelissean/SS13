/client/proc/TemplatePanel()
	set name = "Template Panel"
	set category = "Debug"

	// Place
	var/primary = check_rights(R_PRIMARYADMIN)
	// Upload, Delete, Reset
	var/senior = check_rights(R_SENIORADMIN)

	if(!primary)
		return 0

	var/dat = "<center><span class='statusDisplay'>"

	if(primary)
		dat += "<a href='?_src_=holder;template_panel=1;action=place'>Place</a>"

	if(senior)
		dat += " | <a href='?_src_=holder;template_panel=1;action=upload'>Upload and Place</a>"

	dat += "</span><br><br>"

	if(length(template_controller.placed_templates))
		dat += "<table>"
		dat += "<tr><th>Name</th><th>Position</th>[senior ? "<th>Actions</th>" : ""]"

		for(var/datum/dmm_object_collection/template in template_controller.placed_templates)
			dat += "<tr><td>[template.name]</td><td>{[template.location.x], [template.location.y], [template.location.z]}</td>"
			if(senior)
				dat += "<td>"
				dat += "<a href='?_src_=holder;template_panel=1;action=delete;template=\ref[template]'>Delete</a> | "
				dat += "<a href='?_src_=holder;template_panel=1;action=reset;template=\ref[template]'>Reset</a>"
				dat += "</td>"

			dat += "</tr>"

		dat += "</table>"

	dat += "</center>"

	var/datum/browser/popup = new(mob, "templ_panel", "Template Panel")
	popup.set_content(dat)
	popup.open()
