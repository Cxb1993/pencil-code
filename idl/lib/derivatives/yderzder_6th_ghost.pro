;;
;;  $Id: yderzder_6th_ghost.pro,v 1.7 2008-06-24 17:11:00 brandenb Exp $
;;
;;  Second derivative d2/dydz
;;  - 6th-order
;;  - with ghost cells
;;
function yderzder,f,ghost=ghost,bcx=bcx,bcy=bcy,bcz=bcz,param=param,t=t
  COMPILE_OPT IDL2,HIDDEN
;
  common cdat,x,y,z
  common cdat_nonequidist,dx_1,dy_1,dz_1,dx_tilde,dy_tilde,dz_tilde,lequidist
;
;  Default values.
;
  default, ghost, 0
;
;  Calculate mx, my, and mz, based on the input array size.
;
  s=size(f) & d=make_array(size=s)
  mx=s[1] & my=s[2] & mz=s[3]
;
;  Not implemented for non-equidistant grid.
;
;
;  Determine location of ghost zones - assume nghost=3 for now.
;
  l1=3 & l2=mx-4 & m1=3 & m2=my-4 & n1=3 & n2=mz-4
;
;
;  Calculate d2/dydz.
;
  if (s[0] eq 3) then begin
    d=fltarr(mx,my,mz)
    if ( (m1 ne m2) and (n1 ne n2) ) then begin
      for n=n1,n2 do begin & for m=m1,m2 do begin
        ;
        ;  take care of nonuniform meah
        ;
        if (lequidist[0]) then begin
          fac=1/(60.^2*(y[4]-y[3])*(z[4]-z[3]))
        endif else begin
          fac=(1/60.^2)*dy_1[m]*dz_1[n]
        endelse
        ;
        d[l1:l2,m,n,*]=fac*( $
            45.*( (45.*(f[l1:l2,m+1,n+1]-f[l1:l2,m-1,n+1])  $
                   -9.*(f[l1:l2,m+2,n+1]-f[l1:l2,m-2,n+1])  $
                      +(f[l1:l2,m+3,n+1]-f[l1:l2,m-3,n+1])) $
                 -(45.*(f[l1:l2,m+1,n-1]-f[l1:l2,m-1,n-1])  $
                   -9.*(f[l1:l2,m+2,n-1]-f[l1:l2,m-2,n-1])  $
                      +(f[l1:l2,m+3,n-1]-f[l1:l2,m-3,n-1])))$
            -9.*( (45.*(f[l1:l2,m+1,n+2]-f[l1:l2,m-1,n+2])  $
                   -9.*(f[l1:l2,m+2,n+2]-f[l1:l2,m-2,n+2])  $
                      +(f[l1:l2,m+3,n+2]-f[l1:l2,m-3,n+2])) $
                 -(45.*(f[l1:l2,m+1,n-2]-f[l1:l2,m-1,n-2])  $
                   -9.*(f[l1:l2,m+2,n-2]-f[l1:l2,m-2,n-2])  $
                      +(f[l1:l2,m+3,n-2]-f[l1:l2,m-3,n-2])))$
               +( (45.*(f[l1:l2,m+1,n+3]-f[l1:l2,m-1,n+3])  $
                   -9.*(f[l1:l2,m+2,n+3]-f[l1:l2,m-2,n+3])  $
                      +(f[l1:l2,m+3,n+3]-f[l1:l2,m-3,n+3])) $
                 -(45.*(f[l1:l2,m+1,n-3]-f[l1:l2,m-1,n-3])  $
                   -9.*(f[l1:l2,m+2,n-3]-f[l1:l2,m-2,n-3])  $
                      +(f[l1:l2,m+3,n-3]-f[l1:l2,m-3,n-3]))) )
      endfor & endfor
    endif
  endif else if (s[0] eq 4) then begin
    d=fltarr(mx,my,mz,3)
    if ( (m1 ne m2) and (n1 ne n2) ) then begin
      for n=n1,n2 do begin & for m=m1,m2 do begin
        ;
        ;  take care of nonuniform meah
        ;
        if (lequidist[0]) then begin
          fac=1/(60.^2*(y[4]-y[3])*(z[4]-z[3]))
        endif else begin
          fac=(1/60.^2)*dy_1[m]*dz_1[n]
        endelse
        ;
        d[l1:l2,m,n,*]=fac*( $
            45.*( (45.*(f[l1:l2,m+1,n+1,*]-f[l1:l2,m-1,n+1,*])  $
                   -9.*(f[l1:l2,m+2,n+1,*]-f[l1:l2,m-2,n+1,*])  $
                      +(f[l1:l2,m+3,n+1,*]-f[l1:l2,m-3,n+1,*])) $
                 -(45.*(f[l1:l2,m+1,n-1,*]-f[l1:l2,m-1,n-1,*])  $
                   -9.*(f[l1:l2,m+2,n-1,*]-f[l1:l2,m-2,n-1,*])  $
                      +(f[l1:l2,m+3,n-1,*]-f[l1:l2,m-3,n-1,*])))$
            -9.*( (45.*(f[l1:l2,m+1,n+2,*]-f[l1:l2,m-1,n+2,*])  $
                   -9.*(f[l1:l2,m+2,n+2,*]-f[l1:l2,m-2,n+2,*])  $
                      +(f[l1:l2,m+3,n+2,*]-f[l1:l2,m-3,n+2,*])) $
                 -(45.*(f[l1:l2,m+1,n-2,*]-f[l1:l2,m-1,n-2,*])  $
                   -9.*(f[l1:l2,m+2,n-2,*]-f[l1:l2,m-2,n-2,*])  $
                      +(f[l1:l2,m+3,n-2,*]-f[l1:l2,m-3,n-2,*])))$
               +( (45.*(f[l1:l2,m+1,n+3,*]-f[l1:l2,m-1,n+3,*])  $
                   -9.*(f[l1:l2,m+2,n+3,*]-f[l1:l2,m-2,n+3,*])  $
                      +(f[l1:l2,m+3,n+3,*]-f[l1:l2,m-3,n+3,*])) $
                 -(45.*(f[l1:l2,m+1,n-3,*]-f[l1:l2,m-1,n-3,*])  $
                   -9.*(f[l1:l2,m+2,n-3,*]-f[l1:l2,m-2,n-3,*])  $
                      +(f[l1:l2,m+3,n-3,*]-f[l1:l2,m-3,n-3,*]))) )
      endfor & endfor
    endif
  endif else begin
    print, 'error: yderzder_6th_ghost not implemented for ', $
        strtrim(s[0],2), '-D arrays'
  endelse
;
;  Set ghost zones.
;
  if (ghost) then d=pc_setghost(d,bcx=bcx,bcy=bcy,bcz=bcz,param=param,t=t)
;
  return, d
;
end
