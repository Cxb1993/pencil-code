! $Id: eos_temperature_ionization.f90,v 1.39 2006-06-24 07:06:10 brandenb Exp $

!  Dummy routine for ideal gas

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 1
!
! PENCILS PROVIDED ss,ee,pp,lnTT,cs2,nabla_ad,glnTT,TT,TT1
! PENCILS PROVIDED yH,del2lnTT,cv,cv1,cp,cp1,gamma,gamma1,gamma11,mu1
! PENCILS PROVIDED glnTT,rho1gpp,delta
!
!***************************************************************

module EquationOfState

  use Cparam
  use Cdata
  use Messages

  implicit none

  include 'eos.h'

  interface eoscalc ! Overload subroutine `eoscalc' function
    module procedure eoscalc_pencil   ! explicit f implicit m,n
    module procedure eoscalc_point    ! explicit lnrho, ss
    module procedure eoscalc_farray   ! explicit lnrho, ss
  end interface

  interface pressure_gradient ! Overload subroutine `pressure_gradient'
    module procedure pressure_gradient_farray  ! explicit f implicit m,n
    module procedure pressure_gradient_point   ! explicit lnrho, ss
  end interface

  ! integers specifying which independent variables to use in eoscalc
  integer, parameter :: ilnrho_ss=1,ilnrho_ee=2,ilnrho_pp=3,ilnrho_lnTT=4

  !  secondary parameters calculated in initialize
  real :: mu1_0,Rgas
  real :: TT_ion,lnTT_ion,TT_ion_,lnTT_ion_
  real :: ss_ion,kappa0,pp_ion
  real :: rho_H,rho_e,rho_e_,rho_He
  real :: lnrho_H,lnrho_e,lnrho_e_,lnrho_He

  real :: xHe=0.1,yH_const=0.0,yMetals=0.0,tau_relax=1.0
  logical :: lconst_yH=.false.

  real :: lnpp_bot=0.
  real :: ss_bot=0.

  ! input parameters
  namelist /eos_init_pars/ xHe,lconst_yH,yH_const,yMetals,lnpp_bot,ss_bot, &
                           tau_relax

  ! run parameters
  namelist /eos_run_pars/ xHe,lconst_yH,yH_const,yMetals,lnpp_bot,ss_bot, &
                          tau_relax

  real :: cs0=impossible, rho0=impossible, cp=impossible
  real :: cs20=impossible, lnrho0=impossible
  logical :: lcalc_cp=.false. 
!  real :: gamma=impossible, gamma1=impossible, gamma11=impossible
  real :: gamma=5./3., gamma1=impossible, gamma11=impossible
  real :: cs2bot=impossible, cs2top=impossible 
  real :: cs2cool=impossible
  real :: mpoly=impossible, mpoly0=impossible
  real :: mpoly1=impossible, mpoly2=impossible
  integer :: isothtop=0
  real, dimension (3) :: beta_glnrho_global=impossible
  real, dimension (3) :: beta_glnrho_scaled=impossible

  contains

!***********************************************************************
    subroutine register_eos()
!
!  14-jun-03/axel: adapted from register_eos
!
      use Mpicomm, only: stop_it
!
      logical, save :: first=.true.
!
      if (.not. first) call fatal_error('register_eos','module registration called twice')
      first = .false.
!
      leos=.true.
      leos_temperature_ionization=.true.
!
!  set indices for auxiliary variables
!
      iyH   = mvar + naux + 1 + (maux_com - naux_com); naux = naux + 1

      if ((ip<=8) .and. lroot) then
        print*, 'register_eos: ionization nvar = ', nvar
        print*, 'register_eos: iyH = ', iyH
      endif
!
!  Put variable names in array
!
      varname(iyH)   = 'yH'
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
      if (naux < maux)  aux_var(aux_count)=',yH $'
      if (naux == maux) aux_var(aux_count)=',yH'
      aux_count=aux_count+1
      if (lroot) then
        write(15,*) 'yH = fltarr(mx,my,mz)*one'
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           '$Id: eos_temperature_ionization.f90,v 1.39 2006-06-24 07:06:10 brandenb Exp $')
!
    endsubroutine register_eos
!***********************************************************************
    subroutine initialize_eos()
!
!  called by run.f90 after reading parameters, but before the time loop
!
      if (lroot) print*,'initialize_eos: ENTER'
!
!  Useful constants for ionization
!  (Here we assume m_H = m_p = m_u, m_He = 4*m_u, and m_e << m_u)
!
      mu1_0 = 1/(1 + 4*xHe)
      Rgas = k_B/m_u
      TT_ion = chiH/k_B
      lnTT_ion = log(TT_ion)
      TT_ion_ = chiH_/k_B
      lnTT_ion_ = log(TT_ion_)
      rho_H = (1/mu1_0)*m_u*((m_u/hbar)*(chiH/hbar)/(2*pi))**(1.5)
      lnrho_H = log(rho_H)
      rho_e = (1/mu1_0)*m_u*((m_e/hbar)*(chiH/hbar)/(2*pi))**(1.5)
      lnrho_e = log(rho_e)
      rho_He = (1/mu1_0)*m_u*((4*m_u/hbar)*(chiH/hbar)/(2*pi))**(1.5)
      lnrho_He = log(rho_He)
      rho_e_ = (1/mu1_0)*m_u*((m_e/hbar)*(chiH_/hbar)/(2*pi))**(1.5)
      lnrho_e_ = log(rho_e_)
      kappa0 = sigmaH_*mu1_0/(4*m_u)
      pp_ion = Rgas*mu1_0*rho_e*TT_ion
!
!  write scale non-free constants to file; to be read by idl
!
      if (lroot) then
        open (1,file=trim(datadir)//'/pc_constants.pro')
        write (1,*) 'mu1_0=',mu1_0
        write (1,*) 'Rgas=',Rgas
        write (1,*) 'TT_ion=',TT_ion
        write (1,*) 'lnTT_ion=',lnTT_ion
        write (1,*) 'TT_ion_=',TT_ion_
        write (1,*) 'lnTT_ion_=',lnTT_ion_
        write (1,*) 'lnrho_H=',lnrho_H
        write (1,*) 'lnrho_e=',lnrho_e
        write (1,*) 'lnrho_He=',lnrho_He
        write (1,*) 'lnrho_e_=',lnrho_e_
        write (1,*) 'kappa0=',kappa0
        close (1)
      endif

    endsubroutine initialize_eos
!*******************************************************************
    subroutine select_eos_variable(variable,findex)
!
!  dummy (but to be changed)
!
      character (len=*), intent(in) :: variable
      integer, intent(in) :: findex

      if (NO_WARN) print *,variable,findex

    endsubroutine select_eos_variable
!***********************************************************************
    subroutine pencil_criteria_eos()
!
!  dummy (but to be changed)
!
    endsubroutine pencil_criteria_eos
!***********************************************************************
    subroutine pencil_interdep_eos(lpencil_in)
!
!  dummy (but to be changed)
!
      logical, dimension(npencils) :: lpencil_in

      if (lpencil_in(i_cs2)) then
        lpencil_in(i_gamma)=.true.
        lpencil_in(i_rho1)=.true.
        lpencil_in(i_pp)=.true.
      endif

      if (lpencil_in(i_rho1gpp)) then
        lpencil_in(i_gamma11)=.true.
        lpencil_in(i_cs2)=.true.
        lpencil_in(i_glnrho)=.true.
        lpencil_in(i_delta)=.true.
        lpencil_in(i_glnTT)=.true.
      endif

      if (lpencil_in(i_nabla_ad)) then
        lpencil_in(i_mu1)=.true.
        lpencil_in(i_delta)=.true.
        lpencil_in(i_cp1)=.true.
      endif

      if (lpencil_in(i_gamma1)) lpencil_in(i_gamma)=.true.

      if (lpencil_in(i_gamma)) then
        lpencil_in(i_cp)=.true.
        lpencil_in(i_cv1)=.true.
      endif

      if (lpencil_in(i_gamma11)) then
        lpencil_in(i_cv)=.true.
        lpencil_in(i_cp1)=.true.
      endif

      if (lpencil_in(i_cv1)) lpencil_in(i_cv)=.true.

      if (lpencil_in(i_cv)) then
        lpencil_in(i_yH)=.true.
        lpencil_in(i_TT1)=.true.
        lpencil_in(i_mu1)=.true.
      endif

      if (lpencil_in(i_cp1)) lpencil_in(i_cp)=.true.

      if (lpencil_in(i_cp)) then
        lpencil_in(i_yH)=.true.
        lpencil_in(i_TT1)=.true.
        lpencil_in(i_mu1)=.true.
      endif

      if (lpencil_in(i_pp)) then
        lpencil_in(i_mu1)=.true.
        lpencil_in(i_rho)=.true.
        lpencil_in(i_TT)=.true.
      endif

      if (lpencil_in(i_mu1)) lpencil_in(i_yH)=.true.

      if (lpencil_in(i_ee)) then
        lpencil_in(i_mu1)=.true.
        lpencil_in(i_TT)=.true.
        lpencil_in(i_yH)=.true.
      endif

      if (lpencil_in(i_ss)) then
        lpencil_in(i_yH)=.true.
        lpencil_in(i_lnrho)=.true.
        lpencil_in(i_lnTT)=.true.
      endif

      if (lpencil_in(i_TT)) lpencil_in(i_lnTT)=.true.
      if (lpencil_in(i_TT1)) lpencil_in(i_TT)=.true.

      if (NO_WARN) print *,lpencil_in

    endsubroutine pencil_interdep_eos
!*******************************************************************
    subroutine calc_pencils_eos(f,p)
!
!  dummy (but to be changed)
!
      use Sub, only: grad,del2

      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p

      real, dimension (nx) :: rhs,sqrtrhs
      real, dimension (nx) :: yH_term_cv,TT_term_cv
      real, dimension (nx) :: yH_term_cp,TT_term_cp
      real, dimension (nx) :: alpha1,tmp
      integer :: i

      if (NO_WARN) print *,f,p

!
!  Temperature
!
      if (lpencil(i_lnTT)) p%lnTT=f(l1:l2,m,n,ilnTT)
      if (lpencil(i_TT)) p%TT=exp(p%lnTT)
      if (lpencil(i_TT1)) p%TT1=1/p%TT

!
!  Temperature laplacian and gradient
!
      if (lpencil(i_glnTT)) call grad(f,ilnTT,p%glnTT)
      if (lpencil(i_del2lnTT)) call del2(f,ilnTT,p%del2lnTT)

!
!  Ionization fraction
!
      if (lpencil(i_yH)) p%yH = f(l1:l2,m,n,iyH)

!
!  Mean molecular weight
!
      if (lpencil(i_mu1)) p%mu1 = mu1_0*(1 + p%yH + xHe)

!
!  Pressure
!
      if (lpencil(i_pp)) p%pp = Rgas*p%mu1*p%rho*p%TT

!
!  Common terms involving the ionization fraction
!
      if (lpencil(i_cv)) then
        yH_term_cv = p%yH*(1-p%yH)/((2-p%yH)*(1+p%yH+xHe))
        TT_term_cv = 1.5 + p%TT1*TT_ion
      endif

      if (lpencil(i_cp).or.lpencil(i_delta)) then
        yH_term_cp = p%yH*(1-p%yH)/(2+xHe*(2-p%yH))
        TT_term_cp = 2.5 + p%TT1*TT_ion
      endif

!
!  Specific heat at constant volume (i.e. density)
!
      if (lpencil(i_cv)) p%cv = Rgas*p%mu1*(1.5 + yH_term_cv*TT_term_cv**2)
      if (lpencil(i_cv1)) p%cv1=1/p%cv

!
!  Specific heat at constant pressure
!
      if (lpencil(i_cp)) p%cp = Rgas*p%mu1*(2.5 + yH_term_cp*TT_term_cp**2)
      if (lpencil(i_cp1)) p%cp1 = 1/p%cp

!
!  Polytropic index
!
      if (lpencil(i_gamma)) p%gamma = p%cp*p%cv1
      if (lpencil(i_gamma11)) p%gamma11 = p%cv*p%cp1
      if (lpencil(i_gamma1)) p%gamma1 = p%gamma - 1

!
!  For the definition of delta, see Kippenhahn & Weigert
!
      if (lpencil(i_delta)) p%delta = 1 + yH_term_cp*TT_term_cp

!
!  Sound speed
!
      if (lpencil(i_cs2)) then
        alpha1 = (2+xHe*(2-p%yH))/((2-p%yH)*(1+p%yH+xHe))
        p%cs2 = p%gamma*p%rho1*p%pp*alpha1
      endif

!
!  Adiabatic temperature gradient
!
      if (lpencil(i_nabla_ad)) p%nabla_ad = Rgas*p%mu1*p%delta*p%cp1

!
!  Logarithmic pressure gradient
!
      if (lpencil(i_rho1gpp)) then
        do i=1,3
          p%rho1gpp(:,i) = p%gamma11*p%cs2*(p%glnrho(:,i)+p%delta*p%glnTT(:,i))
        enddo
      endif

!
!  Energy per unit mass
!AB: Tobi, is this correct?
!
      if (lpencil(i_ee)) p%ee = 1.5*Rgas*p%mu1*p%TT + p%yH*Rgas*mu1_0*TT_ion

!
!  Entropy per unit mass
!  The contributions from each particle species contain the mixing entropy
!
      if (lpencil(i_ss)) then
        tmp = 2.5 - 1.5*(lnTT_ion-p%lnTT) - p%lnrho
        where (p%yH < 1) ! Neutral Hydrogen
          p%ss = (1-p%yH)*(tmp + lnrho_H - log(1-p%yH))
        endwhere
        where (p%yH > 0) ! Electrons and ionized Hydrogen
          p%ss = p%ss + p%yH*(tmp + lnrho_H - log(p%yH))
          p%ss = p%ss + p%yH*(tmp + lnrho_e - log(p%yH))
        endwhere
        if (xHe > 0) then ! Helium
          p%ss = p%ss + xHe*(tmp + lnrho_He - log(xHe))
        endif
        p%ss = Rgas*mu1_0*p%ss
      endif

    endsubroutine calc_pencils_eos
!*******************************************************************
    subroutine getmu(mu)
!
!  Calculate average particle mass in the gas relative to
!
!   12-aug-03/tony: implemented dummy
!
      real, intent(out) :: mu

      mu=0.
    endsubroutine getmu
!*******************************************************************
    subroutine rprint_eos(lreset,lwrite)
!
!  Writes iyH and ilnTT to index.pro file
!
!  02-apr-03/tony: implemented dummy
!
! 
      logical :: lreset
      logical, optional :: lwrite
!   
      if (NO_WARN) print*,lreset,present(lwrite)  !(keep compiler quiet)
!   
    endsubroutine rprint_eos
!***********************************************************************
    subroutine ioninit(f)
!   
      real, dimension (mx,my,mz,mvar+maux), intent(inout) :: f
!   
      if(NO_WARN) print*,f  !(keep compiler quiet)
!
    endsubroutine ioninit
!***********************************************************************
    subroutine ioncalc(f)

      real, dimension (mx,my,mz,mvar+maux) :: f

      real, dimension (mx) :: yH,rho1,TT1,rhs,sqrtrhs

      if (lconst_yH) then
      
        f(:,m,n,iyH) = yH_const

      else

        do n=1,mz
        do m=1,my

          rho1 = exp(-f(:,m,n,ilnrho))
          TT1 = exp(-f(:,m,n,ilnTT))
          where (TT_ion*TT1 < -log(tiny(TT_ion)))
            rhs = rho_e*rho1*(TT1*TT_ion)**(-1.5)*exp(-TT_ion*TT1)
            sqrtrhs = sqrt(rhs)
            yH = 2*sqrtrhs/(sqrtrhs+sqrt(4+rhs))
          elsewhere
            yH = 0
          endwhere

          f(:,m,n,iyH) = yH

        enddo
        enddo

      endif

    endsubroutine ioncalc
!***********************************************************************
    subroutine eosperturb(f,psize,ee,pp)

      real, dimension(mx,my,mz,mvar+maux), intent(inout) :: f
      integer, intent(in) :: psize
      real, dimension(psize), intent(in), optional :: ee,pp

      call not_implemented("eosperturb")

    end subroutine eosperturb
!***********************************************************************
    subroutine getdensity(EE,TT,yH,rho)
      
      real, intent(in) :: EE,TT,yH
      real, intent(inout) :: rho

      call fatal_error('getdensity','SHOULD NOT BE CALLED WITH NOEOS')
      rho = 0. 
      if (NO_WARN) print*,yH,EE,TT  !(keep compiler quiet)

    end subroutine getdensity
!***********************************************************************
    subroutine pressure_gradient_farray(f,cs2,cp1tilde)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   02-apr-04/tony: implemented dummy
!
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx), intent(out) :: cs2,cp1tilde
!
!
      cs2=impossible
      cp1tilde=impossible
      call fatal_error('pressure_gradient_farray','SHOULD NOT BE CALLED WITH NOEOS')
      if (NO_WARN) print*,f  !(keep compiler quiet)
!
    endsubroutine pressure_gradient_farray
!***********************************************************************
    subroutine pressure_gradient_point(lnrho,ss,cs2,cp1tilde)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   02-apr-04/tony: implemented dummy
!
      real, intent(in) :: lnrho,ss
      real, intent(out) :: cs2,cp1tilde
!
      cs2=impossible
      cp1tilde=impossible
      call fatal_error('pressure_gradient_point','SHOULD NOT BE CALLED WITH NOEOS')
      if (NO_WARN) print*,lnrho,ss  !(keep compiler quiet)
!
    endsubroutine pressure_gradient_point
!***********************************************************************
    subroutine temperature_gradient(f,glnrho,gss,glnTT)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   02-apr-04/tony: implemented dummy
!
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx,3), intent(in) :: glnrho,gss
      real, dimension(nx,3), intent(out) :: glnTT
!
!
      glnTT=0.
      call fatal_error('temperature_gradient','SHOULD NOT BE CALLED WITH NOEOS')
      if (NO_WARN) print*,f,glnrho,gss  !(keep compiler quiet)
    endsubroutine temperature_gradient
!***********************************************************************
    subroutine temperature_laplacian(f,del2lnrho,del2ss,del2lnTT)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally glnPP and glnTT
!   gP/rho=cs2*(glnrho+cp1tilde*gss)
!
!   12-dec-05/tony: adapted from subroutine temperature_gradient
!
      use Cdata
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx), intent(in) :: del2lnrho,del2ss
      real, dimension(nx), intent(out) :: del2lnTT
!
      call fatal_error('temperature_laplacian','SHOULD NOT BE CALLED WITH NOEOS')
!
      del2lnTT=0.
      if (NO_WARN) print*,f,del2lnrho,del2ss !(keep compiler quiet)
    endsubroutine temperature_laplacian
!***********************************************************************
    subroutine temperature_hessian(f,hlnrho,hss,hlnTT)
!
!   Calculate thermodynamical quantities, cs2 and cp1tilde
!   and optionally hlnPP and hlnTT
!   hP/rho=cs2*(hlnrho+cp1tilde*hss)
!
!   13-may-04/tony: adapted from idealgas dummy
!
      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      real, dimension(nx,3), intent(in) :: hlnrho,hss
      real, dimension(nx,3) :: hlnTT
!
      call fatal_error('temperature_hessian','now I do not believe you'// &
                           ' intended to call this!')
!
      if (NO_WARN) print*,f,hlnrho,hss !(keep compiler quiet)
!
    endsubroutine temperature_hessian
!***********************************************************************
    subroutine eoscalc_farray(f,psize,lnrho,ss,yH,mu1,lnTT,ee,pp,kapparho)
!
!   Calculate thermodynamical quantities
!
!   04-apr-06/tobi: Adapted for this EOS module
!
      use Mpicomm, only: stop_it

      real, dimension(mx,my,mz,mvar+maux), intent(in) :: f
      integer, intent(in) :: psize
      real, dimension(psize), intent(out), optional :: lnrho,ss
      real, dimension(psize), intent(out), optional :: yH,lnTT,mu1
      real, dimension(psize), intent(out), optional :: ee,pp,kapparho

      real, dimension(psize) :: lnrho_,lnTT_,yH_
      real, dimension(psize) :: TT1,tmp

      select case (psize)

      case (nx)
        lnrho_=f(l1:l2,m,n,ilnrho)
        lnTT_=f(l1:l2,m,n,ilnTT)
        yH_=f(l1:l2,m,n,iyH)

      case (mx)
        lnrho_=f(:,m,n,ilnrho)
        lnTT_=f(:,m,n,ilnTT)
        yH_=f(:,m,n,iyH)

      case default
        call stop_it("eoscalc: no such pencil size")

      end select


      if (present(lnrho)) lnrho=lnrho_

      if (present(lnTT)) lnTT=lnTT_

      if (present(yH)) yH = yH_

      if (present(mu1).or.present(ss).or.present(ee).or.present(pp)) then
        mu1 = mu1_0*(1 + yH_ + xHe)
      endif

      if (present(ee)) ee = 1.5*Rgas*mu1*exp(lnTT_) + yH_*Rgas*mu1_0*TT_ion

      if (present(pp)) pp = Rgas*mu1*exp(lnrho_+lnTT_)

      if (present(ss)) then
        tmp = 2.5 - 1.5*(lnTT_ion-lnTT_) - lnrho_
        where (yH_ < 1) ! Neutral Hydrogen
          ss = (1-yH_)*(tmp + lnrho_H - log(1-yH_))
        endwhere
        where (yH_ > 0) ! Electrons and ionized Hydrogen
          ss = ss + yH_*(tmp + lnrho_H - log(yH_))
          ss = ss + yH_*(tmp + lnrho_e - log(yH_))
        endwhere
        if (xHe > 0) then ! Helium
          ss = ss + xHe*(tmp + lnrho_He - log(xHe))
        endif
        ss = Rgas*mu1_0*ss
      endif

      if (present(kapparho)) then
        TT1 = exp(-lnTT_)
        kapparho = min(sqrt(0.9*huge(1.0)),(yH_+yMetals)*(1-yH_)*kappa0* &
                   exp(2*lnrho_-lnrho_e_+1.5*(lnTT_ion_-lnTT_)+TT_ion_*TT1))
      endif

    endsubroutine eoscalc_farray
!***********************************************************************
    subroutine eoscalc_point(ivars,var1,var2,lnrho,ss,yH,lnTT,ee,pp)
!
!   Calculate thermodynamical quantities
!
!   02-apr-04/tony: implemented dummy
!
      integer, intent(in) :: ivars
      real, intent(in) :: var1,var2
      real, intent(out), optional :: lnrho,ss
      real, intent(out), optional :: yH,lnTT
      real, intent(out), optional :: ee,pp
!
!
      call fatal_error('eoscalc_point','SHOULD NOT BE CALLED WITH NOEOS')

      if (present(lnrho)) lnrho=0.
      if (present(ss)) ss=0.
      if (present(yH)) yH=impossible
      if (present(lnTT)) lnTT=0.
      if (present(ee)) ee=0.
      if (present(pp)) pp=0.
      if (NO_WARN) print*,ivars,var1,var2  !(keep compiler quiet)
!
    endsubroutine eoscalc_point
!***********************************************************************
    subroutine eoscalc_pencil(ivars,var1,var2,lnrho,ss,yH,lnTT,ee,pp)
!
!   Calculate thermodynamical quantities
!
!   2-feb-03/axel: simple example coded
!   13-jun-03/tobi: the ionization fraction as part of the f-array
!                   now needs to be given as an argument as input
!   17-nov-03/tobi: moved calculation of cs2 and cp1tilde to
!                   subroutine pressure_gradient
!
      integer, intent(in) :: ivars
      real, dimension(nx), intent(in) :: var1,var2
      real, dimension(nx), intent(out), optional :: lnrho,ss
      real, dimension(nx), intent(out), optional :: yH,lnTT
      real, dimension(nx), intent(out), optional :: ee,pp
!
!
      call fatal_error('eoscalc_pencil','SHOULD NOT BE CALLED WITH NOEOS')

      if (present(lnrho)) lnrho=0.
      if (present(ss)) ss=0.
      if (present(yH)) yH=impossible
      if (present(lnTT)) lnTT=0.
      if (present(ee)) ee=0.
      if (present(pp)) pp=0.
      if (NO_WARN) print*,ivars,var1,var2  !(keep compiler quiet)
!
    endsubroutine eoscalc_pencil
!***********************************************************************
    subroutine get_soundspeed(lnTT,cs2)
!
!  Calculate sound speed for given temperature
!
!  02-apr-04/tony: dummy coded
!
      real, intent(in)  :: lnTT
      real, intent(out) :: cs2
!
      call not_implemented('get_soundspeed')
      cs2=0.
      if (NO_WARN) print*,lnTT
!
    end subroutine get_soundspeed
!***********************************************************************
    subroutine units_eos()
!
!  dummy: here we don't allow for inputting cp.
!
    endsubroutine units_eos
!***********************************************************************
    subroutine read_eos_init_pars(unit,iostat)

      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read (unit,NML=eos_init_pars,ERR=99, IOSTAT=iostat)
      else
        read (unit,NML=eos_init_pars,ERR=99)
      endif

99    return

    endsubroutine read_eos_init_pars
!***********************************************************************
    subroutine write_eos_init_pars(unit)

      integer, intent(in) :: unit

      write (unit,NML=eos_init_pars)

    endsubroutine write_eos_init_pars
!***********************************************************************
    subroutine read_eos_run_pars(unit,iostat)

      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read (unit,NML=eos_run_pars,ERR=99, IOSTAT=iostat)
      else
        read (unit,NML=eos_run_pars,ERR=99)
      endif

99    return

    endsubroutine read_eos_run_pars
!***********************************************************************
    subroutine write_eos_run_pars(unit)

      integer, intent(in) :: unit

      write (unit,NML=eos_run_pars)

    endsubroutine write_eos_run_pars
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
      real, dimension(mx,my,mz,mvar+maux), intent(inout) :: f
      real, intent(in) :: T0
      real, dimension(nx) :: lnrho,ss
      real :: ss_offset=0.
!
!  if T0 is different from unity, we interpret
!  ss_offset = ln(T0)/gamma as an additive offset of ss
!
      if (T0/=1.) ss_offset=alog(T0)/gamma
!
      do n=n1,n2
      do m=m1,m2
        lnrho=f(l1:l2,m,n,ilnrho)
        ss=-gamma1*(lnrho-lnrho0)/gamma
          !+ other terms for sound speed not equal to cs_0
        f(l1:l2,m,n,iss)=ss+ss_offset
      enddo
      enddo
!
!  cs2 values at top and bottom may be needed to boundary conditions.
!  The values calculated here may be revised in the entropy module.
!
      cs2bot=cs20
      cs2top=cs20
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
      use Gravity
!
      real, intent(in) :: Fheat, FheatK, hcond0, hcond1, chi
      logical, intent(in) :: lmultilayer, lcalc_heatcond_constchi
      
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my) :: tmp_xy,cs2_xy,rho_xy
      integer :: i
      
!
      if(ldebug) print*,'bc_ss_flux: ENTER - cs20,cs0=',cs20,cs0
!
!  Do the `c1' boundary condition (constant heat flux) for entropy.
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!  ===============
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
        cs2_xy=cs20*exp(gamma1*(f(:,:,n1,ilnrho)-lnrho0)+gamma*f(:,:,n1,iss))
!
!  check whether we have chi=constant at bottom, in which case
!  we have the nonconstant rho_xy*chi in tmp_xy. 
!
        if(lcalc_heatcond_constchi) then
          tmp_xy=Fheat/(rho_xy*chi*cs2_xy)
        else
          tmp_xy=FheatK/cs2_xy
        endif
!
!  enforce ds/dz + gamma1/gamma*dlnrho/dz = - gamma1/gamma*Fbot/(K*cs2)
!
        do i=1,nghost
          f(:,:,n1-i,iss)=f(:,:,n1+i,iss)+gamma1/gamma* &
              (f(:,:,n1+i,ilnrho)-f(:,:,n1-i,ilnrho)+2*i*dz*tmp_xy)
        enddo
!
!  top boundary
!  ============
!
      case('top')
        if (lmultilayer) then
          if(headtt) print*,'bc_ss_flux: Ftop,hcond=',Fheat,hcond0*hcond1
        else
          if(headtt) print*,'bc_ss_flux: Ftop,hcond=',Fheat,hcond0
        endif
!
!  calculate Ftop/(K*cs2)
!
        rho_xy=exp(f(:,:,n2,ilnrho))
        cs2_xy=cs20*exp(gamma1*(f(:,:,n2,ilnrho)-lnrho0)+gamma*f(:,:,n2,iss))
!
!  check whether we have chi=constant at bottom, in which case
!  we have the nonconstant rho_xy*chi in tmp_xy. 
!
        if(lcalc_heatcond_constchi) then
          tmp_xy=Fheat/(rho_xy*chi*cs2_xy)
        else
          tmp_xy=FheatK/cs2_xy
        endif
!
!  enforce ds/dz + gamma1/gamma*dlnrho/dz = - gamma1/gamma*Fbot/(K*cs2)
!
        do i=1,nghost
          f(:,:,n2+i,iss)=f(:,:,n2-i,iss)+gamma1/gamma* &
              (f(:,:,n2-i,ilnrho)-f(:,:,n2+i,ilnrho)-2*i*dz*tmp_xy)
        enddo
      case default
        call fatal_error('bc_ss_flux','invalid argument')
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
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my) :: tmp_xy
      integer :: i
!
      if(ldebug) print*,'bc_ss_temp_old: ENTER - cs20,cs0=',cs20,cs0
!
!  Do the `c2' boundary condition (fixed temperature/sound speed) for entropy.
!  This assumes that the density is already set (ie density must register
!  first!)
!  tmp_xy = s(x,y) on the boundary.
!  gamma*s/cp = [ln(cs2/cs20)-(gamma-1)ln(rho/rho0)]
!
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('bot')
        if ((bcz1(ilnrho) /= 'a2') .and. (bcz1(ilnrho) /= 'a3')) &
          call fatal_error('bc_ss_temp_old','Inconsistent boundary conditions 3.')
        if (ldebug) print*, &
                'bc_ss_temp_old: set bottom temperature: cs2bot=',cs2bot
        if (cs2bot<=0.) &
              print*,'bc_ss_temp_old: cannot have cs2bot<=0'
        tmp_xy = (-gamma1*(f(:,:,n1,ilnrho)-lnrho0) &
             + alog(cs2bot/cs20)) / gamma
        f(:,:,n1,iss) = tmp_xy
        do i=1,nghost
          f(:,:,n1-i,iss) = 2*tmp_xy - f(:,:,n1+i,iss)
        enddo
 
!
!  top boundary
!
      case('top')
        if ((bcz1(ilnrho) /= 'a2') .and. (bcz1(ilnrho) /= 'a3')) &
          call fatal_error('bc_ss_temp_old','Inconsistent boundary conditions 3.')
        if (ldebug) print*, &
                   'bc_ss_temp_old: set top temperature - cs2top=',cs2top
        if (cs2top<=0.) print*, &
                   'bc_ss_temp_old: cannot have cs2top<=0'
  !     if (bcz1(ilnrho) /= 'a2') &
  !          call fatal_error(bc_ss_temp_old','Inconsistent boundary conditions 4.')
        tmp_xy = (-gamma1*(f(:,:,n2,ilnrho)-lnrho0) &
                 + alog(cs2top/cs20)) / gamma
        f(:,:,n2,iss) = tmp_xy
        do i=1,nghost
          f(:,:,n2+i,iss) = 2*tmp_xy - f(:,:,n2-i,iss)
        enddo 
      case default
        call fatal_error('bc_ss_temp_old','invalid argument')
      endselect
!
    endsubroutine bc_ss_temp_old
!***********************************************************************
    subroutine bc_ss_temp_x(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real :: tmp
      integer :: i
!
      if(ldebug) print*,'bc_ss_temp_x: cs20,cs0=',cs20,cs0
!
!  Constant temperature/sound speed for entropy, i.e. antisymmetric
!  ln(cs2) relative to cs2top/cs2bot.
!  This assumes that the density is already set (ie density _must_ register
!  first!)
!
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('bot')
        if (ldebug) print*, &
                   'bc_ss_temp_x: set x bottom temperature: cs2bot=',cs2bot
        if (cs2bot<=0.) print*, &
                   'bc_ss_temp_x: cannot have cs2bot<=0'
        tmp = 2/gamma*alog(cs2bot/cs20)
        f(l1,:,:,iss) = 0.5*tmp - gamma1/gamma*(f(l1,:,:,ilnrho)-lnrho0)
        do i=1,nghost
          f(l1-i,:,:,iss) = -f(l1+i,:,:,iss) + tmp &
               - gamma1/gamma*(f(l1+i,:,:,ilnrho)+f(l1-i,:,:,ilnrho)-2*lnrho0)
        enddo
!
!  top boundary
!
      case('top')
        if (ldebug) print*, &
                       'bc_ss_temp_x: set x top temperature: cs2top=',cs2top
        if (cs2top<=0.) print*, &
                       'bc_ss_temp_x: cannot have cs2top<=0'
        tmp = 2/gamma*alog(cs2top/cs20)
        f(l2,:,:,iss) = 0.5*tmp - gamma1/gamma*(f(l2,:,:,ilnrho)-lnrho0)
        do i=1,nghost
          f(l2+i,:,:,iss) = -f(l2-i,:,:,iss) + tmp &
               - gamma1/gamma*(f(l2-i,:,:,ilnrho)+f(l2+i,:,:,ilnrho)-2*lnrho0)
        enddo

      case default
        call fatal_error('bc_ss_temp_x','invalid argument')
      endselect
      

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
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real :: tmp
      integer :: i
!
      if(ldebug) print*,'bc_ss_temp_y: cs20,cs0=',cs20,cs0
!
!  Constant temperature/sound speed for entropy, i.e. antisymmetric
!  ln(cs2) relative to cs2top/cs2bot.
!  This assumes that the density is already set (ie density _must_ register
!  first!)
!
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('bot')
        if (ldebug) print*, &
                   'bc_ss_temp_y: set y bottom temperature - cs2bot=',cs2bot
        if (cs2bot<=0.) print*, &
                   'bc_ss_temp_y: cannot have cs2bot<=0'
        tmp = 2/gamma*alog(cs2bot/cs20)
        f(:,m1,:,iss) = 0.5*tmp - gamma1/gamma*(f(:,m1,:,ilnrho)-lnrho0)
        do i=1,nghost
          f(:,m1-i,:,iss) = -f(:,m1+i,:,iss) + tmp &
               - gamma1/gamma*(f(:,m1+i,:,ilnrho)+f(:,m1-i,:,ilnrho)-2*lnrho0)
        enddo
!
!  top boundary
!
      case('top')
        if (ldebug) print*, &
                     'bc_ss_temp_y: set y top temperature - cs2top=',cs2top
        if (cs2top<=0.) print*, &
                     'bc_ss_temp_y: cannot have cs2top<=0'
        tmp = 2/gamma*alog(cs2top/cs20)
        f(:,m2,:,iss) = 0.5*tmp - gamma1/gamma*(f(:,m2,:,ilnrho)-lnrho0)
        do i=1,nghost
          f(:,m2+i,:,iss) = -f(:,m2-i,:,iss) + tmp &
               - gamma1/gamma*(f(:,m2-i,:,ilnrho)+f(:,m2+i,:,ilnrho)-2*lnrho0)
        enddo

      case default
        call fatal_error('bc_ss_temp_y','invalid argument')
      endselect
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
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real :: tmp
      integer :: i
!
      if(ldebug) print*,'bc_ss_temp_z: cs20,cs0=',cs20,cs0
!
!  Constant temperature/sound speed for entropy, i.e. antisymmetric
!  ln(cs2) relative to cs2top/cs2bot.
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
        if (ldebug) print*, &
                   'bc_ss_temp_z: set z bottom temperature: cs2bot=',cs2bot
        if (cs2bot<=0.) print*, &
                   'bc_ss_temp_z: cannot have cs2bot<=0'
        tmp = 2/gamma*alog(cs2bot/cs20)
        f(:,:,n1,iss) = 0.5*tmp - gamma1/gamma*(f(:,:,n1,ilnrho)-lnrho0)
        do i=1,nghost
          f(:,:,n1-i,iss) = -f(:,:,n1+i,iss) + tmp &
               - gamma1/gamma*(f(:,:,n1+i,ilnrho)+f(:,:,n1-i,ilnrho)-2*lnrho0)
        enddo
!
!  top boundary
!
      case('top')
        if (ldebug) print*, &
                     'bc_ss_temp_z: set z top temperature: cs2top=',cs2top
        if (cs2top<=0.) print*,'bc_ss_temp_z: cannot have cs2top<=0'
        tmp = 2/gamma*alog(cs2top/cs20)
        f(:,:,n2,iss) = 0.5*tmp - gamma1/gamma*(f(:,:,n2,ilnrho)-lnrho0)
        do i=1,nghost
          f(:,:,n2+i,iss) = -f(:,:,n2-i,iss) + tmp &
               - gamma1/gamma*(f(:,:,n2-i,ilnrho)+f(:,:,n2+i,ilnrho)-2*lnrho0)
        enddo
      case default
        call fatal_error('bc_ss_temp_z','invalid argument')
      endselect
!
    endsubroutine bc_ss_temp_z
!***********************************************************************
    subroutine bc_lnrho_temp_z(f,topbot)
!
!  boundary condition for lnrho *and* ss: constant temperature
!
!  27-sep-2002/axel: coded
!  19-aug-2005/tobi: distributed across ionization modules
!
      use Cdata
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real :: tmp
      integer :: i
!
      if(ldebug) print*,'bc_lnrho_temp_z: cs20,cs0=',cs20,cs0
!
!  Constant temperature/sound speed for entropy, i.e. antisymmetric
!  ln(cs2) relative to cs2top/cs2bot.
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
        if (ldebug) print*, &
                 'bc_lnrho_temp_z: set z bottom temperature: cs2bot=',cs2bot
        if (cs2bot<=0. .and. lroot) print*, &
                 'bc_lnrho_temp_z: cannot have cs2bot<=0'
        tmp = 2/gamma*log(cs2bot/cs20)
!
!  set boundary value for entropy, then extrapolate ghost pts by antisymmetry
!
        f(:,:,n1,iss) = 0.5*tmp - gamma1/gamma*(f(:,:,n1,ilnrho)-lnrho0)
        do i=1,nghost; f(:,:,n1-i,iss) = 2*f(:,:,n1,iss)-f(:,:,n1+i,iss); enddo
!
!  set density in the ghost zones so that dlnrho/dz + ds/dz = gz/cs2bot
!  for the time being, we don't worry about lnrho0 (assuming that it is 0)
!
        tmp=-gravz/cs2bot
        do i=1,nghost
          f(:,:,n1-i,ilnrho) = f(:,:,n1+i,ilnrho) +f(:,:,n1+i,iss) &
                                                  -f(:,:,n1-i,iss) +2*i*dz*tmp
        enddo
!
!  top boundary
!
      case('top')
        if (ldebug) print*, &
                    'bc_lnrho_temp_z: set z top temperature: cs2top=',cs2top
        if (cs2top<=0. .and. lroot) print*, &
                    'bc_lnrho_temp_z: cannot have cs2top<=0'
        tmp = 2/gamma*log(cs2top/cs20)
!
!  set boundary value for entropy, then extrapolate ghost pts by antisymmetry
!
        f(:,:,n2,iss) = 0.5*tmp - gamma1/gamma*(f(:,:,n2,ilnrho)-lnrho0)
        do i=1,nghost; f(:,:,n2+i,iss) = 2*f(:,:,n2,iss)-f(:,:,n2-i,iss); enddo
!
!  set density in the ghost zones so that dlnrho/dz + ds/dz = gz/cs2top
!  for the time being, we don't worry about lnrho0 (assuming that it is 0)
!
        tmp=gravz/cs2top
        do i=1,nghost
          f(:,:,n2+i,ilnrho) = f(:,:,n2-i,ilnrho) +f(:,:,n2-i,iss) &
                                                  -f(:,:,n2+i,iss) +2*i*dz*tmp
        enddo

      case default
        call fatal_error('bc_lnrho_temp_z','invalid argument')
      endselect
!
    endsubroutine bc_lnrho_temp_z
!***********************************************************************
    subroutine bc_lnrho_pressure_z(f,topbot)
!
!  boundary condition for lnrho: constant pressure
!
!   4-apr-2003/axel: coded
!   1-may-2003/axel: added the same for top boundary
!  19-aug-2005/tobi: distributed across ionization modules
!
      use Cdata
      use Gravity, only: lnrho_bot,lnrho_top,ss_bot,ss_top
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: i
!
      if(ldebug) print*,'bc_lnrho_pressure_z: cs20,cs0=',cs20,cs0
!
!  Constant pressure, i.e. antisymmetric
!  This assumes that the entropy is already set (ie density _must_ register
!  first!)
!
!  check whether we want to do top or bottom (this is processor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('top')
        if (ldebug) print*,'bc_lnrho_pressure_z: lnrho_top,ss_top=',lnrho_top,ss_top
!
!  fix entropy if inflow (uz>0); otherwise leave s unchanged
!  afterwards set s antisymmetrically about boundary value
!
        if(lentropy) then
!         do m=m1,m2
!         do l=l1,l2
!           if (f(l,m,n1,iuz)>=0) then
!             f(l,m,n1,iss)=ss_bot
!           else
!             f(l,m,n1,iss)=f(l,m,n1+1,iss)
!           endif
!         enddo
!         enddo
          f(:,:,n2,iss)=ss_top
          do i=1,nghost; f(:,:,n2+i,iss)=2*f(:,:,n2,iss)-f(:,:,n2-i,iss); enddo
!
!  set density value such that pressure is constant at the bottom
!
          f(:,:,n2,ilnrho)=lnrho_top+ss_top-f(:,:,n2,iss)
        else
          f(:,:,n2,ilnrho)=lnrho_top
        endif
!
!  make density antisymmetric about boundary
!  another possibility might be to enforce hydrostatics
!  ie to set dlnrho/dz=-g/cs^2, assuming zero entropy gradient
!
        do i=1,nghost
          f(:,:,n2+i,ilnrho)=2*f(:,:,n2,ilnrho)-f(:,:,n2-i,ilnrho)
        enddo
!
!  top boundary
!
      case('bot')
        if (ldebug) print*,'bc_lnrho_pressure_z: lnrho_bot,ss_bot=',lnrho_bot,ss_bot
!
!  fix entropy if inflow (uz>0); otherwise leave s unchanged
!  afterwards set s antisymmetrically about boundary value
!
        if(lentropy) then
!         do m=m1,m2
!         do l=l1,l2
!           if (f(l,m,n1,iuz)>=0) then
!             f(l,m,n1,iss)=ss_bot
!           else
!             f(l,m,n1,iss)=f(l,m,n1+1,iss)
!           endif
!         enddo
!         enddo
          f(:,:,n1,iss)=ss_bot
          do i=1,nghost; f(:,:,n1-i,iss)=2*f(:,:,n1,iss)-f(:,:,n1+i,iss); enddo
!
!  set density value such that pressure is constant at the bottom
!
          f(:,:,n1,ilnrho)=lnrho_bot+ss_bot-f(:,:,n1,iss)
        else
          f(:,:,n1,ilnrho)=lnrho_bot
        endif
!
!  make density antisymmetric about boundary
!  another possibility might be to enforce hydrostatics
!  ie to set dlnrho/dz=-g/cs^2, assuming zero entropy gradient
!
        do i=1,nghost
          f(:,:,n1-i,ilnrho)=2*f(:,:,n1,ilnrho)-f(:,:,n1+i,ilnrho)
        enddo
!
      case default
        call fatal_error('bc_lnrho_pressure_z','invalid argument')
      endselect
!
    endsubroutine bc_lnrho_pressure_z
!***********************************************************************
    subroutine bc_ss_temp2_z(f,topbot)
!
!  boundary condition for entropy: constant temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real :: tmp
      integer :: i
!
      if(ldebug) print*,'bc_ss_temp2_z: cs20,cs0=',cs20,cs0
!
!  Constant temperature/sound speed for entropy, i.e. antisymmetric
!  ln(cs2) relative to cs2top/cs2bot.
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
        if (ldebug) print*, &
                   'bc_ss_temp2_z: set z bottom temperature: cs2bot=',cs2bot
        if (cs2bot<=0.) print*, &
                   'bc_ss_temp2_z: cannot have cs2bot<=0'
        tmp = 1/gamma*alog(cs2bot/cs20)
        do i=0,nghost
          f(:,:,n1-i,iss) = tmp &
               - gamma1/gamma*(f(:,:,n1-i,ilnrho)-lnrho0)
        enddo
!
!  top boundary
!
      case('top')
        if (ldebug) print*, &
                     'bc_ss_temp2_z: set z top temperature: cs2top=',cs2top
        if (cs2top<=0.) print*,'bc_ss_temp2_z: cannot have cs2top<=0'
        tmp = 1/gamma*alog(cs2top/cs20)
        do i=0,nghost
          f(:,:,n2+i,iss) = tmp &
               - gamma1/gamma*(f(:,:,n2+i,ilnrho)-lnrho0)
        enddo
      case default
        call fatal_error('bc_ss_temp2_z','invalid argument')
      endselect
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
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: i
!
      if(ldebug) print*,'bc_ss_stemp_x: cs20,cs0=',cs20,cs0
!
!  Symmetric temperature/sound speed for entropy.
!  This assumes that the density is already set (ie density _must_ register
!  first!)
!
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('bot')
        if (cs2bot<=0.) print*, &
                        'bc_ss_stemp_x: cannot have cs2bot<=0'
        do i=1,nghost
          f(l1-i,:,:,iss) = f(l1+i,:,:,iss) &
               + gamma1/gamma*(f(l1+i,:,:,ilnrho)-f(l1-i,:,:,ilnrho))
        enddo
!
!  top boundary
!
      case('top')
        if (cs2top<=0.) print*, &
                        'bc_ss_stemp_x: cannot have cs2top<=0'
        do i=1,nghost
          f(l2+i,:,:,iss) = f(l2-i,:,:,iss) &
               + gamma1/gamma*(f(l2-i,:,:,ilnrho)-f(l2+i,:,:,ilnrho))
        enddo

      case default
        call fatal_error('bc_ss_stemp_x','invalid argument')
      endselect
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
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: i
!
      if(ldebug) print*,'bc_ss_stemp_y: cs20,cs0=',cs20,cs0
!
!  Symmetric temperature/sound speed for entropy.
!  This assumes that the density is already set (ie density _must_ register
!  first!)
!
!  check whether we want to do top or bottom (this is precessor dependent)
!
      select case(topbot)
!
!  bottom boundary
!
      case('bot')
        if (cs2bot<=0.) print*, &
                       'bc_ss_stemp_y: cannot have cs2bot<=0'
        do i=1,nghost
          f(:,m1-i,:,iss) = f(:,m1+i,:,iss) &
               + gamma1/gamma*(f(:,m1+i,:,ilnrho)-f(:,m1-i,:,ilnrho))
        enddo
!
!  top boundary
!
      case('top')
        if (cs2top<=0.) print*, &
                       'bc_ss_stemp_y: cannot have cs2top<=0'
        do i=1,nghost
          f(:,m2+i,:,iss) = f(:,m2-i,:,iss) &
               + gamma1/gamma*(f(:,m2-i,:,ilnrho)-f(:,m2+i,:,ilnrho))
        enddo

      case default
        call fatal_error('bc_ss_stemp_y','invalid argument')
      endselect
!

    endsubroutine bc_ss_stemp_y
!***********************************************************************
    subroutine bc_ss_stemp_z(f,topbot)
!
!  boundary condition for entropy: symmetric temperature
!
!   3-aug-2002/wolf: coded
!  26-aug-2003/tony: distributed across ionization modules
!
      use Gravity
!
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      integer :: i
!
      if(ldebug) print*,'bc_ss_stemp_z: cs20,cs0=',cs20,cs0
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
          if (cs2bot<=0.) print*, &
                                  'bc_ss_stemp_z: cannot have cs2bot<=0'
          do i=1,nghost
             f(:,:,n1-i,iss) = f(:,:,n1+i,iss) &
                  + gamma1/gamma*(f(:,:,n1+i,ilnrho)-f(:,:,n1-i,ilnrho))
          enddo
!
!  top boundary
!
      case('top')
        if (cs2top<=0.) print*, &
                 'bc_ss_stemp_z: cannot have cs2top<=0'
         do i=1,nghost
           f(:,:,n2+i,iss) = f(:,:,n2-i,iss) &
                + gamma1/gamma*(f(:,:,n2-i,ilnrho)-f(:,:,n2+i,ilnrho))
         enddo
      case default
        call fatal_error('bc_ss_stemp_z','invalid argument')
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
      character (len=3) :: topbot
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my) :: cs2_2d
      integer :: i
!
!  The 'ce' boundary condition for entropy makes the energy constant at
!  the boundaries.
!  This assumes that the density is already set (ie density must register
!  first!)
!
    select case(topbot)
!
! Bottom boundary
!
    case('bot')
      !  Set cs2 (temperature) in the ghost points to the value on
      !  the boundary
      !
      cs2_2d=cs20*exp(gamma1*f(:,:,n1,ilnrho)+gamma*f(:,:,n1,iss))
      do i=1,nghost
         f(:,:,n1-i,iss)=1./gamma*(-gamma1*f(:,:,n1-i,ilnrho)-log(cs20)&
              +log(cs2_2d))
      enddo

!
! Top boundary
!
    case('top')
      !  Set cs2 (temperature) in the ghost points to the value on
      !  the boundary
      !
      cs2_2d=cs20*exp(gamma1*f(:,:,n2,ilnrho)+gamma*f(:,:,n2,iss))
      do i=1,nghost
         f(:,:,n2+i,iss)=1./gamma*(-gamma1*f(:,:,n2+i,ilnrho)-log(cs20)&
              +log(cs2_2d))
      enddo
    case default
      call fatal_error('bc_ss_energy','invalid argument')
    endselect

    end subroutine bc_ss_energy
!***********************************************************************
    subroutine bc_stellar_surface(f,topbot)
!
!  Boundary condition for density.
!
!  We make both the lower and the upper boundary hydrostatic.
!    rho1*(dpp/dz) = gravz
!
!  Additionally, we make the lower boundary isentropic
!    (dss/dz) = 0
!  and the upper boundary isothermal
!    (dlnTT/dz) = 0
!
!  At the moment, this is probably only useful for solar surface convection.
!
!
!  11-May-2006/tobi: coded
!  16-May-2006/tobi: isentropic lower boundary
!
      use Gravity, only: gravz,grav_profile,reduced_top

      real, dimension (mx,my,mz,mvar+maux), intent (inout) :: f
      character (len=3), intent (in) :: topbot

      real, dimension (mx,my) :: rho1,TT1
      real, dimension (mx,my) :: rhs,sqrtrhs,yH
      real, dimension (mx,my) :: mu1,rho1pp
      real, dimension (mx,my) :: yH_term_cv,yH_term_cp
      real, dimension (mx,my) :: TT_term_cv,TT_term_cp
      real, dimension (mx,my) :: alpha,delta
      real, dimension (mx,my) :: cv,cp,cs2,nabla_ad
      real, dimension (mx,my) :: dlnrhodz,dlnTTdz
      real :: fac
      integer :: i,j

      select case (topbot)

!
!  Bottom boundary
!
      case ('bot')

!
!  Boundary condition for density and temperature
!
        if (bcz1(ilnTT)/='StS'.and.bcz1(ilnTT)/='') then
          call fatal_error("bc_stellar_surface", &
                           "This boundary condition for density also sets "// &
                           "temperature. We therfore require "// &
                           "bcz1(ilnTT)='StS' or bcz1(ilnTT)=''")
        endif

!
!  Get variables from f-array
!
        rho1 = exp(-f(:,:,n1,ilnrho))
        TT1 = exp(-f(:,:,n1,ilnTT))

!
!  Hydrogen ionization fraction
!
        rhs = rho_e*rho1*(TT1*TT_ion)**(-1.5)*exp(-TT_ion*TT1)
        sqrtrhs = sqrt(rhs)
        yH = 2*sqrtrhs/(sqrtrhs+sqrt(4+rhs))

!
!  Inverse mean molecular weight
!
        mu1 = mu1_0*(1 + yH + xHe)

!
!  Pressure over density
!
        rho1pp = Rgas*mu1/TT1

!
!  Abreviations
!
        yH_term_cv = yH*(1-yH)/((2-yH)*(1+yH+xHe))
        TT_term_cv = 1.5 + TT_ion*TT1

        yH_term_cp = yH*(1-yH)/(2+xHe*(2-yH))
        TT_term_cp = 2.5 + TT_ion*TT1

!
!  Specific heats in units of Rgas/mu
!
        cv = 1.5 + yH_term_cv*TT_term_cv**2
        cp = 2.5 + yH_term_cp*TT_term_cp**2

!
!  See Kippenhahn & Weigert
!
        alpha = ((2-yH)*(1+yH+xHe))/(2+xHe*(2-yH))
        delta = 1 + yH_term_cp*TT_term_cp

!
!  Speed of sound
!
        cs2 = cp*rho1pp/(alpha*cv)

!
!  Adiabatic pressure gradient
!
        nabla_ad = delta/cp

!
!  z-derivatives of density and temperature on the boundary
!
        dlnrhodz = gravz/cs2
        dlnTTdz = (nabla_ad/rho1pp)*gravz

!
!  Fill ghost zones accordingly
!
        do i=1,nghost
          f(:,:,n1-i,ilnrho) = f(:,:,n1+i,ilnrho) - 2*i*dz*dlnrhodz
          f(:,:,n1-i,ilnTT)  = f(:,:,n1+i,ilnTT)  - 2*i*dz*dlnTTdz
        enddo

!
!  Top boundary
!
      case ('top')

!
!  Boundary condition for density, temperature, and vector potential
!
        if (bcz2(ilnTT)/='StS'.and.bcz2(ilnTT)/='') then
          call fatal_error("bc_stellar_surface", &
                           "This boundary condition for density also sets "// &
                           "temperature. We therfore require "// &
                           "bcz2(ilnTT)='StS' or bcz2(ilnTT)=''")
        endif

!
!  Get variables from f-array
!
        rho1 = exp(-f(:,:,n2,ilnrho))
        TT1 = exp(-f(:,:,n2,ilnTT))

!
!  `Effective' gravitational acceleration (geff = gravz - rho1*dz1ppm)
!
        if (grav_profile=='reduced') then
          fac = reduced_top
        else
          fac = 1.0
        endif

!
!  Hydrogen ionization fraction
!
        rhs = rho_e*rho1*(TT1*TT_ion)**(-1.5)*exp(-TT_ion*TT1)
        sqrtrhs = sqrt(rhs)
        yH = 2*sqrtrhs/(sqrtrhs+sqrt(4+rhs))

!
!  Inverse mean molecular weight
!
        mu1 = mu1_0*(1 + yH + xHe)

!
!  Pressure over density
!
        rho1pp = Rgas*mu1/TT1

!
!  Pressure derivative
!
        alpha = ((2-yH)*(1+yH+xHe))/(2+xHe*(2-yH))

!
!  z-derivatives of density on the boundary
!
        dlnrhodz = fac*gravz*alpha/rho1pp

!
!  Fill ghost zones accordingly
!
        do i=1,nghost
          f(:,:,n2+i,ilnrho) = f(:,:,n2-i,ilnrho) + 2*i*dz*dlnrhodz
          f(:,:,n2+i,ilnTT) = f(:,:,n2-i,ilnTT)
        enddo

      case default

      endselect

    end subroutine bc_stellar_surface
!***********************************************************************
    subroutine bc_stellar_surface_2(f,topbot,df)
!
!  Boundary condition for density.
!
!  We make both the lower and the upper boundary hydrostatic.
!    rho1*(dpp/dz) = gravz
!
!  Additionally, we make the lower boundary isentropic
!    (dss/dz) = 0
!  and the upper boundary isothermal
!    (dlnTT/dz) = 0
!
!  At the moment, this is probably only useful for solar surface convection.
!
!
!  11-May-2006/tobi: coded
!  16-May-2006/tobi: isentropic lower boundary
!
      use Gravity, only: gravz
      use Sub, only: curl_mn,cross_mn,gij,bij_etc
      use Global, only: get_global

      real, dimension (mx,my,mz,mvar+maux), intent (inout) :: f
      character (len=3), intent (in) :: topbot
      real, dimension (mx,my,mz,mvar), optional :: df

      real, dimension (mx,my) :: lnrho,lnTT,rho1,TT1,uz
      real, dimension (mx,my) :: rhs,sqrtrhs,yH
      real, dimension (mx,my) :: mu1,rho1pp
      real, dimension (mx,my) :: yH_term_cv,yH_term_cp
      real, dimension (mx,my) :: TT_term_cv,TT_term_cp
      real, dimension (mx,my) :: dlnppdlnrho
      real, dimension (mx,my) :: dlnrhodz,dlnTTdz,dlnppdz,dssdz
      real, dimension (mx,my) :: dlnpp,dss
      real, dimension (mx,my) :: cv,cp,cs2,nabla_ad,alpha,delta,gamma
      real, dimension (mx,my) :: lnpp,ss,tmp
      integer, dimension (3) :: coeffs
      integer :: i,j,k

      select case (topbot)

!
!  Bottom boundary
!
      case ('bot')

        if (bcz1(ilnTT)/='sun') then
          call fatal_error("bc_stellar_surface_2", &
                           "This boundary condition for density also sets "// &
                           "temperature. We therfore require "// &
                           "bcz1(ilnTT)='sun'")
        endif

        lnrho = f(:,:,n1,ilnrho)
        lnTT = f(:,:,n1,ilnTT)
        rho1 = exp(-lnrho)
        TT1 = exp(-lnTT)

        ! Hydrogen ionization fraction
        rhs = rho_e*rho1*(TT1*TT_ion)**(-1.5)*exp(-TT_ion*TT1)
        sqrtrhs = sqrt(rhs)
        yH = 2*sqrtrhs/(sqrtrhs+sqrt(4+rhs))

        ! Mean molecular weight
        mu1 = mu1_0*(1 + yH + xHe)

        ! Pressure
        rho1pp = Rgas*mu1/TT1
        lnpp = alog(rho1pp) + lnrho
        !lnpp_bot = sum(lnpp(l1:l2,m1:m2))/(nx*ny)
        dlnpp = lnpp - lnpp_bot

        ! Entropy
        tmp = 2.5 - 1.5*(lnTT_ion-lnTT) - lnrho
        where (yH < 1) ! Neutral Hydrogen
          ss = (1-yH)*(tmp + lnrho_H - log(1-yH))
        endwhere
        where (yH > 0) ! Electrons and ionized Hydrogen
          ss = ss + yH*(tmp + lnrho_H - log(yH))
          ss = ss + yH*(tmp + lnrho_e - log(yH))
        endwhere
        ! Don't use this without Helium!
        !if (xHe > 0) then ! Helium
          ss = ss + xHe*(tmp + lnrho_He - log(xHe))
        !endif
        ss = Rgas*mu1_0*ss
        !ss_bot = maxval(ss(l1:l2,m1:m2))
        dss = ss - ss_bot

        ! Useful definitions
        yH_term_cv = yH*(1-yH)/((2-yH)*(1+yH+xHe))
        TT_term_cv = 1.5 + TT1*TT_ion
        yH_term_cp = yH*(1-yH)/(2+xHe*(2-yH))
        TT_term_cp = 2.5 + TT1*TT_ion

        ! For alpha and delta, see Kippenhahn & Weigert
        alpha = yH_term_cp/yH_term_cv
        delta = 1 + yH_term_cp*TT_term_cp
        cp = 2.5 + yH_term_cp*TT_term_cp**2
        gamma = cp/(1.5 + yH_term_cv*TT_term_cv**2)
        cs2 = gamma*rho1pp*yH_term_cv/yH_term_cp
        nabla_ad = delta/cp
        cp = Rgas*mu1*cp

        ! z-components of velocity at the bottom
        uz = f(:,:,n1,iuz)

        if (present(df)) then
          ! Add cancellation terms to rhs of the continuity and energy equation
          df(:,:,n1,ilnrho) = df(:,:,n1,ilnrho) - (dlnpp/tau_relax)*rho1pp/cs2
          df(:,:,n1,ilnTT)  = df(:,:,n1,ilnTT) - (dlnpp/tau_relax)*nabla_ad
          where (uz > 0)
            df(:,:,n1,ilnrho) = df(:,:,n1,ilnrho) &
                              + (dss/tau_relax)/(Rgas*mu1*nabla_ad)
            df(:,:,n1,ilnTT)  = df(:,:,n1,ilnTT) - (dss/tau_relax)/cp
          endwhere
        endif

        ! Coefficients for `one-sided' derivatives
        ! (anti-symmetric extrapolation with respect to the boundary
        ! value is implied)
        coeffs = (/+90,-18,+2/)*(1./60)*dz_1(n1)

        ! Initialize derivatives
        dlnppdz              = -74*(1./60)*dz_1(n1)*lnpp_bot
        where (uz > 0) dssdz = -74*(1./60)*dz_1(n1)*ss_bot

        ! Loop over the first few active zones in order to compute
        ! the z-derivative of pressure and entropy on the boundary
        do k=1,nghost

          lnrho = f(:,:,n1+k,ilnrho)
          lnTT = f(:,:,n1+k,ilnTT)
          rho1 = exp(-lnrho)
          TT1 = exp(-lnTT)

          ! Hydrogen ionization fraction
          rhs = rho_e*rho1*(TT1*TT_ion)**(-1.5)*exp(-TT_ion*TT1)
          sqrtrhs = sqrt(rhs)
          yH = 2*sqrtrhs/(sqrtrhs+sqrt(4+rhs))

          ! Mean molecular weight
          mu1 = mu1_0*(1 + yH + xHe)

          ! Logarithmic pressure
          lnpp = alog(Rgas*mu1) + lnrho + lnTT
          dlnppdz = dlnppdz + coeffs(k)*lnpp

          ! Entropy in upflow regions
          where (uz > 0)
            tmp = 2.5 - 1.5*(lnTT_ion-lnTT) - lnrho
            where (yH < 1) ! Neutral Hydrogen
              ss = (1-yH)*(tmp + lnrho_H - log(1-yH))
            endwhere
            where (yH > 0) ! Electrons and ionized Hydrogen
              ss = ss + yH*(tmp + lnrho_H - log(yH))
              ss = ss + yH*(tmp + lnrho_e - log(yH))
            endwhere
            ! Don't use this with no Helium!
            !if (xHe > 0) then ! Helium
              ss = ss + xHe*(tmp + lnrho_He - log(xHe))
            !endif
            ss = Rgas*mu1_0*ss
            dssdz = dssdz + coeffs(k)*ss
          endwhere

        enddo

        ! Ensure ientropic outflow, set pressure to pp_bot
        where (uz <= 0)
          dlnrhodz = (alpha/gamma)*dlnppdz
          dlnTTdz = nabla_ad*dlnppdz
        endwhere

        ! Set the entropy for incoming material to ss_bot,
        ! set pressure to pp_bot
        where (uz > 0)
          dlnrhodz = (alpha/gamma)*dlnppdz - delta*(dssdz/cp)
          dlnTTdz = nabla_ad*dlnppdz + dssdz/cp
        endwhere

!
!  Fill ghost zones accordingly
!
        do i=1,nghost
          f(:,:,n1-i,ilnrho) = f(:,:,n1+i,ilnrho) - 2*i*dz*dlnrhodz
          f(:,:,n1-i,ilnTT)  = f(:,:,n1+i,ilnTT)  - 2*i*dz*dlnTTdz
        enddo

!
!  Top boundary
!
      case ('top')

!
!  Get variables from f-array
!
        rho1 = exp(-f(:,:,n2,ilnrho))
        TT1 = exp(-f(:,:,n2,ilnTT))

!
!  Boundary condition for density and temperature
!
        if (bcz2(ilnTT)/='sun') then
          call fatal_error("bc_stellar_surface_2", &
                           "This boundary condition for density also sets "// &
                           "temperature. We therfore require "// &
                           "bcz2(ilnTT)='sun'")
        endif

!
!  Hydrogen ionization fraction
!
        rhs = rho_e*rho1*(TT1*TT_ion)**(-1.5)*exp(-TT_ion*TT1)
        sqrtrhs = sqrt(rhs)
        yH = 2*sqrtrhs/(sqrtrhs+sqrt(4+rhs))

!
!  Inverse mean molecular weight
!
        mu1 = mu1_0*(1 + yH + xHe)

!
!  Pressure over density
!
        rho1pp = Rgas*mu1/TT1

!
!  Pressure derivative
!
        dlnppdlnrho = 1 - yH*(1-yH)/((2-yH)*(1+yH+xHe))

!
!  z-derivatives of density on the boundary
!
        dlnrhodz = gravz/(rho1pp*dlnppdlnrho)

!
!  Fill ghost zones accordingly
!
        do i=1,nghost
          f(:,:,n2+i,ilnrho) = f(:,:,n2-i,ilnrho) + 2*i*dz*dlnrhodz
          f(:,:,n2+i,ilnTT) = f(:,:,n2-i,ilnTT)
        enddo

      case default

      endselect

    end subroutine bc_stellar_surface_2
!***********************************************************************
endmodule EquationOfState
