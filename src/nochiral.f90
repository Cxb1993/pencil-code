! $Id: nochiral.f90,v 1.5 2005-07-05 16:21:42 mee Exp $

!  This modules solves two reactive scalar advection equations
!  This is used for modeling the spatial evolution of left and
!  right handed aminoacids.

!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! MVAR CONTRIBUTION 0
! MAUX CONTRIBUTION 0
!
!***************************************************************

module Chiral

  use Cparam
  use Cdata
  use Messages

  implicit none

  include 'chiral.h'

  integer :: dummy           ! We cannot define empty namelists
  namelist /chiral_init_pars/ dummy
  namelist /chiral_run_pars/  dummy

  ! other variables (needs to be consistent with reset list below)
  integer :: idiag_XX_chiralmax=0, idiag_YY_chiralmax=0

  contains

!***********************************************************************
    subroutine register_chiral()
!
!  Initialise variables which should know that we solve for passive
!  scalar: iXX_chiral and iYY_chiral; increase nvar accordingly
!
!  28-may-04/axel: adapted from pscalar
!
      use Mpicomm
      use Sub
!
      logical, save :: first=.true.
!
      if (.not. first) call stop_it('register_chiral called twice')
      first = .false.
!
      lchiral = .false.
!
!  identify version number
!
      if (lroot) call cvs_id( &
           "$Id: nochiral.f90,v 1.5 2005-07-05 16:21:42 mee Exp $")
!
    endsubroutine register_chiral
!***********************************************************************
    subroutine initialize_chiral(f)
!
!  Perform any necessary post-parameter read initialization
!  Dummy routine
!
!  28-may-04/axel: adapted from pscalar
!
      real, dimension (mx,my,mz,mvar+maux) :: f
! 
!  set to zero and then call the same initial condition
!  that was used in start.csh
!   
      if(NO_WARN) print*,'f=',f
    endsubroutine initialize_chiral
!***********************************************************************
    subroutine init_chiral(f,xx,yy,zz)
!
!  initialise passive scalar field; called from start.f90
!
!  28-may-04/axel: adapted from pscalar
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz) :: xx,yy,zz
!
      if(NO_WARN) print*,f,xx,yy,zz !(prevent compiler warnings)
    endsubroutine init_chiral
!***********************************************************************
    subroutine pencil_criteria_chiral()
! 
!  All pencils that the Chiral module depends on are specified here.
! 
!  21-11-04/anders: coded
!
    endsubroutine pencil_criteria_chiral
!***********************************************************************
    subroutine pencil_interdep_chiral(lpencil_in)
!       
!  Interdependency among pencils provided by the Chiral module
!  is specified here.
!
!  21-11-04/anders: coded
!
      logical, dimension(npencils) :: lpencil_in
!
      if (NO_WARN) print*, lpencil_in  !(keep compiler quiet)
!
    endsubroutine pencil_interdep_chiral
!***********************************************************************
    subroutine calc_pencils_chiral(f,p)
!       
!  Calculate Chiral pencils.
!  Most basic pencils should come first, as others may depend on them.
!   
!  21-11-04/anders: coded
!
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      type (pencil_case) :: p
!      
      intent(in) :: f,p
!
      if (NO_WARN) print*, f, p  !(keep compiler quiet)
!   
    endsubroutine calc_pencils_chiral
!***********************************************************************
    subroutine dXY_chiral_dt(f,df,p)
!
!  passive scalar evolution
!  calculate dc/dt=-uu.gcc + pscaler_diff*[del2cc + glnrho.gcc]
!
!  28-may-04/axel: adapted from pscalar
!
      real, dimension (mx,my,mz,mvar+maux) :: f
      real, dimension (mx,my,mz,mvar) :: df
      type (pencil_case) :: p
!
      intent(in)  :: f,df,p
!
      if(NO_WARN) print*,f,df,p
    endsubroutine dXY_chiral_dt
!***********************************************************************
    subroutine read_chiral_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_chiral_init_pars
!***********************************************************************
    subroutine write_chiral_init_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine write_chiral_init_pars
!***********************************************************************
    subroutine read_chiral_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
                                                                                                   
      if (present(iostat) .and. (NO_WARN)) print*,iostat
      if (NO_WARN) print*,unit
                                                                                                   
    endsubroutine read_chiral_run_pars
!***********************************************************************
    subroutine write_chiral_run_pars(unit)
      integer, intent(in) :: unit
                                                                                                   
      if (NO_WARN) print*,unit
    endsubroutine write_chiral_run_pars
!***********************************************************************
    subroutine rprint_chiral(lreset,lwrite)
!
!  reads and registers print parameters relevant for magnetic fields
!
!  28-may-04/axel: adapted from pscalar
!
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
        idiag_XX_chiralmax=0
        idiag_YY_chiralmax=0
      endif
!
!  write column where which magnetic variable is stored
!
      if (lwr) then
        write(3,*) 'i_XX_chiralmax=',idiag_XX_chiralmax
        write(3,*) 'i_YY_chiralmax=',idiag_YY_chiralmax
        write(3,*) 'iXX_chiral=',iXX_chiral
        write(3,*) 'iYY_chiral=',iYY_chiral
      endif
!
    endsubroutine rprint_chiral
!***********************************************************************

endmodule Chiral
