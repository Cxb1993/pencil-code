; $Id: r2.pro,v 1.3 2003-06-16 21:17:36 theine Exp $

;;;;;;;;;;;;;;;
;;;  r.pro  ;;;
;;;;;;;;;;;;;;;

;;; Read the data produced on one processor
;;; You should have run `start.pro' once before.
;;; $Id: r2.pro,v 1.3 2003-06-16 21:17:36 theine Exp $

function param2
; Dummy to keep IDL from complaining. The real param() routine will be
; compiled below
end

;
;  read data
;
if ((n_elements(started) le 0) or (n_elements(read_all) gt 0)) then begin
  message, "You need to run start.pro first: use `.rnew start'"
endif
undefine, read_all
;
default, datadir, 'data'
default, varfile, 'var.dat'
;

@data/def_var


;
;  Read startup parameters
;
pfile = datatopdir+'/'+'param2.nml'
dummy = findfile(pfile, COUNT=cpar)
if (cpar gt 0) then begin
  print, 'Reading param2.nml..'
  spawn, '$PENCIL_HOME/bin/nl2idl -1 -m '+datatopdir+'/param2.nml', result
  res = flatten_strings(result)
  ;; For people with an unclean shell: remove everything up to the
  ;; opening brace:
  brace = strpos(res,'{')
  if (brace lt 0) then message, 'TROUBLE: no brace found in <'+res+'>'
  if (brace ne 0) then begin
    print, "Your shell produces output when it shouldn't; you'd better"
    print, "fix your prompt."
    print, "Trying to clean up the mess.."
    res = strmid(res,brace)
  endif
  ;; Execute the resulting line
  if (execute('par2 = '+res) ne 1) then $
      message, 'There was a problem with param.nml', /INFO
  if (lhydro) then begin
    nu=par2.nu
  endif
  if (ldensity) then begin
    cs0=par2.cs0
  endif
  if (lentropy) then begin
    hcond0=par2.hcond0 & hcond1=par2.hcond1 & hcond2=par2.hcond2
    luminosity=par2.luminosity & wheat=par2.wheat
    cool=par2.cool & wcool=par2.wcool
    Fbot=par2.Fbot
  endif
endif else begin
  print, 'Warning: cannot find file ', pfile
endelse

;
;  Read data
;
@data/variables
  ;
if (lshear) then begin
  readu,1, t, x, y, z, dx, dy, dz, deltay
end else begin
  readu,1, t, x, y, z, dx, dy, dz
end
;
xx = spread(x, [1,2], [my,mz])
yy = spread(y, [0,2], [mx,mz])
zz = spread(z, [0,1], [mx,my])
rr = sqrt(xx^2+yy^2+zz^2)
;
;  Summarise data
;
print,' t     =',t
print,'----------------------'
;
xyz = ['x', 'y', 'z']
fmt = '(A,4G15.6)'
print, '  var            minval         maxval          mean           rms'
;AB:  does not work ok for kinematic case. I suggest to use only f.
;WD: Ought to work now (the namelist lphysics need to know about the
;    relevant logicals). What is f ?
;
if (lhydro) then $
    for j=0,2 do $
      print, FORMAT=fmt, 'uu_'+xyz[j]+'   =', $
      minmax(uu(*,*,*,j)), mean(uu(*,*,*,j),/DOUBLE), rms(uu(*,*,*,j),/DOUBLE)
if (ldensity) then $
    print, FORMAT=fmt, 'lnrho  =', $
    minmax(lnrho), mean(lnrho,/DOUBLE), rms(lnrho,/DOUBLE)
if (lentropy) then $
    print, FORMAT=fmt, 'ss     =', $
      minmax(ss), mean(ss,/DOUBLE), rms(ss,/DOUBLE)
if (lpscalar) then $
    print, FORMAT=fmt, 'lncc   =', $
      minmax(lncc), mean(lncc,/DOUBLE), rms(lncc,/DOUBLE)
if (lionization) then begin
    print, FORMAT=fmt, 'yH     =', $
      minmax(yH(*,*,*)),mean(yH(*,*,*),/DOUBLE),rms(yH(*,*,*),/DOUBLE)
    print, FORMAT=fmt, 'TT     =', $
      minmax(TT(*,*,*)),mean(TT(*,*,*),/DOUBLE),rms(TT(*,*,*),/DOUBLE)
end
if (lradiation_fld) then begin
    for j=0,2 do begin
      print, FORMAT=fmt, 'ff_'+xyz[j]+'   =', $
      minmax(ff(*,*,*,j)), mean(ff(*,*,*,j),/DOUBLE), rms(ff(*,*,*,j),/DOUBLE)
    end
    print, FORMAT=fmt, 'ee     =', $
    minmax(ee), mean(ee,/DOUBLE), rms(ee,/DOUBLE)
end
if (lradiation AND NOT lradiation_fld) then begin
    print, FORMAT=fmt, 'Qrad   =', $
      minmax(Qrad(*,*,*)),mean(Qrad(*,*,*),/DOUBLE),rms(Qrad(*,*,*),/DOUBLE)
end
if (lmagnetic) then begin
    for j=0,2 do $
      print, FORMAT=fmt, 'aa_'+xyz[j]+'   =', $
      minmax(aa(*,*,*,j)), mean(aa(*,*,*,j),/DOUBLE), rms(aa(*,*,*,j),/DOUBLE)
    if (cpar gt 0) then begin
      eta=par2.eta
    end
end
;
if (par.lvisc_shock ne 0) then begin
    nu_shock=fltarr(mx,my,mz)*one
    readu,1,nu_shock
endif
;
END

; End of file
