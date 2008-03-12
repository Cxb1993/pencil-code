! $Id: shear.f90,v 1.49 2008-03-12 17:52:36 brandenb Exp $

!  This modules deals with all aspects of shear; if no
!  shear is invoked, a corresponding replacement dummy
!  routine is used instead which absorbs all the calls to the
!  shear relevant subroutines listed in here.
!  Shear can either be given relative to Omega (using qshear),
!  or in absolute fashion via the parameters Sshear.

module Shear

  use Sub
  use Cdata
  use Messages

  implicit none

  real, dimension (nz) :: uy0_extra, duy0dz_extra
  real :: eps_vshear=0.0
  logical :: luy0_extra=.false.,lshearadvection_as_shift=.false.
  logical :: lmagnetic_stretching=.true.

  include 'shear.h'

  namelist /shear_init_pars/ &
      qshear,Sshear,deltay,eps_vshear,Omega,lshearadvection_as_shift, &
      lmagnetic_stretching

  namelist /shear_run_pars/ &
      qshear,Sshear,deltay,eps_vshear,Omega,lshearadvection_as_shift, &
      lmagnetic_stretching

  integer :: idiag_dtshear=0

  contains

!***********************************************************************
    subroutine register_shear()
!
!  Initialise variables
!
!  2-july-02/nils: coded
!
      use Mpicomm
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_shear called twice')
      first = .false.
!
      lshear = .true.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: shear.f90,v 1.49 2008-03-12 17:52:36 brandenb Exp $")
!
    endsubroutine register_shear
!***********************************************************************
    subroutine initialize_shear()
!
!  21-nov-02/tony: coded
!  08-jul-04/anders: Sshear calculated whenever qshear /= 0

!  calculate shear flow velocity; if qshear is given then Sshear=-qshear*Omega
!  is calculated. Otherwise Sshear keeps its value from the input list.
!
      if (qshear/=0.0) Sshear=-qshear*Omega
      if (lroot .and. ip<=12) &
          print*,'initialize_shear: Sshear,qshear=',Sshear,qshear
!
!  Possible to add extra rotation profile.
!
      if (eps_vshear/=0.0) then
        if (lroot) print*, 'initialize_shear: eps_vshear=', eps_vshear
        uy0_extra=Sshear*eps_vshear*Lx*cos(2*pi/Lz*z(n1:n2))
        duy0dz_extra=-Sshear*eps_vshear*Lx*sin(2*pi/Lz*z(n1:n2))*2*pi/Lz
        luy0_extra=.true.
      endif
!
    endsubroutine initialize_shear
!***********************************************************************
    subroutine read_shear_init_pars(unit,iostat)
!
!  read initial shear parameters
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=shear_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=shear_init_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_shear_init_pars
!***********************************************************************
    subroutine write_shear_init_pars(unit)
!
!  write initial shear parameters
!
      integer, intent(in) :: unit
!
      write(unit,NML=shear_init_pars)
!
    endsubroutine write_shear_init_pars
!***********************************************************************
    subroutine read_shear_run_pars(unit,iostat)
!
!  read run shear parameters
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      if (present(iostat)) then
        read(unit,NML=shear_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=shear_run_pars,ERR=99)
      endif
!
99    return
!
    endsubroutine read_shear_run_pars
!***********************************************************************
    subroutine write_shear_run_pars(unit)
!
!  write run shear parameters
!
      integer, intent(in) :: unit
!
      write(unit,NML=shear_run_pars)
!
    endsubroutine write_shear_run_pars
!***********************************************************************
    subroutine shearing(f,df)
!
!  Calculates the shear terms, -uy0*df/dy (shearing sheat approximation)
!
!  2-jul-02/nils: coded
!  6-jul-02/axel: runs through all nvar variables; added timestep check
! 16-aug-02/axel: use now Sshear which is calculated in param_io.f90
! 20-aug-02/axel: added magnetic stretching term
!
      use Cdata
      use Deriv
      use Fourier, only: fourier_shift_yz_y
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
!
      real, dimension (ny,nz) :: f_tmp_yz
      real, dimension (nx) :: uy0,dfdy
      integer :: j,k
!
      intent(in)  :: f
!
!  print identifier
!
      if (headtt.or.ldebug) print*, 'shearing: Sshear,qshear=', Sshear, qshear
!
!  add shear term, -uy0*df/dy, for all variables
!
      uy0=Sshear*x(l1:l2)
!
!  Add extra rotation profile.
!
      if (luy0_extra) uy0=uy0+uy0_extra(n-nghost)
!
!  Advection of all variables by shear flow.
!
      if (.not. lshearadvection_as_shift) then
        do j=1,nvar
          call der(f,j,dfdy,2)
          df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-uy0*dfdy
        enddo
      endif
!
! Taking care of the fact that the Coriolis force changes when
! we have got shear. The rest of the Coriolis force is calculated
! in hydro.
!
      if (lhydro) then
        df(l1:l2,m,n,iuy)=df(l1:l2,m,n,iuy)-Sshear*f(l1:l2,m,n,iux)
!
        if (luy0_extra) df(l1:l2,m,n,iuy) = df(l1:l2,m,n,iuy) &
           -f(l1:l2,m,n,iuz)*duy0dz_extra(n-nghost)
      endif
!
!  Loop over dust species
!
      if (ldustvelocity) then
        do k=1,ndustspec
!
!  Correct Coriolis force term for all dust species
!
           df(l1:l2,m,n,iudy(k)) = df(l1:l2,m,n,iudy(k)) &
              - Sshear*f(l1:l2,m,n,iudx(k))
!
!  End loop over dust species
!
        enddo
      endif
!
!  Magnetic stretching term (can be turned off for debugging purposes).
!
      if (lmagnetic .and. lmagnetic_stretching) then
        df(l1:l2,m,n,iax)=df(l1:l2,m,n,iax)-Sshear*f(l1:l2,m,n,iay)
        if (luy0_extra) df(l1:l2,m,n,iaz)=df(l1:l2,m,n,iaz)-duy0dz_extra(n-nghost)*f(l1:l2,m,n,iay)
      endif
!
!  Testfield stretching term
!  Loop through all the dax/dt equations and add -S*ay contribution
!
      if (ltestfield) then
        do j=iaatest,iaxtestpq,3
          df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-Sshear*f(l1:l2,m,n,j+1)
        enddo
      endif
!
!  Testflow stretching term
!  Loop through all the duy/dt equations and add -S*ux contribution
!
      if (ltestflow) then
        do j=iuutest+1,iuxtestpq,3
          df(l1:l2,m,n,j)=df(l1:l2,m,n,j)-Sshear*f(l1:l2,m,n,j-1)
        enddo
      endif
!
!  Meanfield stretching term
!  Loop through all the dax/dt equations and add -S*ay contribution
!
      if (iam/=0) then
        df(l1:l2,m,n,iamx)=df(l1:l2,m,n,iamx)-Sshear*f(l1:l2,m,n,iamy)
      endif
!
!  Take shear into account for calculating time step
!
      if (lfirst.and.ldt.and.(.not.lshearadvection_as_shift)) &
          advec_shear=abs(uy0*dy_1(m))
!
!  Calculate shearing related diagnostics
!
      if (ldiagnos) then
        if (idiag_dtshear/=0) &
            call max_mn_name(advec_shear/cdt,idiag_dtshear,l_dt=.true.)
      endif
!
    end subroutine shearing
!***********************************************************************
    subroutine advance_shear(f,df,dt_shear)
!
!  Advance shear distance, deltay, using dt. Using t instead introduces
!  significant errors when nt = t/dt exceeds ~100,000 steps.
!  This formulation works also when Sshear is changed during the run.
!
!  18-aug-02/axel: incorporated from nompicomm.f90
!
      use Cdata
      use Fourier, only: fourier_shift_y
      use Mpicomm, only: stop_it
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real :: dt_shear
!
      real, dimension (nx,ny,nz) :: tmp
      real, dimension (nx) :: uy0
      integer :: l, ivar
!
!  Works currently only when Sshear is not positive.
!
      if (Sshear>0.) then
        if (lroot) print*, 'Note: must use non-positive values of Sshear'
        call stop_it('')
      endif
!
!  Make sure deltay is in the range 0 <= deltay < Ly (assuming Sshear<0).
!
      deltay=deltay-Sshear*Lx*dt_shear
      deltay=deltay-int(deltay/Ly)*Ly
!
!  Solve for advection by shear motion by shifting all variables and their
!  time derivative (following Gammie 2001). Removes time-step constraint
!  from shear motion.
!
      if (lshearadvection_as_shift) then
        uy0=Sshear*x(l1:l2)
        do ivar=1,mvar
          tmp=f(l1:l2,m1:m2,n1:n2,ivar)
          call fourier_shift_y(tmp,uy0*dt_shear)
          f(l1:l2,m1:m2,n1:n2,ivar)=tmp
        enddo
        if (itsub/=itorder) then
          do ivar=1,mvar
            tmp=df(l1:l2,m1:m2,n1:n2,ivar)
            call fourier_shift_y(tmp,uy0*dt_shear)
            df(l1:l2,m1:m2,n1:n2,ivar)=tmp
          enddo
        endif
      endif
!
!  Print identifier.
!
      if (headtt.or.ldebug) print*, 'advance_shear: deltay=',deltay
!
    end subroutine advance_shear
!***********************************************************************
    subroutine boundcond_shear(f,ivar1,ivar2)
!
!  Shearing boundary conditions, called from the Boundconds module.
!
!  02-oct-07/anders: coded
!
      use Mpicomm, only: initiate_shearing, finalize_shearing
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: ivar1, ivar2
!
      if (ip<12.and.headtt) print*, &
          'boundconds_x: use shearing sheet boundary condition'
!
      if (lshearadvection_as_shift) then
        call fourier_shift_ghostzones(f,ivar1,ivar2)
      else
        call initiate_shearing(f,ivar1,ivar2)
        if (nprocy>1 .or. (.not. lmpicomm)) call finalize_shearing(f,ivar1,ivar2)
      endif
!
    endsubroutine boundcond_shear
!***********************************************************************
    subroutine fourier_shift_ghostzones(f,ivar1,ivar2)
!
!  Shearing boundary conditions by Fourier interpolation.
!
!  02-oct-07/anders: coded
!
      use Fourier, only: fourier_shift_yz_y
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: ivar1, ivar2
!
      real, dimension (ny,nz) :: f_tmp_yz
      integer :: i, ivar
!
      if (nxgrid/=1) then
        f(l2+1:mx,m1:m2,n1:n2,ivar1:ivar2)=f(l1:l1+2,m1:m2,n1:n2,ivar1:ivar2)
        f( 1:l1-1,m1:m2,n1:n2,ivar1:ivar2)=f(l2-2:l2,m1:m2,n1:n2,ivar1:ivar2)
      endif
!
      if (nygrid/=1) then
        do ivar=ivar1,ivar2
          do i=1,3
            f_tmp_yz=f(l1-i,m1:m2,n1:n2,ivar)
            call fourier_shift_yz_y(f_tmp_yz,+deltay)
            f(l1-i,m1:m2,n1:n2,ivar)=f_tmp_yz
            f_tmp_yz=f(l2+i,m1:m2,n1:n2,ivar)
            call fourier_shift_yz_y(f_tmp_yz,-deltay)
            f(l2+i,m1:m2,n1:n2,ivar)=f_tmp_yz
          enddo
        enddo
      endif
!
    endsubroutine fourier_shift_ghostzones
!***********************************************************************
    subroutine rprint_shear(lreset,lwrite)
!
!  reads and registers print parameters relevant to shearing
!
!   2-jul-04/tobi: adapted from entropy
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
        idiag_dtshear=0
      endif
!
!  iname runs through all possible names that may be listed in print.in
!
      do iname=1,nname
        call parse_name(iname,cname(iname),cform(iname),'dtshear',idiag_dtshear)
      enddo
!
!  write column where which shear variable is stored
!
      if (lwr) then
        write(3,*) 'i_dtshear=',idiag_dtshear
      endif
!
    endsubroutine rprint_shear
!***********************************************************************
  endmodule Shear
