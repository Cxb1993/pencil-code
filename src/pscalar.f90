! $Id: pscalar.f90,v 1.55 2005-07-05 16:21:43 mee Exp $

!  This modules solves the passive scalar advection equation

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 1
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED cc,cc1,glncc,uglncc,del2lncc,hlncc
!
!***************************************************************

module Pscalar

  use Cparam
  use Cdata
  use Messages

  implicit none

  include 'pscalar.h'

  character (len=labellen) :: initlncc='zero', initlncc2='zero'
  character (len=40) :: tensor_pscalar_file
  logical :: nopscalar=.false.

  ! input parameters
  real :: ampllncc=.1, widthlncc=.5, cc_min=0., lncc_min
  real :: ampllncc2=0.,kx_lncc=1.,ky_lncc=1.,kz_lncc=1.,radius_lncc=0.
  real :: epsilon_lncc=0., cc_const=0., unit_rhocc=0.
  real, dimension(3) :: gradC0=(/0.,0.,0./)

  namelist /pscalar_init_pars/ &
       initlncc,initlncc2,ampllncc,ampllncc2,kx_lncc,ky_lncc,kz_lncc, &
       radius_lncc,epsilon_lncc,widthlncc,cc_min,cc_const

  ! run parameters
  real :: pscalar_diff=0.,tensor_pscalar_diff=0.
  real :: rhoccm=0., cc2m=0., gcc2m=0.
  logical :: lpscalar_turb_diff=.false.

  namelist /pscalar_run_pars/ &
       pscalar_diff,nopscalar,tensor_pscalar_diff,gradC0,lpscalar_turb_diff

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_rhoccm=0,idiag_ccmax=0,idiag_ccmin=0.,idiag_lnccm=0
  integer :: idiag_lnccmz=0,idiag_gcc5m=0,idiag_gcc10m=0
  integer :: idiag_ucm=0,idiag_uudcm=0,idiag_Cz2m=0,idiag_Cz4m=0,idiag_Crmsm=0
  integer :: idiag_cc1m=0,idiag_cc2m=0,idiag_cc3m=0,idiag_cc4m=0,idiag_cc5m=0
  integer :: idiag_cc6m=0,idiag_cc7m=0,idiag_cc8m=0,idiag_cc9m=0,idiag_cc10m=0
  integer :: idiag_gcc1m=0,idiag_gcc2m=0,idiag_gcc3m=0,idiag_gcc4m=0
  integer :: idiag_gcc6m=0,idiag_gcc7m=0,idiag_gcc8m=0,idiag_gcc9m=0

  contains

!***********************************************************************
    subroutine register_pscalar()
!
!  Initialise variables which should know that we solve for passive
!  scalar: ilncc; increase nvar accordingly
!
!  6-jul-02/axel: coded
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_lncc called twice')
      first = .false.
!
      lpscalar = .true.
      ilncc = nvar+1            ! index to access lncc
      nvar = nvar+1             ! added 1 variable
!
      if ((ip<=8) .and. lroot) then
        print*, 'Register_lncc:  nvar = ', nvar
        print*, 'ilncc = ', ilncc
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: pscalar.f90,v 1.55 2005-07-05 16:21:43 mee Exp $")
!
      if (nvar > mvar) then
        if (lroot) write(0,*) 'nvar = ', nvar, ', mvar = ', mvar
        call stop_it('Register_lncc: nvar > mvar')
      endif
!
!  Put variable name in array
!
      varname(ilncc) = 'lncc'
!
!  Writing files for use with IDL
!
      if (lroot) then
        if (maux == 0) then
          if (nvar < mvar) write(4,*) ',lncc $'
          if (nvar == mvar) write(4,*) ',lncc'
        else
          write(4,*) ',lncc $'
        endif
        write(15,*) 'lncc = fltarr(mx,my,mz)*one'
      endif
!
    endsubroutine register_pscalar
!***********************************************************************
    subroutine initialize_pscalar(f)
!
!  Perform any necessary post-parameter read initialization
!  Dummy routine
!
!  24-nov-02/tony: coded
!
      real, dimension (mx,my,mz,mvar+maux) :: f
! 
!  set to zero and then call the same initial condition
!  that was used in start.csh
!   
      if (NO_WARN) print*,'f=',f
    endsubroutine initialize_pscalar
!***********************************************************************
    subroutine init_lncc(f,xx,yy,zz)
!
!  initialise passive scalar field; called from start.f90
!
!   6-jul-2001/axel: coded
!
      use Cdata
      use Mpicomm
      use Density
      use Sub
      use Initcond
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz)      :: xx,yy,zz,prof
!
      select case(initlncc)
        case('zero'); f(:,:,:,ilncc)=0.
        case('constant'); f(:,:,:,ilncc)=log(cc_const)
        case('gaussian-x'); call gaussian(ampllncc,f,ilncc,kx=kx_lncc)
        case('gaussian-y'); call gaussian(ampllncc,f,ilncc,ky=ky_lncc)
        case('gaussian-z'); call gaussian(ampllncc,f,ilncc,kz=kz_lncc)
        case('parabola-x'); call parabola(ampllncc,f,ilncc,kx=kx_lncc)
        case('parabola-y'); call parabola(ampllncc,f,ilncc,ky=ky_lncc)
        case('parabola-z'); call parabola(ampllncc,f,ilncc,kz=kz_lncc)
        case('gaussian-noise'); call gaunoise(ampllncc,f,ilncc,ilncc)
        case('wave-x'); call wave(ampllncc,f,ilncc,kx=kx_lncc)
        case('wave-y'); call wave(ampllncc,f,ilncc,ky=ky_lncc)
        case('wave-z'); call wave(ampllncc,f,ilncc,kz=kz_lncc)
        case('propto-ux'); call wave_uu(ampllncc,f,ilncc,kx=kx_lncc)
        case('propto-uy'); call wave_uu(ampllncc,f,ilncc,ky=ky_lncc)
        case('propto-uz'); call wave_uu(ampllncc,f,ilncc,kz=kz_lncc)
        case('tang-discont-z')
           print*,'init_lncc: widthlncc=',widthlncc
        prof=.5*(1.+tanh(zz/widthlncc))
        f(:,:,:,ilncc)=-1.+2.*prof
        case('hor-tube'); call htube2(ampllncc,f,ilncc,ilncc,xx,yy,zz,radius_lncc,epsilon_lncc)
        case default; call stop_it('init_lncc: bad initlncc='//trim(initlncc))
      endselect
!
!  superimpose something else
!
      select case(initlncc2)
        case('wave-x'); call wave(ampllncc2,f,ilncc,ky=5.)
      endselect
!
!  add floor value if cc_min is set
!
      if (cc_min/=0.) then
        lncc_min=log(cc_min)
        if (lroot) print*,'set floor value for cc; cc_min=',cc_min
        f(:,:,:,ilncc)=max(lncc_min,f(:,:,:,ilncc))
      endif
!
      if (NO_WARN) print*,xx,yy,zz !(prevent compiler warnings)
    endsubroutine init_lncc
!***********************************************************************
    subroutine pencil_criteria_pscalar()
! 
!  All pencils that the Pscalar module depends on are specified here.
! 
!  20-11-04/anders: coded
!
      integer :: i
!
      if (lhydro) lpenc_requested(i_uglncc)=.true.
      if (pscalar_diff/=0.) then
        lpenc_requested(i_glncc)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
      do i=1,3
        if (gradC0(i)/=0.) lpenc_requested(i_uu)=.true.
      enddo
      if (tensor_pscalar_diff/=0.) lpenc_requested(i_hlncc)=.true.
!
      if (idiag_rhoccm/=0 .or. idiag_ccmax/=0 .or. idiag_ccmin/=0 .or. &
          idiag_ucm/=0 .or. idiag_uudcm/=0 .or. idiag_Cz2m/=0 .or. &
          idiag_Cz4m/=0 .or. idiag_Crmsm/=0) lpenc_diagnos(i_cc)=.true.
      if (idiag_rhoccm/=0 .or. idiag_Cz2m/=0 .or. idiag_Cz4m/=0 .or. &
          idiag_Crmsm/=0) lpenc_diagnos(i_rho)=.true.
      if (idiag_lnccmz/=0) lpenc_diagnos(i_lncc)=.true.
      if (idiag_ucm/=0 .or. idiag_uudcm/=0) lpenc_diagnos(i_uu)=.true.
      if (idiag_uudcm/=0) lpenc_diagnos(i_uglncc)=.true.
!
    endsubroutine pencil_criteria_pscalar
!***********************************************************************
    subroutine pencil_interdep_pscalar(lpencil_in)
!
!  Interdependency among pencils provided by the Pscalar module
!  is specified here.
!
!  20-11-04/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_cc1)) lpencil_in(i_cc)=.true.
      if (lpencil_in(i_uglncc)) then
        lpencil_in(i_uu)=.true.
        lpencil_in(i_glncc)=.true.
      endif
      if (tensor_pscalar_diff/=0.) lpencil_in(i_glncc)=.true.
!
    endsubroutine pencil_interdep_pscalar
!***********************************************************************
    subroutine calc_pencils_pscalar(f,p)
!
!  Calculate Pscalar pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  20-11-04/anders: coded
!
      use Cdata
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p
!      
      intent(in) :: f
      intent(inout) :: p
! cc
      if (lpencil(i_cc)) p%cc=exp(f(l1:l2,m,n,icc))
! cc1
      if (lpencil(i_cc1)) p%cc1=1/p%cc
! glncc
      if (lpencil(i_glncc)) call grad(f,ilncc,p%glncc)
! uglncc
      if (lpencil(i_uglncc)) call dot_mn(p%uu,p%glncc,p%uglncc)
! del2lncc
      if (lpencil(i_del2lncc)) call del2(f,ilncc,p%del2lncc)
! hlncc        
      if (lpencil(i_hlncc)) call g2ij(f,ilncc,p%hlncc)
!
    endsubroutine calc_pencils_pscalar
!***********************************************************************
    subroutine dlncc_dt(f,df,p)
!
!  passive scalar evolution
!  calculate dc/dt=-uu.glncc + pscaler_diff*[del2lncc + (glncc+glnrho).glncc]
!
!   6-jul-02/axel: coded
!
      use Sub
      use Hydro, only: nu_turb
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!      
      real, dimension (nx) :: diff_op
      integer :: j
!
      intent(in)  :: f
      intent(out) :: df
!
!  identify module and boundary conditions
!
      if (nopscalar) then
        if (headtt.or.ldebug) print*,'not SOLVED: dlncc_dt'
      else
        if (headtt.or.ldebug) print*,'SOLVE dlncc_dt'
      endif
      if (headtt) call identify_bcs('cc',ilncc)
!
!  gradient of passive scalar
!  allow for possibility to turn off passive scalar
!  without changing file size and recompiling everything.
!
      if (.not. nopscalar) then ! i.e. if (pscalar)
!
!  passive scalar equation
!
        if (lhydro) df(l1:l2,m,n,ilncc) = df(l1:l2,m,n,ilncc) - p%uglncc
!
!  diffusion operator
!
        if (lpscalar_turb_diff) pscalar_diff=nu_turb
        if (pscalar_diff/=0.) then
          if (headtt) print*,'dlncc_dt: pscalar_diff=',pscalar_diff
          call dot_mn(p%glncc+p%glnrho,glncc,diff_op)
          diff_op=diff_op+p%del2lncc
          df(l1:l2,m,n,ilncc) = df(l1:l2,m,n,ilncc) + pscalar_diff*diff_op
        endif
!
!  add advection of imposed constant gradient of lncc (called gradC0)
!  makes sense really only for periodic boundary conditions
!  This gradient can have arbitary direction.
!
        do j=1,3
          if (gradC0(j)/=0.) then
            df(l1:l2,m,n,ilncc) = df(l1:l2,m,n,ilncc) - gradC0(j)*p%uu(:,j)
          endif
        enddo
!
!  tensor diffusion (but keep the isotropic one)
!
        if (tensor_pscalar_diff/=0.) &
            call tensor_diff(f,df,p,tensor_pscalar_diff)
!
      endif
!
!  diagnostics
!
!  output for double and triple correlators (assume z-gradient of cc)
!  <u_k u_j d_j c> = <u_k c uu.gradlncc>
!
      if (ldiagnos) then
        if (idiag_rhoccm/=0) call sum_mn_name(p%rho*p%cc,idiag_rhoccm)
        if (idiag_ccmax/=0) call max_mn_name(p%cc,idiag_ccmax)
        if (idiag_ccmin/=0) call max_mn_name(-p%cc,idiag_ccmin,lneg=.true.)
        if (idiag_lnccmz/=0) call xysum_mn_name_z(p%lncc,idiag_lnccmz)
        if (idiag_ucm/=0) call sum_mn_name(p%uu(:,3)*p%cc,idiag_ucm)
        if (idiag_uudcm/=0) &
            call sum_mn_name(p%uu(:,3)*p%cc*p%uglncc,idiag_uudcm)
        if (idiag_Cz2m/=0) call sum_mn_name(p%rho*p%cc*z(n)**2,idiag_Cz2m)
        if (idiag_Cz4m/=0) call sum_mn_name(p%rho*p%cc*z(n)**4,idiag_Cz4m)
        if (idiag_Crmsm/=0) &
            call sum_mn_name((p%rho*p%cc)**2,idiag_Crmsm,lsqrt=.true.)
      endif
!
    endsubroutine dlncc_dt
!***********************************************************************
    subroutine read_pscalar_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat)) then
        read(unit,NML=pscalar_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=pscalar_init_pars,ERR=99)
      endif
                                                                                                   
                                                                                                   
99    return
    endsubroutine read_pscalar_init_pars
!***********************************************************************
    subroutine write_pscalar_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      write(unit,NML=pscalar_init_pars)
                                                                                                   
    endsubroutine write_pscalar_init_pars
!***********************************************************************
    subroutine read_pscalar_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat)) then
        read(unit,NML=pscalar_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=pscalar_run_pars,ERR=99)
      endif
                                                                                                   
                                                                                                   
99    return
    endsubroutine read_pscalar_run_pars
!***********************************************************************
    subroutine write_pscalar_run_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      write(unit,NML=pscalar_run_pars)
                                                                                                   
    endsubroutine write_pscalar_run_pars
!***********************************************************************
    subroutine rprint_pscalar(lreset,lwrite)
!
!  reads and registers print parameters relevant for magnetic fields
!
!   6-jul-02/axel: coded
!
      use Sub
!
      integer :: iname,inamez
      logical :: lreset,lwr
      logical, optional :: lwrite
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_rhoccm=0; idiag_ccmax=0; idiag_ccmin=0.; idiag_lnccm=0
        idiag_lnccmz=0; idiag_ucm=0; idiag_uudcm=0; idiag_Cz2m=0; idiag_Cz4m=0
        idiag_Crmsm=0
      endif
!
!  check for those quantities that we want to evaluate online
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'rhoccm',idiag_rhoccm)
        call parse_name(iname,cname(iname),cform(iname),'ccmax',idiag_ccmax)
        call parse_name(iname,cname(iname),cform(iname),'ccmin',idiag_ccmin)
        call parse_name(iname,cname(iname),cform(iname),'lnccm',idiag_lnccm)
        call parse_name(iname,cname(iname),cform(iname),'ucm',idiag_ucm)
        call parse_name(iname,cname(iname),cform(iname),'uudcm',idiag_uudcm)
        call parse_name(iname,cname(iname),cform(iname),'Cz2m',idiag_Cz2m)
        call parse_name(iname,cname(iname),cform(iname),'Cz4m',idiag_Cz4m)
        call parse_name(iname,cname(iname),cform(iname),'Crmsm',idiag_Crmsm)
      enddo
!
!  check for those quantities for which we want xy-averages
!
      do inamez=1,nnamez
        call parse_name(inamez,cnamez(inamez),cformz(inamez),&
            'lnccmz',idiag_lnccmz)
      enddo
!
!  write column where which magnetic variable is stored
!
      if (lwr) then
        write(3,*) 'i_rhoccm=',idiag_rhoccm
        write(3,*) 'i_ccmax=',idiag_ccmax
        write(3,*) 'i_ccmin=',idiag_ccmin
        write(3,*) 'i_lnccm=',idiag_lnccm
        write(3,*) 'i_ucm=',idiag_ucm
        write(3,*) 'i_uudcm=',idiag_uudcm
        write(3,*) 'i_lnccmz=',idiag_lnccmz
        write(3,*) 'i_Cz2m=',idiag_Cz2m
        write(3,*) 'i_Cz4m=',idiag_Cz4m
        write(3,*) 'i_Crmsm=',idiag_Crmsm
        write(3,*) 'ilncc=',ilncc
      endif
!
    endsubroutine rprint_pscalar
!***********************************************************************
    subroutine calc_mpscalar
!
!  calculate mean magnetic field from xy- or z-averages
!
!  14-apr-03/axel: adaped from calc_mfield
!
      use Cdata
      use Sub
!
      logical,save :: first=.true.
      real :: lnccm
!
!  Magnetic energy in horizontally averaged field
!  The bxmz and bymz must have been calculated,
!  so they are present on the root processor.
!
      if (idiag_lnccm/=0) then
        if (idiag_lnccmz==0) then
          if (first) print*
          if (first) print*,"NOTE: to get lnccm, lnccmz must also be set in xyaver"
          if (first) print*,"      We proceed, but you'll get lnccm=0"
          lnccm=0.
        else
          lnccm=sqrt(sum(fnamez(:,:,idiag_lnccmz)**2)/(nz*nprocz))
        endif
        call save_name(lnccm,idiag_lnccm)
      endif
!
    endsubroutine calc_mpscalar
!***********************************************************************
    subroutine tensor_diff(f,df,p,tensor_pscalar_diff)
!
!  reads file
!
!  11-jul-02/axel: coded
!
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
      real :: tensor_pscalar_diff
!      
      real, save, dimension (nx,ny,nz,3) :: bunit,hhh
      real, dimension (nx) :: tmp,scr
      integer :: iy,iz,i,j
      logical, save :: first=.true.
!
!  read H and Bunit arrays and keep them in memory
!
      if (first) then
        open(1,file=trim(directory)//'/bunit.dat',form='unformatted')
        print*,'read bunit.dat with dimension: ',nx,ny,nz,3
        read(1) bunit,hhh
        close(1)
        print*,'read bunit.dat; bunit(1,1,1,1)=',bunit(1,1,1,1)
      endif
!
!  tmp = (Bunit.G)^2 + H.G + Bi*Bj*Gij
!  for details, see tex/mhd/thcond/tensor_der.tex
!
      call dot_mn(bunit,p%glncc,scr)
      call dot_mn(hhh,p%glncc,tmp)
      tmp=tmp+scr**2
!
!  dot with bi*bj
!
      iy=m-m1+1
      iz=n-n1+1
      do j=1,3
      do i=1,3
        tmp=tmp+bunit(:,iy,iz,i)*bunit(:,iy,iz,j)*p%hlncc(:,i,j)
      enddo
      enddo
!
!  and add result to the dlncc/dt equation
!
      df(l1:l2,m,n,ilncc)=df(l1:l2,m,n,ilncc)+tensor_pscalar_diff*tmp
!
      first=.false.
    endsubroutine tensor_diff
!***********************************************************************

endmodule Pscalar



