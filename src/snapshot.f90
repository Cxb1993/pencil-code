! $Id$
!
!  Write snapshot files (variables and power spectra).
!
module Snapshot
!
  use Cdata
  use Cparam
  use Messages
!
  implicit none
!
  private
!
  integer :: lun_output=92
!
  public :: rsnap, wsnap, powersnap
  public :: output_globals, input_globals
!
  contains
!***********************************************************************
    subroutine wsnap(chsnap,a,msnap,enum,flist,noghost)
!
!  Write snapshot file, labelled consecutively if enum==.true.
!  Otherwise just write a snapshot without label (used for var.dat).
!
!  30-sep-97/axel: coded
!  08-oct-02/tony: expanded file to handle 120 character datadir // '/tsnap.dat'
!   5-apr-03/axel: possibility for additional (hard-to-get) output
!  31-may-03/axel: wsnap can write either w/ or w/o auxiliary variables
!
      use Boundcond, only: update_ghosts
      use General, only: safe_character_assign
      use IO, only: log_filename_to_file
      use Sub, only: read_snaptime,update_snaptime
!
!  The dimension msnap can either be mfarray (for f-array in run.f90)
!  or just mvar (for f-array in start.f90 or df-array in run.f90
!
      character (len=*) :: chsnap, flist
      real, dimension (mx,my,mz,msnap) :: a
      integer :: msnap
      logical :: enum,enum_,noghost
      optional :: enum, flist, noghost
!
      real, save :: tsnap
      integer, save :: ifirst=0,nsnap
      logical :: lsnap
      character (len=fnlen) :: file
      character (len=5) :: ch
!
      if (present(enum)) then
        enum_=enum
      else
        enum_=.false.
      endif
!
!  Output snapshot with label in 'tsnap' time intervals.
!  File keeps the information about number and time of last snapshot.
!
      if (enum_) then
        call safe_character_assign(file,trim(datadir)//'/tsnap.dat')
!
!  At first call, need to initialize tsnap.
!  tsnap calculated in read_snaptime, but only available to root processor.
!
        if (ifirst==0) then
          call read_snaptime(file,tsnap,nsnap,dsnap,t)
          ifirst=1
        endif
!
!  Check whether we want to output snapshot. If so, then
!  update ghost zones for var.dat (cheap, since done infrequently).
!
        call update_snaptime(file,tsnap,nsnap,dsnap,t,lsnap,ch,ENUM=.true.)
        if (lsnap) then
          call update_ghosts(a)
          if (msnap==mfarray) call update_auxiliaries(a)
          call output_snap(chsnap//ch,a,msnap)
          if (ip<=10.and.lroot) print*,'wsnap: written snapshot ',chsnap//ch
          if (present(flist)) call log_filename_to_file(chsnap//ch,flist)
        endif
!
      else
!
!  Write snapshot without label (typically, var.dat). For dvar.dat we need to
!  make sure that ghost zones are not set on df!
!
        if (present(noghost)) then
          if (.not. noghost) call update_ghosts(a)
        else
          call update_ghosts(a)
        endif
        if (msnap==mfarray) call update_auxiliaries(a) ! Not if e.g. dvar.dat.
        if (present(noghost)) then
          if (.not. noghost) call update_ghosts(a)
        else
          call update_ghosts(a)
        endif
        call output_snap(chsnap,a,msnap)
        if (present(flist)) call log_filename_to_file(chsnap,flist)
      endif
!
    endsubroutine wsnap
!***********************************************************************
    subroutine rsnap(chsnap,f,msnap)
!
!  Read snapshot file.
!
!  24-jun-05/tony: coded from snap reading code in run.f90
!
!  The dimension msnap can either be mfarray (for f-array in run.f90)
!  or just mvar (for f-array in start.f90 or df-array in run.f90.
!
      integer :: msnap
      real, dimension (mx,my,mz,msnap) :: f
      character (len=*) :: chsnap
      integer :: ivar
!
        if (ip<=6.and.lroot) print*,'reading var files'
!
!  No need to read maux variables as they will be calculated
!  at the first time step -- even if lwrite_aux is set.
!  Allow for the possibility to read in files that didn't
!  have magnetic fields or passive scalar in it.
!  NOTE: for this to work one has to modify *manually* data/param.nml
!  by adding an entry for MAGNETIC_INIT_PARS or PSCALAR_INIT_PARS.
!
!DM: I do not understand why we need to shift the data below.
! I seem to need to set f(:,:,:,iax:iaz) = 0 . Otherwise
! the vector potential is initialised as junk data. And then
! init_aa just adds to it, so junk remains junk. Anyhow
! the initialisation to zero cannot do any harm.
!
        if (lread_oldsnap_nomag) then
          f(:,:,:,iax:iaz)=0.
          print*,'read old snapshot file (but without magnetic field)'
          call input_snap(trim(directory_snap)//'/var.dat',f,msnap-3,1)
          ! shift the rest of the data
          if (iaz<mvar) then
            do ivar=iaz+1,mvar
              f(:,:,:,ivar)=f(:,:,:,ivar-3)
            enddo
            f(:,:,:,iax:iaz)=0.
          endif
!
!  Read data without passive scalar into new run with passive scalar.
!
        elseif (lread_oldsnap_nopscalar) then
          print*,'read old snapshot file (but without passive scalar)'
          call input_snap(chsnap,f,msnap-1,1)
          ! shift the rest of the data
          if (ilncc<mvar) then
            do ivar=ilncc+1,mvar
              f(:,:,:,ivar)=f(:,:,:,ivar-1)
            enddo
            f(:,:,:,ilncc)=0.
          endif
!
!  Read data without testfield into new run with testfield.
!
        elseif (lread_oldsnap_notestfield) then
          print*,'read old snapshot file (but without testfield),iaatest,iaztestpq,mvar,msnap=',iaatest,iaztestpq,mvar,msnap
          call input_snap(chsnap,f,msnap-ntestfield,1)
          ! shift the rest of the data
          if (iaztestpq<msnap) then
            do ivar=iaztestpq+1,msnap
              f(:,:,:,ivar)=f(:,:,:,ivar-ntestfield)
            enddo
            f(:,:,:,iaatest:iaatest+ntestfield-1)=0.
          endif
!
!  Read data without testscalar into new run with testscalar.
!
        elseif (lread_oldsnap_notestscalar) then
          print*,'read old snapshot file (but without testscalar),icctest,mvar,msnap=',icctest,mvar,msnap
          call input_snap(chsnap,f,msnap-ntestscalar,1)
          ! shift the rest of the data
          if (iaztestpq<msnap) then
            do ivar=iaztestpq+1,msnap
              f(:,:,:,ivar)=f(:,:,:,ivar-ntestscalar)
            enddo
            f(:,:,:,icctest:icctest+ntestscalar-1)=0.
          endif
        else
          call input_snap(chsnap,f,msnap,1)
        endif
!
    endsubroutine rsnap
!***********************************************************************
   subroutine powersnap(f,lwrite_only)
!
!  Write a snapshot of power spectrum.
!
!  30-sep-97/axel: coded
!  07-oct-02/nils: adapted from wsnap
!  08-oct-02/tony: expanded file to handle 120 character datadir // '/tspec.dat'
!  28-dec-02/axel: call structure from herel; allow optional lwrite_only
!
      use Boundcond, only: update_ghosts
      use Particles_main, only: particles_powersnap
      use Power_spectrum
      use Pscalar, only: cc2m, gcc2m, rhoccm
      use Struct_func, only: structure
      use Sub, only: update_snaptime, read_snaptime, curli
!
      real, dimension (mx,my,mz,mfarray) :: f
      logical, optional :: lwrite_only
!
      real, dimension (:,:,:), allocatable :: b_vec
      character (len=135) :: file
      character (len=5) :: ch
      logical :: lspec,llwrite_only=.false.,ldo_all
      integer, save :: ifirst=0,nspec
      real, save :: tspec
      integer :: ivec,im,in,stat
      real, dimension (nx) :: bb
!
!  Allocate memory for b_vec at run time.
!
      allocate(b_vec(nx,ny,nz),stat=stat)
      if (stat>0) call fatal_error('powersnap', &
          'Could not allocate memory for b_vec')
!
!  Set llwrite_only.
!
      if (present(lwrite_only)) llwrite_only=lwrite_only
      ldo_all=.not.llwrite_only
!
!  Output snapshot in 'tpower' time intervals.
!  File keeps the information about time of last snapshot.
!
      file=trim(datadir)//'/tspec.dat'
!
!  At first call, need to initialize tspec.
!  tspec calculated in read_snaptime, but only available to root processor.
!
      if (ldo_all.and.ifirst==0) then
        call read_snaptime(file,tspec,nspec,dspec,t)
        ifirst=1
      endif
!
!  Check whether we want to output power snapshot. If so, then
!  update ghost zones for var.dat (cheap, since done infrequently).
!
      if (ldo_all) &
           call update_snaptime(file,tspec,nspec,dspec,t,lspec,ch,ENUM=.false.)
      if (lspec.or.llwrite_only) then
        if (ldo_all)  call update_ghosts(f)
        if (vel_spec) call power(f,'u')
        if (r2u_spec) call power(f,'r2u')
        if (r3u_spec) call power(f,'r3u')
        if (mag_spec) call power(f,'b')
        if (vec_spec) call power(f,'a')
        if (j_spec)   call power_vec(f,'j')            
!         if (jb_spec)   call powerhel(f,'jb')            
        if (uxj_spec) call powerhel(f,'uxj')
        if (ou_spec)  call powerhel(f,'kin')
        if (ab_spec)  call powerhel(f,'mag')
        if (ub_spec)  call powerhel(f,'u.b')
        if (EP_spec)  call powerhel(f,'bEP')
        if (ro_spec)  call powerscl(f,'ro')
        if (lr_spec)  call powerscl(f,'lr')
        if (TT_spec)  call powerscl(f,'TT')
        if (ss_spec)  call powerscl(f,'ss')
        if (cc_spec)  call powerscl(f,'cc')
        if (cr_spec)  call powerscl(f,'cr')
        if (har_spec) call powerscl(f,'hr')
        if (hav_spec) call powerscl(f,'ha')
        if (oned) then
          if (vel_spec) call power_1d(f,'u',1)
          if (mag_spec) call power_1d(f,'b',1)
          if (vec_spec) call power_1d(f,'a',1)
          if (vel_spec) call power_1d(f,'u',2)
          if (mag_spec) call power_1d(f,'b',2)
          if (vec_spec) call power_1d(f,'a',2)
          if (vel_spec) call power_1d(f,'u',3)
          if (mag_spec) call power_1d(f,'b',3)
          if (vec_spec) call power_1d(f,'a',3)
        endif
        if (twod) then
          if (vel_spec) call power_2d(f,'u')
          if (mag_spec) call power_2d(f,'b')
          if (vec_spec) call power_2d(f,'a')
        endif
!
!  xy power spectra
!
        if (uxy_spec) call power_xy(f,'u')
        if (bxy_spec) call power_xy(f,'b')
!
!  phi power spectra (in spherical or cylindrical coordinates)
!
        if (vel_phispec) call power_phi(f,'u')
        if (mag_phispec) call power_phi(f,'b')
        if (vec_phispec) call power_phi(f,'a')
        if (ab_phispec)  call powerhel_phi(f,'mag')
        if (ou_phispec)  call powerhel_phi(f,'kin')
!
!  Spectra of particle variables.
!
        if (lparticles) call particles_powersnap(f)
!
!  Structure functions.
!
        do ivec=1,3
          if (lsfb .or. lsfz1 .or. lsfz2 .or. lsfflux .or. lpdfb .or. &
              lpdfz1 .or. lpdfz2) then
             do n=n1,n2
               do m=m1,m2
                 call curli(f,iaa,bb,ivec)
                 im=m-nghost
                 in=n-nghost
                 b_vec(:,im,in)=bb
               enddo
            enddo
            b_vec=b_vec/sqrt(exp(f(l1:l2,m1:m2,n1:n2,ilnrho)))
          endif
          if (lsfu)     call structure(f,ivec,b_vec,'u')
          if (lsfb)     call structure(f,ivec,b_vec,'b')
          if (lsfz1)    call structure(f,ivec,b_vec,'z1')
          if (lsfz2)    call structure(f,ivec,b_vec,'z2')
          if (lsfflux)  call structure(f,ivec,b_vec,'flux')
          if (lpdfu)    call structure(f,ivec,b_vec,'pdfu')
          if (lpdfb)    call structure(f,ivec,b_vec,'pdfb')
          if (lpdfz1)   call structure(f,ivec,b_vec,'pdfz1')
          if (lpdfz2)   call structure(f,ivec,b_vec,'pdfz2')
        enddo
!
!  Do pdf of passive scalar field (if present).
!
        if (rhocc_pdf) call pdf(f,'rhocc',rhoccm,sqrt(cc2m))
        if (cc_pdf)    call pdf(f,'cc'   ,rhoccm,sqrt(cc2m))
        if (lncc_pdf)  call pdf(f,'lncc' ,rhoccm,sqrt(cc2m))
        if (gcc_pdf)   call pdf(f,'gcc'  ,0.    ,sqrt(gcc2m))
        if (lngcc_pdf) call pdf(f,'lngcc',0.    ,sqrt(gcc2m))
!
      endif
!
      deallocate(b_vec)
!
    endsubroutine powersnap
!***********************************************************************
    subroutine output_snap(file,a,nv)
!
!  Write snapshot file, always write time and mesh, could add other things
!  version for vector field.
!
!  11-apr-97/axel: coded
!  28-jun-10/julien: Added different file formats
!
      use Mpicomm, only: start_serialize,end_serialize
      use Persist, only: output_persistent
!
      integer :: nv
      real, dimension (mx,my,mz,nv) :: a
      character (len=*) :: file
      real :: t_sp   ! t in single precision for backwards compatibility
!
      t_sp = t
      if (ip<=8.and.lroot) print*,'output_vect: nv =', nv
!
      if (lserial_io) call start_serialize()
      open(lun_output,FILE=file,FORM='unformatted')
      if (lwrite_2d) then
        if (nx==1) then
          write(lun_output) a(l1,:,:,:)
        elseif (ny==1) then
          write(lun_output) a(:,m1,:,:)
        elseif (nz==1) then
          write(lun_output) a(:,:,n1,:)
        else
          call fatal_error('output_snap','lwrite_2d used for 3-D simulation!')
        endif
      else
        write(lun_output) a
      endif
!
      if (lformat) call output_snap_form (file,a,nv)
!
      if (ltec) call output_snap_tec (file,a,nv)
!
!  Write shear at the end of x,y,z,dx,dy,dz.
!  At some good moment we may want to treat deltay like with
!  other modules and call a corresponding i/o parameter module.
!
      if (lshear) then
        write(lun_output) t_sp,x,y,z,dx,dy,dz,deltay
      else
        write(lun_output) t_sp,x,y,z,dx,dy,dz
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
!  Read snapshot file, possibly with mesh and time (if mode=1).
!
!  11-apr-97/axel: coded
!
      use Mpicomm, only: start_serialize,end_serialize
      use Persist, only: input_persistent
!
      character (len=*) :: file
      integer :: nv,mode
      real, dimension (mx,my,mz,nv) :: a
      real :: t_sp   ! t in single precision for backwards compatibility
!
      if (lserial_io) call start_serialize()
      open(1,FILE=file,FORM='unformatted')
!      if (ip<=8) print*,'input_snap: open, mx,my,mz,nv=',mx,my,mz,nv
      if (lwrite_2d) then
        if (nx==1) then
          read(1) a(4,:,:,:)
        elseif (ny==1) then
          read(1) a(:,4,:,:)
        elseif (nz==1) then
          read(1) a(:,:,4,:)
        else
          call fatal_error('input_snap','lwrite_2d used for 3-D simulation!')
        endif
      else
        read(1) a
      endif
      if (ip<=8) print*,'input_snap: read ',file
      if (mode==1) then
!
!  Check whether we want to read deltay from snapshot.
!
        if (lshear) then
          read(1) t_sp,x,y,z,dx,dy,dz,deltay
        else
          read(1) t_sp,x,y,z,dx,dy,dz
        endif
        t = t_sp
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
!
    endsubroutine input_snap
!***********************************************************************
    subroutine output_globals(file,a,nv)
!
!  Write snapshot file of globals, always write mesh.
!
!  10-nov-06/tony: coded
!
      use Mpicomm, only: start_serialize,end_serialize
!
      integer :: nv
      real, dimension (mx,my,mz,nv) :: a
      character (len=*) :: file
!
      if (ip<=8.and.lroot) print*,'output_vect: nv =', nv
!
      if (lserial_io) call start_serialize()
      open(lun_output,FILE=file,FORM='unformatted')
!
      if (lwrite_2d) then
        if (nx==1) then
          write(lun_output) a(4,:,:,:)
        elseif (ny==1) then
          write(lun_output) a(:,4,:,:)
        elseif (nz==1) then
          write(lun_output) a(:,:,4,:)
        else
          call fatal_error('output_globals','lwrite_2d used for 3-D simulation!')
        endif
      else
        write(lun_output) a
      endif
!
      close(lun_output)
!
      if (lserial_io) call end_serialize()
!
    endsubroutine output_globals
!***********************************************************************
    subroutine input_globals(filename,a,nv)
!
!  Read globals snapshot file, ignoring mesh.
!
!  10-nov-06/tony: coded
!
      use Mpicomm, only: start_serialize,end_serialize
!
      character (len=*) :: filename
      integer :: nv
      real, dimension (mx,my,mz,nv) :: a
!
      if (lserial_io) call start_serialize()
!
      open(1,FILE=filename,FORM='unformatted')
      if (ip<=8) print*,'input_globals: open, mx,my,mz,nv=',mx,my,mz,nv
      if (lwrite_2d) then
        if (nx==1) then
          read(1) a(4,:,:,:)
        elseif (ny==1) then
          read(1) a(:,4,:,:)
        elseif (nz==1) then
          read(1) a(:,:,4,:)
        else
          call fatal_error('input_globals','lwrite_2d used for 3-D simulation!')
        endif
      else
        read(1) a
      endif
      if (ip<=8) print*,'input_globals: read ',filename
      close(1)
!
      if (lserial_io) call end_serialize()
!
    endsubroutine input_globals
!***********************************************************************
    subroutine update_auxiliaries(a)
!
      use EquationOfState, only: ioncalc
      use Radiation, only: radtransfer
      use Shock, only: calc_shock_profile,calc_shock_profile_simple
      use Viscosity, only: lvisc_first,calc_viscosity
!
      real, dimension (mx,my,mz,mfarray), intent (inout) :: a
!
      if (lshock) then
        call calc_shock_profile(a)
        call calc_shock_profile_simple(a)
      endif
      if (leos_ionization.or.leos_temperature_ionization) call ioncalc(a)
      if (lradiation_ray)  call radtransfer(a)
      if (lvisc_hyper.or.lvisc_smagorinsky) then
        if (.not.lvisc_first.or.lfirst) call calc_viscosity(a)
      endif
!
    endsubroutine update_auxiliaries
!***********************************************************************
    subroutine output_snap_form(file,a,nv)
!
!  Write FORMATED snapshot file 
!
!  28-june-10/julien: coded (copy from output_snap)
!
      integer :: nv
      integer :: i, j, k
      real, dimension (mx,my,mz,nv) :: a
      real :: t_sp
      character (len=*) :: file
!
      t_sp = t
      open(lun_output+1,FILE=file//'_form')
!
      if (lwrite_2d) then
        if (nx==1) then
	  do i = m1, m2
	    do j = n1, n2
	      write(lun_output+1,'(22(f12.5))') t_sp,x(l1),y(i),z(j),dx,dy,dz,a(l1,i,j,:)
	    enddo
	  enddo
        elseif (ny==1) then
          do i = l1, l2
	    do j = n1, n2          
	      write(lun_output+1,'(22(f12.5))') t_sp,x(i),y(m1),z(j),dx,dy,dz,a(i,m1,j,:)
	    enddo
	  enddo
        elseif (nz==1) then
          do i = l1, l2
	    do j = m1, m2  	
              write(lun_output+1,'(22(f12.5))') t_sp,x(i),y(j),z(n1),dx,dy,dz,a(i,j,n1,:)
	    enddo
	  enddo
        else
          call fatal_error('output_snap','lwrite_2d used for 3-D simulation!')
        endif
      else
        do i = l1, l2
	  do j = m1, m2   
	    do k = n1, n2       
	      write(lun_output+1,'(22(f12.5))') t_sp,x(i),y(j),z(k),dx,dy,dz,a(i,j,k,:)
	    enddo
	  enddo
	enddo
      endif
!
      close(lun_output+1)     
!
    endsubroutine output_snap_form
!***********************************************************************
    subroutine output_snap_tec(file,a,nv)
!
!  Write TECPLOT output files (binary)
!
!  28-june-10/julien: coded
!
      integer :: nv, nd
      integer :: i, j, k, kk
      integer :: nnx, nny, nnz
      real, dimension (mx,my,mz,nv) :: a
      real, dimension (nx*ny*nz) :: xx, yy, zz
      character (len=*) :: file
      character (len=300) :: car
      character(len=2) :: car2
      character (len=8), dimension (nv) :: name
!
      open(lun_output+2,FILE=file//'.tec')
!
      kk = 0
      do k = 1, nz
        do j = 1, ny
          do i = 1, nx
            xx(kk+i) = x(i)
	    yy(kk+i) = y(j)
	    zz(kk+i) = z(k)	    
          enddo
          kk = kk + nx
        enddo
      enddo
!
!  Write header
!
      write(lun_output+2,*) 'TITLE     = "output"'
      if (lwrite_2d) then
      nd = 2             
      if (nx==1) then      
      write(lun_output+2,*) 'VARIABLES = "y"'
      write(lun_output+2,*) '"z"'
      elseif (ny==1) then 
      write(lun_output+2,*) 'VARIABLES = "x"'
      write(lun_output+2,*) '"z"'           
      elseif (nz==1) then
      write(lun_output+2,*) 'VARIABLES = "x"'
      write(lun_output+2,*) '"y"'
      endif      
      else
      if (ny==1.and.nz==1) then
      write(lun_output+2,*) 'VARIABLES = "x"' 
      nd = 1     
      else 
      write(lun_output+2,*) 'VARIABLES = "x"'
      write(lun_output+2,*) '"y"'  
      write(lun_output+2,*) '"z"' 
      nd = 3         
      endif
      endif
      do i = 1, nv
        write(car2,'(i2)') i
        name(i) = 'VAR_'//adjustl(car2)
        write(lun_output+2,*) '"'//trim(name(i))//'"'
      enddo
!
      write(lun_output+2,*) 'ZONE T="Zone"'    
      if (lwrite_2d) then     
      if (nx==1) write(lun_output+2,*) ' I=1, J=',ny, ', K=',nz
      if (ny==1) write(lun_output+2,*) ' I=',nx, ', J=1, K=',nz   
      if (nz==1) write(lun_output+2,*) ' I=',nx, ', J=',ny, ', K=1'  
      else
      if (ny==1.and.nz==1) then
      write(lun_output+2,*) ' I=',nx, ', J=1, K='    
      else
      write(lun_output+2,*) ' I=',nx, ', J=',ny, ', K=',nz     
      endif
      endif
      write(lun_output+2,*) ' DATAPACKING=BLOCK'
      car= 'DOUBLE'
      do i = 1, nv+nd-1
        car = trim(car)//' DOUBLE '
      enddo
      write(lun_output+2,*) ' DT=('//trim(car)//')'
!
!  Write data
!
      if (lwrite_2d) then
        if (nx==1) then
	  write(lun_output+2,*) yy
	  write(lun_output+2,*) zz
	  do j = 1, nv
	    write(lun_output+2,*) a(l1,m1:m2,n1:n2,j)
          enddo
	elseif (ny==1) then
	  write(lun_output+2,*) xx
	  write(lun_output+2,*) zz	  
	  do j = 1, nv
	    write(lun_output+2,*) a(l1:l2,m1,n1:n2,j)
          enddo
	elseif (nz==1) then
	  write(lun_output+2,*) xx
	  write(lun_output+2,*) yy	  
          do j = 1, nv
	    write(lun_output+2,*) a(l1:l2,m1:m2,n1,j)
          enddo
	else
          call fatal_error('output_snap','lwrite_2d used for 3-D simulation!')
        endif
      else
	if (ny==1.and.nz==1) then
	write(lun_output+2,*) xx	
	do j = 1, nv
          write(lun_output+2,*) a(l1:l2,m1,n1,j)
	enddo	
	else
	write(lun_output+2,*) xx
	write(lun_output+2,*) yy
	write(lun_output+2,*) zz
	do j = 1, nv
          write(lun_output+2,*) a(l1:l2,m1:m2,n1:n2,j)
	enddo
	endif
      endif
!
      close(lun_output+2)     
!
    endsubroutine output_snap_tec
!
!***********************************************************************
endmodule Snapshot
