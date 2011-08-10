;;
;; $Id$
;;
;;   Read yz-averages from file
;;
pro pc_read_yzaver, object=object, varfile=varfile, datadir=datadir, $
    nx=nx, double=double, monotone=monotone, quiet=quiet
COMPILE_OPT IDL2,HIDDEN
COMMON pc_precision, zero, one
;;
;;  Default data directory.
;;
if (not keyword_set(datadir)) then datadir=pc_get_datadir()
default, double, 0
default, varfile, 'yzaverages.dat'
default, monotone, 0
default, quiet, 0
;;
;;  Get necessary dimensions.
;;
if (not keyword_set(nx)) then begin
  pc_read_dim, obj=dim, datadir=datadir, quiet=quiet
  pc_set_precision, dim=dim, quiet=quiet
  nx=dim.nx
endif else begin
  if (double) then begin
    zero=0.0d
    one=1.0d
  endif else begin
    zero=0.0
    one=1.0
  endelse
endelse
;;
;;  Read variables from xyaver.in
;;
spawn, "echo "+datadir+" | sed -e 's/data\/*$//g'", datatopdir
spawn, 'cat '+datatopdir+'/yzaver.in', varnames
if (not quiet) then print, 'Preparing to read yz-averages ', $
    arraytostring(varnames,quote="'",/noleader)
nvar=n_elements(varnames)
;;
;;  Define arrays to put data in.
;;
spawn, 'wc -l '+datadir+'/'+varfile, nlines
nlines=long(nlines[0])
nit=nlines/(1+nvar*nx/8)
;
if (not quiet) then print, 'Going to read averages at ', strtrim(nit,2), ' times'
;
for i=0,nvar-1 do begin
  cmd=varnames[i]+'=fltarr(nx,nit)*one'
  if (execute(cmd,0) ne 1) then message, 'Error defining data arrays'
endfor
var=fltarr(nx*nvar)*one
tt =fltarr(nit)*one
;;
;;  Prepare for read
;;
get_lun, file
filename=datadir+'/'+varfile 
if (not quiet) then print, 'Reading ', filename
if (not file_test(filename)) then begin
  print, 'ERROR: cannot find file '+ filename
  stop
endif
close, file
openr, file, filename
;;
;;  Read xy-averages and put in arrays.
;;
for it=0L,nit-1 do begin
;; Read time
  readf, file, t
  tt[it]=t
;; Read data
  readf, file, var
  for i=0,nvar-1 do begin
    cmd=varnames[i]+'[*,it]=var[i*nx:(i+1)*nx-1]'
    if (execute(cmd,0) ne 1) then message, 'Error putting data in array'
  endfor
endfor
;;
;;  Close file.
;;
close, file
free_lun, file
;;
;;  Make time monotonous and crop all variables accordingly.
;;  
if (monotone) then begin
  ii=monotone_array(tt)
endif else begin
  ii=lindgen(n_elements(tt))
endelse
;;
;;  Read x array from file.
;;
pc_read_grid, obj=grid, /trim, datadir=datadir, /quiet
;;
;;  Put data in structure.
;;
makeobject="object = CREATE_STRUCT(name=objectname,['t','x'," + $
    arraytostring(varnames,QUOTE="'",/noleader) + "]," + $
    "tt[ii],grid.x,"+arraytostring(varnames+'[*,ii]',/noleader) + ")"
;
if (execute(makeobject) ne 1) then begin
  message, 'ERROR Evaluating variables: ' + makeobject, /INFO
  undefine,object
endif
;
end
