! $Id: eos_ionization.f90,v 1.6 2005-07-05 16:21:42 mee Exp $

!  This modules contains the routines for simulation with
!  simple hydrogen ionization.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 2
!
!***************************************************************

module EquationOfState

  use Cparam
  use Cdata
  use Messages

  implicit none

  include 'eos.h'

! integers specifying which independent variables to use in eoscalc
  integer, parameter :: ilnrho_ss=1,ilnrho_ee=2,ilnrho_pp=3,ilnrho_lnTT=4

  interface eoscalc              ! Overload subroutine eoscalc
    module procedure eoscalc_farray
    module procedure eoscalc_pencil
    module procedure eoscalc_point
  endinterface

  interface pressure_gradient    ! Overload subroutine pressure_gradient
    module procedure pressure_gradient_farray
    module procedure pressure_gradient_point
  endinterface

  
  !  secondary parameters calculated in initialize
  real :: TT_ion,lnTT_ion,TT_ion_,lnTT_ion_
  real :: ss_ion,ee_ion,kappa0,lnchi0,xHe_term,ss_ion1,Srad0
  real :: lnrho_H,lnrho_e,lnrho_e_,lnrho_p,lnrho_He
  integer :: l

  ! namelist parameters
  !real, parameter :: yHmin=tiny(TT_ion), yHmax=1-epsilon(TT_ion)
  real, parameter :: yHmin=epsilon(TT_ion), yHmax=1-epsilon(TT_ion)
  real :: xHe=0.1
  real :: yMetals=0
  real :: yHacc=1e-5

  ! input parameters
  namelist /eos_init_pars/ xHe,yMetals,yHacc

  ! run parameters
  namelist /eos_run_pars/ xHe,yMetals,yHacc


!ajwm  Moved here from Density.f90
!ajwm  Completely irrelevant to eos_ionization but density and entropy need
!ajwm  reworking to be independent of these things first
!ajwm  can't use impossible else it breaks reading param.nml 
!ajwm  SHOULDN'T BE HERE... But can wait till fully unwrapped 
  real :: cs0=impossible, rho0=impossible, cp=impossible
  real :: cs20=impossible, lnrho0=impossible
  logical :: lcalc_cp = .false.
  real :: gamma=impossible, gamma1=impossible
  real :: cs2bot=impossible, cs2top=impossible
!ajwm  Not sure this should exist either...
  real :: lnTT0
  real :: cs2cool=0.
  real :: mpoly=1.5, mpoly0=1.5, mpoly1=1.5, mpoly2=1.5
  integer :: isothtop=0
  real, dimension (3) :: beta_glnrho_global=0.0,beta_glnrho_scaled=0.0

  contains

!***********************************************************************
    subroutine register_eos()
!
!   2-feb-03/axel: adapted from Interstellar module
!   13-jun-03/tobi: re-adapted from visc_shock module
!
      use Cdata
      use Mpicomm, only: stop_it
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_eos: called twice')
      first = .false.
!
      leos=.true.
      leos_ionization=.true.
!
!  set indices for auxiliary variables
!
      iyH = mvar + naux +1; naux = naux + 1 
      ilnTT = mvar + naux +1; naux = naux + 1 

      if ((ip<=8) .and. lroot) then
        print*, 'register_eos: ionization nvar = ', nvar
        print*, 'register_eos: iyH = ', iyH
        print*, 'register_eos: ilnTT = ', ilnTT
      endif
!
!  Put variable names in array
!
      varname(iyH)   = 'yH'
      varname(ilnTT) = 'lnTT'
!
!  identify version number (generated automatically by CVS)
!
      if (lroot) call cvs_id( &
           "$Id: eos_ionization.f90,v 1.6 2005-07-05 16:21:42 mee Exp $")
!
!  Check we aren't registering too many auxiliary variables
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
        call stop_it('register_eos: naux > maux')
      endif
!
!  Writing files for use with IDL
!
      aux_var(aux_count)=',yh $'
      aux_count=aux_count+1
      if (naux < maux)  aux_var(aux_count)=',lnTT $'
      if (naux == maux) aux_var(aux_count)=',lnTT'
      aux_count=aux_count+1
      if (lroot) then
        write(15,*) 'yH = fltarr(mx,my,mz)*one'
        write(15,*) 'lnTT = fltarr(mx,my,mz)*one'
      endif
!
    endsubroutine register_eos
!***********************************************************************
    subroutine initialize_eos()
!
!  Perform any post-parameter-read initialization, e.g. set derived 
!  parameters.
!
!   2-feb-03/axel: adapted from Interstellar module
!
      use Cdata
      use General
      use Mpicomm, only: stop_it
!
      real :: mu1yHxHe
!
      if (lroot) print*,'initialize_eos: ENTER'
!
!  ionization parameters
!  since m_e and chiH, as well as hbar are all very small
!  it is better to divide m_e and chiH separately by hbar.
!
      mu1yHxHe=1+3.97153*xHe
      TT_ion=chiH/k_B
      lnTT_ion=log(TT_ion)
      TT_ion_=chiH_/k_B
      lnTT_ion_=log(chiH_/k_B)
      lnrho_e=1.5*log((m_e/hbar)*(chiH/hbar)/2./pi)+log(m_H)+log(mu1yHxHe)
      lnrho_H=1.5*log((m_H/hbar)*(chiH/hbar)/2./pi)+log(m_H)+log(mu1yHxHe)
      lnrho_p=1.5*log((m_p/hbar)*(chiH/hbar)/2./pi)+log(m_H)+log(mu1yHxHe)
      lnrho_He=1.5*log((m_He/hbar)*(chiH/hbar)/2./pi)+log(m_H)+log(mu1yHxHe)
      lnrho_e_=1.5*log((m_e/hbar)*(chiH_/hbar)/2./pi)+log(m_H)+log(mu1yHxHe)
      ss_ion=k_B/m_H/mu1yHxHe
      ss_ion1=1/ss_ion
      ee_ion=ss_ion*TT_ion
      kappa0=sigmaH_/m_H/mu1yHxHe
      lnchi0=log(kappa0)-log(4.0)
      Srad0=sigmaSB*TT_ion**4/pi
!
      if (xHe>0) then
        xHe_term=xHe*(log(xHe)-lnrho_He)
      elseif (xHe<0) then
        call stop_it('initialize_eos: xHe lower than zero makes no sense')
      else
        xHe_term=0
      endif
!
      if(lroot.and.ip<14) then
        print*,'initialize_eos: reference values for ionization'
        print*,'initialize_eos: yHmin,yHmax,yMetals=',yHmin,yHmax,yMetals
        print*,'initialize_eos: TT_ion,ss_ion,kappa0=', &
                TT_ion,ss_ion,kappa0
        print*,'initialize_eos: lnrho_e,lnrho_H,lnrho_p,lnrho_He,lnrho_e_=', &
                lnrho_e,lnrho_H,lnrho_p,lnrho_He,lnrho_e_
      endif
!
!  write scale non-free constants to file; to be read by idl
!
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro')
        write (1,*) 'TT_ion=',TT_ion
        write (1,*) 'lnTT_ion=',lnTT_ion
        write (1,*) 'TT_ion_=',TT_ion_
        write (1,*) 'lnTT_ion_=',lnTT_ion_
        write (1,*) 'lnrho_e=',lnrho_e
        write (1,*) 'lnrho_H=',lnrho_H
        write (1,*) 'lnrho_p=',lnrho_p
        write (1,*) 'lnrho_He=',lnrho_He
        write (1,*) 'lnrho_e_=',lnrho_e_
        write (1,*) 'ss_ion=',ss_ion
        write (1,*) 'ee_ion=',ee_ion
        write (1,*) 'kappa0=',kappa0
        write (1,*) 'lnchi0=',lnchi0
        write (1,*) 'Srad0=',Srad0
        write (1,*) 'k_B=',k_B
        write (1,*) 'm_H=',m_H
        close (1)
      endif
!
    endsubroutine initialize_eos
!*******************************************************************
    subroutine rprint_eos(lreset,lwrite)
!
!  Writes iyH and ilnTT to index.pro file
!
!  14-jun-03/axel: adapted from rprint_radiation
!  21-11-04/anders: moved diagnostics to entropy
!
      use Cdata
! 
      logical :: lreset
      logical, optional :: lwrite
!   
      if(NO_WARN) print*,lreset  !(to keep compiler quiet)
!        
    endsubroutine rprint_eos
!*******************************************************************
    subroutine getmu(mu)
!
!  Calculate average particle mass in the gas relative to
!  Note that the particles density is N = nHI + nHII + ne + nHe
!  = (1-y)*nH + y*nH + y*nH + xHe*nH = (1 + yH + xHe) * nH, where
!  nH is the number of protons per cubic centimeter.
!  The number of particles per mole is therefore 1 + yH + xHe.
!  The mass per mole is M=1.+3.97153*xHe, so the mean molecular weight
!  per particle is M/N = (1.+3.97153*xHe)/(1 + yH + xHe).
!
!   12-aug-03/tony: implemented
!
      real, intent(out) :: mu
!
      mu=1.+3.97153*xHe  
!
! tobi: the real mean molecular weight would be:
!
! mu=(1.+3.97153*xHe)/(1+yH+xHe)
!
    endsubroutine getmu
!***********************************************************************
    subroutine ioninit(f)
!
!  the ionization fraction has to be set to a value yH0 < yH < yHmax before
!  rtsafe is called for the first time
!
!  12-jul-03/tobi: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux), intent(inout) :: f
      real, dimension (mx) :: lnrho,ss,yH,lnTT
!
      f(:,:,:,iyH) = 0.5*(yHmax-yHmin)
      call ioncalc(f)
!
    endsubroutine ioninit
!***********************************************************************
    subroutine ioncalc(f)
!
!   calculate degree of ionization and temperature
!   This routine is called from equ.f90 and operates on the full 3-D array.
!
!   13-jun-03/tobi: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx) :: lnrho,ss,yH,lnTT
!
      do n=1,mz
      do m=1,my
        if (ldensity_nolog) then
          lnrho=log(f(:,m,n,ilnrho))
        else
          lnrho=f(:,m,n,ilnrho)
        endif
        ss=f(:,m,n,iss)
        yH=f(:,m,n,iyH)
        call rtsafe_pencil(lnrho,ss,yH)
        f(:,m,n,iyH)=yH
        lnTT=(ss/ss_ion+(1-yH)*(log(1-yH)-lnrho_H) &
              +yH*(2*log(yH)-lnrho_e-lnrho_p)+xHe_term)/(1+yH+xHe)
        lnTT=(2.0/3.0)*(lnTT+lnrho-2.5)+lnTT_ion
        f(:,m,n,ilnTT)=lnTT
      enddo
      enddo
!
    endsubroutine ioncalc
!***********************************************************************
    subroutine perturb_energy(lnrho,ee,ss,lnTT,yH)
!
!  DOCUMENT ME!
!
      real, dimension(nx) ,intent(in) :: lnrho,ee
      real, dimension(nx) ,intent(out) :: ss,lnTT,yH
      real, dimension(nx) :: TT
      real :: temp

      temp=0.5*min(ee(1)/ee_ion,1.0)

      do l=1,nx 
        temp=min(temp,(1-2*epsilon(yHacc))*ee(l)/ee_ion)
        call rtsafe(ilnrho_ee,lnrho(l),ee(l),yHmin,yHmax*min(ee(l)/ee_ion,1.0),temp)
        yH(l)=temp
      enddo

      TT=(ee-yH*ee_ion)/(1.5*(1.+yH+xHe)*ss_ion)
      lnTT=log(TT)
      ss=ss_ion*((1.+yH+xHe)*(1.5*log(TT/TT_ion)-lnrho+2.5) &
                 -yH*(2*log(yH)-lnrho_e-lnrho_p) &
                 -(1.-yH)*(log(1.-yH)-lnrho_H)-xHe_term)

    end subroutine perturb_energy
!***********************************************************************
    subroutine getdensity(EE,TT,yH,rho)
!
!  DOCUMENT ME!
!
      real, intent(in) :: EE,TT,yH
      real, intent(out) :: rho

      rho=EE/(1.5*(1.+yH+xHe)*ss_ion*TT+yH*ee_ion)

    end subroutine getdensity
!***********************************************************************
    subroutine pressure_gradient_farray(f,cs2,cp1tilde)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      use Cdata
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx), intent(out) :: cs2,cp1tilde
      real, dimension(nx) :: lnrho,yH,lnTT
      real, dimension(nx) :: R,dlnTTdy,dRdy,temp
      real, dimension(nx) :: dlnPPdlnrho,fractions,fractions1
      real, dimension(nx) :: dlnPPdss,TT1
!
      lnrho=f(l1:l2,m,n,ilnrho)
      yH=f(l1:l2,m,n,iyH)
      lnTT=f(l1:l2,m,n,ilnTT)
      TT1=exp(-lnTT)
      fractions=(1+yH+xHe)
      fractions1=1/fractions
!
      R=lnrho_e-lnrho+1.5*(lnTT-lnTT_ion)-TT_ion*TT1+log(1-yH)-2*log(yH)
      dlnTTdy=(2*(lnrho_H-lnrho_p-R-TT_ion*TT1)-3)/3*fractions1
      dRdy=dlnTTdy*(1.5+TT_ion*TT1)-1/(1-yH)-2/yH
      temp=(dlnTTdy+fractions1)/dRdy
      dlnPPdlnrho=(5-2*TT_ion*TT1*temp)/3
      dlnPPdss=ss_ion1*fractions1*(dlnPPdlnrho-temp-1)
      cs2=fractions*ss_ion*dlnPPdlnrho/TT1
      cp1tilde=dlnPPdss/dlnPPdlnrho
!
    endsubroutine pressure_gradient_farray
!***********************************************************************
    subroutine pressure_gradient_point(lnrho,ss,cs2,cp1tilde)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      use Cdata
!
      real, intent(in) :: lnrho,ss
      real, intent(out) :: cs2,cp1tilde
      real :: yH,lnTT
      real :: R,dlnTTdy,dRdy,temp
      real :: dlnPPdlnrho,fractions,fractions1
      real :: dlnPPdss,TT1
!
      yH=0.5
      call rtsafe(ilnrho_ss,lnrho,ss,yHmin,yHmax,yH)
      fractions=(1+yH+xHe)
      fractions1=1/fractions
      lnTT=(2.0/3.0)*((ss/ss_ion+(1-yH)*(log(1-yH)-lnrho_H) &
                       +yH*(2*log(yH)-lnrho_e-lnrho_p) &
                       +xHe_term)/fractions+lnrho-2.5)+lnTT_ion
      TT1=exp(-lnTT)
!
      R=lnrho_e-lnrho+1.5*(lnTT-lnTT_ion)-TT_ion*TT1+log(1-yH)-2*log(yH)
      dlnTTdy=(2*(lnrho_H-lnrho_p-R-TT_ion*TT1)-3)/3*fractions1
      dRdy=dlnTTdy*(1.5+TT_ion*TT1)-1/(1-yH)-2/yH
      temp=(dlnTTdy+fractions1)/dRdy
      dlnPPdlnrho=(5-2*TT_ion*TT1*temp)/3
      dlnPPdss=ss_ion1*fractions1*(dlnPPdlnrho-temp-1)
      cs2=fractions*ss_ion*dlnPPdlnrho/TT1
      cp1tilde=dlnPPdss/dlnPPdlnrho
!
    endsubroutine pressure_gradient_point
!***********************************************************************
    subroutine temperature_gradient(f,glnrho,gss,glnTT)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   17-nov-03/tobi: adapted from subroutine eoscalc
!
      use Cdata
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx,3), intent(in) :: glnrho,gss
      real, dimension(nx,3), intent(out) :: glnTT
      real, dimension(nx) :: lnrho,yH,lnTT,TT1,fractions1
      real, dimension(nx) :: R,dlnTTdy,dRdy
      real, dimension(nx) :: dlnTTdydRdy,dlnTTdlnrho,dlnTTdss
      integer :: j
!
      lnrho=f(l1:l2,m,n,ilnrho)
      yH=f(l1:l2,m,n,iyH)
      lnTT=f(l1:l2,m,n,ilnTT)
      TT1=exp(-lnTT)
      fractions1=1/(1+yH+xHe)
!
      R=lnrho_e-lnrho+1.5*(lnTT-lnTT_ion)-TT_ion*TT1+log(1-yH)-2*log(yH)
      dlnTTdy=((2.0/3.0)*(lnrho_H-lnrho_p-R-TT_ion*TT1)-1)*fractions1
      dRdy=dlnTTdy*(1.5+TT_ion*TT1)-1/(1-yH)-2/yH
      dlnTTdydRdy=dlnTTdy/dRdy
      dlnTTdlnrho=(2.0/3.0)*(1-TT_ion*TT1*dlnTTdydRdy)
      dlnTTdss=(dlnTTdlnrho-dlnTTdydRdy)*fractions1*ss_ion1
      do j=1,3
        glnTT(:,j)=dlnTTdlnrho*glnrho(:,j)+dlnTTdss*gss(:,j)
      enddo
!
    endsubroutine temperature_gradient
!***********************************************************************
    subroutine temperature_hessian(f,hlnrho,hss,hlnTT)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally hlnPP and hlnTT
!   hP/rho=cs2*(hlnrho+cp1tilde*hss)
!
!   10-apr-04/axel: adapted from temperature_gradient
!
      use Cdata
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx,3,3), intent(in) :: hlnrho,hss
      real, dimension(nx,3,3), intent(out) :: hlnTT
      real, dimension(nx) :: lnrho,yH,lnTT,TT1,fractions1
      real, dimension(nx) :: R,dlnTTdy,dRdy
      real, dimension(nx) :: dlnTTdydRdy,dlnTTdlnrho,dlnTTdss
      integer :: i,j
!
      lnrho=f(l1:l2,m,n,ilnrho)
      yH=f(l1:l2,m,n,iyH)
      lnTT=f(l1:l2,m,n,ilnTT)
      TT1=exp(-lnTT)
      fractions1=1/(1+yH+xHe)
!
      R=lnrho_e-lnrho+1.5*(lnTT-lnTT_ion)-TT_ion*TT1+log(1-yH)-2*log(yH)
      dlnTTdy=((2.0/3.0)*(lnrho_H-lnrho_p-R-TT_ion*TT1)-1)*fractions1
      dRdy=dlnTTdy*(1.5+TT_ion*TT1)-1/(1-yH)-2/yH
      dlnTTdydRdy=dlnTTdy/dRdy
      dlnTTdlnrho=(2.0/3.0)*(1-TT_ion*TT1*dlnTTdydRdy)
      dlnTTdss=(dlnTTdlnrho-dlnTTdydRdy)*fractions1*ss_ion1
      do j=1,3
      do i=1,3
        hlnTT(:,i,j)=dlnTTdlnrho*hlnrho(:,i,j)+dlnTTdss*hss(:,i,j)
      enddo
      enddo
!
    endsubroutine temperature_hessian
!***********************************************************************
    subroutine eoscalc_farray(f,psize,lnrho,ss,yH,lnTT,ee,pp,lnchi)
!
!   Calculate thermodynamical quantities
!
!   2-feb-03/axel: simple example coded
!   13-jun-03/tobi: the ionization fraction as part of the f-array
!                   now needs to be given as an argument as input
!   17-nov-03/tobi: moved calculation of cs2 and cp1tilde to
!                   subroutine pressure_gradient
!
      use Cdata
      use Sub
      use Mpicomm, only: stop_it
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      integer, intent(in) :: psize
      real, dimension(psize), intent(out), optional :: lnrho,ss
      real, dimension(psize), intent(out), optional :: yH,lnTT
      real, dimension(psize), intent(out), optional :: ee,pp,lnchi
      real, dimension(psize) :: lnrho_,ss_,yH_,lnTT_,TT_,fractions
!
      select case (psize)

      case (nx)
        lnrho_=f(l1:l2,m,n,ilnrho)
        ss_=f(l1:l2,m,n,iss)
        yH_=f(l1:l2,m,n,iyH)
        lnTT_=f(l1:l2,m,n,ilnTT)

      case (mx)
        lnrho_=f(:,m,n,ilnrho)
        ss_=f(:,m,n,iss)
        yH_=f(:,m,n,iyH)
        lnTT_=f(:,m,n,ilnTT)

      case default
        call stop_it("eoscalc: no such pencil size")

      end select

      TT_=exp(lnTT_)
      fractions=(1+yH_+xHe)

      if (present(lnrho)) lnrho=lnrho_
      if (present(ss)) ss=ss_
      if (present(yH)) yH=yH_
      if (present(lnTT)) lnTT=lnTT_
      if (present(ee)) ee=1.5*fractions*ss_ion*TT_+yH_*ee_ion
      if (present(pp)) pp=fractions*exp(lnrho_)*TT_*ss_ion
!
!  Hminus opacity
!
      if (present(lnchi)) then
         lnchi=2*lnrho_-lnrho_e_+1.5*(lnTT_ion_-lnTT_) &
              +TT_ion_/TT_+log(yH_+yMetals)+log(1-yH_)+lnchi0
      endif
!
    endsubroutine eoscalc_farray
!***********************************************************************
    subroutine eoscalc_pencil(ivars,var1,var2,lnrho,ss,yH,lnTT,ee,pp)
!
!   Calculate thermodynamical quantities
!
!   i13-mar-04/tony: modified 
!
      use Cdata
      use Mpicomm, only: stop_it
!
      integer, intent(in) :: ivars
      real, dimension(nx), intent(in) :: var1,var2
      real, dimension(nx), intent(out), optional :: lnrho,ss
      real, dimension(nx), intent(out), optional :: yH,lnTT
      real, dimension(nx), intent(out), optional :: ee,pp
      real, dimension(nx) :: lnrho_,ss_,yH_,lnTT_,TT_,rho_,ee_,pp_,fractions
      integer :: i
!
      select case (ivars)

      case (ilnrho_ss)
        lnrho_=var1
        ss_=var2
        yH_=0.5*yHmax
        do i=1,nx 
          call rtsafe(ilnrho_ss,lnrho_(i),ss_(i),yHmin,yHmax,yH_(i))
        enddo
        fractions=(1+yH_+xHe)
        lnTT_=(2.0/3.0)*((ss_/ss_ion+(1-yH_)*(log(1-yH_)-lnrho_H) &
                          +yH_*(2*log(yH_)-lnrho_e-lnrho_p) &
                          +xHe_term)/fractions+lnrho_-2.5)+lnTT_ion
        TT_=exp(lnTT_)
        rho_=exp(lnrho_)
        ee_=1.5*fractions*ss_ion*TT_+yH_*ee_ion
        pp_=fractions*rho_*TT_*ss_ion

      case (ilnrho_ee)
        lnrho_=var1
        ee_=var2
        yH_=yHmax
        yH_=0.5*min(ee_/ee_ion,yH_)
        do i=1,nx 
          call rtsafe(ilnrho_ee,lnrho_(i),ee_(i),yHmin,yHmax*min(ee_(i)/ee_ion,1.0),yH_(i))
        enddo
        fractions=(1+yH_+xHe)
        TT_=(ee_-yH_*ee_ion)/(1.5*fractions*ss_ion)
        lnTT_=log(TT_)
        rho_=exp(lnrho_)
        ss_=ss_ion*(fractions*(1.5*(lnTT_-lnTT_ion)-lnrho_+2.5) &
                    -yH_*(2*log(yH_)-lnrho_e-lnrho_p) &
                    -(1-yH_)*(log(1-yH_)-lnrho_H)-xHe_term)
        pp_=fractions*rho_*TT_*ss_ion

      case (ilnrho_pp)
        lnrho_=var1
        pp_=var2
        yH_=0.5*yHmax
        do i=1,nx 
          call rtsafe(ilnrho_pp,lnrho_(i),pp_(i),yHmin,yHmax,yH_(i))
        enddo
        fractions=(1+yH_+xHe)
        rho_=exp(lnrho_)
        TT_=pp_/(fractions*ss_ion*rho_)
        lnTT_=log(TT_)
        ss_=ss_ion*(fractions*(1.5*(lnTT_-lnTT_ion)-lnrho_+2.5) &
                   -yH_*(2*log(yH_)-lnrho_e-lnrho_p) &
                   -(1-yH_)*(log(1-yH_)-lnrho_H)-xHe_term)
        ee_=1.5*fractions*ss_ion*TT_+yH_*ee_ion

      case default
        call stop_it("eoscalc_point: I don't get what the independent variables are.")

      end select

      if (present(lnrho)) lnrho=lnrho_
      if (present(ss)) ss=ss_
      if (present(yH)) yH=yH_
      if (present(lnTT)) lnTT=lnTT_
      if (present(ee)) ee=ee_
      if (present(pp)) pp=pp_
!
    endsubroutine eoscalc_pencil
!!***********************************************************************
    subroutine eoscalc_point(ivars,var1,var2,lnrho,ss,yH,lnTT,ee,pp)
!
!   Calculate thermodynamical quantities
!
!   2-feb-03/axel: simple example coded
!   13-jun-03/tobi: the ionization fraction as part of the f-array
!                   now needs to be given as an argument as input
!   17-nov-03/tobi: moved calculation of cs2 and cp1tilde to
!                   subroutine pressure_gradient
!
      use Cdata
      use Mpicomm, only: stop_it
!
      integer, intent(in) :: ivars
      real, intent(in) :: var1,var2
      real, intent(out), optional :: lnrho,ss
      real, intent(out), optional :: yH,lnTT
      real, intent(out), optional :: ee,pp
      real :: lnrho_,ss_,yH_,lnTT_,TT_,rho_,ee_,pp_,fractions
!
      select case (ivars)

      case (ilnrho_ss)
        lnrho_=var1
        ss_=var2
        yH_=0.5*yHmax
        call rtsafe(ilnrho_ss,lnrho_,ss_,yHmin,yHmax,yH_)
        lnTT_=(ss_/ss_ion+(1-yH_)*(log(1-yH_)-lnrho_H) &
              +yH_*(2*log(yH_)-lnrho_e-lnrho_p)+xHe_term)/(1+yH_+xHe)
        lnTT_=(2.0/3.0)*(lnTT_+lnrho_-2.5)+lnTT_ion

        TT_=exp(lnTT_)
        rho_=exp(lnrho_)
        ee_=1.5*(1+yH_+xHe)*ss_ion*TT_+yH_*ee_ion
        pp_=(1+yH_+xHe)*rho_*TT_*ss_ion

      case (ilnrho_ee)
        lnrho_=var1
        ee_=var2
        yH_=0.5*min(ee_/ee_ion,yHmax)
        call rtsafe(ilnrho_ee,lnrho_,ee_,yHmin,yHmax*min(ee_/ee_ion,1.0),yH_)
        fractions=(1+yH_+xHe)
        TT_=(ee_-yH_*ee_ion)/(1.5*fractions*ss_ion)
        lnTT_=log(TT_)
        rho_=exp(lnrho_)
        ss_=ss_ion*(fractions*(1.5*(lnTT_-lnTT_ion)-lnrho_+2.5) &
                    -yH_*(2*log(yH_)-lnrho_e-lnrho_p) &
                    -(1-yH_)*(log(1-yH_)-lnrho_H)-xHe_term)
        pp_=fractions*rho_*TT_*ss_ion

      case (ilnrho_pp)
        lnrho_=var1
        pp_=var2
        yH_=0.5*yHmax
        call rtsafe(ilnrho_pp,lnrho_,pp_,yHmin,yHmax,yH_)
        fractions=(1+yH_+xHe)
        rho_=exp(lnrho_)
        TT_=pp_/(fractions*ss_ion*rho_)
        lnTT_=log(TT_)
        ss_=ss_ion*(fractions*(1.5*(lnTT_-lnTT_ion)-lnrho_+2.5) &
                   -yH_*(2*log(yH_)-lnrho_e-lnrho_p) &
                   -(1-yH_)*(log(1-yH_)-lnrho_H)-xHe_term)
        ee_=1.5*fractions*ss_ion*TT_+yH_*ee_ion

      case default
        call stop_it("eoscalc_point: I don't get what the independent variables are.")

      end select

      if (present(lnrho)) lnrho=lnrho_
      if (present(ss)) ss=ss_
      if (present(yH)) yH=yH_
      if (present(lnTT)) lnTT=lnTT_
      if (present(ee)) ee=ee_
      if (present(pp)) pp=pp_
!
    endsubroutine eoscalc_point
!***********************************************************************
    subroutine read_eos_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=eos_init_pars,ERR=99, IOSTAT=iostat) 
      else 
        read(unit,NML=eos_init_pars,ERR=99) 
      endif

99    return
    endsubroutine read_eos_init_pars
!***********************************************************************
    subroutine write_eos_init_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=eos_init_pars)
    endsubroutine write_eos_init_pars
!***********************************************************************
    subroutine read_eos_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=eos_run_pars,ERR=99, IOSTAT=iostat) 
      else 
        read(unit,NML=eos_run_pars,ERR=99) 
      endif

99    return
    endsubroutine read_eos_run_pars
!***********************************************************************
    subroutine write_eos_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=eos_run_pars)
    endsubroutine write_eos_run_pars
!***********************************************************************
    subroutine rtsafe_pencil(lnrho,ss,yH)
!
!   safe newton raphson algorithm (adapted from NR) !
!   09-apr-03/tobi: changed to subroutine
!
      real, dimension(mx), intent(in) :: lnrho,ss
      real, dimension(mx), intent(inout) :: yH
!
      real, dimension(mx) :: dyHold,dyH,yHlow,yHhigh,f,df,yHcheck
      real, dimension(mx) :: lnTT_,dlnTT_,TT1_,fractions1
      integer             :: i
      integer, parameter  :: maxit=1000
!
      yHlow=yHmin
      yHhigh=yHmax
      dyH=yHhigh-yHlow
      dyHold=dyH
!
      yHcheck=0
!
      fractions1=1/(1+yH+xHe)
      lnTT_=(2.0/3.0)*((ss/ss_ion+(1-yH)*(log(1-yH)-lnrho_H) &
                         +yH*(2*log(yH)-lnrho_e-lnrho_p) &
                         +xHe_term)*fractions1+lnrho-2.5)
      TT1_=exp(-lnTT_)
      f=lnrho_e-lnrho+1.5*lnTT_-TT1_+log(1-yH)-2*log(yH)
      dlnTT_=((2.0/3.0)*(lnrho_H-lnrho_p-f-TT1_)-1)*fractions1
      df=dlnTT_*(1.5+TT1_)-1/(1-yH)-2/yH
!
      do i=1,maxit
        where (yHcheck/=yH)
          where (((yH-yHlow)*df-f)*((yH-yHhigh)*df-f)>0.or.abs(2*f)>abs(dyHold*df))
            !
            !  Bisection
            !
            dyHold=dyH
            dyH=0.5*(yHhigh-yHlow)
            yHcheck=yHhigh
            yH=yHhigh-dyH
          elsewhere
            !
            !  Newton-Raphson
            !
            dyHold=dyH
            dyH=f/df
            yHcheck=yH
            yH=yH-dyH
          endwhere
        endwhere
        ! Apply floor to yH (necessary to avoid negative yH in samples
        ! /0d-tests/heating_ionize)
        yH = max(yH,yHmin)
        yH = min(yH,yHmax)    ! plausibly needed as well
        where (abs(dyH)>yHacc*yH.and.yHcheck/=yH)
          fractions1=1/(1+yH+xHe)
          lnTT_=(2.0/3.0)*((ss/ss_ion+(1-yH)*(log(1-yH)-lnrho_H) &
                             +yH*(2*log(yH)-lnrho_e-lnrho_p) &
                             +xHe_term)*fractions1+lnrho-2.5)
          TT1_=exp(-lnTT_)
          f=lnrho_e-lnrho+1.5*lnTT_-TT1_+log(1-yH)-2*log(yH)
          dlnTT_=((2.0/3.0)*(lnrho_H-lnrho_p-f-TT1_)-1)*fractions1
          df=dlnTT_*(1.5+TT1_)-1/(1-yH)-2/yH
          where (f<0)
            yHhigh=yH
          elsewhere
            yHlow=yH
          endwhere
        elsewhere
          yHcheck=yH
        endwhere
        if (all(yHcheck==yH)) return
      enddo
!
    endsubroutine rtsafe_pencil
!***********************************************************************
    subroutine rtsafe(ivars,var1,var2,yHlb,yHub,yH,rterror,rtdebug)
!
!   safe newton raphson algorithm (adapted from NR) !
!   09-apr-03/tobi: changed to subroutine
!
      use Cdata
!
      integer, intent(in)            :: ivars
      real, intent(in)               :: var1,var2
      real, intent(in)               :: yHlb,yHub
      real, intent(inout)            :: yH
      logical, intent(out), optional :: rterror
      logical, intent(in), optional  :: rtdebug
!
      real               :: dyHold,dyH,yHl,yHh,f,df,temp
      integer            :: i
      integer, parameter :: maxit=1000
!
      if (present(rterror)) rterror=.false.
      if (present(rtdebug)) then
        if(rtdebug) print*,'rtsafe: i,yH=',0,yH
      endif
!
      yHl=yHlb
      yHh=yHub
      dyH=1
      dyHold=dyH
!
      call saha(ivars,var1,var2,yH,f,df)
!
      do i=1,maxit
        if (present(rtdebug)) then
          if (rtdebug) print*,'rtsafe: i,yH=',i,yH
        endif
        if (((yH-yHl)*df-f)*((yH-yHh)*df-f)>0.or.abs(2*f)>abs(dyHold*df)) then
          dyHold=dyH
          dyH=0.5*(yHl-yHh)
          yH=yHh+dyH
          if (yHh==yH) return
        else
          dyHold=dyH
          dyH=f/df
          temp=yH
          yH=yH-dyH
          if (temp==yH) return
        endif
        if (abs(dyH)<yHacc*yH) return
        call saha(ivars,var1,var2,yH,f,df)
        if (f<0) then
          yHh=yH
        else
          yHl=yH
        endif
      enddo
!
      if (present(rterror)) rterror=.true.
!
    endsubroutine rtsafe
!***********************************************************************
    subroutine saha(ivars,var1,var2,yH,f,df)
!
!   we want to find the root of f
!
!   23-feb-03/tobi: errors fixed
!
      use Mpicomm, only: stop_it
!
      integer, intent(in)          :: ivars
      real, intent(in)             :: var1,var2,yH
      real, intent(out)            :: f,df
!
      real :: lnrho,ss,ee,pp
      real :: lnTT_,dlnTT_,TT1_,fractions1
!
      fractions1=1/(1+yH+xHe)
!
      select case (ivars)
      case (ilnrho_ss)
        lnrho=var1
        ss=var2
        lnTT_=(2.0/3.0)*((ss/ss_ion+(1-yH)*(log(1-yH)-lnrho_H) &
                         +yH*(2*log(yH)-lnrho_e-lnrho_p) &
                         +xHe_term)*fractions1+lnrho-2.5)
      case (ilnrho_ee)
        lnrho=var1
        ee=var2
        !print*,'saha: TT_',2.0/3.0*(ee-yH*ee_ion)*fractions1
        !lnTT_=log(2.0/3.0*(ee/ee_ion-yH)*fractions1)
      !  if (ee.lt.yH*ee_ion) then
      !    lnTT_=-25.
      !  else
        lnTT_=log(2.0/3.0*(ee-yH*ee_ion)*fractions1)
      !  endif
      case (ilnrho_pp)
        lnrho=var1
        pp=var2
        lnTT_=log(pp/ss_ion*fractions1)-lnrho
      case default
        call stop_it("saha: I don't get what the independent variables are.")
        lnTT_=0.
      end select
!
      TT1_=exp(-lnTT_)
      f=lnrho_e-lnrho+1.5*lnTT_-TT1_+log(1-yH)-2*log(yH)
      dlnTT_=((2.0/3.0)*(lnrho_H-lnrho_p-f-TT1_)-1)*fractions1
      df=dlnTT_*(1.5+TT1_)-1/(1-yH)-2/yH
!
    endsubroutine saha
!***********************************************************************
    subroutine scale_height_xy(radz0,nrad,f,H_xy)
!
!  calculate characteristic scale height for exponential boundary
!  condition in the radiation module
!
      use Gravity
!
      integer, intent(in) :: radz0,nrad
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(mx,my,radz0), intent(out) :: H_xy
      real, dimension(mx,my,radz0) :: yH_xy,lnTT_xy
!
      if (nrad>0) then
        yH_xy=f(:,:,n1-radz0:n1-1,iyH)
        lnTT_xy=f(:,:,n1-radz0:n1-1,ilnTT)
      endif
!
      if (nrad<0) then
        yH_xy=f(:,:,n2+1:n2+radz0,iyH)
        lnTT_xy=f(:,:,n2+1:n2+radz0,ilnTT)
      endif
!
      H_xy=(1.+yH_xy+xHe)*ss_ion*exp(lnTT_xy)/gravz
!
    endsubroutine scale_height_xy
!***********************************************************************
    subroutine get_soundspeed(lnTT,cs2)
!
!  Calculate sound speed for given temperature
!
!  20-Oct-03/tobi: coded
!
      use Mpicomm
!
      real, intent(in)  :: lnTT
      real, intent(out) :: cs2
!
      call stop_it("get_soundspeed: with ionization, lnrho needs to be known here")
!
      if (NO_WARN) print*, lnTT     !(keep compiler quiet)
      if (NO_WARN) cs2=0          !(keep compiler quiet)
!
    end subroutine get_soundspeed
!***********************************************************************
    subroutine isothermal_entropy(f,T0)
!
!  Isothermal stratification (for lnrho and ss)
!  This routine should be independent of the gravity module used.
!  When entropy is present, this module also initializes entropy.
!
!  Sound speed (and hence Temperature), is
!  initialised to the reference value:
!           sound speed: cs^2_0            from start.in  
!           density: rho0 = exp(lnrho0)
!
!  11-jun-03/tony: extracted from isothermal routine in Density module
!                  to allow isothermal condition for arbitrary density
!  17-oct-03/nils: works also with leos_ionization=T
!  18-oct-03/tobi: distributed across ionization modules
!
      use Cdata
!
      real, dimension(mx,my,mz,mvar+maux), intent(inout) :: f
      real, intent(in) :: T0
      real, dimension(nx) :: lnrho,ss,yH,K,sqrtK,yH_term,one_yH_term
!
      do n=n1,n2
      do m=m1,m2
!
        lnrho=f(l1:l2,m,n,ilnrho)
!
        K=exp(lnrho_e-lnrho-TT_ion/T0)*(T0/TT_ion)**1.5
        sqrtK=sqrt(K)
        yH=2*sqrtK/(sqrtK+sqrt(4+K))
!
        where (yH>0)
          yH_term=yH*(2*log(yH)-lnrho_e-lnrho_p)
        elsewhere
          yH_term=0
        endwhere
!
        where (yH<1)
          one_yH_term=(1-yH)*(log(1-yH)-lnrho_H)
        elsewhere
          one_yH_term=0
        endwhere
!
        ss=ss_ion*((1+yH+xHe)*(1.5*log(T0/TT_ion)-lnrho+2.5) &
                   -yH_term-one_yH_term-xHe_term)
!
        f(l1:l2,m,n,iss)=ss
!
      enddo
      enddo
!
    endsubroutine isothermal_entropy
!***********************************************************************
    subroutine isothermal_lnrho_ss(f,T0,rho0)
!
!  Isothermal stratification for lnrho and ss (for yH=0!)
!
!  Currently only implemented for ionization_fixed.
!
      real, dimension(mx,my,mz,mvar+maux), intent(inout) :: f
      real, intent(in) :: T0,rho0
!
      if (NO_WARN) print*,f,T0,rho0
!
    endsubroutine isothermal_lnrho_ss
!***********************************************************************
    subroutine bc_ss_flux(f,topbot,hcond0,hcond1,Fheat,FheatK,chi, &
                lmultilayer,lcalc_heatcond_constchi)
!
!  constant flux boundary condition for entropy (called when bcz='c1')
!
!  23-jan-2002/wolf: coded
!  11-jun-2002/axel: moved into the entropy module
!   8-jul-2002/axel: split old bc_ss into two
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
      use Gravity
!
      real, intent(in) :: Fheat, FheatK, hcond0, hcond1, chi
      logical, intent(in) :: lmultilayer, lcalc_heatcond_constchi
      
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my) :: tmp_xy,TT_xy,rho_xy,yH_xy
      integer :: i
      
!
!  Do the `c1' boundary condition (constant heat flux) for entropy.
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!  ---------------
!
      case('bot')
        if (lmultilayer) then
          if(headtt) print*,'bc_ss_flux: Fbot,hcond=',Fheat,hcond0*hcond1
        else
          if(headtt) print*,'bc_ss_flux: Fbot,hcond=',Fheat,hcond0
        endif
!
!  calculate Fbot/(K*cs2)
!
        rho_xy=exp(f(:,:,n1,ilnrho))
        TT_xy=exp(f(:,:,n1,ilnTT))
!
!  check whether we have chi=constant at bottom, in which case
!  we have the nonconstant rho_xy*chi in tmp_xy. 
!
        if(lcalc_heatcond_constchi) then
          tmp_xy=Fheat/(rho_xy*chi*TT_xy)
        else
          tmp_xy=FheatK/TT_xy
        endif
!
!  get ionization fraction at bottom boundary
!
        yH_xy=f(:,:,n1,iyH)
!
!  enforce ds/dz + gamma1/gamma*dlnrho/dz = - gamma1/gamma*Fbot/(K*cs2)
!
        do i=1,nghost
          f(:,:,n1-i,iss)=f(:,:,n1+i,iss)+ss_ion*(1+yH_xy+xHe)* &
              (f(:,:,n1+i,ilnrho)-f(:,:,n1-i,ilnrho)+3*i*dz*tmp_xy)
        enddo
!
!  top boundary
!  ------------
!
      case('top')
        if (lmultilayer) then
          if(headtt) print*,'bc_ss_flux: Ftop,hcond=',Fheat,hcond0*hcond1
        else
          if(headtt) print*,'bc_ss_flux: Ftop,hcond=',Fheat,hcond0
        endif
!
!  calculate Fbot/(K*cs2)
!
        rho_xy=exp(f(:,:,n2,ilnrho))
        TT_xy=exp(f(:,:,n2,ilnTT))
!
!  check whether we have chi=constant at bottom, in which case
!  we have the nonconstant rho_xy*chi in tmp_xy. 
!
        if(lcalc_heatcond_constchi) then
          tmp_xy=Fheat/(rho_xy*chi*TT_xy)
        else
          tmp_xy=FheatK/TT_xy
        endif
!
!  get ionization fraction at top boundary
!
        yH_xy=f(:,:,n2,iyH)
!
!  enforce ds/dz + gamma1/gamma*dlnrho/dz = - gamma1/gamma*Fbot/(K*cs2)
!
        do i=1,nghost
          f(:,:,n2+i,iss)=f(:,:,n2-i,iss)+ss_ion*(1+yH_xy+xHe)* &
              (f(:,:,n2-i,ilnrho)-f(:,:,n2+i,ilnrho)-3*i*dz*tmp_xy)
        enddo
!
      case default
        print*,"bc_ss_flux: invalid argument"
        call stop_it("")
      endselect
!
    endsubroutine bc_ss_flux
!***********************************************************************
    subroutine bc_ss_temp_old(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!  23-jan-2002/wolf: coded
!  11-jun-2002/axel: moved into the entropy module
!   8-jul-2002/axel: split old bc_ss into two
!  23-jun-2003/tony: implemented for leos_fixed_ionization
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_temp_old: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
    endsubroutine bc_ss_temp_old
!***********************************************************************
    subroutine bc_ss_temp_x(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_temp_x: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    endsubroutine bc_ss_temp_x
!***********************************************************************
    subroutine bc_ss_temp_y(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_temp_y: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    endsubroutine bc_ss_temp_y
!***********************************************************************
    subroutine bc_ss_temp_z(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_temp_z: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    endsubroutine bc_ss_temp_z
!***********************************************************************
    subroutine bc_ss_temp2_z(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_temp2_z: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    endsubroutine bc_ss_temp2_z
!***********************************************************************
    subroutine bc_ss_stemp_x(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_stemp_x: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    endsubroutine bc_ss_stemp_x
!***********************************************************************
    subroutine bc_ss_stemp_y(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
      call stop_it("bc_ss_stemp_y: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    endsubroutine bc_ss_stemp_y
!***********************************************************************
    subroutine bc_ss_stemp_z(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!  26-sep-2003/tony: coded
!
      use Mpicomm, only: stop_it
      use Cdata
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,nghost) :: lnrho,ss,yH,lnTT,TT,K,sqrtK,yH_term,one_yH_term
      integer :: i
!
!  Symmetric temperature/sound speed for entropy.
!  This assumes that the density is already set (ie density _must_ register
!  first!)
!
!  check whether we want to do top or bottom (this is processor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('bot')
        do i=1,nghost
          f(:,:,n1-i,ilnTT) = f(:,:,n1+i,ilnTT) 
        enddo
!
        lnrho=f(:,:,1:n1-1,ilnrho)
        lnTT=f(:,:,1:n1-1,ilnTT)
        TT=exp(lnTT)
!
        K=exp(lnrho_e-lnrho-TT_ion/TT)*(TT/TT_ion)**1.5
        sqrtK=sqrt(K)
        yH=2*sqrtK/(sqrtK+sqrt(4+K))
!
        where (yH>0)
          yH_term=yH*(2*log(yH)-lnrho_e-lnrho_p)
        elsewhere
          yH_term=0
        endwhere
!
        where (yH<1)
          one_yH_term=(1-yH)*(log(1-yH)-lnrho_H)
        elsewhere
          one_yH_term=0
        endwhere
!
        ss=ss_ion*((1+yH+xHe)*(1.5*log(TT/TT_ion)-lnrho+2.5) &
                    -yH_term-one_yH_term-xHe_term)
!
        f(:,:,1:n1-1,iyH)=yH
        f(:,:,1:n1-1,iss)=ss
!
!  top boundary
!
      case('top')
        do i=1,nghost
          f(:,:,n2+i,ilnTT) = f(:,:,n2-i,ilnTT) 
        enddo
!
        lnrho=f(:,:,n2+1:mz,ilnrho)
        lnTT=f(:,:,n2+1:mz,ilnTT)
        TT=exp(lnTT)
!
        K=exp(lnrho_e-lnrho-TT_ion/TT)*(TT/TT_ion)**1.5
        sqrtK=sqrt(K)
        yH=2*sqrtK/(sqrtK+sqrt(4+K))
!
        where (yH>0)
          yH_term=yH*(2*log(yH)-lnrho_e-lnrho_p)
        elsewhere
          yH_term=0
        endwhere
!
        where (yH<1)
          one_yH_term=(1-yH)*(log(1-yH)-lnrho_H)
        elsewhere
          one_yH_term=0
        endwhere
!
        ss=ss_ion*((1+yH+xHe)*(1.5*log(TT/TT_ion)-lnrho+2.5) &
                    -yH_term-one_yH_term-xHe_term)
!
        f(:,:,n2+1:mz,iyH)=yH
        f(:,:,n2+1:mz,iss)=ss
!
      case default
        print*,"bc_ss_stemp_z: invalid argument"
        call stop_it("")
      endselect
!
    endsubroutine bc_ss_stemp_z
!***********************************************************************
    subroutine bc_ss_energy(f,topbot)
!
!  boundary condition for entropy
!
!  may-2002/nils: coded
!  11-jul-2002/nils: moved into the entropy module
!  26-aug-2003/tony: distributed across ionization modules
!
      use Mpicomm, only: stop_it
      use Cdata
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
!
!  The 'ce' boundary condition for entropy makes the energy constant at
!  the boundaries.
!  This assumes that the density is already set (ie density must register
!  first!)
!
      call stop_it("bc_ss_stemp_y: NOT IMPLEMENTED IN EOS_IONIZATION")
      if (NO_WARN) print*,f(1,1,1,1),topbot
!
    end subroutine bc_ss_energy
!***********************************************************************
endmodule EquationOfState
