;; $Id: pc_read_xzaver.pro,v 1.2 2006-03-15 15:29:45 ajohan Exp $
;;
;;   Read xz-averages from file
;;
pro pc_read_xzaver, object=object, varfile=varfile, datadir=datadir, $
    monotone=monotone, quiet=quiet
COMPILE_OPT IDL2,HIDDEN
COMMON pc_precision, zero, one
;;
;;  Default data directory.
;;
default, datadir, './data'
default, varfile, 'xzaverages.dat'
default, montone, 0
default, quiet, 0
;;
;;  Get necessary dimensions.
;;
pc_read_dim, obj=dim, datadir=datadir, quiet=quiet
pc_set_precision, dim=dim, quiet=quiet
;;
;;  Derived dimensions.
;;
ny=dim.ny
;;
;;  Read variables from xzaver.in
;;
spawn, "echo "+datadir+" | sed -e 's/data$//g'", datatopdir
spawn, 'cat '+datatopdir+'/xzaver.in', varnames
if (not quiet) then print, 'Preparing to read xz-averages ', $
    arraytostring(varnames,quote="'",/noleader)
nvar=n_elements(varnames)
;;
;;  Define arrays to put data in.
;;
spawn, 'wc -l '+datadir+'/'+varfile, nlines
nlines=long(nlines[0])
nit=nlines/(1+nvar*ny/8)

if (not quiet) then print, 'Going to read averages at ', strtrim(nit,2), ' times'

for i=0,nvar-1 do begin
  cmd=varnames[i]+'=fltarr(ny,nit)*one'
  if (execute(cmd,0) ne 1) then message, 'Error defining data arrays'
endfor
var=fltarr(ny)*one
tt =fltarr(nit)*one
;;
;;  Prepare for read
;;
GET_LUN, file
filename=datadir+'/'+varfile 
if (not quiet) then print, 'Reading ', filename
dummy=findfile(filename, COUNT=countfile)
if (not countfile gt 0) then begin
  print, 'ERROR: cannot find file '+ filename
  stop
endif
close, file
openr, file, filename
;;
;;  Read xz-averages and put in arrays.
;;
for it=0,nit-1 do begin
;; Read time
  readf, file, t
  tt[it]=t
;; Read data
  for i=0,nvar-1 do begin
    readf, file, var
    cmd=varnames[i]+'[*,it]=var'
    if (execute(cmd,0) ne 1) then message, 'Error putting data in array'
  endfor
endfor
;;
;;  Make time monotonous and crop all variables accordingly.
;;  
if (monotone) then begin
  ii=monotone_array(tt)
endif else begin
  ii=indgen(n_elements(tt))
endelse
;;
;;  Put data in structure.
;;
makeobject="object = CREATE_STRUCT(name=objectname,['t'," + $
    arraytostring(varnames,QUOTE="'",/noleader) + "]," + $
    "tt[ii],"+arraytostring(varnames+'[*,ii]',/noleader) + ")"

if (execute(makeobject) ne 1) then begin
  message, 'ERROR Evaluating variables: ' + makeobject, /INFO
  undefine,object
endif


end
