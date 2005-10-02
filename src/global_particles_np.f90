 ! $Id: global_particles_np.f90,v 1.2 2005-10-02 11:24:55 ajohan Exp $

module Global

!
  use Cparam
  use Mpicomm

  implicit none

  include 'global.h'

  interface set_global
    module procedure set_global_vect_pencil
    module procedure set_global_scal_pencil
  endinterface

  interface set_global_point
    module procedure set_global_scal_point
    module procedure set_global_vect_point
  endinterface

  interface get_global
    module procedure get_global_vect
    module procedure get_global_scal
  endinterface

  interface get_global_point
    module procedure get_global_point_vect
    module procedure get_global_point_scal
  endinterface
!
  real, dimension (mx,my,mz) :: np

  contains

!***********************************************************************
    subroutine register_global()
!
!  Register Global module.
!
!  13-jun-05/anders: coded
!
      use Cdata, only: lglobal
!
      lglobal=.true.
!
    endsubroutine register_global
!***********************************************************************
    subroutine set_global_vect_pencil(var,m,n,label,length)
!
!  set (m,n)-pencil of the global vector variable identified by LABEL
!
!  18-jul-02/wolf coded
!
      integer :: length
      real, dimension(length,3) :: var
      integer :: m,n
      character (len=*) ::label
!
      if (NO_WARN) print*, var(1,1),m,n,label,length ! keep compiler quiet
!
    endsubroutine set_global_vect_pencil
!***********************************************************************
    subroutine set_global_scal_pencil(var,m,n,label,length)
!
!  set (m,n)-pencil of the global scalar variable identified by LABEL
!
!  20-jun-05/anders: dummy
!
      integer :: length
      real, dimension(length) :: var
      integer :: m,n
      character (len=*) ::label
!
      if (NO_WARN) print*, var(1),m,n,label,length ! keep compiler quiet
!
    endsubroutine set_global_scal_pencil
!***********************************************************************
    subroutine set_global_scal_point(var,l,m,n,label)
!
!  set point value of the global scalar variable identified by LABEL
!
!  20-jun-05/anders: adapted
!
      real :: var
      integer :: l,m,n
      character (len=*) ::label
!
      select case(label)

      case ('np')
        np(l,m,n) = np(l,m,n) + var

      case default
        if (lroot) print*, &
            'set_global_scal_point: No such value for label=', trim(label)
        call stop_it('set_global_scal_point')

      endselect
!
    endsubroutine set_global_scal_point
!***********************************************************************
    subroutine set_global_vect_point(var,l,m,n,label)
!
!  set point value of the global scalar variable identified by LABEL
!
!  20-jun-05/anders: adapted
!
      real, dimension(3) :: var
      integer :: l,m,n
      character (len=*) ::label
!
      select case(label)

      case default
        if (lroot) print*, &
            'set_global_vect_point: No such value for label=', trim(label)
        call stop_it('set_global_vect_point')

      endselect
!
    endsubroutine set_global_vect_point
!***********************************************************************
    subroutine reset_global(label)
!
!  reset global variable identified by LABEL
!
!  20-jun-05/anders: coded
!
      character (len=*) ::label
!
      select case(label)

      case ('np')
        np(:,:,:) = 0.0

      case default
        if (lroot) print*, &
            'reset_global: No such value for label=', trim(label)
        call stop_it('reset_global')

      endselect
!
    endsubroutine reset_global
!***********************************************************************
    subroutine get_global_vect(var,m,n,label)
!
!  set (m,n)-pencil of the global vector variable identified by LABEL
!
!  13-jun-05/anders: adapted
!
      real, dimension(nx,3) :: var
      integer :: m,n
      character (len=*) ::label
!
      select case(label)

      case default
        if (lroot) print*, 'get_global_vect: No such value for label=', trim(label)
        call stop_it('get_global_vect')

      endselect
!
    endsubroutine get_global_vect
!***********************************************************************
    subroutine get_global_scal(var,m,n,label)
!
!  set (m,n)-pencil of the global scalar variable identified by LABEL
!
!  13-jun-05/anders: adapted
!
      real, dimension(nx) :: var
      integer :: m,n
      character (len=*) ::label
!
      select case(label)

      case ('np')
        var = np(l1:l2,m,n)

      case default
        if (lroot) print*, 'get_global_scal: No such value for label=', trim(label)
        call stop_it('get_global_scal')

      endselect
!
    endsubroutine get_global_scal
!***********************************************************************
    subroutine get_global_point_vect(var,l,m,n,label)
!   
!  Get (l,m,n)-point of the global vector variable identified by LABEL
!  [dummy routine]
! 
!  18-jul-02/wolf coded
!   
!      use Cparam
!
      real, dimension(3) :: var
      integer :: l,m,n
      character (len=*) :: label
! 
      if (NO_WARN) print*, var(1),l,m,n,label ! keep compiler quiet
! 
    endsubroutine get_global_point_vect
!***********************************************************************
    subroutine get_global_point_scal(var,m,n,label)
!
!  Set (l,m,n)-pointof the global scalar variable identified by LABEL
!  [dummy routine]
!
!  18-jul-02/wolf coded
!
!      use Cparam
!
      real :: var
      integer :: l,m,n
      character (len=*) :: label
!
      if (NO_WARN) print*, var,l,m,n,label ! keep compiler quiet
!
    endsubroutine get_global_point_scal
!***********************************************************************
    subroutine global_derivs(m,n,label,der6)
!
!  take any derivative of global scalar variable.
!
!  13-jun-05/anders: coded
!
      real, dimension (nx), optional :: der6
      integer :: m,n
      character (len=*) ::label
!
    endsubroutine global_derivs
!***********************************************************************
    subroutine wglobal()
!
!  write global variables
!
!  10-jan-02/wolf: coded
!
      use Cdata, only: directory
      use Io, only: output
!
      call output(trim(directory)//'/np.dat',np,1)
!
    endsubroutine wglobal
!***********************************************************************
    subroutine rglobal()
!
!  read global variables
!
!  10-jan-02/wolf: coded
!
    endsubroutine rglobal
!***********************************************************************

endmodule Global
