;
;  gwav.pro
;
;  generate table of wave numbers in a given range for helical (and
;  non-helical) forcing of the velocity field
;
;  Author: axel
;  CVS: $Id: generate_kvectors.pro,v 1.7 2003-03-15 18:18:33 brandenb Exp $
;
; Wave vectors are located in a subvolume of the box
;   -kmax <= kk:=(kx,ky,kz) <= kmax
; given by
;   k1 < |kk| < k2
; (normally a spherical shell, if kmax is large enough)

;  uncomment (or reorder) the following as appropriate
;
k1=2.5 & k2=3.5
k1=1. & k2=2.
k1=9.99 & k2=10.01 ;(gives 30 vectors)
kmax=6 & k1=5.5 & k2=6.5   ;(gives  450 vectors)
kmax=11 & k1=9.9 & k2=10.1   ;(gives 318 vectors)
kmax=6 & k1=1.5 & k2=2.5   ;(gives 62 vectors)
kmax=31 & k1=29.9 & k2=30.1   ;(gives 318 vectors)
kmax=10 & k1=4.0 & k2=5.0    ;(gives 228 vectors)
kmax=10 & k1=4.5 & k2=5.5    ;(gives 350 vectors)
kmax=31 & k1=26.9 & k2=27.1   ;(gives 2286 vectors)
kmax=6  & k1=3.2 & k2=4.8   ;(gives 314 vectors)
kmax=6  & k1=3.2 & k2=4.6   ;(gives 314 vectors)
kmax=6  & k1=2.0 & k2=3.0   ;(gives 60 vectors)
kmax=16 & k1=14.95 & k2=15.05    ;(gives 294 vectors)
kmax=10 & k1=2.5 & k2=3.5    ;(gives 98 vectors)
kmax=6 & k1=1.0 & k2=2.0   ;(gives 20 vectors)
kmax=6 & k1=1.0 & k2=2.01   ;(gives 26 vectors)
kmax=6 & k1=1.0 & k2=3.0   ;(gives 86 vectors)
;
kav=0.
;
if (kmax lt k2) then print, 'Warning: non-spherical region in k-space'
;
i=0 ;(initialize counter)
for kx=-kmax,kmax do begin
for ky=-kmax,kmax do begin
for kz=-kmax,kmax do begin
  k=sqrt(float(kx^2+ky^2+kz^2))
  if k gt k1 and k lt k2 then begin
  kav=kav+k
    print,kx,ky,kz,k,i
    if i eq 0 then begin
      kkx=kx
      kky=ky
      kkz=kz
    end else begin
      kkx=[kkx,kx]
      kky=[kky,ky]
      kkz=[kkz,kz]
    end
    i=i+1
  end
end
end
end
n=n_elements(kkx)
kav=kav/n
;
;kratio=k1/k2
;print,'k1,k2,kaveraged',k1,k2,kav
;print,'3/4 k2,  mean(k)', 3./4.*k2 , 3./4.*k2*(1.-kratio^3.)/(1.-kratio^4.)
;
;  write result
;
print, 'writing ' + strtrim(n,2) + ' wave vectors; kav = ' + strtrim(kav,2)
close,1
openw,1,'k.dat'
printf,1,n,kav
printf,1,kkx
printf,1,kky
printf,1,kkz
;
print,'check for isotropy: <k>=',mean(kkx),mean(kky),mean(kkz)
print,'check for isotropy: <k^2>=',mean(kkx^2),mean(kky^2),mean(kkz^2)
close,1
END
