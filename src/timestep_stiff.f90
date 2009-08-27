! $Id: timestep_stiff.f90 10805 2009-06-30 14:53:07Z rplasson@nordita.org $
! adapted from timestep_rkf, and from numerical recipe stiff algorithm

module Timestep

  use Cparam
  use Cdata

  implicit none

  private

  public :: rk_2n, border_profiles, timestep_autopsy

  ! Parameters for adaptive time stepping
  integer, parameter :: maxtry = 40
  real, parameter :: safety           = 0.9
  real, parameter :: dt_increase      = -0.25
  real, parameter :: dt_decrease      = -1.0 / 3.0
  real, parameter :: errcon           = 0.1296
  real, parameter :: grow             = 1.5
  real, parameter :: shrnk            = 0.5
! Shampine parameters
  real, parameter :: gam      = 1.0 / 2.0
  real, parameter :: a21      = 2.0
  real, parameter :: a31      = 48.0 / 25.0
  real, parameter :: a32      = 6.0 / 25.0
  real, parameter :: c21      = -8.0
  real, parameter :: c31      = 372.0 / 25.0
  real, parameter :: c32      = 12.0 / 5.0
  real, parameter :: c41      = -112.0 / 125.0
  real, parameter :: c42      = -54.0 / 125.0
  real, parameter :: c43      = -2.0 / 5.0
  real, parameter :: b1       = 19.0 / 9.0
  real, parameter :: b2       = 1.0 / 2.0
  real, parameter :: b3       = 25.0 / 108.0
  real, parameter :: b4       = 125.0 / 108.0
  real, parameter :: e1       = 17.0 / 54.0
  real, parameter :: e2       = 7.0 / 36.0
  real, parameter :: e3       = 0.0
  real, parameter :: e4       = 125.0 / 108.0
!
! Kaps-Rentrop parameters (possible alternative for above. 
! On some tests, slightly more accurate, but slower)
!
!  real, parameter :: gam              = 0.231
!  real, parameter :: a21      = 2.0                 
!  real, parameter :: a31      = 4.52470820736       
!  real, parameter :: a32      = 4.16352878860       
!  real, parameter :: c21      = -5.07167533877      
!  real, parameter :: c31      = 6.02015272865       
!  real, parameter :: c32      = 0.159750684673      
!  real, parameter :: c41      = -1.856343618677     
!  real, parameter :: c42      = -8.50538085819      
!  real, parameter :: c43      = -2.08407513602      
!  real, parameter :: b1       =3.95750374663        
!  real, parameter :: b2       =4.62489238836        
!  real, parameter :: b3       =0.617477263873       
!  real, parameter :: b4       =1.282612945268       
!  real, parameter :: e1       =-2.30215540292       
!  real, parameter :: e2       =-3.07363448539       
!  real, parameter :: e3       =0.873280801802       
!  real, parameter :: e4       =1.282612945268       

!
!  border_prof_[x-z] could be of size n[x-z], but having the same
!  length as f() (in the given dimension) gives somehow more natural code.
!
  real, dimension(mx) :: border_prof_x=1.0
  real, dimension(my) :: border_prof_y=1.0
  real, dimension(mz) :: border_prof_z=1.0

  contains

!***********************************************************************
    subroutine rk_2n(f,df,p)
!
!  Runge-Kutta-Fehlberg accurate to 5th order
!  At the moment, itorder can be 1, 2, or 3.
!
!  22-jun-06/tony: coded
!
      use Mpicomm
      use Cdata
      use Messages
!!      use Particles_main
!!      use Interstellar, only: calc_snr_damp_int
!!      use Shear, only: advance_shear
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension(mx,my,mz,nchemspec,nchemspec) :: jacob
      type (pencil_case) :: p
      real :: ds
      real, dimension(1) :: dt1, dt1_local

      real :: errmax, tnew
      real :: dt_temp, dt_next, dt_did
      integer :: j,i
      logical :: dtnotok
      integer :: l

      ldt=.false.
      dtnotok=.true.

      if (itorder/=5) &
        call fatal_error('rk_2n','itorder must be 5 for Runge-Kutta-Fehlberg')

!
!  dt_beta_ts may be needed in other modules (like Dustdensity) for fixed dt
!
!      if (.not. ldt) dt_beta_ts=dt*beta_ts
!

      if (linterstellar.or.lshear.or.lparticles) &
            call fatal_error("rk_2n", &
                   "Shear, interstellar and particles are not" // &
                   " yet supported by the adaptive rkf scheme")

      lfirst=.true.      
      do i=1,maxtry
!        print*,"i=",i,"   trying dt=",dt
        ! Do a Stiff step
        call stiff(f(:,:,:,1:mvar), df, p, errmax)
!        print*,"errmax=",errmax
        ! Step succeeded so exit
        ! New time
        tnew = t+dt
        if (tnew == t) then
          ! Guard against infinitesimal time steps
          print*, 'WARNING: Timestep underflow in stiff()'
        endif
        if (errmax <= 1.0) then
          dtnotok=.false.
          exit
        endif
        ! Step didn't succeed so decrease the time step
!        print*,"Decreasing"
        dt_next = safety*dt*(errmax**dt_decrease)
        ! Don't decrease the time step by more than a factor shrnk
        dt = sign(max(abs(dt_next), shrnk*abs(dt)), dt)
        !print*,"timestep=",dt
        !print*,"errmax=",errmax
      enddo
      if (dtnotok) call fatal_error("timestep_stiff","exceeded maxtry")
!      print*,"errmax, errcon", errmax,errcon

      if (errmax > errcon) then
        ! Increase the time step
        dt_next = safety*dt*(errmax**dt_increase)
      else
        ! But not by more than a factor of grow
        dt_next = grow*dt
      endif

      ! Time step that was actually performed
      dt_did = dt

      if (ip<=6) print*,'TIMESTEP: iproc,dt=',iproc,dt  !(all have same dt?)
      ! Increase time
      t = t+dt
      ! Time step to try next time
      dt = dt_next
!
!  Time evolution of grid variables
!  (do this loop in pencils, for cache efficiency)
!
      do j=1,mvar; do n=n1,n2; do m=m1,m2
        f(l1:l2,m,n,j)=f(l1:l2,m,n,j)+df(l1:l2,m,n,j)
      enddo; enddo; enddo
!
    endsubroutine rk_2n
!***********************************************************************
    subroutine stiff(f, df, p, errmax)
    ! Stiff algorithm for time stepping
      use Cdata
      use Mpicomm, only: mpiallreduce_max
      use Equ
      use Sub, only: ludcmp, lubksb
      use Chemistry, only: jacobn

      real, dimension (mx,my,mz,mvar), intent(in) :: f
      real, dimension (mx,my,mz,mvar) :: fscal
      real, dimension (mx,my,mz,nchemspec,nchemspec) :: jacob
      real, dimension (mx,my,mz,mvar), intent(out) :: df
      type (pencil_case), intent(inout) :: p
      integer, dimension (mx,my,mz,nchemspec) :: indx
      real, dimension(mx,my,mz,mvar,4) :: k
      real, dimension(mx,my,mz,nchemspec) :: ktemp
      real, dimension(nx) :: scal, err
      real, intent(inout) :: errmax
      real :: errmaxs
      integer :: i,j,l,lll
      integer :: i1

      df=0.
      errmax=0.
      k=0.
      call jacobn(f,jacob)
!      do n=n1,n2; do m=m1,m2;do l=l1,l2
!        print*,"jacob(",n,",",m,",",l,")="
!        do i=1,nchemspec
!          do j=1,nchemspec
!            print*,jacob(n,m,l,i,j)
!          enddo
!          print*,"/"
!        enddo
!      enddo; enddo; enddo
      jacob(:,:,:,:,:)=-jacob(:,:,:,:,:)
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        jacob(l1:l2,m,n,j,j)=1.0/(gam*dt)+jacob(l1:l2,m,n,j,j)
      enddo; enddo; enddo
!      do n=n1,n2; do m=m1,m2;do l=l1,l2
!        print*,"jacob(",n,",",m,",",l,")="
!        do i=1,nchemspec
!          do j=1,nchemspec
!            print*,jacob(n,m,l,i,j)
!          enddo
!          print*,"/"
!        enddo
!      enddo; enddo; enddo
      do n=n1,n2; do m=m1,m2; do l=l1,l2
        call ludcmp(jacob(l,m,n,:,:),indx(l,m,n,:))
      enddo; enddo; enddo
!      do n=n1,n2; do m=m1,m2;do l=l1,l2
!        print*,"jacob_lu(",n,",",m,",",l,")="
!        do i=1,nchemspec
!          do j=1,nchemspec
!            print*,jacob(n,m,l,i,j)
!          enddo
!          print*,"/"
!        enddo
!      enddo; enddo; enddo

      call pde(f,k(:,:,:,:,1),p)

      do j=1,mvar; do n=n1,n2; do m=m1,m2
!      XppAut stiff scaling
!        fscal(l1:l2,m,n,j) = max(1.0,abs(f(l1:l2,m,n,j)))
!      Numerical Recipe scaling
        fscal(l1:l2,m,n,j) = abs(f(l1:l2,m,n,j))+abs(df(l1:l2,m,n,j)*dt)+1e-8!tiny(0.)
      enddo; enddo; enddo
        
!      print*,"before:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        ktemp(l1:l2,m,n,j)=k(l1:l2,m,n,ichemspec(j),1)
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        
      do n=n1,n2; do m=m1,m2; do l=l1,l2
        call lubksb(jacob(l,m,n,:,:),indx(l,m,n,:),ktemp(l,m,n,:))
      enddo; enddo; enddo
!      print*,"after:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        k(l1:l2,m,n,ichemspec(j),1)=ktemp(l1:l2,m,n,j)
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        

      lfirst=.false.

      call pde(f+a21*k(:,:,:,:,1),k(:,:,:,:,2),p)
!      print*,"before:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        ktemp(l1:l2,m,n,j)=k(l1:l2,m,n,ichemspec(j),2)+ &
            c21*k(l1:l2,m,n,ichemspec(j),1)/dt
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        
      do n=n1,n2; do m=m1,m2; do l=l1,l2
        call lubksb(jacob(l,m,n,:,:),indx(l,m,n,:),ktemp(l,m,n,:))
      enddo; enddo; enddo
!      print*,"after:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        k(l1:l2,m,n,ichemspec(j),2)=ktemp(l1:l2,m,n,j)
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        

      call pde(f+a31*k(:,:,:,:,1)+a32*k(:,:,:,:,2),k(:,:,:,:,3),p)
      k(:,:,:,:,4)=k(:,:,:,:,3)
!      print*,"before:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        ktemp(l1:l2,m,n,j)=k(l1:l2,m,n,ichemspec(j),3)+ &
            (c31*k(l1:l2,m,n,ichemspec(j),1)+ &
             c32*k(l1:l2,m,n,ichemspec(j),2))/dt
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        
      do n=n1,n2; do m=m1,m2; do l=l1,l2
        call lubksb(jacob(l,m,n,:,:),indx(l,m,n,:),ktemp(l,m,n,:))
      enddo; enddo; enddo
!      print*,"after:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        k(l1:l2,m,n,ichemspec(j),3)=ktemp(l1:l2,m,n,j)
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        

!      print*,"before:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        ktemp(l1:l2,m,n,j)=k(l1:l2,m,n,ichemspec(j),4)+&
            (c41*k(l1:l2,m,n,ichemspec(j),1)+ &
             c42*k(l1:l2,m,n,ichemspec(j),2)+ &
             c43*k(l1:l2,m,n,ichemspec(j),3))/dt
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        
      do n=n1,n2; do m=m1,m2; do l=l1,l2
        call lubksb(jacob(l,m,n,:,:),indx(l,m,n,:),ktemp(l,m,n,:))
      enddo; enddo; enddo
!      print*,"after:"
      do j=1,nchemspec; do n=n1,n2; do m=m1,m2
        k(l1:l2,m,n,ichemspec(j),4)=ktemp(l1:l2,m,n,j)
!        print*,ktemp(l1:l2,m,n,j)
      enddo; enddo; enddo        

      errmaxs=0.
 
      do j=1,mvar 
!        print*,"j=",j
        do n=n1,n2; do m=m1,m2
        
          err = e1*k(l1:l2,m,n,j,1) + e2*k(l1:l2,m,n,j,2) + &
              e3*k(l1:l2,m,n,j,3) + e4*k(l1:l2,m,n,j,4)
          
          df(l1:l2,m,n,j) = b1*k(l1:l2,m,n,j,1) + b2*k(l1:l2,m,n,j,2) + &
              b3*k(l1:l2,m,n,j,3) + b4*k(l1:l2,m,n,j,4) 
          
!          print*,df(l1:l2,m,n,j)," (",err,")"
          ! Get the maximum error over the whole field
          !
          select case(timestep_scaling(j))
          case('per_var_err')
            !
            ! Per variable error
            !    
            scal=  ( &
                sqrt(f(l1:l2,m,n,1)**2+f(l1:l2,m,n,2)**2)  + &
                sqrt(k(l1:l2,m,n,1,1)**2 + k(l1:l2,m,n,2,1)**2) + &
                1e-30)
            errmaxs = max(maxval(abs(err/scal)),errmaxs)
            !scal=  ( &
            !     abs(f(l1:l2,m,n,j))  + abs(k(l1:l2,m,n,j,1)) + 1e-30)
            !errmaxs = max(maxval(abs(err/scal)),errmaxs)
          case('cons_frac_err')
            !
            ! Constant fractional error
            !
            errmaxs = max(maxval(abs(err/f(l1:l2,m,n,j))),errmaxs)
          case('cons_err')
            !
            ! Constant error
            !
            !scal = abs(f(l1:l2,m,n,j))+abs(df(l1:l2,m,n,j)*dt)+1e-30!tiny(0.)
            errmaxs = max(maxval(abs(err/fscal(l1:l2,m,n,j))),errmaxs)
            !
          case('none')
            !
            ! No error check 
            !
            errmaxs = 0
            !
          endselect
          !
        enddo; enddo
!        print*,"j=",j," errmaxs=",errmaxs
      enddo
      !
      ! Divide your maximum error by the required accuracy
      !
      errmaxs=errmaxs/eps_stiff
      !
      call mpiallreduce_max(errmaxs,errmax)
      
    endsubroutine stiff
!***********************************************************************
    subroutine timestep_autopsy
!
!  After the event, determine where the timestep too short occured
!  Kinda like playing Cluedo... Just without the dice.
!
!  25-aug-04/tony: coded
!
      use Cdata
      use Cparam
      use Mpicomm, only: start_serialize, end_serialize

      real :: dt_local, dt1_max_local, dt1_max_global
      integer :: l
      integer, dimension(1) :: turn

      if (lroot) then
        print*,"-------- General Description of Time Step Failure -----------"
        print*,"  it=",it
        print*,"  t=",t
        print*,"  Detailed breakdown not available for Adaptive Runge--Kutta--Fehlberg scheme"
      endif

! Procs testify in serial
!     call start_serialize
!!        if ( dt >= dt_local ) then
!          print*,"------------------ START OF CONFESSION (", iproc, ") ----------------------"
!            print*,"     "
!            print*,"------------------- END OF CONFESSION -----------------------"
!
!!          endif
!!        endif
!     call end_serialize

    endsubroutine timestep_autopsy
!***********************************************************************
    subroutine border_profiles()
!
!  Position-dependent quenching factor that multiplies rhs of pde
!  by a factor that goes gradually to zero near the boundaries.
!  border_frac_[xyz] is a 2-D array, separately for all three directions.
!  border_frac_[xyz]=1 would affect everything between center and border.
!
      use Cdata

      real, dimension(nx) :: xi
      real, dimension(ny) :: eta
      real, dimension(nz) :: zeta
      real :: border_width,lborder,uborder
!
!  x-direction
!
      border_prof_x(l1:l2)=1

      if ((border_frac_x(1)>0) .and. (.not. lperi(1))) then
        border_width=border_frac_x(1)*Lxyz(1)/2
        lborder=xyz0(1)+border_width
        xi=1-max(lborder-x(l1:l2),0.0)/border_width
        border_prof_x(l1:l2)=min(border_prof_x(l1:l2),xi**2*(3-2*xi))
      endif

      if ((border_frac_x(2)>0) .and. (.not. lperi(1))) then
        border_width=border_frac_x(2)*Lxyz(1)/2
        uborder=xyz1(1)-border_width
        xi=1-max(x(l1:l2)-uborder,0.0)/border_width
        border_prof_x(l1:l2)=min(border_prof_x(l1:l2),xi**2*(3-2*xi))
      endif
!
!  y-direction
!
      border_prof_y(m1:m2)=1

      if ((border_frac_y(1)>0) .and. (.not. lperi(2))) then
        border_width=border_frac_y(1)*Lxyz(2)/2
        lborder=xyz0(2)+border_width
        eta=1-max(lborder-y(m1:m2),0.0)/border_width
        border_prof_y(m1:m2)=min(border_prof_y(m1:m2),eta**2*(3-2*eta))
      endif

      if ((border_frac_y(2)>0) .and. (.not. lperi(2))) then
        border_width=border_frac_y(2)*Lxyz(2)/2
        uborder=xyz1(2)-border_width
        eta=1-max(y(m1:m2)-uborder,0.0)/border_width
        border_prof_y(m1:m2)=min(border_prof_y(m1:m2),eta**2*(3-2*eta))
      endif
!
!  z-direction
!
      border_prof_z(n1:n2)=1

      if ((border_frac_z(1)>0) .and. (.not. lperi(3))) then
        border_width=border_frac_z(1)*Lxyz(3)/2
        lborder=xyz0(3)+border_width
        zeta=1-max(lborder-z(n1:n2),0.0)/border_width
        border_prof_z(n1:n2)=min(border_prof_z(n1:n2),zeta**2*(3-2*zeta))
      endif

      if ((border_frac_z(2)>0) .and. (.not. lperi(3))) then
        border_width=border_frac_z(2)*Lxyz(3)/2
        uborder=xyz1(3)-border_width
        zeta=1-max(z(n1:n2)-uborder,0.0)/border_width
        border_prof_z(n1:n2)=min(border_prof_z(n1:n2),zeta**2*(3-2*zeta))
      endif
!
    endsubroutine border_profiles



endmodule Timestep
