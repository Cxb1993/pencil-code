!  -*-f90-*-  (for emacs)    vim:set filetype=fortran:  (for vim)
  private

  public :: register_special, initialize_special
  public :: read_special_init_pars, write_special_init_pars
  public :: read_special_run_pars,  write_special_run_pars
  public :: rprint_special
  public :: init_special

  public :: dspecial_dt

  public :: calc_pencils_special
  public :: pencil_criteria_special
  public :: pencil_interdep_special

  public :: special_calc_density
  public :: special_calc_hydro
  public :: special_calc_entropy
  public :: special_calc_magnetic

  public :: special_boundconds
  public :: special_before_boundary
