! $Id: noentropy.f90,v 1.74 2005-08-22 17:55:42 wlyra Exp $

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lentropy = .false.
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
! PENCILS PROVIDED cs2,pp,TT1,Ma2
!
!***************************************************************

module Entropy

  !
  ! isothermal case; almost nothing to do
  !

  use Cparam
  use Cdata
  use Messages

  implicit none

  include 'entropy.h'

  !namelist /entropy_init_pars/ dummyss
  !namelist /entropy_run_pars/  dummyss

  ! run parameters
  real :: hcond0=0.,hcond1=impossible,chi=impossible
  real :: Fbot=impossible,FbotKbot=impossible,Kbot=impossible
  real :: Ftop=impossible,FtopKtop=impossible
  logical :: lmultilayer=.true.
  logical :: lheatc_chiconst=.false.

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_dtc=0,idiag_ssm=0,idiag_ugradpm=0

  contains

!***********************************************************************
    subroutine register_entropy()
!
!  no energy equation is being solved; use isothermal equation of state
!  28-mar-02/axel: dummy routine, adapted from entropy.f of 6-nov-01.
!
      use Cdata
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call fatal_error('register_entropy','module registration called twice')
      first = .false.
!
!ajwm      lentropy = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: noentropy.f90,v 1.74 2005-08-22 17:55:42 wlyra Exp $")
!
    endsubroutine register_entropy
!***********************************************************************
    subroutine initialize_entropy(f,lstarting)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  24-nov-02/tony: coded 
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      logical :: lstarting
!
      if (ip == 0) print*,f,lstarting ! keep compiler quiet
!
    endsubroutine initialize_entropy
!***********************************************************************
    subroutine init_ss(f,xx,yy,zz)
!
!  initialise entropy; called from start.f90
!  28-mar-02/axel: dummy routine, adapted from entropy.f of 6-nov-01.
!  24-nov-02/tony: renamed for consistancy (i.e. init_[varaible name])
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
!
      if(ip==1) print*,f,xx,yy,zz  !(to remove compiler warnings)
!
    endsubroutine init_ss
!***********************************************************************
    subroutine pencil_criteria_entropy()
! 
!  All pencils that the Entropy module depends on are specified here.
! 
!  20-11-04/anders: coded
!
      use Cdata
!
      if (ldt) lpenc_requested(i_cs2)=.true.
      if (lhydro) then
        lpenc_requested(i_cs2)=.true.
        lpenc_requested(i_glnrho)=.true.
      endif
!
      if (idiag_ugradpm/=0) then
        lpenc_diagnos(i_rho)=.true.
        lpenc_diagnos(i_uglnrho)=.true.
      endif
!
    endsubroutine pencil_criteria_entropy
!***********************************************************************
    subroutine pencil_interdep_entropy(lpencil_in)
!       
!  Interdependency among pencils from the Entropy module is specified here.
!
!  20-11-04/anders: coded
!
      use EquationOfState, only: gamma1
!
      logical, dimension(npencils) :: lpencil_in
!
      if (lpencil_in(i_Ma2)) then
        lpencil_in(i_u2)=.true.
        lpencil_in(i_cs2)=.true.
      endif
      if (lpencil_in(i_TT1) .and. gamma1/=0.) lpencil_in(i_cs2)=.true.
      if (lpencil_in(i_cs2) .and. gamma1/=0.) lpencil_in(i_lnrho)=.true.
!
    endsubroutine pencil_interdep_entropy
!***********************************************************************
    subroutine calc_pencils_entropy(f,p)
!       
!  Calculate Entropy pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  20-11-04/anders: coded
!
      use Cdata
      use EquationOfState, only: gamma,gamma1,cs20,lnrho0,&
           llocal_iso,local_isothermal
 !
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (nx) :: corr
      type (pencil_case) :: p
!
      intent(in) :: f
      intent(inout) :: p
! cs2
      if (lpencil(i_cs2)) then
        if (gamma==1.) then
           p%cs2=cs20 
        else
!
           if (llocal_iso) then
              call local_isothermal(cs20,corr)
              p%cs2 = cs20 * corr
           else   
              p%cs2=cs20*exp(gamma1*(p%lnrho-lnrho0))
           endif
!
        endif
     endif
! Ma2
      if (lpencil(i_Ma2)) p%Ma2=p%u2/p%cs2
! pp
      if (lpencil(i_pp)) p%pp=1/gamma*p%cs2*p%rho
! TT1
      if (lpencil(i_TT1)) then
        if (gamma==1. .or. cs20==0) then
          p%TT1=0.
        else
          p%TT1=gamma1/p%cs2
        endif
      endif
!
    endsubroutine calc_pencils_entropy
!**********************************************************************
    subroutine dss_dt(f,df,p) 
!
!  Isothermal/polytropic equation of state
!
      use Sub
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!      
      integer :: j,ju
!
      intent(in) :: f,p
      intent(out) :: df
!
!  ``cs2/dx^2'' for timestep
!
      if (lfirst.and.ldt) advec_cs2=p%cs2*dxyz_2
      if (headtt.or.ldebug) print*,'dss_dt: max(advec_cs2) =',maxval(advec_cs2)
!
!  subtract isothermal/polytropic pressure gradient term in momentum equation
!
      if (lhydro) then
        do j=1,3
          ju=j+iuu-1
          df(l1:l2,m,n,ju)=df(l1:l2,m,n,ju)-p%cs2*p%glnrho(:,j)
        enddo
      endif
!
!  Calculate entropy related diagnostics
!
      if (ldiagnos) then
        if (idiag_dtc/=0) &
            call max_mn_name(sqrt(advec_cs2)/cdt,idiag_dtc,l_dt=.true.)
        if (idiag_ugradpm/=0) &
            call sum_mn_name(p%rho*p%cs2*p%uglnrho,idiag_ugradpm)
      endif
!
      if (NO_WARN) print*,f !(keep compiler quiet)
!
    endsubroutine dss_dt
!***********************************************************************
    subroutine read_entropy_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_entropy_init_pars
!***********************************************************************
    subroutine write_entropy_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine write_entropy_init_pars
!***********************************************************************
    subroutine read_entropy_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_entropy_run_pars
!***********************************************************************
    subroutine write_entropy_run_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
    endsubroutine write_entropy_run_pars
!***********************************************************************
    subroutine rprint_entropy(lreset,lwrite)
!
!  reads and registers print parameters relevant to entropy
!
!   1-jun-02/axel: adapted from magnetic fields
!
      use Cdata
      use Sub
!
      integer :: iname
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
        idiag_dtc=0; idiag_ssm=0; idiag_ugradpm=0
      endif
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtc',idiag_dtc)
        call parse_name(iname,cname(iname),cform(iname),'ugradpm',idiag_ugradpm)
      enddo
!
!  write column where which magnetic variable is stored
!
      if (lwr) then
        write(3,*) 'i_dtc=',idiag_dtc
        write(3,*) 'i_ssm=',idiag_ssm
        write(3,*) 'i_ugradpm=',idiag_ugradpm
        write(3,*) 'nname=',nname
        write(3,*) 'iss=',iss
      endif
!
    endsubroutine rprint_entropy
!***********************************************************************
    subroutine heatcond(x,y,z,hcond)
!
!  calculate the heat conductivity lambda
!  NB: if you modify this profile, you *must* adapt gradloghcond below.
!
!  23-jan-02/wolf: coded
!  28-mar-02/axel: dummy routine, adapted from entropy.f of 6-nov-01.
!
      use Cdata, only: ip
!
      real, dimension (nx) :: x,y,z
      real, dimension (nx) :: hcond
      if(ip==1) print*,x,y,z,hcond  !(to remove compiler warnings)
!
    endsubroutine heatcond
!***********************************************************************
    subroutine gradloghcond(x,y,z,glhc)
!
!  calculate grad(log lambda), where lambda is the heat conductivity
!  NB: *Must* be in sync with heatcond() above.
!
!  23-jan-02/wolf: coded
!  28-mar-02/axel: dummy routine, adapted from entropy.f of 6-nov-01.
!
      use Cdata, only: ip
!
      real, dimension (nx) :: x,y,z
      real, dimension (nx,3) :: glhc
      if(ip==1) print*,x,y,z,glhc  !(to remove compiler warnings)
!
    endsubroutine gradloghcond
!***********************************************************************
endmodule Entropy
