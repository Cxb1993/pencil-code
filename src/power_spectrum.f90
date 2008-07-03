! $Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $
!
!  reads in full snapshot and calculates power spetrum of u
!
!-----------------------------------------------------------------------
!    3-sep-02/axel+nils: coded
!    5-sep-02/axel: loop first over all points, then distribute to k-shells
!   23-sep-02/nils: adapted from postproc/src/power_spectrum.f90
!   14-mar-06/axel: made kx,ky,kz going only in integers. Works only for cubes.

module  power_spectrum
  !
  use Cdata
  use General
  use Fourier
  use Mpicomm
  use Messages
  use Sub
  !
  implicit none

  include 'power_spectrum.h'
  !
  contains

!***********************************************************************
    subroutine power(f,sp)
!
!  Calculate power spectra (on shperical shells) of the variable
!  specified by `sp'.
!  Since this routine is only used at the end of a time step,
!  one could in principle reuse the df array for memory purposes.
!
  integer, parameter :: nk=nx/2
  integer :: i,k,ikx,iky,ikz,im,in,ivec
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension(nx,ny,nz) :: a1,b1
  real, dimension(nx) :: bb
  real, dimension(nk) :: spectrum=0.,spectrum_sum=0
  real, dimension(nxgrid) :: kx
  real, dimension(nygrid) :: ky
  real, dimension(nzgrid) :: kz
  character (len=*) :: sp
  !
  !  identify version
  !
  if (lroot .AND. ip<10) call cvs_id( &
       "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
  !
  !  Define wave vector, defined here for the *full* mesh.
  !  Each processor will see only part of it.
  !  Ignore *2*pi/Lx factor, because later we want k to be integers
  !
  kx=cshift((/(i-(nxgrid+1)/2,i=0,nxgrid-1)/),+(nxgrid+1)/2) !*2*pi/Lx
  ky=cshift((/(i-(nygrid+1)/2,i=0,nygrid-1)/),+(nygrid+1)/2) !*2*pi/Ly
  kz=cshift((/(i-(nzgrid+1)/2,i=0,nzgrid-1)/),+(nzgrid+1)/2) !*2*pi/Lz
  !
  spectrum=0
  !
  !  In fft, real and imaginary parts are handled separately.
  !  Initialize real part a1-a3; and put imaginary part, b1-b3, to zero
  !  Added power spectra of rho^(1/2)*u and rho^(1/3)*u.
  !
  do ivec=1,3
     !
     if (trim(sp)=='u') then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)
     elseif (trim(sp)=='r2u') then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)*exp(f(l1:l2,m1:m2,n1:n2,ilnrho)/2.)
     elseif (trim(sp)=='r3u') then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)*exp(f(l1:l2,m1:m2,n1:n2,ilnrho)/3.)
     elseif (trim(sp)=='b') then
        do n=n1,n2
           do m=m1,m2
              call curli(f,iaa,bb,ivec)
              im=m-nghost
              in=n-nghost
              a1(:,im,in)=bb
           enddo
        enddo
     elseif (trim(sp)=='a') then
        a1=f(l1:l2,m1:m2,n1:n2,iax+ivec-1)
     else
        print*,'There are no such sp=',trim(sp)
     endif
     b1=0
!
!  Doing the Fourier transform
!
     call fourier_transform(a1,b1)
!
!  integration over shells
!
     if(lroot .AND. ip<10) print*,'fft done; now integrate over shells...'
     do ikz=1,nz
        do iky=1,ny
           do ikx=1,nx
              k=nint(sqrt(kx(ikx)**2+ky(iky+ipy*ny)**2+kz(ikz+ipz*nz)**2))
              if(k>=0 .and. k<=(nk-1)) spectrum(k+1)=spectrum(k+1) &
                   +a1(ikx,iky,ikz)**2+b1(ikx,iky,ikz)**2
           enddo
        enddo
     enddo
     !
  enddo !(from loop over ivec)
  !
  !  Summing up the results from the different processors
  !  The result is available only on root
  !
  call mpireduce_sum(spectrum,spectrum_sum,nk)
  !
  !  on root processor, write global result to file
  !  multiply by 1/2, so \int E(k) dk = (1/2) <u^2>
  !
!
!  append to diagnostics file
!
  if (iproc==root) then
     if (ip<10) print*,'Writing power spectra of variable',trim(sp) &
          ,'to ',trim(datadir)//'/power'//trim(sp)//'.dat'
     spectrum_sum=.5*spectrum_sum
     open(1,file=trim(datadir)//'/power'//trim(sp)//'.dat',position='append')
     write(1,*) t
     write(1,'(1p,8e10.2)') spectrum_sum
     close(1)
  endif
  !
  endsubroutine power
!***********************************************************************
    subroutine power_2d(f,sp)
!
!  Calculate power spectra (on circles) of the variable
!  specified by `sp'.
!  Since this routine is only used at the end of a time step,
!  one could in principle reuse the df array for memory purposes.
!
  integer, parameter :: nk=nx/2
  integer :: i,k,ikx,iky,ikz,im,in,ivec
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension(nx,ny,nz) :: a1,b1
  real, dimension(nx) :: bb
  real, dimension(nk) :: spectrum=0.,spectrum_sum=0
  real, dimension(nxgrid) :: kx
  real, dimension(nygrid) :: ky
  real, dimension(nzgrid) :: kz
  character (len=1) :: sp
  !
  !  identify version
  !
  if (lroot .AND. ip<10) call cvs_id( &
       "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
  !
  !  Define wave vector, defined here for the *full* mesh.
  !  Each processor will see only part of it.
  !  Ignore *2*pi/Lx factor, because later we want k to be integers
  !
  kx=cshift((/(i-(nxgrid+1)/2,i=0,nxgrid-1)/),+(nxgrid+1)/2) !*2*pi/Lx
  ky=cshift((/(i-(nygrid+1)/2,i=0,nygrid-1)/),+(nygrid+1)/2) !*2*pi/Ly
  kz=cshift((/(i-(nzgrid+1)/2,i=0,nzgrid-1)/),+(nzgrid+1)/2) !*2*pi/Lz
  !
  spectrum=0
  !
  !  In fft, real and imaginary parts are handled separately.
  !  Initialize real part a1-a3; and put imaginary part, b1-b3, to zero
  !
  do ivec=1,3
     !
     if (sp=='u') then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)
     elseif (sp=='b') then
        do n=n1,n2
           do m=m1,m2
              call curli(f,iaa,bb,ivec)
              im=m-nghost
              in=n-nghost
              a1(:,im,in)=bb
           enddo
        enddo
     elseif (sp=='a') then
        a1=f(l1:l2,m1:m2,n1:n2,iax+ivec-1)
     else
        print*,'There are no such sp=',sp
     endif
     b1=0
!
!  Doing the Fourier transform
!
     call fourier_transform_xz(a1,b1)
!
!  integration over shells
!
     if(lroot .AND. ip<10) print*,'fft done; now integrate over circles...'
     do ikz=1,nz
       do iky=1,ny
         do ikx=1,nx
           k=nint(sqrt(kx(ikx)**2+kz(ikz+ipz*nz)**2))
           if(k>=0 .and. k<=(nk-1)) spectrum(k+1)=spectrum(k+1) &
                +a1(ikx,iky,ikz)**2+b1(ikx,iky,ikz)**2
         enddo
       enddo
     enddo
     !
  enddo !(from loop over ivec)
  !
  !  Summing up the results from the different processors
  !  The result is available only on root
  !
  call mpireduce_sum(spectrum,spectrum_sum,nk)
  !
  !  on root processor, write global result to file
  !  multiply by 1/2, so \int E(k) dk = (1/2) <u^2>
  !
!
!  append to diagnostics file
!
  if (iproc==root) then
     if (ip<10) print*,'Writing power spectra of variable',sp &
          ,'to ',trim(datadir)//'/power'//trim(sp)//'_2d.dat'
     spectrum_sum=.5*spectrum_sum
     open(1,file=trim(datadir)//'/power'//trim(sp)//'_2d.dat',position='append')
     write(1,*) t
     write(1,'(1p,8e10.2)') spectrum_sum
     close(1)
  endif
  !
  endsubroutine power_2d
!***********************************************************************
  subroutine powerhel(f,sp)
!
!  Calculate power and helicity spectra (on shperical shells) of the
!  variable specified by `sp', i.e. either the spectra of uu and kinetic
!  helicity, or those of bb and magnetic helicity..
!  Since this routine is only used at the end of a time step,
!  one could in principle reuse the df array for memory purposes.
!
  integer, parameter :: nk=nx/2
  integer :: i,k,ikx,iky,ikz,im,in,ivec,ivec_jj
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension(nx,ny,nz) :: a_re,a_im,b_re,b_im
  real, dimension(nx) :: bbi,jji
  real, dimension(nk) :: spectrum=0.,spectrum_sum=0
  real, dimension(nk) :: spectrumhel=0.,spectrumhel_sum=0
  real, dimension(nxgrid) :: kx
  real, dimension(nygrid) :: ky
  real, dimension(nzgrid) :: kz
  character (len=3) :: sp
  !
  !  identify version
  !
  if (lroot .AND. ip<10) call cvs_id( &
       "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
  !
  !  Define wave vector, defined here for the *full* mesh.
  !  Each processor will see only part of it.
  !  Ignore *2*pi/Lx factor, because later we want k to be integers
  !
  kx=cshift((/(i-(nxgrid+1)/2,i=0,nxgrid-1)/),+(nxgrid+1)/2) !*2*pi/Lx
  ky=cshift((/(i-(nygrid+1)/2,i=0,nygrid-1)/),+(nygrid+1)/2) !*2*pi/Ly
  kz=cshift((/(i-(nzgrid+1)/2,i=0,nzgrid-1)/),+(nzgrid+1)/2) !*2*pi/Lz
  !
  !  initialize power spectrum to zero
  !
  spectrum=0.
  spectrumhel=0.
  !
  !  loop over all the components
  !
  do ivec=1,3
    !
    !  In fft, real and imaginary parts are handled separately.
    !  For "kin", calculate spectra of <uk^2> and <ok.uk>
    !  For "mag", calculate spectra of <bk^2> and <ak.bk>
    !
    if (sp=='kin') then
      do n=n1,n2
        do m=m1,m2
          call curli(f,iuu,bbi,ivec)
          im=m-nghost
          in=n-nghost
          a_re(:,im,in)=bbi  !(this corresponds to vorticity)
        enddo
      enddo
      b_re=f(l1:l2,m1:m2,n1:n2,iuu+ivec-1)
      a_im=0.
      b_im=0.
    elseif (sp=='mag') then
      do n=n1,n2
        do m=m1,m2
          call curli(f,iaa,bbi,ivec)
          im=m-nghost
          in=n-nghost
          b_re(:,im,in)=bbi  !(this corresponds to magnetic field)
        enddo
      enddo
      a_re=f(l1:l2,m1:m2,n1:n2,iaa+ivec-1)
      a_im=0.
      b_im=0.
    elseif (sp=='uxj') then
      do n=n1,n2
        do m=m1,m2
          if(ivec==1) ivec_jj=2
          if(ivec==2) ivec_jj=1
          if(ivec/=3) call del2vi_etc(f,iaa,ivec_jj,curlcurl=jji)
          im=m-nghost
          in=n-nghost
          if(ivec==1) b_re(:,im,in)=+jji
          if(ivec==2) b_re(:,im,in)=-jji
          if(ivec==3) b_re(:,im,in)=+0.
        enddo
      enddo
      a_re=f(l1:l2,m1:m2,n1:n2,iuu+ivec-1)
      a_im=0.
      b_im=0.
    endif
!
!  Doing the Fourier transform
!
    call fourier_transform(a_re,a_im)
    call fourier_transform(b_re,b_im)
!
!  integration over shells
!
    if(lroot .AND. ip<10) print*,'fft done; now integrate over shells...'
    do ikz=1,nz
      do iky=1,ny
        do ikx=1,nx
          k=nint(sqrt(kx(ikx)**2+ky(iky+ipy*ny)**2+kz(ikz+ipz*nz)**2))
          if(k>=0 .and. k<=(nk-1)) then
            spectrum(k+1)=spectrum(k+1) &
               +b_re(ikx,iky,ikz)**2 &
               +b_im(ikx,iky,ikz)**2
            spectrumhel(k+1)=spectrumhel(k+1) &
               +a_re(ikx,iky,ikz)*b_re(ikx,iky,ikz) &
               +a_im(ikx,iky,ikz)*b_im(ikx,iky,ikz)
          endif
        enddo
      enddo
    enddo
    !
  enddo !(from loop over ivec)
  !
  !  Summing up the results from the different processors
  !  The result is available only on root
  !
  call mpireduce_sum(spectrum,spectrum_sum,nk)
  call mpireduce_sum(spectrumhel,spectrumhel_sum,nk)
  !
  !  on root processor, write global result to file
  !  multiply by 1/2, so \int E(k) dk = (1/2) <u^2>
  !  ok for helicity, so \int F(k) dk = <o.u> = 1/2 <o*.u+o.u*>
  !
  !  append to diagnostics file
  !
  if (iproc==root) then
    if (ip<10) print*,'Writing power spectrum ',sp &
         ,' to ',trim(datadir)//'/power_'//trim(sp)//'.dat'
    !
    spectrum_sum=.5*spectrum_sum
    open(1,file=trim(datadir)//'/power_'//trim(sp)//'.dat',position='append')
    write(1,*) t
    write(1,'(1p,8e10.2)') spectrum_sum
    close(1)
    !
    open(1,file=trim(datadir)//'/powerhel_'//trim(sp)//'.dat',position='append')
    write(1,*) t
    write(1,'(1p,8e10.2)') spectrumhel_sum
    close(1)
  endif
  !
  endsubroutine powerhel
!***********************************************************************
  subroutine powerscl(f,sp)
!
!  Calculate power spectrum of scalar quantity (on spherical shells) of the
!  variable specified by `sp', e.g. spectra of cc, rho, etc.
!  Since this routine is only used at the end of a time step,
!  one could in principle reuse the df array for memory purposes.
!
  integer, parameter :: nk=nx/2
  integer :: i,k,ikx,iky,ikz,im,in,ivec
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension(nx,ny,nz) :: a_re,a_im
  real, dimension(nk) :: spectrum=0.,spectrum_sum=0
  real, dimension(nxgrid) :: kx
  real, dimension(nygrid) :: ky
  real, dimension(nzgrid) :: kz
  character (len=2) :: sp
  !
  !  identify version
  !
  if (lroot .AND. ip<10) call cvs_id( &
       "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
  !
  !  Define wave vector, defined here for the *full* mesh.
  !  Each processor will see only part of it.
  !  Ignore *2*pi/Lx factor, because later we want k to be integers
  !
  kx=cshift((/(i-(nxgrid+1)/2,i=0,nxgrid-1)/),+(nxgrid+1)/2) !*2*pi/Lx
  ky=cshift((/(i-(nygrid+1)/2,i=0,nygrid-1)/),+(nygrid+1)/2) !*2*pi/Ly
  kz=cshift((/(i-(nzgrid+1)/2,i=0,nzgrid-1)/),+(nzgrid+1)/2) !*2*pi/Lz
  !
  !  initialize power spectrum to zero
  !
  spectrum=0.
  !
  !  In fft, real and imaginary parts are handled separately.
  !  For "kin", calculate spectra of <uk^2> and <ok.uk>
  !  For "mag", calculate spectra of <bk^2> and <ak.bk>
  !
  if (sp=='ro') then
    a_re=exp(f(l1:l2,m1:m2,n1:n2,ilnrho))
  elseif (sp=='lr') then
    a_re=f(l1:l2,m1:m2,n1:n2,ilnrho)
  elseif (sp=='TT') then
    a_re=exp(f(l1:l2,m1:m2,n1:n2,ilnTT))
  elseif (sp=='ss') then
    a_re=f(l1:l2,m1:m2,n1:n2,iss)
  elseif (sp=='cc') then
    a_re=f(l1:l2,m1:m2,n1:n2,ilncc)
  elseif (sp=='cr') then
    a_re=f(l1:l2,m1:m2,n1:n2,iecr)
  endif
  a_im=0.
!
!  Doing the Fourier transform
!
  call fourier_transform(a_re,a_im)
!
!  integration over shells
!
  if(lroot .AND. ip<10) print*,'fft done; now integrate over shells...'
  do ikz=1,nz
    do iky=1,ny
      do ikx=1,nx
        k=nint(sqrt(kx(ikx)**2+ky(iky+ipy*ny)**2+kz(ikz+ipz*nz)**2))
        if(k>=0 .and. k<=(nk-1)) then
          spectrum(k+1)=spectrum(k+1) &
             +a_re(ikx,iky,ikz)**2 &
             +a_im(ikx,iky,ikz)**2
        endif
      enddo
    enddo
  enddo
  !
  !  Summing up the results from the different processors
  !  The result is available only on root
  !
  call mpireduce_sum(spectrum,spectrum_sum,nk)
  !
  !  on root processor, write global result to file
  !  multiply by 1/2, so \int E(k) dk = (1/2) <u^2>
  !  ok for helicity, so \int F(k) dk = <o.u> = 1/2 <o*.u+o.u*>
  !
  !  append to diagnostics file
  !
  if (iproc==root) then
    if (ip<10) print*,'Writing power spectrum ',sp &
         ,' to ',trim(datadir)//'/power_'//trim(sp)//'.dat'
    spectrum_sum=.5*spectrum_sum
    open(1,file=trim(datadir)//'/power_'//trim(sp)//'.dat',position='append')
    write(1,*) t
    write(1,'(1p,8e10.2)') spectrum_sum
    close(1)
  endif
  !
  endsubroutine powerscl
!***********************************************************************
  subroutine power_1d(f,sp,ivec,ivar)
!
!  Calculate power spectra of the variable specified by `sp'.
!  Since this routine is only used at the end of a time step,
!  one could in principle reuse the df array for memory purposes.
!
    real, dimension (mx,my,mz,mfarray) :: f
    character (len=1) :: sp
    integer :: ivec
    integer, optional :: ivar
!
    integer, parameter :: nk=nx/2
    integer :: ix,iy,iz,im,in,ikx,iky,ikz
    real, dimension(nx,ny,nz) :: a1,b1,a2
    real, dimension(nx) :: bb
    real, dimension(nk) :: spectrumx=0.,spectrumx_sum=0
    real, dimension(nk) :: spectrumy=0.,spectrumy_sum=0
    real, dimension(nk) :: spectrumz=0.,spectrumz_sum=0
    character (len=7) :: str
!
!  identify version
!
    if (lroot .AND. ip<10) call cvs_id( &
        "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
!
!  In fft, real and imaginary parts are handled separately.
!  Initialize real part a1-a3; and put imaginary part, b1-b3, to zero
!
    if (sp=='u') then
      if (lhydro) then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)
      else
        if (lroot) &
            print*, 'power_1d: must have hydro module for velocity power'
        call fatal_error('power_1d','')
      endif
    elseif (sp=='b') then
      if (lmagnetic) then
        do n=n1,n2; do m=m1,m2
          call curli(f,iaa,bb,ivec)
          im=m-nghost
          in=n-nghost
          a1(:,im,in)=bb
        enddo; enddo
      else
        if (lroot) &
            print*, 'power_1d: must have magnetic module for magnetic power'
        call fatal_error('power_1d','')
      endif
    elseif (sp=='a') then
      if (lmagnetic) then
        a1=f(l1:l2,m1:m2,n1:n2,iax+ivec-1)
      else
        if (lroot) &
            print*, 'power_1d: must have magnetic module for magnetic power'
        call fatal_error('power_1d','')
      endif
    elseif (sp=='p') then
      if (ivar>0) then
        a1=f(l1:l2,m1:m2,n1:n2,ivar)
      else
        if (lroot) &
            print*, 'power_1d: ivar must be >0, ivar=', ivar
        call fatal_error('power_1d','')
      endif
    else
      if (lroot) print*,'There is no such spectra variable: sp=',sp
      call fatal_error('power_1d','')
    endif
    b1=0
    a2=a1
!
! Need to initialize
!
    spectrumx=0
    spectrumx_sum=0
    spectrumy=0
    spectrumy_sum=0
    spectrumz=0
    spectrumz_sum=0
!
!  Do the Fourier transform
!
    call fourier_transform_x(a1,b1)
!
!  Stop the run if FFT=nofft
!
    if (.not.lfft) &
        call stop_it('Need FFT=fft in Makefile.local to get spectra!')
!
!  Spectra in x-direction
!
    do ikx=1,nk; do iy=1,ny; do iz=1,nz
      spectrumx(ikx) = spectrumx(ikx) + &
          sqrt(a1(ikx,iy,iz)**2 + b1(ikx,iy,iz)**2)
    enddo; enddo; enddo
!  Multiply all modes, except the constant mode, by two.
    spectrumx(2:nk)=2*spectrumx(2:nk)
!
!  Doing fourier spectra in all directions if onedall=T
!
    if (onedall) then
!
!  Spectra in y-direction
!
      if (nygrid/=1) then
        a1=a2
        b1=0
        call transp(a1,'y')
        call fourier_transform_x(a1,b1)
        do iky=1,nk; do ix=1,nxgrid/nprocy; do iz=1,nz
          spectrumy(iky) = spectrumy(iky) + &
              sqrt(a1(iky,ix,iz)**2 + b1(iky,ix,iz)**2)
        enddo; enddo; enddo
!  Multiply all modes, except the constant mode, by two.
        spectrumy(2:nk)=2*spectrumy(2:nk)
      endif
!
!  Spectra in z-direction
!
      if (nzgrid/=1) then
        a1=a2
        b1=0
        call transp(a1,'z')
        call fourier_transform_x(a1,b1)
        do ikz=1,nk; do ix=1,nxgrid/nprocz; do iy=1,ny
          spectrumz(ikz) = spectrumz(ikz) + &
              sqrt(a1(ikz,iy,ix)**2 + b1(ikz,iy,ix)**2)
        enddo; enddo; enddo
!  Multiply all modes, except the constant mode, by two.
        spectrumz(2:nk)=2*spectrumz(2:nk)
      endif
    endif
!
!  Summing up the results from the different processors
!  The result is available only on root
!
    call mpireduce_sum(spectrumx,spectrumx_sum,nk)
    if (onedall.and.nygrid/=1) call mpireduce_sum(spectrumy,spectrumy_sum,nk)
    if (onedall.and.nzgrid/=1) call mpireduce_sum(spectrumz,spectrumz_sum,nk)
!
!  on root processor, write global result to file
!  don't need to multiply by 1/2 to get \int E(k) dk = (1/2) <u^2>
!  because we have only taken the data for positive values of kx.
!
    if (ivec==1) then
      str='x_x.dat'
    elseif (ivec==2) then
      str='y_x.dat'
    elseif (ivec==3) then
      str='z_x.dat'
    else
      str='_x.dat'
    endif
!  Append to diagnostics file
    if (iproc==root) then
      if (lroot.and.ip<10) print*, 'Writing power spectra of variable', sp, &
          'to ', trim(datadir)//'/power'//trim(sp)//trim(str)
      open(1,file=trim(datadir)//'/power'//trim(sp)//trim(str), &
          position='append')
      write(1,*) t
      write(1,'(1p,8e10.2)') spectrumx_sum/(nygrid*nzgrid)
      close(1)
    endif
!
!  Save data for y and z spectra if onedall=.true.
!
    if (onedall) then
!
!  Save y data
!
      if (lroot .and. nygrid/=1) then
        if (ivec==1) then
          str='x_y.dat'
        elseif (ivec==2) then
          str='y_y.dat'
        elseif (ivec==3) then
          str='z_y.dat'
        else
          str='_y.dat'
        endif
!  Append to diagnostics file
        if (lroot.and.ip<10) print*, 'Writing power spectra of variable', sp, &
            'to ', trim(datadir)//'/power'//trim(sp)//trim(str)
        open(1,file=trim(datadir)//'/power'//trim(sp)//trim(str), &
            position='append')
        write(1,*) t
        write(1,'(1p,8e10.2)') spectrumy_sum/(nxgrid*nzgrid)
        close(1)
      endif
!
!  Save z data
!
      if (lroot .and. nzgrid/=1) then
        if (ivec==1) then
          str='x_z.dat'
        elseif (ivec==2) then
          str='y_z.dat'
        elseif (ivec==3) then
          str='z_z.dat'
        else
          str='_z.dat'
        endif
!  Append to diagnostics file
        if (lroot.and.ip<10) print*,'Writing power spectra of variable', sp,  &
            'to ', trim(datadir)//'/power'//trim(sp)//trim(str)
        open(1,file=trim(datadir)//'/power'//trim(sp)//trim(str), &
            position='append')
        write(1,*) t
        write(1,'(1p,8e10.2)') spectrumz_sum/(nxgrid*nygrid)
        close(1)
      endif
    endif
!
  endsubroutine power_1d
!***********************************************************************
    subroutine pdf(f,variabl,pdf_mean,pdf_rms)
!
!  Calculated pdf of scalar field.
!  This routine is in this module, because it is always called at the
!  same time when spectra are invoked (called in wsnaps).
!
!    2-dec-03/axel: coded
!
  use Cdata
  use Sub
  use General
  use Mpicomm
!
  integer :: i,l,i_pdf
  integer, parameter :: n_pdf=3001
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension (nx,3) :: gcc
  real, dimension (nx) :: pdf_var,gcc2
  real, dimension(n_pdf) :: pdf_xx
  integer, dimension (n_pdf) :: pdf_yy
  real :: pdf_min,pdf_max,pdf_mean,pdf_rms,pdf_dx,pdf_dx1,pdf_scl
  character (len=120) :: pdf_file=''
  character (len=*) :: variabl
  logical :: logscale=.false.
!
!  initialize counter and set scaling factor
!
   pdf_yy=0.
   pdf_scl=1./pdf_rms
!
!  m-n loop
!
   do n=n1,n2
   do m=m1,m2
!
!  select the right variable
!
     if (variabl=='rhocc') then
       pdf_var=exp(f(l1:l2,m,n,ilnrho))*f(l1:l2,m,n,ilncc)-pdf_mean
       logscale=.false.
     elseif (variabl=='cc') then
       pdf_var=f(l1:l2,m,n,ilncc)-pdf_mean
       logscale=.false.
     elseif (variabl=='lncc') then
       pdf_var=abs(f(l1:l2,m,n,ilncc)-pdf_mean)
       logscale=.true.
     elseif (variabl=='gcc') then
       call grad(f,ilncc,gcc)
       call dot2_mn(gcc,gcc2)
       pdf_var=sqrt(gcc2)
       logscale=.false.
     elseif (variabl=='lngcc') then
       call grad(f,ilncc,gcc)
       call dot2_mn(gcc,gcc2)
       pdf_var=sqrt(gcc2)
       logscale=.true.
     endif
!
!  put in the right pdf slot
!
     if (logscale) then
       !pdf_max=1.5  !(fixed choice, for time being)
       pdf_max=3.0  !(fixed choice, for time being)
       pdf_min=-pdf_max
       pdf_dx=(pdf_max-pdf_min)/n_pdf
       pdf_dx1=1./pdf_dx
       do l=l1,l2
         i_pdf=1+int(pdf_dx1*log10(pdf_scl*pdf_var(l))-pdf_min)
         i_pdf=min(max(i_pdf,1),n_pdf)  !(make sure its inside array boundries)
         pdf_yy(i_pdf)=pdf_yy(i_pdf)+1
       enddo
     else
       pdf_max=30.  !(fixed choice, for time being)
       pdf_min=-pdf_max
       pdf_dx=(pdf_max-pdf_min)/n_pdf
       pdf_dx1=1./pdf_dx
       do l=l1,l2
         i_pdf=1+int(pdf_dx1*(pdf_scl*pdf_var(l)-pdf_min))
         i_pdf=min(max(i_pdf,1),n_pdf)  !(make sure its inside array boundries)
         pdf_yy(i_pdf)=pdf_yy(i_pdf)+1
       enddo
     endif
   enddo
   enddo
!
!  write file
!
   pdf_file=trim(directory)//'/pdf_'//trim(variabl)//'.dat'
   open(1,file=trim(pdf_file),position='append')
   write(1,10) t,n_pdf,pdf_dx,pdf_min,pdf_mean,pdf_rms
   write(1,11) pdf_yy
   close(1)
!
10 format(1p,e11.5,0p,i6,1p,4e12.4)
11 format(8i10)
endsubroutine pdf
!***********************************************************************
    subroutine power_phi(f,sp)
!
! Power spectra in phi direction in spherical coordinates:
! I define power_phi of a variable 'u' in the following way:
! {\hat u}(r,\theta,k) \equiv FFT (u(r,\theta,k))
! power_phi(u) \equiv 
!         \sum_{r,\theta} dr d\theta 
!             {\hat u}(r,\theta,k)*{\hat u}(r,\theta,-k) r^2 sin(\theta)
! ---------------------------------------------------------------------
! As this subroutine is called at the end of a time-step df can be 
! used for storing temporary data. 
! The \phi direction is the z direction. 
! ----------------------------------------------------------------------
  integer, parameter :: nk=nz/2
  integer :: i,j,k,l,ikz,im,in,ivec,ispec,ifirst_fft
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension(nx,ny,nz) :: a1
  real, dimension(nx) :: bb
  real, dimension(nzgrid/2) :: spectrum=0.,spectrum_sum=0
  real, dimension(nzgrid) :: aatemp
  real, dimension(2*nzgrid+15) :: fftpack_temp
  real :: kz,nVol2d,spec_real,spec_imag
  character (len=*) :: sp
  !
  !  identify version
  !
  if (lroot .AND. ip<10) call cvs_id( &
       "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
!--------------Makes sense only in spherical coordinate system -----------
  if(.not.lspherical_coords) call stop_it("power_phi works only in spherical coordinates")
  !
  !  Define wave vector, defined here for the *full* mesh.
  !  Each processor will see only part of it.
  !  Ignore *2*pi/Lx factor, because later we want k to be integers
  !
  !
  spectrum=0
  spectrum_sum=0
  !
  !  In fft, real and imaginary parts are handled separately.
  !  Initialize real part a1-a3; and put imaginary part, b1-b3, to zero
  !  Added power spectra of rho^(1/2)*u and rho^(1/3)*u.
  !
  do ivec=1,3
     !
     if (trim(sp)=='u') then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)
      elseif (trim(sp)=='b') then
        do n=n1,n2
           do m=m1,m2
              call curli(f,iaa,bb,ivec)
              im=m-nghost
              in=n-nghost
              a1(:,im,in)=bb
           enddo
        enddo
     elseif (trim(sp)=='a') then
        a1=f(l1:l2,m1:m2,n1:n2,iax+ivec-1)
     else
        print*,'There are no such sp=',trim(sp)
     endif
!
     ifirst_fft=1
     do l=1,nx
       do m=1,ny
         do j=1,nprocy
           call z2x(a1,l,m,j,aatemp)
! For multiple processor runs aatemp exists only in the root 
! processor. Hence rest of the analysis is done only
! in the root processor
           if (lroot) then 
!             write(*,*)l,m,j,'got data shall fft'
             call fourier_transform_real_1(aatemp,nzgrid,ifirst_fft,fftpack_temp)
             ifirst_fft = ifirst_fft+1
             spectrum(1)=(aatemp(1)**2)&
                    *r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
             do ispec=2,nzgrid/2
               spec_real=aatemp(2*ispec-2)
               spec_imag=aatemp(2*ispec-1)
               spectrum(ispec)= 2.*(spec_real**2+spec_imag**2)&
                    *r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
             enddo
             spectrum(nzgrid/2)=(aatemp(nzgrid)**2)&
                    *r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
             spectrum_sum=spectrum_sum+spectrum
             nVol2d = nVol2d+r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
           else
             nVol2d=1.
           endif
         enddo ! loop over yproc
       enddo   ! loop over ny
     enddo     ! loop over nx
!
   enddo !(from loop over ivec)
!
!  append to diagnostics file
!
  if (iproc==root) then
     if (ip<10) print*,'Writing power spectra of variable',trim(sp) &
          ,'to ',trim(datadir)//'/power_phi'//trim(sp)//'.dat'
     spectrum_sum=.5*spectrum_sum
     open(1,file=trim(datadir)//'/power_phi'//trim(sp)//'.dat',position='append')
     write(1,*) t
     write(1,'(1p,8e10.2)') spectrum_sum/nVol2d
     close(1)
  endif
  !
  endsubroutine power_phi
!***********************************************************************
    subroutine powerhel_phi(f,sp)
!
! Power spectra in phi direction in spherical coordinates:
! I define power_phi of a variable 'u' in the following way:
! {\hat u}(r,\theta,k) \equiv FFT (u(r,\theta,k))
! power_phi(u) \equiv 
!         \sum_{r,\theta} dr d\theta 
!             {\hat u}(r,\theta,k)*{\hat u}(r,\theta,-k) r^2 sin(\theta)
! ---------------------------------------------------------------------
! As this subroutine is called at the end of a time-step df can be 
! used for storing temporary data. 
! The \phi direction is the z direction. 
! ----------------------------------------------------------------------
  integer, parameter :: nk=nz/2
  integer :: i,j,k,l,ikz,im,in,ivec,ifirst_fft,ispec
  real, dimension (mx,my,mz,mfarray) :: f
  real, dimension(nx,ny,nz) :: a1
  real, dimension(nx) :: bb
  real, dimension(nzgrid/2) :: spectrum=0.,spectrum_sum=0
  real, dimension(nzgrid) :: aatemp
  real, dimension(2*nzgrid+15) :: fftpack_temp
  real :: kz,nVol2d,spec_real,spec_imag
  character (len=*) :: sp
  !
  call stop_it("subroutine powerhel_phi not written yet")
  !  identify version
  !
  if (lroot .AND. ip<10) call cvs_id( &
       "$Id: power_spectrum.f90,v 1.63 2008-07-03 16:15:30 dhruba Exp $")
!--------------Makes sense only in spherical coordinate system -----------
  if(.not.lspherical_coords) call stop_it("power_phi works only in spherical coordinates")
  !
  !  Define wave vector, defined here for the *full* mesh.
  !  Each processor will see only part of it.
  !  Ignore *2*pi/Lx factor, because later we want k to be integers
  !
  !
  spectrum=0
  spectrum_sum=0
  !
  !  In fft, real and imaginary parts are handled separately.
  !  Initialize real part a1-a3; and put imaginary part, b1-b3, to zero
  !  Added power spectra of rho^(1/2)*u and rho^(1/3)*u.
  !
  do ivec=1,3
     !
     if (trim(sp)=='u') then
        a1=f(l1:l2,m1:m2,n1:n2,iux+ivec-1)
      elseif (trim(sp)=='b') then
        do n=n1,n2
           do m=m1,m2
              call curli(f,iaa,bb,ivec)
              im=m-nghost
              in=n-nghost
              a1(:,im,in)=bb
           enddo
        enddo
     elseif (trim(sp)=='a') then
        a1=f(l1:l2,m1:m2,n1:n2,iax+ivec-1)
     else
        print*,'There are no such sp=',trim(sp)
     endif
!
     do l=1,nx
       do m=1,ny
         do j=1,nprocy
           call z2x(a1,l,m,j,aatemp)
! For multiple processor runs aatemp exists only in the root 
! processor. Hence rest of the analysis is done only
! in the root processor
           if (lroot) then 
             call fourier_transform_real_1(aatemp,nzgrid,ifirst_fft,fftpack_temp)
             ifirst_fft = ifirst_fft+1
             spectrum(1)=(aatemp(1)**2)&
                    *r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
             do ispec=2,nzgrid/2
               spec_real=aatemp(2*ispec-2)
               spec_imag=aatemp(2*ispec-1)
               spectrum(ispec)= 2.*(spec_real**2+spec_imag**2)&
                    *r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
             enddo
             spectrum(nzgrid/2)=(aatemp(nzgrid)**2)&
                    *r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
             spectrum_sum=spectrum_sum+spectrum
             nVol2d = nVol2d+r2_weight(l)*sinth_weight_across_proc(m+(j-1)*ny)
           else
             nVol2d=1.
           endif
         enddo ! loop over yproc
       enddo   ! loop over ny
     enddo     ! loop over nx
!
   enddo !(from loop over ivec)
!
!  append to diagnostics file
!
  if (iproc==root) then
     if (ip<10) print*,'Writing power spectra of variable',trim(sp) &
          ,'to ',trim(datadir)//'/power_phi'//trim(sp)//'.dat'
     spectrum_sum=.5*spectrum_sum
     open(1,file=trim(datadir)//'/power_phi'//trim(sp)//'.dat',position='append')
     write(1,*) t
     write(1,'(1p,8e10.2)') spectrum_sum/nVol2d
     close(1)
  endif
  !
  endsubroutine powerhel_phi
!***********************************************************************
endmodule power_spectrum
