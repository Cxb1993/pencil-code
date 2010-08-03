;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;   cmp_cslice.pro   ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  $Id$
;;;
;;;  Description:
;;;   Fast and powerful to use tool to view and compare slices of 3D data
;;;  To do:
;;;   Add more comments


; Simple interface to cmp_cslice_cache without caching mechanism
pro cmp_cslice, sets, limits, units=units, scaling=scaling

	common varset_common, set, overplot, oversets, unit, coord, varsets, varfiles, sources

	set_names = tag_names (sets)
	num_names = n_elements (set_names)

	exe_1 = "varsets = { "
	exe_2 = "set = { "
	for i=0, num_names-1 do begin
		if (i gt 0) then begin
			exe_1 += ", "
			exe_2 += ", "
		end
		exe_1 += set_names[i]+":sets."+set_names[i]
		exe_2 += set_names[i]+":'"+set_names[i]+"'"
	end
	exe_1 += " }"
	exe_2 += " }"

	res = execute (exe_1)
	if (not res) then begin
		print, "ERROR: could not generate varsets!"
		return
	end

	res = execute (exe_2)
	if (not res) then begin
		print, "ERROR: could not generate set!"
		return
	end

	varfiles = { title:"N/A", loaded:1, number:0, precalc_done:1 }

	cmp_cslice_cache, set, limits, units=units, coords=coords, scaling=scaling

	return
end

