;; $Id: pc_read_xyaver.pro,v 1.4 2005-10-02 11:22:51 ajohan Exp $
;;
;;   Read xy-averages from file
;;
pro pc_read_xyaver, object=object, varfile=varfile, datadir=datadir, $
    quiet=quiet
COMPILE_OPT IDL2,HIDDEN
COMMON pc_precision, zero, one
;;
;;  Default data directory.
;;
default, datadir, './data'
default, varfile, 'xyaverages.dat'
default, quiet, 0
;;
;;  Get necessary dimensions.
;;
pc_read_dim, obj=dim, datadir=datadir, quiet=quiet
pc_set_precision, dim=dim, quiet=quiet
;;
;;  Derived dimensions.
;;
nz=dim.nz
;;
;;  Read variables from xyaver.in
;;
spawn, "echo "+datadir+" | sed -e 's/data$//g'", datatopdir
spawn, 'cat '+datatopdir+'/xyaver.in', varnames
if (not quiet) then print, 'Preparing to read xy-averages ', $
    arraytostring(varnames,quote="'",/noleader)
nvar=n_elements(varnames)
;;
;;  Define arrays to put data in.
;;
spawn, 'wc -l '+datadir+'/'+varfile, nlines
nlines=long(nlines[0])
nit=nlines/(1+nvar*nz/8)

if (not quiet) then print, 'Going to read averages at ', strtrim(nit,2), ' times'

for i=0,nvar-1 do begin
  cmd=varnames[i]+'=fltarr(nz,nit)*one'
  if (execute(cmd,0) ne 1) then message, 'Error defining data arrays'
endfor
var=fltarr(nz)*one
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
;;  Read xy-averages and put in arrays.
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
;;  Put data in structure.
;;
makeobject="object = CREATE_STRUCT(name=objectname,['t'," + $
    arraytostring(varnames,QUOTE="'",/noleader) + "]," + $
    "tt,"+arraytostring(varnames,/noleader) + ")"

if (execute(makeobject) ne 1) then begin
  message, 'ERROR Evaluating variables: ' + makeobject, /INFO
  undefine,object
endif


end
