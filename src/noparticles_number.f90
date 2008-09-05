! $Id$
!
!  This module takes care of everything related to particle number.
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
!
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
! CPARAM logical, parameter :: lparticles_number=.false.
!
!***************************************************************
module Particles_number

  use Cdata
  use Particles_cdata
  use Particles_sub

  implicit none

  real :: np_tilde0

  include 'particles_number.h'

  contains

!***********************************************************************
    subroutine register_particles_number()
!
!  Set up indices for access to the fp and dfp arrays.
!
!  24-nov-05/anders: dummy
!
    endsubroutine register_particles_number
!***********************************************************************
    subroutine initialize_particles_number(lstarting)
!
!  Perform any post-parameter-read initialization i.e. calculate derived
!  parameters.
!
!  25-nov-05/anders: coded
!
      logical :: lstarting
!
      np_tilde0=rhop_tilde/mp_tilde
      if (lroot) print*, 'initialize_particles_number: '// &
          'number density per particle np_tilde0=', np_tilde0
!
      if (NO_WARN) print*, lstarting
!
    endsubroutine initialize_particles_number
!***********************************************************************
    subroutine init_particles_number(f,fp)
!
!  Initial internal particle number.
!
!  24-nov-05/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mpar_loc,mpvar) :: fp
!
      if (NO_WARN) print*, f, fp
!
    endsubroutine init_particles_number
!***********************************************************************
    subroutine pencil_criteria_par_number()
!
!  All pencils that the Particles_number module depends on are specified here.
!
!  21-nov-06/anders: dummy
!
    endsubroutine pencil_criteria_par_number
!***********************************************************************
    subroutine dnptilde_dt_pencil(f,df,fp,dfp,p,ineargrid)
!
!  Evolution of internal particle number.
!
!  24-oct-05/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      type (pencil_case) :: p
      integer, dimension (mpar_loc,3) :: ineargrid
!
      if (NO_WARN) print*, f, df, fp, dfp, ineargrid
!
    endsubroutine dnptilde_dt_pencil
!***********************************************************************
    subroutine dnptilde_dt(f,df,fp,dfp,ineargrid)
!
!  Evolution of internal particle number.
!
!  24-oct-05/anders: dummy
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df
      real, dimension (mpar_loc,mpvar) :: fp, dfp
      integer, dimension (mpar_loc,3) :: ineargrid
!
      if (NO_WARN) print*, f, df, fp, dfp, ineargrid
!
    endsubroutine dnptilde_dt
!***********************************************************************
    subroutine get_nptilde(fp,k,np_tilde)
!
!  Get internal particle number.
!
!  25-oct-05/anders: coded
!
      use Messages, only: fatal_error
!
      real, dimension (mpar_loc,mpvar) :: fp
      real :: np_tilde
      integer :: k
!
      intent (in)  :: fp, k
      intent (out) :: np_tilde
!
      if (k<1 .or. k>mpar_loc) then
        if (lroot) print*, 'get_nptilde: k out of range, k=', k
        call fatal_error('get_nptilde','')
      endif
!
      np_tilde=np_tilde0
!
      if (NO_WARN) print*, fp
!
    endsubroutine get_nptilde
!***********************************************************************
    subroutine read_particles_num_init_pars(unit,iostat)
!
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      if (NO_WARN) print*, unit, iostat
!
    endsubroutine read_particles_num_init_pars
!***********************************************************************
    subroutine write_particles_num_init_pars(unit)
!
      integer, intent (in) :: unit
!
      if (NO_WARN) print*, unit
!
    endsubroutine write_particles_num_init_pars
!***********************************************************************
    subroutine read_particles_num_run_pars(unit,iostat)
!
      integer, intent (in) :: unit
      integer, intent (inout), optional :: iostat
!
      if (NO_WARN) print*, unit, iostat
!
    endsubroutine read_particles_num_run_pars
!***********************************************************************
    subroutine write_particles_num_run_pars(unit)
!
      integer, intent (in) :: unit
!
      if (NO_WARN) print*, unit
!
    endsubroutine write_particles_num_run_pars
!***********************************************************************
    subroutine rprint_particles_number(lreset,lwrite)
!
!  Read and register print parameters relevant for internal particle number.
!
!  24-nov-05/anders: dummy
!
      use Cdata
      use Sub, only: parse_name
!
      logical :: lreset
      logical, optional :: lwrite
!
      logical :: lwr
!
!  Write information to index.pro
!
      lwr = .false.
      if (present(lwrite)) lwr=lwrite
!
      if (lwr) write(3,*) 'inptilde=', inptilde
!
      if (NO_WARN) print*, lreset
!
    endsubroutine rprint_particles_number
!***********************************************************************

endmodule Particles_number
