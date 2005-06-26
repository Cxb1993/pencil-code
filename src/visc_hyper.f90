! $Id: visc_hyper.f90,v 1.17 2005-06-26 17:34:13 eos_merger_tony Exp $

!  This modules implements viscous heating and diffusion terms
!  here for third order hyper viscosity 

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lviscosity = .true.
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 3
!
!***************************************************************

module Viscosity

  use Cparam
  use Cdata
  use Density

  implicit none

  include 'viscosity.inc'

  character (len=labellen) :: ivisc='hyper3'
  real :: maxeffectivenu,nu_mol
  logical :: lvisc_first=.false.

  ! input parameters
  !namelist /viscosity_init_pars/ dummy

  ! run parameters
  namelist /viscosity_run_pars/ nu, lvisc_first,ivisc
 
  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_epsK2=0

  ! Not implemented but needed for bodged implementation in hydro
  integer :: idiag_epsK=0

  contains

!***********************************************************************
    subroutine register_viscosity()
!
!  19-nov-02/tony: coded
!  24-nov-03/nils: adapted from visc_shock
!
      use Cdata
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_viscosity called twice')
      first = .false.
!
      lvisc_hyper = .true.
!
      ihyper = mvar + naux + 1
      naux = naux + 3
!
      if ((ip<=8) .and. lroot) then
        print*, 'register_viscosity: hyper viscosity nvar = ', nvar
        print*, 'ihyper = ', ihyper
      endif
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: visc_hyper.f90,v 1.17 2005-06-26 17:34:13 eos_merger_tony Exp $")
!
! Check we aren't registering too many auxiliary variables
!
      if (naux > maux) then
        if (lroot) write(0,*) 'naux = ', naux, ', maux = ', maux
        call stop_it('register_viscosity: naux > maux')
      endif
!
!  Writing files for use with IDL
!
      if (naux < maux) aux_var(aux_count)=',hyper $'
      if (naux == maux) aux_var(aux_count)=',hyper'
      aux_count=aux_count+3
      if (lroot) write(15,*) 'hyper = fltarr(mx,my,mz)*one'
!
    endsubroutine register_viscosity
!***********************************************************************
    subroutine initialize_viscosity(lstarting)
!
!  20-nov-02/tony: coded
!  24-nov-03/nils: adapted from visc_shock
!
      use Cdata
!
      if (headtt.and.lroot) print*,'viscosity: nu=',nu
!
       logical, intent(in) :: lstarting
!
       lneed_sij=.false.
!
        if (headtt.and.lroot.and.(.not.lstarting)) print*,'viscosity: nu=',nu

    endsubroutine initialize_viscosity
!***********************************************************************
    subroutine read_viscosity_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat).and.NO_WARN) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_viscosity_init_pars
!***********************************************************************
    subroutine write_viscosity_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine write_viscosity_init_pars
!***********************************************************************
    subroutine read_viscosity_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat)) then
        read(unit,NML=viscosity_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=viscosity_run_pars,ERR=99)
      endif
                                                                                                   
                                                                                                   
99    return
    endsubroutine read_viscosity_run_pars
!***********************************************************************
    subroutine write_viscosity_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=viscosity_run_pars)

    endsubroutine write_viscosity_run_pars
!*******************************************************************
    subroutine rprint_viscosity(lreset,lwrite)
!
!  Writes ihyper to index.pro file
!
!  24-nov-03/tony: adapted from rprint_ionization
!
      use Cdata
      use Sub
! 
      logical :: lreset
      logical, optional :: lwrite
      integer :: iname
!
!  reset everything in case of reset
!  (this needs to be consistent with what is defined above!)
!
      if (lreset) then
        idiag_epsK2=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      if(lroot.and.ip<14) print*,'rprint_viscosity: run through parse list'
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'epsK2',idiag_epsK2)
      enddo
!
!  write column where which ionization variable is stored
!
      if (present(lwrite)) then
        if (lwrite) then
          write(3,*) 'ihyper=',ihyper
          write(3,*) 'ishock=',ishock
          write(3,*) 'i_epsK2=',idiag_epsK2
        endif
      endif
!        
    endsubroutine rprint_viscosity
!***********************************************************************
    subroutine pencil_criteria_viscosity()
!    
!  All pencils that the Viscosity module depends on are specified here.
!
!  21-11-04/anders: coded
!
    endsubroutine pencil_criteria_viscosity
!***********************************************************************
    subroutine pencil_interdep_viscosity(lpencil_in)
!
!  Interdependency among pencils from the Viscosity module is specified here.
!
!  21-11-04/anders: coded
!
      use Cdata
!
      logical, dimension (npencils) :: lpencil_in
!      
      if (NO_WARN) print*, lpencil_in !(keep compiler quiet)
!
    endsubroutine pencil_interdep_viscosity
!***********************************************************************
    subroutine calc_pencils_viscosity(f,p)
!     
!  Calculate Viscosity pencils.
!  Most basic pencils should come first, as others may depend on them.
!
!  21-11-04/anders: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p
!
      intent(in) :: f,p
!
      if (NO_WARN) print*, f, p !(keep compiler quiet)
!
    endsubroutine calc_pencils_viscosity
!***********************************************************************
    subroutine calc_viscosity(f)
!
!  calculate viscous heating term for right hand side of entropy equation
!
!  24-nov-03/nils: coded
!
      use IO
      use Mpicomm
      use CData, only: lfirst
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,3) :: tmp
      real, dimension (nx,ny,nz) :: sij2,del2divu
      integer :: i,j
!
  if ((.not.lvisc_first).or.lfirst) then
      if(headt) print*,'calc_viscosity: dxmin=',dxmin
!
!  calculate grad4 grad div u
!
      if (ivisc == 'hyper3' .or. ivisc == 'hyper3.1') then
        call divgrad_2nd(f,tmp,iux)
        f(:,:,:,ihyper:ihyper+2)=tmp
        call del2v_2nd(f,tmp,ihyper)
        f(:,:,:,ihyper:ihyper+2)=tmp
        call del2v_2nd(f,tmp,ihyper)
        f(:,:,:,ihyper:ihyper+2)=tmp
      elseif (ivisc == 'hyper2') then
        call divgrad_2nd(f,tmp,iux)
        f(:,:,:,ihyper:ihyper+2)=tmp
        call del2v_2nd(f,tmp,ihyper)
        f(:,:,:,ihyper:ihyper+2)=tmp
      else
        call stop_it('calc_viscosity: no such ivisc')          
      endif
!
! find heating term (yet it only works for ivisc='hyper3')
! the heating term is d/dt(0.5*rho*u^2) = -2*mu3*( S^(2) )^2
!
      if (ldiagnos) then
        if (ivisc == 'hyper3') then
          sij2=0
          do i=1,2
            do j=i+1,3
!
! find uij and uji (stored in tmp in order to save space)
!
              call der_2nd_nof(f(:,:,:,iux+i-1),tmp(:,:,:,1),j) ! uij
              call der_2nd_nof(f(:,:,:,iux+j-1),tmp(:,:,:,2),i) ! uji
!
! find (nabla2 uij) and (nable2 uji)
!          
              call del2_2nd_nof(tmp(:,:,:,1),tmp(:,:,:,3))
              tmp(:,:,:,1)=tmp(:,:,:,3) ! nabla2 uij
              call del2_2nd_nof(tmp(:,:,:,2),tmp(:,:,:,3))
              tmp(:,:,:,2)=tmp(:,:,:,3) ! nabla2 uji
!
! find sij2 for full array
!
              sij2=sij2+tmp(l1:l2,m1:m2,n1:n2,1)*tmp(l1:l2,m1:m2,n1:n2,2) &
                   +0.5*tmp(l1:l2,m1:m2,n1:n2,1)**2 &
                   +0.5*tmp(l1:l2,m1:m2,n1:n2,2)**2 
            enddo
          enddo
!
!  add diagonal terms
!
          tmp(:,:,:,1)=0
          call shock_divu(f,tmp(:,:,:,1))                     ! divu
          call del2_2nd_nof(tmp(:,:,:,1),tmp(:,:,:,3))        ! del2(divu)
          do i=1,3
            call der_2nd_nof(f(:,:,:,iux+i-1),tmp(:,:,:,1),i) ! uii
            call del2_2nd_nof(tmp(:,:,:,1),tmp(:,:,:,2))      ! nabla2 uii
            sij2=sij2+(tmp(l1:l2,m1:m2,n1:n2,2)-tmp(l1:l2,m1:m2,n1:n2,3)/3.)**2
          enddo
!
          epsK_hyper=2*nu*sum(sij2)
        endif
      endif
!
!  max effective nu is the max of shock viscosity and the ordinary viscosity
!
      !maxeffectivenu = maxval(f(:,:,:,ihyper))*nu
  endif
!
    endsubroutine calc_viscosity
!***********************************************************************
    subroutine shock_divu(f,df)
!
!  calculate divergence of a vector U, get scalar
!  accurate to 2nd order, explicit,  centred an left and right biased 
!
!  23-nov-02/tony: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: df
!
!ajwm If using mx,my,mz do we need degenerate n(xyz)grid=1 cases??
!ajwm Much slower using partial array?
!      fac=1./(2.*dx)
      df=0.


      if (nxgrid/=1) then
         df(1     ,:,:) =  df(1    ,:,:) &
                           + (  4.*f(2,:,:,iux) &
                              - 3.*f(1,:,:,iux) &
                              -    f(3,:,:,iux))/(2.*dx)
         df(2:mx-1,:,:) =  df(2:mx-1,:,:) &
                           + ( f(3:mx,:,:,iux)-f(1:mx-2,:,:,iux) ) / (2.*dx)
         df(mx    ,:,:) =  df(mx    ,:,:) &
                           + (  3.*f(mx  ,:,:,iux) &
                              - 4.*f(mx-1,:,:,iux) &
                              +    f(mx-2,:,:,iux))/(2.*dx)
      endif

      if (nygrid/=1) then
         df(:,1     ,:) = df(:,1     ,:) &
                          + (  4.*f(:,2,:,iuy) &
                             - 3.*f(:,1,:,iuy) &
                             -    f(:,3,:,iuy))/(2.*dy)
         df(:,2:my-1,:) = df(:,2:my-1,:) &  
                          + (f(:,3:my,:,iuy)-f(:,1:my-2,:,iuy))/(2.*dy)
         df(:,my    ,:) = df(:,my    ,:) &
                          + (  3.*f(:,my  ,:,iuy) &
                             - 4.*f(:,my-1,:,iuy) &
                             +    f(:,my-2,:,iuy))/(2.*dy)
      endif

      if (nzgrid/=1) then
         df(:,:,1     ) = df(:,:,1     ) &
                          + (  4.*f(:,:,2,iuz) &
                             - 3.*f(:,:,1,iuz) &
                             -    f(:,:,3,iuz))/(2.*dz)
         df(:,:,2:mz-1) = df(:,:,2:mz-1) &
                          + (f(:,:,3:mz,iuz)-f(:,:,1:mz-2,iuz))/(2.*dz)
         df(:,:,mz    ) = df(:,:,mz    ) &
                          + (  3.*f(:,:,mz  ,iuz) &
                             - 4.*f(:,:,mz-1,iuz) &
                             +    f(:,:,mz-2,iuz))/(2.*dz)
      endif
!      
    endsubroutine shock_divu
!***********************************************************************
    subroutine calc_viscous_heat(f,df,glnrho,divu,rho1,cs2,TT1,shock,Hmax)
!
!  calculate viscous heating term for right hand side of entropy equation
!
!  20-nov-02/tony: coded
!
      use Cdata
      use Mpicomm
      use Sub

      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx) :: rho1,TT1,cs2,Hmax
      real, dimension (nx) :: sij2, divu,shock
      real, dimension (nx,3) :: glnrho
!
!  traceless strain matrix squared
!
      !call multm2(sij,sij2)
!      if (headtt) print*,'viscous heating: ',ivisc

      !df(l1:l2,m,n,iss) = df(l1:l2,m,n,iss) + TT1 * &
       !    (2.*nu*sij2  & 
        !   + nu_shock * shock * divu**2)

      !call max_for_dt(df(l1:l2,m,n,iss),maxheating)
!
      !if(NO_WARN) print*,glnrho,rho1,cs2 !(to keep compiler quiet)
!      
    endsubroutine calc_viscous_heat
!***********************************************************************
    subroutine calc_viscous_force(f,df,glnrho,divu,rho,rho1,shock,gshock,bij)
!
!  calculate viscous force
!
!  24-nov-03/nils: coded
!
      use Cdata
      use Mpicomm
      use Sub

      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (nx,3,3) :: bij
      real, dimension (nx,3) :: hyper
      real, dimension (nx,3) :: glnrho,del6u,fvisc,gshock,del4u
      real, dimension (nx) :: rho,rho1,divu,shock,ufvisc,rufvisc,murho1
      integer :: i
!
      intent (out) :: df
      intent(in) :: rho,rho1,divu,shock
!
      if (nu /= 0.) then
        if (ivisc == 'hyper3') then
          !  viscous force:nu*(del6u+del4*graddivu/3)
          !  (Assuming rho*nu=const)
          hyper=f(l1:l2,m,n,ihyper:ihyper+2)/3.
          if (headtt) print*,'viscous force: nu*(del6u+del4*graddivu/3)'
          call del6v(f,iuu,del6u)
          fvisc=nu*(del6u+hyper)
          diffus_nu=max(diffus_nu,nu*dxyz_2)
          df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+fvisc
        elseif (ivisc == 'hyper3.1') then
          !  viscous force:nu*(del6u+del4*graddivu/3)
          !  (Assuming rho*nu=const, so nu->nu*rho0/rho)
          hyper=f(l1:l2,m,n,ihyper:ihyper+2)/3.
          if (headtt) print*,'viscous force: nu*(del6u+del4*graddivu/3)'
          call del6v(f,iuu,del6u)
          murho1=(nu*rho0)*rho1
          do i=1,3
            fvisc(:,i)=murho1*(del6u(:,i)+hyper(:,i))
          enddo
          diffus_nu=max(diffus_nu,nu*dxyz_2)
          df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+fvisc
        elseif (ivisc == 'hyper2') then
          !  viscous force:nu*(del4u+del2*graddivu/3)
          !  (Assuming rho*nu=const)
          hyper=f(l1:l2,m,n,ihyper:ihyper+2)/3.
          if (headtt) print*,'viscous force: nu*(del4u+del2*graddivu/3)'
          call del4v(f,iuu,del4u)
          fvisc=nu*(del4u+hyper)
          diffus_nu=max(diffus_nu,nu*dxyz_2)
          df(l1:l2,m,n,iux:iuz)=df(l1:l2,m,n,iux:iuz)+fvisc
        else
          call stop_it('calc_viscous_force: no such ivisc')  
        endif
      else ! (nu=0)
        if (headtt.and.lroot) print*,'no viscous force: (nu=0)'
      endif
!
! Code to dobbel check epsK
!
      if (ldiagnos) then
        if (idiag_epsK2/=0) then
          call dot(f(l1:l2,m,n,iux:iuz),fvisc,ufvisc)
          rufvisc=ufvisc/rho1
          call sum_mn_name(-rufvisc,idiag_epsK2)
        endif
        !  mean heating term
        if ((idiag_epsK/=0) .or. (idiag_epsK_LES/=0)) call multm2_mn(sij,sij2)
        if ((idiag_epsK_LES/=0) .and. (ivisc .eq. 'smagorinsky_simplified')) &
        !ajwm nu_smag should already be calculated!
            call sum_mn_name(2*nu_smag* &
                              exp(f(l1:l2,m,n,ilnrho))*sij2,idiag_epsK_LES)
        if (idiag_epsK/=0) then
           call sum_mn_name(2*nu*exp(f(l1:l2,m,n,ilnrho))*sij2,idiag_epsK)
        endif
      endif
!
      if(NO_WARN) print*,divu,shock,gshock !(to keep compiler quiet)
!        
    end subroutine calc_viscous_force
!***********************************************************************
    subroutine der_2nd_nof(var,tmp,j)
!
!  24-nov-03/nils: coded
!
      use Cdata
!
      real, dimension (mx,my,mz) :: var
      real, dimension (mx,my,mz) :: tmp
      integer :: j
!
      intent (in) :: var,j
      intent (out) :: tmp
!
      tmp=0.

      if (j==1 .and. nxgrid/=1) then
          tmp(     1,:,:) = (- 3.*var(1,:,:) &
                            + 4.*var(2,:,:) &
                            - 1.*var(3,:,:))/(2.*dx) 
          tmp(2:mx-1,:,:) = (- 1.*var(1:mx-2,:,:) &
                            + 1.*var(3:mx  ,:,:))/(2.*dx) 
          tmp(    mx,:,:) = (+ 1.*var(mx-2,:,:) &
                            - 4.*var(mx-1,:,:) &
                            + 3.*var(mx  ,:,:))/(2.*dx) 
      endif
!
      if (j==2 .and. nygrid/=1) then
          tmp(:,     1,:) = (- 3.*var(:,1,:) &
                            + 4.*var(:,2,:) &
                            - 1.*var(:,3,:))/(2.*dy) 
          tmp(:,2:my-1,:) = (- 1.*var(:,1:my-2,:) &
                            + 1.*var(:,3:my  ,:))/(2.*dy) 
          tmp(:,    my,:) = (+ 1.*var(:,my-2,:) &
                            - 4.*var(:,my-1,:) &
                            + 3.*var(:,my  ,:))/(2.*dy) 
      endif
!
      if (j==3 .and. nzgrid/=1) then
          tmp(:,:,     1) = (- 3.*var(:,:,1) &
                            + 4.*var(:,:,2) &
                            - 1.*var(:,:,3))/(2.*dz) 
          tmp(:,:,2:mz-1) = (- 1.*var(:,:,1:mz-2) &
                            + 1.*var(:,:,3:mz  ))/(2.*dz) 
          tmp(:,:,    mz) = (+ 1.*var(:,:,mz-2) &
                            - 4.*var(:,:,mz-1) &
                            + 3.*var(:,:,mz  ))/(2.*dz) 
      endif
!
    end subroutine der_2nd_nof
!***********************************************************************
    subroutine del2v_2nd(f,del2f,k)
!
!  24-nov-03/nils: adapted from del2v
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,3) :: del2f
      real, dimension (mx,my,mz) :: tmp
      integer :: i,k,k1
!
      intent (in) :: f, k
      intent (out) :: del2f
!
      del2f=0.
!
!  do the del2 diffusion operator
!
      k1=k-1
      do i=1,3
        call del2_2nd(f,tmp,k1+i)
        del2f(:,:,:,i)=tmp
      enddo
!
    end subroutine del2v_2nd
!***********************************************************************
    subroutine del2_2nd(f,del2f,k)
!
!  calculate del2 of a scalar, get scalar
!  24-nov-03/nils: adapted from del2
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: del2f,d2fd
      integer :: i,k,k1
!
      intent (in) :: f, k
      intent (out) :: del2f
!
      k1=k-1
      call der2_2nd(f,d2fd,k,1)
      del2f=d2fd
      call der2_2nd(f,d2fd,k,2)
      del2f=del2f+d2fd
      call der2_2nd(f,d2fd,k,3)
      del2f=del2f+d2fd
!
    endsubroutine del2_2nd
!***********************************************************************
    subroutine del2_2nd_nof(f,del2f)
!
!  calculate del2 of a scalar, get scalar
!  same as del2_2nd but for the case where f is a scalar
!  24-nov-03/nils: adapted from del2_2nd
!
      use Cdata
!
      real, dimension (mx,my,mz) :: f
      real, dimension (mx,my,mz) :: del2f,d2fd
      integer :: i
!
      intent (in) :: f
      intent (out) :: del2f
!
      call der2_2nd_nof(f,d2fd,1)
      del2f=d2fd
      call der2_2nd_nof(f,d2fd,2)
      del2f=del2f+d2fd
      call der2_2nd_nof(f,d2fd,3)
      del2f=del2f+d2fd
!
    endsubroutine del2_2nd_nof
!***********************************************************************
    subroutine der2_2nd(f,der2f,i,j)
!
!  24-nov-03/nils: coded
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: der2f
      integer :: i,j
!
      intent (in) :: f,i,j
      intent (out) :: der2f
!
      der2f=0.
!
      if (j==1 .and. nxgrid/=1) then
        der2f(1     ,:,:) =    (+ 2.*f(1,:,:,i) &
                               - 5.*f(2,:,:,i) &
                               + 4.*f(3,:,:,i) &
                               - 1.*f(4,:,:,i) ) &
                               / (dx**2) 
        der2f(2:mx-1,:,:) =    (+ 1.*f(1:mx-2,:,:,i) &
                               - 2.*f(2:mx-1,:,:,i) &
                               + 1.*f(3:mx  ,:,:,i) ) &
                               / (dx**2) 
        der2f(mx    ,:,:) =    (+ 2.*f(mx  ,:,:,i) &
                               - 5.*f(mx-1,:,:,i) &
                               + 4.*f(mx-2,:,:,i) &
                               - 1.*f(mx-3,:,:,i) ) &
                               / (dx**2) 
      endif
!
     if (j==2 .and. nygrid/=1) then
        der2f(:,1     ,:) =    (+ 2.*f(:,1,:,i) &
                               - 5.*f(:,2,:,i) &
                               + 4.*f(:,3,:,i) &
                               - 1.*f(:,4,:,i) ) &
                               / (dy**2) 
        der2f(:,2:my-1,:) =    (+ 1.*f(:,1:my-2,:,i) &
                               - 2.*f(:,2:my-1,:,i) &
                               + 1.*f(:,3:my  ,:,i) ) &
                               / (dy**2) 
        der2f(:,my    ,:) =    (+ 2.*f(:,my  ,:,i) &
                               - 5.*f(:,my-1,:,i) &
                               + 4.*f(:,my-2,:,i) &
                               - 1.*f(:,my-3,:,i) ) &
                               / (dy**2) 
      endif
!
     if (j==3 .and. nzgrid/=1) then
        der2f(:,:,1     ) =    (+ 2.*f(:,:,1,i) &
                               - 5.*f(:,:,2,i) &
                               + 4.*f(:,:,3,i) &
                               - 1.*f(:,:,4,i) ) &
                               / (dz**2) 
        der2f(:,:,2:mz-1) =    (+ 1.*f(:,:,1:mz-2,i) &
                               - 2.*f(:,:,2:mz-1,i) &
                               + 1.*f(:,:,3:mz  ,i) ) &
                               / (dz**2) 
        der2f(:,:,mz    ) =    (+ 2.*f(:,:,mz  ,i) &
                               - 5.*f(:,:,mz-1,i) &
                               + 4.*f(:,:,mz-2,i) &
                               - 1.*f(:,:,mz-3,i) ) &
                               / (dz**2) 
      endif
!
    endsubroutine der2_2nd
!***********************************************************************
    subroutine der2_2nd_nof(f,der2f,j)
!
!  07-jan-04/nils: adapted from der2_2nd
!  same as der2_2nd but for the case where f is a scalar
!
      use Cdata
!
      real, dimension (mx,my,mz) :: f
      real, dimension (mx,my,mz) :: der2f
      integer :: j
!
      intent (in) :: f,j
      intent (out) :: der2f
!
      der2f=0.
!
      if (j==1 .and. nxgrid/=1) then
        der2f(1     ,:,:) =    (+ 2.*f(1,:,:) &
                               - 5.*f(2,:,:) &
                               + 4.*f(3,:,:) &
                               - 1.*f(4,:,:) ) &
                               / (dx**2) 
        der2f(2:mx-1,:,:) =    (+ 1.*f(1:mx-2,:,:) &
                               - 2.*f(2:mx-1,:,:) &
                               + 1.*f(3:mx  ,:,:) ) &
                               / (dx**2) 
        der2f(mx    ,:,:) =    (+ 2.*f(mx  ,:,:) &
                               - 5.*f(mx-1,:,:) &
                               + 4.*f(mx-2,:,:) &
                               - 1.*f(mx-3,:,:) ) &
                               / (dx**2) 
      endif
!
     if (j==2 .and. nygrid/=1) then
        der2f(:,1     ,:) =    (+ 2.*f(:,1,:) &
                               - 5.*f(:,2,:) &
                               + 4.*f(:,3,:) &
                               - 1.*f(:,4,:) ) &
                               / (dy**2) 
        der2f(:,2:my-1,:) =    (+ 1.*f(:,1:my-2,:) &
                               - 2.*f(:,2:my-1,:) &
                               + 1.*f(:,3:my  ,:) ) &
                               / (dy**2) 
        der2f(:,my    ,:) =    (+ 2.*f(:,my  ,:) &
                               - 5.*f(:,my-1,:) &
                               + 4.*f(:,my-2,:) &
                               - 1.*f(:,my-3,:) ) &
                               / (dy**2) 
      endif
!
     if (j==3 .and. nzgrid/=1) then
        der2f(:,:,1     ) =    (+ 2.*f(:,:,1) &
                               - 5.*f(:,:,2) &
                               + 4.*f(:,:,3) &
                               - 1.*f(:,:,4) ) &
                               / (dz**2) 
        der2f(:,:,2:mz-1) =    (+ 1.*f(:,:,1:mz-2) &
                               - 2.*f(:,:,2:mz-1) &
                               + 1.*f(:,:,3:mz  ) ) &
                               / (dz**2) 
        der2f(:,:,mz    ) =    (+ 2.*f(:,:,mz  ) &
                               - 5.*f(:,:,mz-1) &
                               + 4.*f(:,:,mz-2) &
                               - 1.*f(:,:,mz-3) ) &
                               / (dz**2) 
      endif
!
    endsubroutine der2_2nd_nof
!***********************************************************************
    subroutine divgrad_2nd(f,divgradf,k)
!
!  24-nov-03/nils: coded (should be called graddiv)
!
      use Cdata
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,3) :: divgradf
      real, dimension (mx,my,mz) :: tmp,tmp2
      integer :: k,k1
!
      intent (in) :: f, k
      intent (out) :: divgradf
!
      divgradf=0.
!
      k1=k-1
!
      call der2_2nd(f,tmp,k1+1,1)
      divgradf(:,:,:,1)=tmp
      call der_2nd_nof(f(:,:,:,k1+2),tmp,1)
      call der_2nd_nof(tmp,tmp2,2)
      divgradf(:,:,:,1)=divgradf(:,:,:,1)+tmp2
      call der_2nd_nof(f(:,:,:,k1+3),tmp,1)
      call der_2nd_nof(tmp,tmp2,3)
      divgradf(:,:,:,1)=divgradf(:,:,:,1)+tmp2
!
      call der2_2nd(f,tmp,k1+2,2)
      divgradf(:,:,:,2)=tmp
      call der_2nd_nof(f(:,:,:,k1+1),tmp,1)
      call der_2nd_nof(tmp,tmp2,2)
      divgradf(:,:,:,2)=divgradf(:,:,:,2)+tmp2
      call der_2nd_nof(f(:,:,:,k1+3),tmp,2)
      call der_2nd_nof(tmp,tmp2,3)
      divgradf(:,:,:,2)=divgradf(:,:,:,2)+tmp2
!
      call der2_2nd(f,tmp,k1+3,3)
      divgradf(:,:,:,3)=tmp
      call der_2nd_nof(f(:,:,:,k1+1),tmp,1)
      call der_2nd_nof(tmp,tmp2,3)
      divgradf(:,:,:,3)=divgradf(:,:,:,3)+tmp2
      call der_2nd_nof(f(:,:,:,k1+2),tmp,2)
      call der_2nd_nof(tmp,tmp2,3)
      divgradf(:,:,:,3)=divgradf(:,:,:,3)+tmp2
!
    endsubroutine divgrad_2nd
!***********************************************************************

endmodule Viscosity
