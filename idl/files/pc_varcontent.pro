;  $Id: pc_varcontent.pro,v 1.5 2004-05-10 18:22:19 mee Exp $
FUNCTION pc_varcontent,datadir=datadir,dim=dim,param=param
COMPILE_OPT IDL2,HIDDEN

; 
;  Read the positions of variables in f
;  Can't just use `@data/index', as the data directory may have a different name
;
if (n_elements(dim) eq 0) then pc_read_dim,obj=dim
if (n_elements(param) eq 0) then pc_read_param,obj=param

default,datadir,'data'
cmd = 'perl -000 -ne '+"'"+'s/[ \t]+/ /g; print join(" & ",split(/\n/,$_)),"\n"'+"' "+datadir+'/index.pro'
spawn, cmd, result
res = flatten_strings(result) 

;res=''
;get_lun,indexfile
;openr,indexfile,datadir+'/index.pro'

;repeat begin
;readf,indexfile,res
if (execute(res) ne 1) then $
    message, 'There was a problem with index.pro', /INFO
;endrep until eof(indexfile)

;close,indexfile
;free_lun,indexfile

;
; VARCONTENT STRUCTURE DESCRIPTION
;
; variable (string)
;   Human readable name for the variable
;
; idlvar (string)
;   Name of the variable (usually in the IDL global namespace)
;   in which the variables data will be stored
;
; idlinit (string)
;   IDL command to initialise the storage variable ready for
;   reading in from a file
;
; idlvarloc (string)
;   As idlvar but used when two grid sizes are used eg. global mesh
;   and processor mesh (local -> loc). And used in processes such
;   as in rall.pro.  Eg. uses mesh sizes of (mxloc,myloc,mzloc)
;
; idlinitloc (string)
;   Again as idlinit but used when two mesh sizes are required at once.
;   see idlvarloc

; How many variables are expected to be stored in the var file?


if (param.lwrite_aux ne 0) then totalvars=dim.mvar+dim.maux else totalvars=dim.mvar

; Make an array of structures in which to store their descriptions
; index zero is kept as a dummy entry.
varcontent=REPLICATE({varcontent_all, variable:'UNKNOWN', $ 
                                      idlvar:'dummy', $
                                      idlinit:'fltarr(mx,my,mz)*one', $
                                      idlvarloc:'dummy_loc', $
                                      idlinitloc:'fltarr(mxloc,myloc,mzloc)*one', $
                                      skip:0},totalvars+1)
;for i=1L,totalvars do begin
;  varcontent[i].idlvar='dummy'+str(i)
;endfor
;
; Declare ALL variables that MAY OCCUR
;

;Predefine some variable types used regularly
INIT_3VECTOR     = 'fltarr(mx,my,mz,3)*one'
INIT_3VECTOR_LOC = 'fltarr(mxloc,myloc,mzloc,3)*one'
INIT_SCALAR      = 'fltarr(mx,my,mz)*one'
INIT_SCALAR_LOC  = 'fltarr(mxloc,myloc,mzloc)*one'

; For EVERY POSSIBLE variable in a var file, store a
; description of the variable in an indexed array of structures
; where the indexes line up with those in the saved f array

; Any variable not stored should have iXXXXXX set to zero
; and will only update the dummy index zero entry

; DO mvar VARIABLES FIRST


varcontent[iuu].variable   = 'Velocity (uu)'
varcontent[iuu].idlvar     = 'uu'
varcontent[iuu].idlinit    = INIT_3VECTOR
varcontent[iuu].idlvarloc  = 'uu_loc'
varcontent[iuu].idlinitloc = INIT_3VECTOR_LOC
varcontent[iuu].skip       = 2

varcontent[ilnrho].variable   = 'Log density (lnrho)'
varcontent[ilnrho].idlvar     = 'lnrho'
varcontent[ilnrho].idlinit    = INIT_SCALAR
varcontent[ilnrho].idlvarloc  = 'lnrho_loc'
varcontent[ilnrho].idlinitloc = INIT_SCALAR_LOC

varcontent[iss].variable = 'Entropy (ss)'
varcontent[iss].idlvar   = 'ss'
varcontent[iss].idlinit    = INIT_SCALAR
varcontent[iss].idlvarloc= 'ss_loc'
varcontent[iss].idlinitloc = INIT_SCALAR_LOC

varcontent[iaa].variable = 'Magnetic vector potential (aa)'
varcontent[iaa].idlvar   = 'aa'
varcontent[iaa].idlinit    = INIT_3VECTOR
varcontent[iaa].idlvarloc= 'aa_loc'
varcontent[iaa].idlinitloc = INIT_3VECTOR_LOC
varcontent[iaa].skip  = 2

varcontent[ifx].variable = 'Radiation vector ?something? (ff)'
varcontent[ifx].idlvar   = 'ff'
varcontent[ifx].idlinit    = INIT_3VECTOR
varcontent[ifx].idlvarloc= 'ff_loc'
varcontent[ifx].idlinitloc = INIT_3VECTOR_LOC
varcontent[ifx].skip  = 2

varcontent[ie].variable = 'Radiation scalar ?something? (ee)'
varcontent[ie].idlvar   = 'ee'
varcontent[ie].idlinit    = INIT_SCALAR
varcontent[ie].idlvarloc= 'ee_loc'
varcontent[ie].idlinitloc = INIT_SCALAR_LOC

varcontent[ilncc].variable = 'Log passive scalar (lncc)'
varcontent[ilncc].idlvar   = 'lncc'
varcontent[ilncc].idlinit    = INIT_SCALAR
varcontent[ilncc].idlvarloc= 'lncc_loc'
varcontent[ilncc].idlinitloc = INIT_SCALAR_LOC

varcontent[iecr].variable = 'Cosmic ray energy density (ecr)'
varcontent[iecr].idlvar   = 'ecr'
varcontent[iecr].idlinit    = INIT_SCALAR
varcontent[iecr].idlvarloc= 'ecr_loc'
varcontent[iecr].idlinitloc = INIT_SCALAR_LOC

dustcount=n_elements(iuud) 
if (dustcount gt 0L) then begin
varcontent[iuud[0]].variable = 'Dust velocity  (uud)'
varcontent[iuud[0]].idlvar   = 'uud'
varcontent[iuud[0]].idlinit  = 'fltarr(mx,my,mz,3,'+str(dustcount)+')' 
varcontent[iuud[0]].idlvarloc= 'uud_loc'
varcontent[iuud[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,3,'+str(dustcount)+')'
varcontent[iuud[0]].skip     = (dustcount * 3) - 1
endif

dustcount=n_elements(ind)
if (dustcount gt 0L) then begin
varcontent[ind[0]].variable = 'Dust number density (nd)'
varcontent[ind[0]].idlvar   = 'nd'
varcontent[ind[0]].idlinit  = 'fltarr(mx,my,mz,'+str(dustcount)+')' 
varcontent[ind[0]].idlvarloc= 'nd_loc'
varcontent[ind[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,'+str(dustcount)+')'
varcontent[ind[0]].skip     = dustcount - 1
endif

dustcount=n_elements(imd)
if (dustcount gt 0L) then begin
varcontent[imd[0]].variable = 'Dust density (md)'
varcontent[imd[0]].idlvar   = 'md'
varcontent[imd[0]].idlinit  = 'fltarr(mx,my,mz,'+str(dustcount)+')' 
varcontent[imd[0]].idlvarloc= 'md_loc'
varcontent[imd[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,'+str(dustcount)+')'
varcontent[imd[0]].skip     = dustcount - 1
endif

dustcount=n_elements(imi)
if (dustcount gt 0L) then begin
varcontent[imi[0]].variable = 'Ice density (mi)'
varcontent[imi[0]].idlvar   = 'mi'
varcontent[imi[0]].idlinit  = 'fltarr(mx,my,mz,'+str(dustcount)+')' 
varcontent[imi[0]].idlvarloc= 'mi_loc'
varcontent[imi[0]].idlinitloc = 'fltarr(mxloc,myloc,mzloc,'+str(dustcount)+')'
varcontent[imi[0]].skip     = dustcount - 1
endif

varcontent[igg].variable = 'Gravitational acceleration (gg)'
varcontent[igg].idlvar   = 'gg'
varcontent[igg].idlinit    = INIT_3VECTOR
varcontent[igg].idlvarloc= 'gg_loc'
varcontent[igg].idlinitloc = INIT_3VECTOR_LOC
varcontent[igg].skip     = 2


; Special condition as can be maux or mvar variable
if ((ilnTT le dim.mvar) or (param.lwrite_aux ne 0)) then begin
    varcontent[ilnTT].variable   = 'Log temperature (lnTT)'
    varcontent[ilnTT].idlvar     = 'lnTT'
    varcontent[ilnTT].idlinit    = INIT_SCALAR
    varcontent[ilnTT].idlvarloc  = 'lnTT_loc'
    varcontent[ilnTT].idlinitloc = INIT_SCALAR_LOC
end

; THEN DO maux VARIABLES 
; ** ONLY IF THEY HAVE BEEN SAVED **
if (param.lwrite_aux ne 0) then begin
    varcontent[iQrad].variable = 'Radiation (Qrad)'
    varcontent[iQrad].idlvar   = 'Qrad'
    varcontent[iQrad].idlinit    = INIT_SCALAR
    varcontent[iQrad].idlvarloc= 'Qrad_loc'
    varcontent[iQrad].idlinitloc = INIT_SCALAR_LOC
    
    ;varcontent[iSrad].variable = 'Radiation (Srad)'
    ;varcontent[iSrad].idlvar   = 'Srad'
    ;varcontent[iSrad].idlinit    = INIT_SCALAR
    ;varcontent[iSrad].idlvarloc= 'Srad_loc'
    ;varcontent[iSrad].idlinitloc = INIT_SCALAR_LOC
    
    ;varcontent[ikappa].variable = 'Radiation (kappa)'
    ;varcontent[ikappa].idlvar   = 'kappa'
    ;varcontent[ikappa].idlinit    = INIT_SCALAR
    ;varcontent[ikappa].idlvarloc= 'kappa_loc'
    ;varcontent[ikappa].idlinitloc = INIT_SCALAR_LOC
    

    varcontent[iyH].variable   = 'Hydrogen ionization fraction (yH)'
    varcontent[iyH].idlvar     = 'yH'
    varcontent[iyH].idlinit    = INIT_SCALAR
    varcontent[iyH].idlvarloc  = 'yH_loc'
    varcontent[iyH].idlinitloc = INIT_SCALAR_LOC

    varcontent[ishock].variable = 'Shock Profile (shock)'
    varcontent[ishock].idlvar   = 'shock'
    varcontent[ishock].idlinit    = INIT_SCALAR
    varcontent[ishock].idlvarloc= 'shock_loc'
    varcontent[ishock].idlinitloc = INIT_SCALAR_LOC
end

; ZERO out default 'should never be used' definition
; will have been filled in where i?????? has not been
; set above.
varcontent[0].variable = 'UNKNOWN'
varcontent[0].idlvar   = 'UNKNOWN'
varcontent[0].idlinit  = '0.'
varcontent[0].skip  = 0


return,varcontent

END
