;;
;; $Id$
;;
;; NAME:
;;      PC_READ_VIDEO
;;
;; PURPOSE:
;;     Read video slices and put in structure
;;
;; MODIFICATION HISTORY:
;;     Written by: Anders Johansen (johansen@mpia.de) on 28.06.2007
;;
pro pc_read_video, field=field, object=object, nt=nt, njump=njump, $
    dim=dim, datadir=datadir, proc=proc, swap_endian=swap_endian, $
    xy2read=xy2read, xyread=xyread, xzread=xzread, yzread=yzread, $
    print=print, quiet=quiet, help=help
COMPILE_OPT IDL2,HIDDEN
COMMON pc_precision, zero, one
;
; Default values.
;
default, field, 'lnrho'
if (not keyword_set(datadir)) then datadir=pc_get_datadir()
default, proc, -1
default, nt, 100
default, njump, 0
default, swap_endian, 0
default, xy2read, 1
default, xyread, 1
default, xzread, 1
default, yzread, 1
default, print, 1
default, quiet, 0
default, help, 0
;
; Read either from global data directory or from single processor directory.
;
if (proc eq -1) then begin
  readdir=datadir
endif else begin
  readdir=datadir+'/proc'+strtrim(proc,2)
endelse
;
; Read dimensions and set precision.
;
pc_read_dim, obj=dim, datadir=readdir, /quiet
pc_set_precision, dim=dim, datadir=readdir, /quiet
;
; Define filenames of slices.
;
file_slice1=readdir+'/slice_'+field+'.xy2'
file_slice2=readdir+'/slice_'+field+'.xy'
file_slice3=readdir+'/slice_'+field+'.xz'
file_slice4=readdir+'/slice_'+field+'.yz'
;
; Read data with proper precision.
;
xy2_tmp=fltarr(dim.nx,dim.ny)*one
xy_tmp =fltarr(dim.nx,dim.ny)*one
xz_tmp =fltarr(dim.nx,dim.nz)*one
yz_tmp =fltarr(dim.ny,dim.nz)*one
t_tmp  =one
;
; Put data in arrays.
;
xy2=fltarr(dim.nx,dim.ny,nt)*one
xy =fltarr(dim.nx,dim.ny,nt)*one
xz =fltarr(dim.nx,dim.nz,nt)*one
yz =fltarr(dim.ny,dim.nz,nt)*one
t  =fltarr(nt)*one
;
; Open slice files.
;
if (xy2read) then begin
  close, 1 & openr, 1, file_slice1, /f77, swap_endian=swap_endian
endif
if (xyread) then begin
  close, 2 & openr, 2, file_slice2, /f77, swap_endian=swap_endian
endif
print, xzread
if (xzread) then begin
  close, 3 & openr, 3, file_slice3, /f77, swap_endian=swap_endian
endif
if (yzread) then begin
  close, 4 & openr, 4, file_slice4, /f77, swap_endian=swap_endian
endif
;
; Read slices at nt times.
;
for it=0,nt-1 do begin
;
; Possible to skip njump slices.
;
  if (njump gt 0) then begin
    dummy=zero
    for ijump=0,njump-1 do begin
      if (xy2read) then readu, 1, dummy1
      if (xyread)  then readu, 2, dummy1
      if (xzread)  then readu, 3, dummy1
      if (yzread)  then readu, 4, dummy1
      if (xy2read) then begin
        if (eof(1)) then break
      endif
      if (xyread) then begin
        if (eof(2)) then break
      endif
      if (xzread) then begin
        if (eof(3)) then break
      endif
      if (yzread) then begin
        if (eof(4)) then break
      endif
    endfor
  endif
;
; Stop if end of file reached.
;
  if (xy2read) then begin
    if (eof(1)) then break
  endif
  if (xyread) then begin
    if (eof(2)) then break
  endif
  if (xzread) then begin
    if (eof(3)) then break
  endif
  if (yzread) then begin
    if (eof(4)) then break
  endif
;
  if (xy2read) then readu, 1, xy2_tmp, t_tmp, slice_z2pos
  if (xyread)  then readu, 2, xy_tmp, t_tmp, slice_zpos
  if (xzread)  then readu, 3, xz_tmp, t_tmp, slice_ypos
  if (yzread)  then readu, 4, yz_tmp, t_tmp, slice_xpos
  xy2[*,*,it]=xy2_tmp
  xy [*,*,it]=xy_tmp
  xz [*,*,it]=xz_tmp
  yz [*,*,it]=yz_tmp
  t[it]=t_tmp
endfor
;
; Close files.
;
if (xy2read) then close, 1
if (xyread)  then close, 2
if (xzread)  then close, 3
if (yzread)  then close, 4
;
; Build structure of all the variables.
;
object = create_struct(name=objectname,['t','xy','xy2','xz','yz'], $
    t, xy, xy2, xz, yz)
;
; If requested print a summary.
;
if (keyword_set(print)) then begin
  print, 'field=''', field, ''', datadir=''', readdir, ''''
  print, 'min(t)  , max(t)   = ', min(t), ',', max(t)
  print, 'min(xy) , max(xy)  = ', min(xy), ', ', max(xy)
  print, 'min(xy2), max(xy2) = ', min(xy2), ', ', max(xy2)
  print, 'min(xz) , max(xz)  = ', min(xz), ', ', max(xz)
  print, 'min(yz) , max(yz)  = ', min(yz), ', ', max(yz)
endif
;
end
