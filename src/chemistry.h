!  -*-f90-*-  (for emacs)    vim:set filetype=fortran:  (for vim)
  private

  public :: register_chemistry, initialize_chemistry
  public :: read_chemistry_init_pars, write_chemistry_init_pars
  public :: read_chemistry_run_pars,  write_chemistry_run_pars
  public :: rprint_chemistry
  public :: get_slices_chemistry
  public :: init_chemistry

  public :: dchemistry_dt

  public :: calc_pencils_chemistry
  public :: pencil_criteria_chemistry
  public :: pencil_interdep_chemistry

! public :: chemistry_calc_density
! public :: chemistry_calc_hydro
! public :: chemistry_calc_entropy
! public :: chemistry_calc_magnetic

! public :: chemistry_before_boundary
