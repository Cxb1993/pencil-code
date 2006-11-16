! $Id: snapshot.f90,v 1.10 2006-11-16 06:56:37 mee Exp $

!!!!!!!!!!!!!!!!!!!!!!!
!!!   wsnaps.f90   !!!
!!!!!!!!!!!!!!!!!!!!!!!

!!!  Write snapshot files (variables and powerspectra). Is a separate
!!!  module, so it can be used with whatever IO module we want.

module Snapshot

  use Messages

  implicit none

  private

  integer :: lun_output=92

  public :: rsnap, wsnap, powersnap
  public :: output_globals, input_globals

contains

!***********************************************************************
    subroutine wsnap(chsnap,a,msnap,enum,flist)
!
!  Write snapshot file, labelled consecutively if enum==.true.
!  Otherwise just write a snapshot without label (used for var.dat)
!
!  30-sep-97/axel: coded
!  08-oct-02/tony: expanded file to handle 120 character datadir // '/tsnap.dat'
!   5-apr-03/axel: possibility for additional (hard-to-get) output 
!  31-may-03/axel: wsnap can write either w/ or w/o auxiliary variables
!
      use Cdata
      use Mpicomm
      use Boundcond, only: update_ghosts
      use General, only: safe_character_assign
      use Sub, only: read_snaptime,update_snaptime
      use IO, only: log_filename_to_file
!
!  the dimension msnap can either be mfarray (for f-array in run.f90)
!  or just mvar (for f-array in start.f90 or df-array in run.f90
!
      integer :: msnap
      real, dimension (mx,my,mz,msnap) :: a
      character (len=4) :: ch
      character (len=fnlen) :: file
      character (len=*) :: chsnap,flist
      logical :: lsnap,enum
      integer, save :: ifirst=0,nsnap
      real, save :: tsnap
      optional :: flist
!
!  Output snapshot with label in 'tsnap' time intervals
!  file keeps the information about number and time of last snapshot
!
      if (enum) then
        call safe_character_assign(file,trim(datadir)//'/tsnap.dat')
!
!  at first call, need to initialize tsnap
!  tsnap calculated in read_snaptime, but only available to root processor
!
        if (ifirst==0) then
          call read_snaptime(file,tsnap,nsnap,dsnap,t)
          ifirst=1
        endif
!
!  Check whether we want to output snapshot. If so, then
!  update ghost zones for var.dat (cheap, since done infrequently)
!
        call update_snaptime(file,tsnap,nsnap,dsnap,t,lsnap,ch,ENUM=.true.)
        if (lsnap) then
          call update_ghosts(a)
          call update_auxiliaries(a)
          call output_snap(chsnap//ch,a,msnap)
          if(ip<=10.and.lroot) print*,'wsnap: written snapshot ',chsnap//ch
          if (present(flist)) call log_filename_to_file(chsnap//ch,flist)
        endif
!
      else
!
!  write snapshot without label (typically, var.dat)
!
        call update_ghosts(a)
        call update_auxiliaries(a)
        call output_snap(chsnap,a,msnap)
        if (present(flist)) call log_filename_to_file(chsnap,flist)
      endif
!
    endsubroutine wsnap
!***********************************************************************
    subroutine rsnap(chsnap,f,msnap)
!
!  Read snapshot file
!
!  24-jun-05/tony: coded from snap reading code in run.f90 
!
      use Cdata
      use Mpicomm
      use Magnetic, only: pert_aa
!
!  the dimension msnap can either be mfarray (for f-array in run.f90)
!  or just mvar (for f-array in start.f90 or df-array in run.f90
!
      integer :: msnap
      real, dimension (mx,my,mz,msnap) :: f
      character (len=*) :: chsnap
      integer :: ivar
!
        if (ip<=6.and.lroot) print*,'reading var files'
!          
!  no need to read maux variables as they will be calculated
!  at the first time step -- even if lwrite_aux is set
!  Allow for the possibility to read in files that didn't
!  have magnetic fields or passive scalar in it.
!  NOTE: for this to work one has to modify *manually* data/param.nml
!  by adding an entry for MAGNETIC_INIT_PARS or PSCALAR_INIT_PARS.
!
        if(lread_oldsnap_nomag) then
          print*,'read old snapshot file (but without magnetic field)'
          call input_snap(trim(directory_snap)//'/var.dat',f,msnap-3,1)
          ! shift the rest of the data
          if (iaz<mvar) then
            do ivar=iaz+1,mvar
              f(:,:,:,ivar)=f(:,:,:,ivar-3)
            enddo
            f(:,:,:,iax:iaz)=0. 
          endif
! dgm
          if (lrun) call pert_aa(f)
!
!  read data without passive scalar into new run with passive scalar
!
        elseif(lread_oldsnap_nopscalar) then
          print*,'read old snapshot file (but without passive scalar)'
          call input_snap(chsnap,f,msnap-1,1)
          ! shift the rest of the data
          if (iaz<mvar) then
            do ivar=ilncc+1,mvar
              f(:,:,:,ivar)=f(:,:,:,ivar-1)
            enddo
            f(:,:,:,ilncc)=0.
          endif
        else
          call input_snap(chsnap,f,msnap,1)
        endif
!
    endsubroutine rsnap
!***********************************************************************
   subroutine powersnap(a,lwrite_only)
!
!  Write a snapshot of power spectrum 
!
!  30-sep-97/axel: coded
!  07-oct-02/nils: adapted from wsnap
!  08-oct-02/tony: expanded file to handle 120 character datadir // '/tspec.dat'
!  28-dec-02/axel: call structure from herel; allow optional lwrite_only
!
      use Boundcond
      use Cdata
      use IO
      use Mpicomm
      use Particles_main
      use Power_spectrum
      use Pscalar
      use Struct_func
      use Sub
!
      real, dimension (mx,my,mz,mfarray) :: a
      real, dimension (nx,ny,nz) :: b_vec
      character (len=135) :: file
      character (len=4) :: ch
      logical :: lspec,llwrite_only=.false.,ldo_all
      logical, optional :: lwrite_only
      integer, save :: ifirst=0,nspec
      real, save :: tspec
      integer :: ivec,im,in
      real, dimension (nx) :: bb 
!
!  set llwrite_only
!
      if (present(lwrite_only)) llwrite_only=lwrite_only
      ldo_all=.not.llwrite_only
!
!  Output snapshot in 'tpower' time intervals
!  file keeps the information about time of last snapshot
!
      file=trim(datadir)//'/tspec.dat'
!
!  at first call, need to initialize tspec
!  tspec calculated in read_snaptime, but only available to root processor
!
      if (ldo_all.and.ifirst==0) then
        call read_snaptime(file,tspec,nspec,dspec,t)
        ifirst=1
      endif
!
!  Check whether we want to output power snapshot. If so, then
!  update ghost zones for var.dat (cheap, since done infrequently)
!
      if (ldo_all) &
           call update_snaptime(file,tspec,nspec,dspec,t,lspec,ch,ENUM=.false.)
      if (lspec.or.llwrite_only) then
        if (ldo_all)  call update_ghosts(a)
        if (vel_spec) call power(a,'u')
        if (mag_spec) call power(a,'b')
        if (vec_spec) call power(a,'a')
        if (uxj_spec) call powerhel(a,'uxj')
        if (ab_spec)  call powerhel(a,'mag')
        if (ou_spec)  call powerhel(a,'kin')
        if (ro_spec)  call powerscl(a,'ro')
        if (TT_spec)  call powerscl(a,'TT')
        if (ss_spec)  call powerscl(a,'ss')
        if (cc_spec)  call powerscl(a,'cc')
        if (cr_spec)  call powerscl(a,'cr')
        if (oned) then
          if (vel_spec) call power_1d(a,'u',1)
          if (mag_spec) call power_1d(a,'b',1)
          if (vec_spec) call power_1d(a,'a',1)
          if (vel_spec) call power_1d(a,'u',2)
          if (mag_spec) call power_1d(a,'b',2)
          if (vec_spec) call power_1d(a,'a',2)
          if (vel_spec) call power_1d(a,'u',3)
          if (mag_spec) call power_1d(a,'b',3)
          if (vec_spec) call power_1d(a,'a',3)
        endif
        if (twod) then
          if (vel_spec) call power_2d(a,'u')
          if (mag_spec) call power_2d(a,'b')
          if (vec_spec) call power_2d(a,'a')
        endif
!
!  Spectra of particle variables.
!         
        if (lparticles) call particles_powersnap(a)
!
!  Structure functions
!
        do ivec=1,3
           if (lsfb .or. lsfz1 .or. lsfz2 .or. lsfflux .or. lpdfb .or. &
               lpdfz1 .or. lpdfz2) then
              do n=n1,n2
                do m=m1,m2
                  call curli(a,iaa,bb,ivec)
                  im=m-nghost
                  in=n-nghost
                  b_vec(:,im,in)=bb
                enddo
             enddo
             b_vec=b_vec/sqrt(exp(a(l1:l2,m1:m2,n1:n2,ilnrho)))
           endif
           if (lsfu)     call structure(a,ivec,b_vec,'u')
           if (lsfb)     call structure(a,ivec,b_vec,'b')
           if (lsfz1)    call structure(a,ivec,b_vec,'z1')
           if (lsfz2)    call structure(a,ivec,b_vec,'z2')
           if (lsfflux)  call structure(a,ivec,b_vec,'flux')
           if (lpdfu)    call structure(a,ivec,b_vec,'pdfu')
           if (lpdfb)    call structure(a,ivec,b_vec,'pdfb')
           if (lpdfz1)   call structure(a,ivec,b_vec,'pdfz1')
           if (lpdfz2)   call structure(a,ivec,b_vec,'pdfz2')
         enddo
!
!  do pdf of passive scalar field (if present)
!
         if (rhocc_pdf) call pdf(a,'rhocc',rhoccm,sqrt(cc2m))
         if (cc_pdf)    call pdf(a,'cc'   ,rhoccm,sqrt(cc2m))
         if (lncc_pdf)  call pdf(a,'lncc' ,rhoccm,sqrt(cc2m))
         if (gcc_pdf)   call pdf(a,'gcc'  ,0.    ,sqrt(gcc2m))
         if (lngcc_pdf) call pdf(a,'lngcc',0.    ,sqrt(gcc2m))
!
      endif
!
    endsubroutine powersnap
!***********************************************************************
    subroutine output_snap(file,a,nv)
!
!  write snapshot file, always write time and mesh, could add other things
!  version for vector field
!
!  11-apr-97/axel: coded
!
      use Cdata
      use Mpicomm, only: start_serialize,end_serialize
      use Persist, only: output_persistent
!
      integer :: nv
      real, dimension (mx,my,mz,nv) :: a
      character (len=*) :: file
!
      if (ip<=8.and.lroot) print*,'output_vect: nv =', nv
!
      if (lserial_io) call start_serialize()
      open(lun_output,FILE=file,FORM='unformatted')
      if (lwrite_2d) then
        if (ny==1) then
          write(lun_output) a(:,4,:,:)
        else
          write(lun_output) a(:,:,4,:)
        endif
      else
        write(lun_output) a
      endif
!     write(lun_output) a(:,4,:,:)
      if (lshear) then
        write(lun_output) t,x,y,z,dx,dy,dz,deltay
      else
        write(lun_output) t,x,y,z,dx,dy,dz
      endif
      call output_persistent(lun_output)
!
      close(lun_output)
      if (lserial_io) call end_serialize()
!
    endsubroutine output_snap
!***********************************************************************
    subroutine input_snap(file,a,nv,mode)
!
!  read snapshot file, possibly with mesh and time (if mode=1)
!  11-apr-97/axel: coded
!
      use Cdata
      use Mpicomm, only: start_serialize,end_serialize
      use Persist, only: input_persistent
!
      character (len=*) :: file
      integer :: nv,mode
      real, dimension (mx,my,mz,nv) :: a
      real, allocatable, dimension (:,:,:) :: aa
!
      if (lserial_io) call start_serialize()
      open(1,FILE=file,FORM='unformatted')
      if (ip<=8) print*,'input_snap: open, mx,my,mz,nv=',mx,my,mz,nv
      if (lwrite_2d) then
        if (ny==1) then
          allocate(aa(mx,mz,nv))
          read(1) aa
          a(:,4,:,:)=aa
        else
          allocate(aa(mx,my,nv))
          read(1) aa
          a(:,:,4,:)=aa
        endif
        deallocate(aa)
      else
        read(1) a
      endif
      if (ip<=8) print*,'input_snap: read ',file
      if (mode==1) then
!
!  check whether we want to read deltay from snapshot
!
        if (lshear) then
          read(1) t,x,y,z,dx,dy,dz,deltay
        else
          read(1) t,x,y,z,dx,dy,dz
        endif
!
        if (ip<=3) print*,'input_snap: ip,x=',ip,x
        if (ip<=3) print*,'input_snap: y=',y
        if (ip<=3) print*,'input_snap: z=',z
!
      endif
!
      call input_persistent(1)
      close(1)
      if (lserial_io) call end_serialize()

    endsubroutine input_snap
!***********************************************************************
    subroutine output_globals(file,a,nv)
!
!  write snapshot file of globals, always write mesh, 
!
!  10-nov-06/tony: coded
!
      use Cdata
      use Mpicomm, only: start_serialize,end_serialize
!
      real, dimension (mx,my,mz,nv) :: a
      integer :: nv
      character (len=*) :: file
!
      if (ip<=8.and.lroot) print*,'output_vect: nv =', nv
!
      if (lserial_io) call start_serialize()
      open(lun_output,FILE=file,FORM='unformatted')

      write(lun_output) mx,my,mz,nv
      if (lwrite_2d) then
        if (ny==1) then
          write(lun_output) a(:,4,:,:)
        else
          write(lun_output) a(:,:,4,:)
        endif
      else
        write(lun_output) a
      endif
      write(lun_output) x,y,z,dx,dy,dz
!
      close(lun_output)
      if (lserial_io) call end_serialize()
!
    endsubroutine output_globals
!***********************************************************************
    subroutine input_globals(file,a,nv)
!
!  read globals snapshot file, ignoring mesh 
!  10-nov-06/tony: coded
!
      use Cdata
      use Mpicomm, only: start_serialize,end_serialize
!
      character (len=*) :: file
      integer :: nv,mode
      real, dimension (mx,my,mz,nv) :: a
      real, allocatable, dimension (:,:,:) :: aa
      integer :: ggmx,ggmy,ggmz,ggnv
!
      if (lserial_io) call start_serialize()
      open(1,FILE=file,FORM='unformatted')
      if (ip<=8) print*,'input_globals: open, mx,my,mz,nv=',mx,my,mz,nv
      read(1) ggmx,ggmy,ggmz,ggnv

      if ((mx/=ggmx).or.(my/=ggmy).or.(mz/=ggmz).or.(nv/=ggnv)) then
        print*,"problem (mx,my,mz,nv): ",mx,my,mz,nv
        print*,"file '"//trim(file)//"' (mx,my,mz,nv): ",ggmx,ggmy,ggmz,ggnv
        call fatal_error("input_globals",&
            "Problem and globals data differ in size!!")
      endif

      if (lwrite_2d) then
        if (ny==1) then
          allocate(aa(mx,mz,nv))
          read(1) aa
          a(:,4,:,:)=aa
        else
          allocate(aa(mx,my,nv))
          read(1) aa
          a(:,:,4,:)=aa
        endif
        deallocate(aa)
      else
        read(1) a
      endif
      if (ip<=8) print*,'input_globals: read ',file
      if (mode==1) then
!
!  check whether we want to read deltay from snapshot
!
        if (lshear) then
          read(1) x,y,z,dx,dy,dz,deltay
        else
          read(1) x,y,z,dx,dy,dz
        endif
!
        if (ip<=3) print*,'input_globals: ip,x=',ip,x
        if (ip<=3) print*,'input_globals: y=',y
        if (ip<=3) print*,'input_globals: z=',z
!
      endif
!
      close(1)
      if (lserial_io) call end_serialize()

    endsubroutine input_globals
!***********************************************************************
    subroutine update_auxiliaries(a)

      use Cparam
      use Cdata
      use Shock, only: calc_shock_profile,calc_shock_profile_simple
      use EquationOfState, only: ioncalc
      use Radiation, only: radtransfer
      use Viscosity, only: lvisc_first,calc_viscosity

      real, dimension (mx,my,mz,mfarray), intent (inout) :: a

      if (lshock) then
        call calc_shock_profile(a)
        call calc_shock_profile_simple(a)
      endif
      if (leos_ionization.or.leos_temperature_ionization) call ioncalc(a)
      if (lradiation_ray)  call radtransfer(a)
      if (lvisc_hyper.or.lvisc_smagorinsky) then
        if (.not.lvisc_first.or.lfirst) call calc_viscosity(a)
      endif

    endsubroutine update_auxiliaries
!***********************************************************************
endmodule Snapshot

