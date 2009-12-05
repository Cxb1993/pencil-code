! $Id$
!
!  Module for NSCBC boundary conditions. 
!  To be included from boundcond.f90.
!
module NSCBC
!
  use Cdata
  use Cparam
  use Messages
  use Mpicomm
  use Sub, only: keep_compiler_quiet
!
  implicit none
!
  include 'NSCBC.h'
!
  contains
!***********************************************************************
    subroutine nscbc_boundtreat(f,df)
!
!  Dummy routine
!
      real, dimension (mx,my,mz,mfarray) :: f
      real, dimension (mx,my,mz,mvar) :: df

      intent(inout) :: f
      intent(inout) :: df
!
      call keep_compiler_quiet(f)
      call keep_compiler_quiet(df)
!    
    endsubroutine nscbc_boundtreat
!***********************************************************************
    subroutine read_NSCBC_init_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      call keep_compiler_quiet(unit)
      if (present(iostat)) call keep_compiler_quiet(iostat)
!
    endsubroutine read_NSCBC_init_pars
!***********************************************************************
    subroutine read_NSCBC_run_pars(unit,iostat)
!
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat
!
      call keep_compiler_quiet(unit)
      if (present(iostat)) call keep_compiler_quiet(iostat)
!
    endsubroutine read_NSCBC_run_pars
!***********************************************************************
    subroutine write_NSCBC_init_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_NSCBC_init_pars
!***********************************************************************
    subroutine write_NSCBC_run_pars(unit)
!
      integer, intent(in) :: unit
!
      call keep_compiler_quiet(unit)
!
    endsubroutine write_NSCBC_run_pars
!***********************************************************************
    subroutine NSCBC_clean_up
!
    endsubroutine NSCBC_clean_up
!***********************************************************************
endmodule NSCBC
