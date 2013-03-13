;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;   pc_check_quantities.pro     ;;;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;;;  $Id$
;;;
;;;  Description:
;;;   Returns a list of available quantities accepted by 'pc_get_quantity'
;;;   and depending on the optionally given varcontent.
;;;   A list can also be checked and only the valid quantities are returned.
;;;
;;;  Parameters:
;;;   * check		list of quantities to be checked for availability
;;;   * sources		array of varcontent IDL names or a varcontent structure
;;;   * /all		return all available quantities, without checking
;;;   * /warn		warn about missing dependencies in the varcontent
;;;   * /indices	list of indices, instead of the quantities itself
;;;
;;;  Available physical quantities are:
;;;
;;;   Label            Description
;;;  =============================================================
;;;   u_abs            absolute velocity
;;;   uu               velocity
;;;   Temp             temperature
;;;   Spitzer_q        absolute value of Spitzer heat flux vector
;;;   ln_rho           natural logarithm of density
;;;   log_rho          decatic logarithm of density
;;;   rho              density
;;;   P                pressure
;;;   HR_viscous       volumetric viscous heating rate
;;;   B                magnetic field
;;;   HR_ohm           volumetric Ohmic heating rate
;;;   j                current density
;;;

; Check if a dependency is fulfilled.
function dependency_ok, tag, depend, sources

	; Check for dependencies
	if (all (tag eq "")) then return, 1

	if (size (depend, /type) ne 8) then begin
		; Iterate through array of alternative sources
		num = n_elements (tag)
		or_flags = bytarr (num)
		for pos = 0, num-1 do or_flags[pos] = any (strcmp (tag[pos], sources, /fold_case))
		return, any (or_flags)
	end

	; If no dependency is found, check against sources
	index = where (strcmp (tag, tag_names (depend), /fold_case))
	if (all (index eq -1)) then return, dependency_ok (tag, -1, sources)

	dependency = depend.(index)

	if (size (dependency, /type) eq 8) then begin
		; Iterate through structure of alternative sources
		num = n_elements (dependency)
		or_flags = bytarr (num)
		for pos = 0, num-1 do begin
			if (strcmp (tag, (tag_names (dependency))[pos], /fold_case)) then begin
				or_flags[pos] = dependency_ok (dependency.(pos), -1, sources)
			end else begin
				or_flags[pos] = dependency_ok (dependency.(pos), depend, sources)
			end
		end
		return, any (or_flags)
	end

	num = n_elements (dependency)
	if (num gt 0) then begin
		; Iterate through array of mandatory sources
		and_flags = bytarr (num)
		for pos = 0, num-1 do and_flags[pos] = dependency_ok (dependency[pos], depend, sources)
		return, all (and_flags)
	end

	; Check dependency against sources
	return, any (strcmp (dependency, sources, /fold_case))
end

; Return available quantities.
function pc_check_quantities, check=check, sources=sources, datadir=datadir, dim=dim, param=param, all=all, available=avail, aliases=aliases, additionals=add_quant, vectorfields=vectorfields, warn=warn, indices=indices

	; List of available quantities.
	available = { $
		Temp:'temperature', $
		ln_Temp:'ln temperature', $
		log_Temp:'log temperature', $
		grad_Temp_abs:'grad temperature', $
		j_abs:'current density', $
		F_Lorentz_abs:'Lorentz force', $
		HR_ohm:'Ohmic heating rate', $
		HR_ohm_particle:'Ohmic heating rate / particle', $
		HR_viscous:'viscous heating rate', $
		HR_viscous_particle:'viscous heating rate / particle', $
		A_x:'magnetic vector potential x', $
		A_y:'magnetic vector potential y', $
		A_z:'magnetic vector potential z', $
		B_abs:'magnetic field strength', $
		B_2:'magnetic field squared', $
		B_x:'magnetic field x', $
		B_y:'magnetic field y', $
		B_z:'magnetic field z', $
		beta:'plasma beta', $
		rho_mag:'magnetic energy', $
		Poynting_x:'Poynting flux x', $
		Poynting_y:'Poynting flux y', $
		Poynting_z:'Poynting flux z', $
		Poynting_abs:'Poynting flux', $
		u_x:'velocity x', $
		u_y:'velocity y', $
		u_z:'velocity z', $
		u_abs:'velocity', $
		P_therm:'thermal pressure', $
		grad_P_therm_abs:'grad thermal pressure', $
		rho_u_z:'impulse density z', $
		Rn_viscous:'viscous Reynolds number', $
		Rn_mag:'magnetic Reynolds number', $
		q_sat:'saturation heatflux', $
		Spitzer_q:'Spitzer heatflux', $
		Spitzer_q_parallel:'field-aligned Spitzer heatflux', $
		Spitzer_dt:'Spitzer timestep', $
		Spitzer_ratio:'Spitzer perp./par. heatflux', $
		Spitzer_q_ratio:'saturation/Spitzer heatflux', $
		rho_c:'minimum density (Alfven < c)', $
		rho_c_ratio:'density/min. Alfven density', $
		rho:'density', $
		ln_rho:'ln density', $
		log_rho:'log density', $
		n_rho:'particle density' $
	}

	; List of code variable aliases.
	alias = { $
		t:'time', $
		TT:'Temp', $
		uu:'u', $
		AA:'A', $
		lnrho:'ln_rho', $
		lnTT:'ln_Temp' $
	}

	; List of available overplot quantities.
	available_vectorfields = { $
		u:'velocities', $
		j:'current density', $
		F_Lorentz:'Lorentz force', $
		Poynting:'Poynting flux', $
		A:'magnetic vector potential', $
		A_contour:'fieldlines', $
		B:'magnetic field', $
		grad_Temp:'grad temperature', $
		grad_P_therm:'grad thermal pressure' $
	}

	; Additional quantities without dependencies.
	additional = { $
		time:'timestamp', $
		x:'x coordinates', $
		y:'y coordinates', $
		z:'z coordinates', $
		dx:'grid distance x', $
		dy:'grid distance y', $
		dz:'grid distance z', $
		inv_dx:'inverse grid distance x', $
		inv_dy:'inverse grid distance y', $
		inv_dz:'inverse grid distance z' $
	}

	; List of dependencies.
	; Arrays list a set of mandatory dependencies (e.g. 'HR_viscous').
	; The elements of structures are all mandatory dependencies,
	; while contained arrays list alternative data sources (e.g. 'Temp').
	depend = { $
		Temp:{ Temp:['lnTT', 'TT'] }, $
		grad_Temp:'Temp', $
		grad_Temp_abs:'grad_Temp', $
		ln_Temp:'Temp', $
		log_Temp:'Temp', $
		A:'aa', $
		A_contour:'A', $
		B:'A', $
		j:'A', $
		j_abs:'j', $
		F_Lorentz:['j', 'B'], $
		F_Lorentz_abs:'F_Lorentz', $
		HR_ohm:'j', $
		HR_ohm_particle:['HR_ohm','n_rho'], $
		HR_viscous:['u', 'rho'], $
		HR_viscous_particle:['HR_viscous', 'n_rho'], $
		A_x:'A', $
		A_y:'A', $
		A_z:'A', $
		B_abs:'B', $
		B_2:'B', $
		B_x:'B', $
		B_y:'B', $
		B_z:'B', $
		beta:['P_therm', 'B_2'], $
		rho_mag:'B_2', $
		Poynting:['u', 'B', 'j'], $
		Poynting_x:'Poynting', $
		Poynting_y:'Poynting', $
		Poynting_z:'Poynting', $
		Poynting_abs:'Poynting', $
		u:'uu', $
		u_x:'u', $
		u_y:'u', $
		u_z:'u', $
		u_abs:'u', $
		P_therm:['Temp', 'rho'], $
		grad_P_therm:'P_therm', $
		grad_P_therm_abs:'grad_P_therm', $
		rho_u_z:['u', 'rho'], $
		Rn_viscous:'u', $
		Rn_mag:['u','B'], $
		q_sat:['Temp', 'rho'], $
		Spitzer_q:['Temp'], $
		Spitzer_q_parallel:['Temp', 'B'], $
		Spitzer_dt:['Temp', 'rho', 'B'], $
		Spitzer_ratio:['Temp', 'B', 'n_rho'], $
		Spitzer_q_ratio:['q_sat', 'Spitzer_q'], $
		rho_c:['rho', 'B'], $
		rho_c_ratio:['rho', 'rho_c'], $
		rho:{ rho:['lnrho', 'rho'] }, $
		ln_rho:'rho', $
		log_rho:'rho', $
		n_rho:'rho', $
		; Additional quantities without dependencies:
		time:'', $
		x:'', $
		y:'', $
		z:'', $
		dx:'', $
		dy:'', $
		dz:'', $
		inv_dx:'', $
		inv_dy:'', $
		inv_dz:'' $
	}

	; Fill default values
	if (keyword_set (all)) then return, create_struct (available, available_vectorfields, alias, additional)
	if (keyword_set (avail)) then return, available
	if (keyword_set (aliases)) then return, alias
	if (keyword_set (add_quant)) then return, additional
	if (keyword_set (vectorfields)) then return, available_vectorfields
	if (not keyword_set (check)) then check = create_struct (available)
	if (not keyword_set (sources)) then sources = pc_varcontent (datadir=datadir, dim=dim, param=param, /quiet)

	if (size (sources, /type) eq 8) then begin
		; Create array of IDL names out of given varcontent structure
		sources = sources.idlvar
		sources = sources[where (sources ne "dummy")]
	end

	if (size (check, /type) eq 7) then begin
		; Create structure out of given array
		names = check
		num = n_elements (names)
		if (num ge 1) then check = create_struct (names[0], names[0])
		if (num ge 2) then for pos = 1, num-1 do check = create_struct (check, names[pos], names[pos])
	end

	; Perform check and build list of available quantities, depending on the actual varcontent
	num = n_tags (check)
	list = ""
	pos_list = -1
	num_list = 0
	avail = create_struct (available, available_vectorfields)
	avail_list = tag_names (avail)
	alias_list = tag_names (alias)
	additional_list = tag_names (additional)
	tags = tag_names (check)
	for pos = 0, num-1 do begin
		tag = tags[pos]
		index = where (avail_list eq tag)
		if (index lt 0) then begin
			index = where (alias_list eq tag)
			if (index ge 0) then begin
				tag = alias.(index)
				index = where (strcmp (avail_list, tag, /fold_case))
			end
		end
		if (index lt 0) then begin
			index = where (strcmp (additional_list, tag, /fold_case))
			if (index ge 0) then label = additional.(index)
		end else begin
			label = avail.(index)
		end
		if (index ge 0) then begin
			if (dependency_ok (tag, depend, sources)) then begin
				if (num_list eq 0) then begin
					list = create_struct (tag, label)
					pos_list = [ pos ]
				end else begin
					list = create_struct (list, tag, label)
					pos_list = [ pos_list, pos ]
				end
				num_list++
			end else if (keyword_set (warn)) then begin
				print, "WARNING: dependency '"+tag+"' not available."
			end
		end else if (keyword_set (warn)) then begin
			print, "WARNING: '"+tag+"' is not in the availability list."
		end
	end

	if (keyword_set (indices)) then return, pos_list

	return, list

end
