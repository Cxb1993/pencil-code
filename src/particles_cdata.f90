! $Id: particles_cdata.f90,v 1.6 2005-09-16 14:18:27 ajohan Exp $
!!
!! Global particle variables
!!

module Particles_cdata

  use Cdata

  public 
  
  real :: dsnap_par_minor=0.0
  real :: rhops=1.0e10, rhop_tilde=0.0, np_tilde=0.0, mp_tilde=0.0
  integer, dimension (mpar_loc) :: ipar
  integer :: npvar=0, npar_loc=0
  integer :: ixp=0,iyp=0,izp=0,ivpx=0,ivpy=0,ivpz=0,iap=0
  integer :: idiag_nmigmax=0
  logical :: linterp_reality_check=.false., lmigration_redo=.false.
  character (len=2*bclen+1) :: bcpx='p',bcpy='p',bcpz='p'

endmodule Particles_cdata
