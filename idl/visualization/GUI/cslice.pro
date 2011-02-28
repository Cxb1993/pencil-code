;;;;;;;;;;;;;;;;;;;;;;
;;;   cslice.pro   ;;;
;;;;;;;;;;;;;;;;;;;;;;
;;;  $Id$
;;;
;;;  Description:
;;;   Fast and powerful to use tool to view and compare slices of 3D data
;;;  To do:
;;;   Add more comments


; Compatibility mode => calls simple interface
pro cslice, cube, limits, units=units, coords=coords, scaling=scaling

	common slider_common, bin_x, bin_y, bin_z, num_x, num_y, num_z, pos_b, pos_t, csmin, csmax, dimensionality

	resolve_routine, "pc_gui_companion", /COMPILE_FULL_FILE, /NO_RECOMPILE

	; some error checking
	if (n_elements (cube) le 0) then begin
		print, "Sorry, the data is undefined."
		return
	end

	; setup a scaling factor to have a minimum size, if necessary
	dim = size (cube)
	default, scaling, fix (256 / max (dim[1:3]))
	if (n_elements (scaling) eq 1) then if (scaling lt 1) then scaling = 1

	; setup cube dimensions
	num_x = (size (cube))[1]
	if (size (cube, /n_dimensions) lt 2) then num_y = 1 else num_y = (size (cube))[2]
	if (size (cube, /n_dimensions) lt 3) then num_z = 1 else num_z = (size (cube))[3]

	; setup limits, if necessary
	if (n_elements (limits) eq 0) then limits = reform (lindgen (num_x, num_y, num_z), num_x, num_y, num_z)

	set = { cube:cube }
	cmp_cslice, set, limits, units=units, scaling=scaling

	return
end

