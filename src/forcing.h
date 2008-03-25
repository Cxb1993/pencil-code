!  -*-f90-*-  (for emacs)    vim:set filetype=fortran:  (for vim)
  private

  public :: register_forcing, initialize_forcing
  public :: read_forcing_init_pars, write_forcing_init_pars
  public :: read_forcing_run_pars,  write_forcing_run_pars
  public :: output_persistent_forcing, input_persistent_forcing
  public :: rprint_forcing
  public :: addforce
  public :: forcing_continuous, calc_lforcing_cont_pars

  public :: pencil_criteria_forcing, pencil_interdep_forcing
  public :: calc_pencils_forcing
