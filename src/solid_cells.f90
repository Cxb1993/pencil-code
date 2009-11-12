! $Id$
!
!  This module add solid (as in no-fluid) cells in the domain.
!  This can be used e.g. in order to simulate a cylinder in a cross flow.
!
module Solid_Cells

  use Cparam
  use Cdata
  use Messages
  
  implicit none
  
  include 'solid_cells.h'

  integer, parameter            :: max_items=10
  integer                       :: ncylinders,nrectangles,dummy
  integer                       :: nforcepoints=300
  real, dimension(max_items,5)  :: cylinder
  real, dimension(max_items,7)  :: rectangle
  real, dimension(max_items)    :: cylinder_radius
  real, dimension(max_items)    :: cylinder_temp=703.0
  real, dimension(max_items)    :: cylinder_xpos,cylinder_ypos,cylinder_zpos
  integer, dimension(mx,my,mz,4):: ba,ba_shift
  real :: skin_depth=0, init_uu=0, ampl_noise=0, cylinder_skin=0
  character (len=labellen), dimension(ninit) :: initsolid_cells='nothing'
  character (len=labellen) :: interpolation_method='staircase'
  integer, parameter :: iradius=1, ixpos=2,iypos=3,izpos=4,itemp=5
  logical :: lclose_interpolation=.false., lclose_linear=.false.
  real                          :: rhosum
  integer                       :: irhocount
  real                          :: theta_shift=1e-2
  real                          :: limit_close_linear=0.5
!
  namelist /solid_cells_init_pars/ &
       cylinder_temp, ncylinders, cylinder_radius, cylinder_xpos, &
       cylinder_ypos, cylinder_zpos, initsolid_cells, skin_depth, init_uu, &
       ampl_noise,interpolation_method, nforcepoints,cylinder_skin,&
       lclose_interpolation,lclose_linear,limit_close_linear
!
  namelist /solid_cells_run_pars/  &
       interpolation_method,cylinder_skin,lclose_interpolation,lclose_linear,&
       limit_close_linear
!
!  diagnostic variables (need to be consistent with reset list below)
  integer :: idiag_c_dragx=0       ! DIAG_DOC: 
  integer :: idiag_c_dragy=0       ! DIAG_DOC: 
!
  integer, allocatable :: fpnearestgrid(:,:,:)
  real, allocatable    :: c_dragx(:), c_dragy(:)
  contains
!***********************************************************************
    subroutine initialize_solid_cells
!
!  Define the geometry of the solids.
!  There might be many separate solid objects of different geometries (currently
!  only cylinders are implemented however).
!
!  19-nov-2008/nils: coded
!
      integer :: icyl
!
      lsolid_cells=.true.
!
!  Define the geometry of the solid object.
!  For more complex geometries (i.e. for objects different than cylinders or
!  rectangles) this shold probably be included as a geometry.local file such that
!  one can define complex geometries on a case to case basis.
!  Alternatively one will here end up with a terribly long series
!  of case checks.
!
      do icyl=1,ncylinders
        if (cylinder_radius(icyl)>0) then
          cylinder(icyl,iradius)=cylinder_radius(icyl)
          cylinder(icyl,ixpos)=cylinder_xpos(icyl)
          cylinder(icyl,iypos)=cylinder_ypos(icyl)
          cylinder(icyl,izpos)=cylinder_zpos(icyl)
          cylinder(icyl,itemp)=cylinder_temp(icyl)
        else
          call fatal_error('initialize_solid_cells',&
               'All cylinders must have non-zero radii!')
        endif
      enddo
!
      call find_solid_cell_boundaries
      call calculate_shift_matrix
!
!
! Find nearest grid point of the "forcepoints" on all cylinders
! (needs also to be called elsewhere if cylinders move)
!
      allocate(fpnearestgrid(ncylinders,nforcepoints,3))
      allocate(c_dragx(ncylinders))
      allocate(c_dragy(ncylinders))
      call fp_nearest_grid
      rhosum    = 0.0
      irhocount = 0
!
    endsubroutine initialize_solid_cells
!***********************************************************************
    subroutine init_solid_cells(f)
!
!  Initial conditions for cases where we have solid structures in the domain.
!  Typically the flow field is set such that we have no-slip conditions
!  at the solid structure surface.
! 
!  28-nov-2008/nils: coded
!
      use Cdata
      use Sub
      use Initcond
      use InitialCondition, only: initial_condition_solid_cells
!
      real, dimension (mx,my,mz,mfarray), intent(inout) :: f
      integer, pointer :: iglobal_cs2,iglobal_glnTT
      real :: a2,rr2,pphi,wall_smoothing,rr2_low,rr2_high,shiftx,shifty
      real :: wall_smoothing_temp,xr,yr
      integer i,j,k,cyl,jj,icyl
!
      do jj=1,ninit
      select case(initsolid_cells(jj))
!
!  This overrides any initial conditions set in the Hydro module.
!
      case('nothing')
        if (lroot) print*,'init_solid_cells: nothing'
      case('cylinderstream_x')
!  Stream functions for flow around a cylinder as initial condition. 
        call gaunoise(ampl_noise,f,iux,iuz)
        f(:,:,:,iux)=f(:,:,:,iux)+init_uu
        shiftx=0
        do i=l1,l2
        do j=m1,m2
        do k=n1,n2
!
!  Loop over all cylinders
!
          do icyl=1,ncylinders
            a2 = cylinder(icyl,1)**2
            xr=x(i)-cylinder(icyl,2)
            if (cylinder(icyl,3) .ne. 0) then
              print*,'When using cylinderstream_x all cylinders must have'
              print*,'zero offset in y-direction!'
              call fatal_error('init_solid_cells:','')
            endif
            yr=y(j)
            rr2 = xr**2+yr**2
            if (rr2 > a2) then
              do cyl=0,100
                if (cyl==0) then
                  wall_smoothing=1-exp(-(rr2-a2)/skin_depth**2)
                  f(i,j,k,iuy) = f(i,j,k,iuy)-init_uu*&
                       2*x(i)*y(j)*a2/rr2**2*wall_smoothing
                  f(i,j,k,iux) = f(i,j,k,iux)+init_uu*&
                       (0. - a2/rr2 + 2*y(j)**2*a2/rr2**2)&
                       *wall_smoothing
                  if (ilnTT .ne. 0) then
                    wall_smoothing_temp=1-exp(-(rr2-a2)/(sqrt(a2))**2)
                    f(i,j,k,ilnTT) = wall_smoothing_temp*f(i,j,k,ilnTT)&
                         +cylinder(icyl,5)*(1-wall_smoothing_temp)
                    f(i,j,k,ilnrho)=f(l2,m2,n2,ilnrho)&
                         *f(l2,m2,n2,ilnTT)/f(i,j,k,ilnTT)
                  endif
                else
                  shifty=cyl*Lxyz(2)
                  rr2_low =(x(i)+shiftx)**2+(y(j)+shifty)**2
                  rr2_high=(x(i)-shiftx)**2+(y(j)-shifty)**2
                  f(i,j,k,iux) = f(i,j,k,iux)+init_uu*( &
                       +2*(y(j)-shifty)**2*a2/rr2_high**2-a2/rr2_high&
                       +2*(y(j)+shifty)**2*a2/rr2_low**2 -a2/rr2_low)
                  f(i,j,k,iuy) = f(i,j,k,iuy)-init_uu*( &
                       +2*(x(i)-shiftx)*(y(j)-shifty)&
                       *a2/rr2_high**2&
                       +2*(x(i)+shiftx)*(y(j)+shifty)&
                       *a2/rr2_low**2)
                endif
              enddo
            else
              if (ilnTT .ne. 0) then
                f(i,j,k,ilnTT) = cylinder(icyl,5)
                f(i,j,k,ilnrho)=f(l2,m2,n2,ilnrho)&
                     *f(l2,m2,n2,ilnTT)/cylinder(icyl,5)
              endif
            endif
          enddo
        enddo
        enddo
        enddo
      case('cylinderstream_y')
!  Stream functions for flow around a cylinder as initial condition.
        call gaunoise(ampl_noise,f,iux,iuz)
        f(:,:,:,iuy)=f(:,:,:,iuy)+init_uu
        shifty=0
        do i=l1,l2
        do j=m1,m2
        do k=n1,n2
          do icyl=1,ncylinders
            a2 = cylinder(icyl,1)**2
            yr=y(j)-cylinder(icyl,3)
            if (cylinder(icyl,2) .ne. 0) then
              print*,'When using cylinderstream_y all cylinders must have'
              print*,'zero offset in x-direction!'
              call fatal_error('init_solid_cells:','')
            endif
            xr=x(i)
            rr2 = xr**2+yr**2
            if (rr2 > a2) then
              do cyl=0,100
                if (cyl==0) then
                  wall_smoothing=1-exp(-(rr2-a2)/skin_depth**2)
                  f(i,j,k,iux) = f(i,j,k,iux)-init_uu*&
                       2*xr*yr*a2/rr2**2*wall_smoothing
                  f(i,j,k,iuy) = f(i,j,k,iuy)+init_uu*&
                       (0. - a2/rr2 + 2*xr**2*a2/rr2**2)&
                       *wall_smoothing
                  if (ilnTT .ne. 0) then
                    wall_smoothing_temp=1-exp(-(rr2-a2)/(sqrt(a2))**2)
                    f(i,j,k,ilnTT) = wall_smoothing_temp*f(i,j,k,ilnTT)&
                         +cylinder(icyl,5)*(1-wall_smoothing_temp)
                    f(i,j,k,ilnrho)=f(l2,m2,n2,ilnrho)&
                         *f(l2,m2,n2,ilnTT)/f(i,j,k,ilnTT)
                  endif
                else
                  shiftx=cyl*Lxyz(1)
                  rr2_low =(xr+shiftx)**2+(yr+shifty)**2
                  rr2_high=(xr-shiftx)**2+(yr-shifty)**2
                  f(i,j,k,iuy) = f(i,j,k,iuy)+init_uu*( &
                       +2*(xr-shiftx)**2*a2/rr2_high**2-a2/rr2_high&
                       +2*(xr+shiftx)**2*a2/rr2_low**2 -a2/rr2_low)
                  f(i,j,k,iux) = f(i,j,k,iux)-init_uu*( &
                       +2*(xr-shiftx)*(y(j)-shifty)&
                       *a2/rr2_high**2&
                       +2*(xr+shiftx)*(y(j)+shifty)&
                       *a2/rr2_low**2)
                endif
              enddo
            else
              if (ilnTT .ne. 0) then
                f(i,j,k,ilnTT) = cylinder(icyl,5)
                f(i,j,k,ilnrho)=f(l2,m2,n2,ilnrho)&
                     *f(l2,m2,n2,ilnTT)/cylinder(icyl,5)
              endif
            endif
          enddo
        enddo
        enddo
        enddo
if (ipy==nprocy-1) f(:,m2-5:m2,:,iux)=0
      case default
!
!  Catch unknown values
!
        if (lroot) print*,'No such value for init_solid_cells:',&
             trim(initsolid_cells(jj))
        call fatal_error('init_solid_cells','')
      endselect
    enddo
!
!  Interface for user's own initial condition
!
    if (linitial_condition) call initial_condition_solid_cells(f)
!
    endsubroutine init_solid_cells
!***********************************************************************  
  subroutine fp_nearest_grid
!
!  Find coordinates for nearest grid point of all the 
!  "forcepoints" (fp) for each cylinder (assume cylinder with axis
!  parallel to the z direction. Assign values to fpnearestgrid.
!
!  mar-2009/kragset: coded
!
!
    integer              :: icyl,iforcepoint, ipoint, inearest, icoord(8,3)
    integer              :: ixl, iyl, izl, ixu, iyu, izu, ju, jl, jm
    real                 :: rcyl, xcyl, ycyl, zcyl,fpx, fpy, fpz
    real                 :: dx1, dy1, dz1
    real                 :: dist_to_fp2(8), dist_to_cent2(8), twopi
    logical              :: interiorpoint
!
    dx1=1/dx
    dy1=1/dy
    dz1=1/dz
!
    twopi=2.*pi
!
!  Loop over all cylinders 
    do icyl=1,ncylinders
      rcyl = cylinder(icyl,iradius)
      xcyl = cylinder(icyl,ixpos)
      ycyl = cylinder(icyl,iypos)
      zcyl = z(n1) !! Needs to be corrected in order to provide variable n in 3D
!
!  Loop over all forcepoints on each cylinder, icyl
      do iforcepoint=1,nforcepoints
!        
!  Marking whether fp is within this processor's domain or not 
        interiorpoint = .true.
!
!  Fp coordinates
!  Shifting the location of the forcpoints in the thetal direction
!  in order to avoid problems with autotesting
        fpx = xcyl - rcyl * sin(twopi*(iforcepoint-theta_shift)/nforcepoints)
        fpy = ycyl - rcyl * cos(twopi*(iforcepoint-theta_shift)/nforcepoints)
        fpz = z(n1)
!
!  Find nearest grid point in x-direction
!          
        if (nxgrid/=1) then
          if (fpx .ge. x(l1-1) .and. fpx .le. x(l2+1)) then
            if (lequidist(1)) then
              ixl = int((fpx-x(1))*dx1) + 1
              ixu = ixl+1
            else
!
!  Find nearest grid point by bisection if grid is not equidistant
!
              ju=l2+1; jl=l1-1
              do while((ju-jl)>1)
                jm=(ju+jl)/2
                if (fpx > x(jm)) then
                  jl=jm
                else
                  ju=jm
                endif
              enddo
              ixl=jl
              ixu=ju
            endif
          else
            interiorpoint=.false.
          endif
        else
          print*,"WARNING: Solid cells need nxgrid > 1."
        endif
!
!  Find nearest grid point in y-direction
!          
        if (nygrid/=1) then
          if (fpy .ge. y(m1-1) .and. fpy .le. y(m2+1)) then
            if (lequidist(2)) then
              iyl = int((fpy-y(1))*dy1) + 1
              iyu = iyl+1
            else
!
!  Find nearest grid point by bisection if grid is not equidistant
!
              ju=m2; jl=m1
              do while((ju-jl)>1)
                jm=(ju+jl)/2
                if (fpy > y(jm)) then
                  jl=jm
                else
                  ju=jm
                endif
              enddo
              iyl=jl
              iyu=ju
            endif
          else
            interiorpoint=.false.
          endif
        else
          print*,"WARNING: Solid cells need nygrid > 1."
        endif
!
!  Find nearest grid point in z-direction
!          
        if (nzgrid/=1) then
          if (fpz .ge. z(n1-1) .and. fpz .le. z(n2+1)) then
            if (lequidist(3)) then
              izl = int((fpz-z(1))*dz1) + 1
              izu = izl+1
            else
!
!  Find nearest grid point by bisection if grid is not equidistant
!
              ju=n2; jl=n1
              do while((ju-jl)>1)
                jm=(ju+jl)/2
                if (fpz > z(jm)) then
                  jl=jm
                else
                  ju=jm
                endif
              enddo
              izl=jl
              izu=ju
            endif
          else
            interiorpoint=.false.
          endif
        else
!  z direction is irrelevant when in 2D
          izl=n1
          izu=n1
        endif
!
!  Now, we have the upper and lower (x,y,z)-coordinates: 
!  ixl, ixu, iyl, iyu, izl, izu,
!  i.e. the eight corners of the grid cell containing the forcepoint (fp).
!  Decide which ones are outside the cylinder, and which one of these
!  is the closest one to fp:
!
!  Check if fp is within this processor's local domain
        if (interiorpoint) then
          dist_to_fp2(1) = (x(ixl)-fpx)**2+(y(iyl)-fpy)**2+(z(izl)-fpz)**2 
          dist_to_fp2(2) = (x(ixu)-fpx)**2+(y(iyl)-fpy)**2+(z(izl)-fpz)**2 
          dist_to_fp2(3) = (x(ixu)-fpx)**2+(y(iyu)-fpy)**2+(z(izl)-fpz)**2 
          dist_to_fp2(4) = (x(ixl)-fpx)**2+(y(iyu)-fpy)**2+(z(izl)-fpz)**2 
          dist_to_fp2(5) = (x(ixl)-fpx)**2+(y(iyl)-fpy)**2+(z(izu)-fpz)**2 
          dist_to_fp2(6) = (x(ixu)-fpx)**2+(y(iyl)-fpy)**2+(z(izu)-fpz)**2 
          dist_to_fp2(7) = (x(ixu)-fpx)**2+(y(iyu)-fpy)**2+(z(izu)-fpz)**2 
          dist_to_fp2(8) = (x(ixl)-fpx)**2+(y(iyu)-fpy)**2+(z(izu)-fpz)**2 
          dist_to_cent2(1) = (x(ixl)-xcyl)**2+(y(iyl)-ycyl)**2+(z(izl)-zcyl)**2 
          dist_to_cent2(2) = (x(ixu)-xcyl)**2+(y(iyl)-ycyl)**2+(z(izl)-zcyl)**2 
          dist_to_cent2(3) = (x(ixu)-xcyl)**2+(y(iyu)-ycyl)**2+(z(izl)-zcyl)**2 
          dist_to_cent2(4) = (x(ixl)-xcyl)**2+(y(iyu)-ycyl)**2+(z(izl)-zcyl)**2 
          dist_to_cent2(5) = (x(ixl)-xcyl)**2+(y(iyl)-ycyl)**2+(z(izu)-zcyl)**2 
          dist_to_cent2(6) = (x(ixu)-xcyl)**2+(y(iyl)-ycyl)**2+(z(izu)-zcyl)**2 
          dist_to_cent2(7) = (x(ixu)-xcyl)**2+(y(iyu)-ycyl)**2+(z(izu)-zcyl)**2 
          dist_to_cent2(8) = (x(ixl)-xcyl)**2+(y(iyu)-ycyl)**2+(z(izu)-zcyl)**2
          icoord(1,:) = (/ixl,iyl,izl/)
          icoord(2,:) = (/ixu,iyl,izl/)
          icoord(3,:) = (/ixu,iyu,izl/)
          icoord(4,:) = (/ixl,iyu,izl/)
          icoord(5,:) = (/ixl,iyl,izu/)
          icoord(6,:) = (/ixu,iyl,izu/)
          icoord(7,:) = (/ixu,iyu,izu/)
          icoord(8,:) = (/ixl,iyu,izu/)
          inearest=0
          do ipoint=1,8 ! Actually, 4 is sufficient in 2D / for cylinder
!  Test if we are in a fluid cell, i.e.
!  that mod(ba(ix,iy,iz,1),10) = 0 
            if (mod(ba(icoord(ipoint,1),icoord(ipoint,2),icoord(ipoint,3),1),10)&
                .eq. 0 .and. inearest .eq. 0) then
              inearest=ipoint
            else if ( &
                mod(ba(icoord(ipoint,1),icoord(ipoint,2),icoord(ipoint,3),1),10)&
                .eq. 0 ) then
              if (dist_to_fp2(ipoint) .le. dist_to_fp2(inearest)) then
                inearest=ipoint
              endif
            endif
          enddo
!          
!  Coordinates of nearest grid point. Zero if outside local domain.
          if (inearest > 0) then
            fpnearestgrid(icyl,iforcepoint,:) = icoord(inearest,:)
          else
            print*, "WARNING: Could not find fpnearestgrid!"
          endif

        else ! fp is outside local domain and fpnearestgrid shouldn't exist
          fpnearestgrid(icyl,iforcepoint,:) = 0
        endif
      enddo
    enddo
!
  endsubroutine fp_nearest_grid
!***********************************************************************  
  subroutine dsolid_dt(f,df,p)
!
!  Find pressure and stress in all the forcepoints (fp) positioned on 
!  cylinder surface, based on values in nearest grid point.
!
!  mar-2009/kragset: coded
!  okt-2009/kragset: updated to include multiple cylinders
!
    use viscosity, only: getnu
!    
    real, dimension (mx,my,mz,mfarray), intent(in):: f
    real, dimension (mx,my,mz,mvar), intent(in)   :: df
    type (pencil_case), intent(in)                :: p

    real    :: fp_pressure
    real    :: fp_stress(3,3)
    integer :: icyl,ifp,ix0,iy0,iz0, i
    real    :: nu, twonu, xr, yr, rr2, a2
    real    :: force_x, force_y
    real    :: twopi, nvec(3)
!
    if (ldiagnos) then
!      
!  Reset cumulating quantities before calculations in first pencil
!
      if (imn .eq. 1) then
        c_dragx=0.
        c_dragy=0.
        rhosum=0
        irhocount=0
      endif
!
      if (idiag_c_dragx .ne. 0 .or. idiag_c_dragy .ne. 0) then 
        call getnu(nu)
        twopi=2.*pi
        twonu=2.*nu
!
        do icyl=1,ncylinders
          do ifp=1,nforcepoints
            iy0=fpnearestgrid(icyl,ifp,2)
!
            iz0=n !!fpnearestgrid(icyl,ifp,3) doesn't yet provide correct iz0
!
!  Test: Use this pencil for force calculation?
!
            if (iy0 .eq. m .and. iz0 .eq. n) then
              ix0=fpnearestgrid(icyl,ifp,1)
              ! Test: ix0 in local domain?
              if (ix0 .ge. l1 .and. ix0 .le. l2) then
!
!  Acquire pressure and stress from grid point (ix0,iy0,iz0).
!  Shifting the location of the forcpoints in the thetal direction
!  in order to avoid problems with autotesting
!
                fp_pressure=p%pp(ix0-nghost)
                fp_stress(:,:)=twonu*p%rho(ix0-nghost)*p%sij(ix0-nghost,:,:)
                
                nvec(1) = -sin(twopi*(ifp-theta_shift)/nforcepoints)
                nvec(2) = -cos(twopi*(ifp-theta_shift)/nforcepoints)
                nvec(3) = 0
!
!  Force in x direction
!
                force_x = -fp_pressure*nvec(1) &
                    + fp_stress(1,1)*nvec(1) &
                    + fp_stress(1,2)*nvec(2) & 
                    + fp_stress(1,3)*nvec(3) 
!                
!  Force in y direction
!
                force_y = -fp_pressure*nvec(2) &
                    + fp_stress(2,1)*nvec(1) &
                    + fp_stress(2,2)*nvec(2) & 
                    + fp_stress(2,3)*nvec(3)                 
                c_dragx(icyl) = c_dragx(icyl) + force_x
                c_dragy(icyl) = c_dragy(icyl) + force_y
              endif
            endif
          enddo
        enddo
!
!  Calculate average density of the domain, excluded
!  solid cell regions:
!
        do i=l1,l2
          if (mod(ba(i,m,n,1),10) .eq. 0) then
            rhosum = rhosum + p%rho(i-nghost)
            irhocount = irhocount+1
          endif
        enddo
      endif
    endif
!
  endsubroutine dsolid_dt
!***********************************************************************  
  subroutine dsolid_dt_integrate
!
!  Calculate drag- and lift-coefficients for solid cell cylinders
!  by integrating fluid force on cylinder surface. 
!
!  mar-2009/kragset: coded
!  okt-2009/kragset: updated to include multiple cylinders
!
    use mpicomm
    use general

    real    :: rhosum_all, c_dragx_all(ncylinders), c_dragy_all(ncylinders)
    real    :: cpx,ctx,cpy,cty
    integer :: irhocount_all,icyl
    real    :: norm, refrho0
    character*50  :: numberstring
    character*500 :: solid_cell_drag
!    
    if (ldiagnos) then
      if (idiag_c_dragx .ne. 0 .or. idiag_c_dragy .ne. 0) then 
!
!  Collect and sum rhosum, irhocount, c_dragx and c_dragy
        call mpireduce_sum(rhosum,rhosum_all)
        call mpireduce_sum_int(irhocount,irhocount_all)
        call mpireduce_sum(c_dragx,c_dragx_all,ncylinders)
        call mpireduce_sum(c_dragy,c_dragy_all,ncylinders)
!        
        if (lroot) then          
          refrho0 = rhosum_all / irhocount_all
          norm = 2. * pi / (nforcepoints*refrho0*init_uu**2)
!          
          c_dragx = c_dragx_all * norm
          c_dragy = c_dragy_all * norm
!          
!  Write drag coefficients for all cylinders
!  (may need to expand solid_cell_drag to more
!  characters if large number of cylinders)
! 
          open(unit=81,file='data/dragcoeffs.dat',position='APPEND')
          write(solid_cell_drag,84) it-1, t
          do icyl=1,ncylinders
            write(numberstring,82) c_dragx(icyl), c_dragy(icyl)
            call safe_character_append(solid_cell_drag,numberstring)
          enddo
          write(81,*) trim(solid_cell_drag)
          close(81)
84        format(1I8,1F15.8)
82        format(2F15.8)
        endif
      endif
      if (idiag_c_dragx .ne. 0) fname(idiag_c_dragx)=c_dragx(1)
      if (idiag_c_dragy .ne. 0) fname(idiag_c_dragy)=c_dragy(1)
    endif
 !   
  endsubroutine dsolid_dt_integrate
 !***********************************************************************  
  subroutine rprint_solid_cells(lreset,lwrite)
!
!  Reads and registers print parameters relevant for solid cells
!
!   mar-2009/kragset: coded
!
!    
    use cdata
    use sub
    use diagnostics
!    
    integer :: iname
    logical :: lreset,lwr
    logical, optional :: lwrite
!
    lwr = .false.
    if (present(lwrite)) lwr=lwrite
!
!  Reset everything in case of reset
! 
    if (lreset) then
      idiag_c_dragx=0 
      idiag_c_dragy=0
    endif
!
!  check for those quantities that we want to evaluate online
!
    do iname=1,nname
      call parse_name(iname,cname(iname),cform(iname),'c_dragx',idiag_c_dragx)
      call parse_name(iname,cname(iname),cform(iname),'c_dragy',idiag_c_dragy)
    enddo
!
!  write column, idiag_XYZ, where our variable XYZ is stored
!
    if (lwr) then
      write(3,*) 'i_c_dragx=',idiag_c_dragx
      write(3,*) 'i_c_dragy=',idiag_c_dragy
    endif
!    
  endsubroutine rprint_solid_cells
!***********************************************************************  
    subroutine update_solid_cells(f)
!
!  Set the boundary values of the solid area such that we get a 
!  correct fluid-solid interface.
!
!  19-nov-2008/nils: coded
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: i,j,k,idir,xind,yind,zind,icyl
      
      real :: y_cyl, x_cyl, r_cyl, r_new, r_point, sin_theta, cos_theta
      real :: xmirror, ymirror, phi, dr
      integer :: lower_i, upper_i, lower_j, upper_j, ii, jj
      logical :: bax, bay
      real :: gpp
      real, dimension(3) :: xxp
!
!  Find ghost points based on the mirror interpolation method
!
      if (interpolation_method=='mirror') then
        do i=l1,l2
        do j=m1,m2
        do k=n1,n2
          bax=(ba(i,j,k,1) .ne. 0).and.(ba(i,j,k,1).ne.9).and.(ba(i,j,k,1).ne.10)
          bay=(ba(i,j,k,2) .ne. 0).and.(ba(i,j,k,2).ne.9).and.(ba(i,j,k,2).ne.10)
!
!  Check if we are in a point which must be interpolated, i.e. we are inside
!  a solid geometry AND we are not more than three grid points from the 
!  closest solid-fluid interface
!
          if (bax.or.bay) then
!
!  Find x and y values of mirror point
!
            icyl=ba(i,j,k,4)
            x_cyl=cylinder(icyl,ixpos)
            y_cyl=cylinder(icyl,iypos)
            r_cyl=cylinder(icyl,iradius)
            r_point=sqrt(((x(i)-x_cyl)**2+(y(j)-y_cyl)**2))
            r_new=r_cyl+(r_cyl-r_point)
            sin_theta=(y(j)-y_cyl)/r_point
            cos_theta=(x(i)-x_cyl)/r_point
            xmirror=cos_theta*r_new+x_cyl
            ymirror=sin_theta*r_new+y_cyl
!
!  Check that we are indeed inside the solid geometry
!
            if (r_point>r_cyl) then
              call fatal_error('update_solid_cells:','r_point>r_cyl')
            endif
!
!  Find i and j indeces for points to be used during interpolation 
!
            lower_i=0
            upper_i=0
            do ii=1,mx
              if (x(ii)>xmirror) then
                lower_i=ii-1
                upper_i=ii
                exit
              endif
            enddo
!
            lower_j=0
            upper_j=0
            do jj=1,my
              if (y(jj)>ymirror) then
                lower_j=jj-1
                upper_j=jj
                exit
              endif
            enddo
!
!  Issue with domain borders: A mirror point can be outside a
!  processor's local domain (including ghost points). Some sort
!  communication has to be implemented!
!
            if (lower_i .eq. 0 .or. upper_i .eq. 0) then
              call fatal_error('update_solid_cells:','lower_i==0 or upper_i==0')
            endif
            if (lower_j .eq. 0 .or. upper_j .eq. 0) then
              call fatal_error('update_solid_cells:','lower_j==0 or upper_j==0')
            endif            
!
!  First we use interpolations to find the value of the mirror point.
!  Then we use the interpolated value to find the value of the ghost point
!  by empoying either Dirichlet or Neuman boundary conditions.
!
            call interpolate_mirror_point(f,phi,iux,k,lower_i,upper_i,lower_j,&
                upper_j,icyl,xmirror,ymirror)
            f(i,j,k,iux)=-phi
            call interpolate_mirror_point(f,phi,iuy,k,lower_i,upper_i,lower_j,&
                upper_j,icyl,xmirror,ymirror)
            f(i,j,k,iuy)=-phi
            call interpolate_mirror_point(f,phi,iuz,k,lower_i,upper_i,lower_j,&
                upper_j,icyl,xmirror,ymirror)
            f(i,j,k,iuz)=-phi
            if (ilnrho>0) then
              call interpolate_mirror_point(f,phi,ilnrho,k,lower_i,upper_i,&
                  lower_j,upper_j,icyl,xmirror,ymirror)
              f(i,j,k,ilnrho)=phi
            endif
            if (ilnTT>0) then
              call interpolate_mirror_point(f,phi,ilnTT,k,lower_i,upper_i,&
                  lower_j,upper_j,icyl,xmirror,ymirror)
              f(i,j,k,ilnTT)=2*cylinder_temp(icyl)-phi
            endif
          else
!
!  For fluid points very close to the solid surface the value of the point
!  is found from interpolation between the value at the closest grid line
!  and the value at the solid surface.
!
            if (lclose_linear) then
              if (ba(i,j,k,1)==10) then
                icyl=ba(i,j,k,4)
                x_cyl=cylinder(icyl,ixpos)
                y_cyl=cylinder(icyl,iypos)
                r_cyl=cylinder(icyl,iradius)
                r_point=sqrt(((x(i)-x_cyl)**2+(y(j)-y_cyl)**2))
                dr=r_point-r_cyl
                if ((dr > 0) .and. (dr<dxmin*limit_close_linear)) then
                  xxp=(/x(i),y(j),z(k)/)
                  call close_interpolation(f,i,j,k,icyl,iux,xxp,gpp,.true.)
                  f(i,j,k,iux)=gpp
                  call close_interpolation(f,i,j,k,icyl,iuy,xxp,gpp,.true.)
                  f(i,j,k,iuy)=gpp
                  call close_interpolation(f,i,j,k,icyl,iuz,xxp,gpp,.true.)
                  f(i,j,k,iuz)=gpp
                endif
              endif
            endif
          endif
        enddo
        enddo
        enddo
!
!  Find ghost points based on the staircase interpolation method
!
      elseif (interpolation_method=='staircase') then
        do i=l1,l2
        do j=m1,m2
        do k=n1,n2
          do idir=1,3
            if (ba_shift(i,j,k,idir).ne.0) then
              xind=i
              yind=j
              zind=k
              if (idir==1) then
                xind=i-ba_shift(i,j,k,idir)
              elseif (idir==2) then
                yind=j-ba_shift(i,j,k,idir)
              elseif (idir==3) then
                zind=k-ba_shift(i,j,k,idir)
              else
                print*,'No such idir!...exiting!'
                stop
              endif
!                
!  Only update the solid cell "ghost points" if all indeces are non-zero.
!  In this way we might loose the innermost "ghost point" if the processor
!  border is two grid cells inside the solid structure, but this will 
!  probably just have a very minor effect.
!
              if (xind.ne.0 .and. yind.ne.0 .and. zind.ne.0) then
                icyl=ba_shift(i,j,k,4)
                f(i,j,k,iux:iuz)=-f(xind,yind,zind,iux:iuz)
                if (ilnrho>0) f(i,j,k,ilnrho) = f(xind,yind,zind,ilnrho)
                if (ilnTT>0) f(i,j,k,ilnTT) = &
                    2*cylinder_temp(icyl)-f(xind,yind,zind,ilnTT)
              endif
            endif
          enddo
        enddo
        enddo
        enddo
      endif
!
    endsubroutine update_solid_cells
!***********************************************************************  
    subroutine interpolate_mirror_point(f,phi,ivar,k,lower_i,upper_i,lower_j,upper_j,icyl,xmirror,ymirror)
!
!  Interpolate value in a mirror point from the four corner values
!
!  23-dec-2008/nils: coded
!  22-apr-2009/nils: added special treatment close to the solid surface
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      integer, intent(in) :: icyl
      integer :: lower_i,upper_i,lower_j,upper_j,k,ivar
      real :: xmirror,ymirror,phi, hx1, hy1,hy2,hx2
      real, dimension(3) :: xxp
      real :: phi_tmp
!
      hx1=xmirror-x(lower_i)
      hx2=x(upper_i)-xmirror
      hy1=ymirror-y(lower_j)
      hy2=y(upper_j)-ymirror
!
      phi=&
          (f(lower_i,upper_j,k,ivar)*hx2*hy1 &
          +f(upper_i,upper_j,k,ivar)*hx1*hy1 &
          +f(lower_i,lower_j,k,ivar)*hx2*hy2 &
          +f(upper_i,lower_j,k,ivar)*hx1*hy2)/((hx1+hx2)*(hy1+hy2))
!
!  If the mirror point is very close to the surface of the cylinder 
!  some special treatment is required.
!
      if (lclose_interpolation .and. ivar < 4) then
        xxp=(/xmirror,ymirror,0.0/)
        call close_interpolation(f,lower_i,lower_j,k,icyl,ivar,xxp,phi,.false.)
      endif
!
    endsubroutine interpolate_mirror_point
!***********************************************************************  
    subroutine close_interpolation(f,ix0_,iy0_,iz0_,icyl,ivar1,xxp,gpp,&
        fluid_point)
!
!  20-mar-2009/nils: coded
!  
!  If fluid_point=.true. this routine check if any of the corners in 
!  the interpolation cell are inside a solid geometry. 
!  If they are: some special treatment is required.
!  
!  If fluid_point=.false. the routine use the value at the surface
!  of the solid geometry together with the interpolated value at the nearest
!  grid line in the direction away from the solid geometry to set a value
!  at a grid point which is very close to the solid geometry.
!  
!  WARNING: This routine only works for cylinders with an infinitely long
!  WARNING: central axis in the z-direction!
!  
!  The interpolation point, named p, has coordinates [xp,yp].
!  The point s on the cylinder surface, with coordinates [xs,ys], is 
!  placed such that the line from s to p is a normal to the cylinder surface.
!  
!  If one of the corner points of the grid cell is within a solid geometry
!  the normal passing through both s and p are continued outward until a
!  grid line is reached. If this line has constant, say y, then the variables
!  constdir and vardir are given the values 2 and 1, respectively.  
!
      real, dimension (mx,my,mz,mfarray), intent(in) :: f
      integer, intent(in) :: ix0_,iy0_,iz0_,ivar1
      integer :: ix0,iy0,iz0
      real, intent(inout) :: gpp
      real :: x0,y0,z0,rs,verylarge=1e9,varval,rint1,rint2,fint,rps,rintp
      integer :: ix1,iy1,iz1,min
      real, dimension(3), intent(in) :: xxp
      real, dimension(2,2) :: rij
      real, dimension(3,2) :: bordervalue
      integer, dimension(3,2) :: borderindex
      integer, dimension(4) :: constdir_arr, vardir_arr, topbot_arr
      real, dimension(2) :: xyint, p_cylinder
      real :: xtemp,r,xp,yp,R1,Rsmall,xs,ys,rp,dist,yp_cylinder,xp_cylinder
      integer :: constdir,vardir,topbot_tmp,dirconst,dirvar,icyl,counter,topbot
      real :: x1,x2,f1,f2,rij_min,rij_max,inputvalue,smallx,gp
      logical, intent(in) :: fluid_point
      real :: fintx, finty,fint_ur,fint_ut,drp,dri,f2x,f2y,f1x,f1y
      real, save :: urp,utp
      logical :: quadratic

!
!  Check if we really want this special treatment close to the fluid-solid 
!  interface
!
      if ((.not. fluid_point .and. lclose_interpolation) &
          .or. ( fluid_point .and. lclose_linear)) then
!
!  This subrutine is not working (and should never be used) with other
!  variables than the velocity.
!
        if (ivar1 > iuz) call fatal_error('close_interpolation',&
            'This subroutine should never be called for anything but velocity!')
!
!  Define some help variables
!
        x0=cylinder(icyl,ixpos)
        y0=cylinder(icyl,iypos)
        z0=cylinder(icyl,izpos)
        rs=cylinder(icyl,iradius)
        xp=xxp(1)
        yp=xxp(2)
!
!  Find the corner points of the grid cell we are in
!
        if (fluid_point) then
          smallx=dx*1e-5
          iz0=iz0_
          if (xp < x0) then
            ix0=ix0_-1
            xp=xp-smallx
          else
            ix0=ix0_
            xp=xp+smallx
          endif
          if (yp < y0) then
            iy0=iy0_-1
            yp=yp-smallx
          else
            iy0=iy0_
            yp=yp+smallx
          endif
        else
          ix0=ix0_
          iy0=iy0_
          iz0=iz0_
        endif
        ix1=ix0+1
        iy1=iy0+1
        iz1=iz0+1
!
!  Find distance from corner points to the cylinder center
!
        rij(1,1)=sqrt((x(ix0)-x0)**2+(y(iy0)-y0)**2)
        rij(1,2)=sqrt((x(ix0)-x0)**2+(y(iy1)-y0)**2)
        rij(2,1)=sqrt((x(ix1)-x0)**2+(y(iy0)-y0)**2)
        rij(2,2)=sqrt((x(ix1)-x0)**2+(y(iy1)-y0)**2) 
!
!  Check if we want special treatment
!
        if ((minval(rij) < rs) .or. fluid_point) then
!
!  Put help variables into arrays
!
          bordervalue(1,1)=x(ix0)
          bordervalue(2,1)=y(iy0)
          bordervalue(1,2)=x(ix1)
          bordervalue(2,2)=y(iy1)
          borderindex(1,1)=ix0
          borderindex(2,1)=iy0
          borderindex(1,2)=ix1
          borderindex(2,2)=iy1
          constdir_arr=(/2,2,1,1/)
          vardir_arr=(/1,1,2,2/)
          topbot_arr=(/2,1,2,1/)
          R1=verylarge
          Rsmall=verylarge/2.0
!
!  Find the x and y coordinates of p in a coordiante system with origin
!  in the center of the cylinder
!
          yp_cylinder=yp-y0
          xp_cylinder=xp-x0
          p_cylinder(1)=xp_cylinder
          p_cylinder(2)=yp_cylinder
          rp=sqrt(xp_cylinder**2+yp_cylinder**2)
!
!  Determine the point s on the cylinder surface where the normal to the
!  cylinder surface pass through the point p. 
!
          xs=rs/rp*xp
          ys=rs/rp*yp
!
!  Find distance from point p to point s
!
          dist=(xp-xs)**2+(yp-ys)**2
!
!  Find which grid line is the closest one in the direction
!  away from the cylinder surface
!
!  Check the distance etc. to all the four (in 2D) possible 
!  grid lines. Pick the grid line which the normal to the
!  cylinder surface (which also pass through the point [xp,yp])
!  cross first. This grid line should however
!  be OUTSIDE the point [xp,yp] compared to the cylinder surface.
!
          do counter=1,4
            constdir=constdir_arr(counter)
            vardir=vardir_arr(counter)
            topbot_tmp=topbot_arr(counter)
!
!  Find the position, xtemp, in the variable direction
!  where the normal cross the grid line
!
            xtemp=(p_cylinder(vardir)/(p_cylinder(constdir)+tini))&
                *(bordervalue(constdir,topbot_tmp)-cylinder(icyl,constdir+1))
!
!  Find the distance, r, from the center of the cylinder
!  to the point where the normal cross the grid line
!
            if (abs(xtemp) > verylarge) then
              r=verylarge*2
            else
              r=sqrt(xtemp**2+(bordervalue(constdir,topbot_tmp)&
                  -cylinder(icyl,constdir+1))**2)
            endif
!
!  Check if the point xtemp is outside the cylinder,
!  outside the point [xp,yp] and that it cross the grid
!  line within this grid cell
!
            if ((r > rs) .and. (r > rp) &
                .and.(xtemp+cylinder(icyl,vardir+1) >= bordervalue(vardir,1))&
                .and.(xtemp+cylinder(icyl,vardir+1) <= bordervalue(vardir,2)))then
              R1=r
            else
              R1=verylarge
            endif
!
!  If we have a new all time low (in radius) then go on....
!
            if (R1 < Rsmall) then
              Rsmall=R1                
              xyint(vardir)=xtemp+cylinder(icyl,vardir+1)
              xyint(constdir)=bordervalue(constdir,topbot_tmp)
              dirconst=constdir
              dirvar=vardir
              topbot=topbot_tmp
              if (constdir == 2) then
                rij_min=rij(1,topbot_tmp)
                rij_max=rij(2,topbot_tmp)
              else
                rij_min=rij(topbot_tmp,1)
                rij_max=rij(topbot_tmp,2)
              endif
              inputvalue=bordervalue(constdir,topbot_tmp)&
                  -cylinder(icyl,constdir+1)
            endif
          enddo
!
!  Check that we have found a valid distance
!
          if (Rsmall==verylarge/2.0) then
            print*,'fluid_point=',fluid_point
            print*,'lclose_interpolation=',lclose_interpolation
            print*,'lclose_linear=',lclose_linear
            print*,'x0,y0,z0=',x0,y0,z0
            print*,'ix0,iy0,iz0=',ix0,iy0,iz0
            print*,'ix1,iy1,iz1=',ix1,iy1,iz1
            print*,'xp,yp=',xp,yp
            print*,'xtemp=',xtemp
            print*,'r,rs,rp=',r,rs,rp
            print*,'R1,Rsmall=',R1,Rsmall
            print*,'rij,rs=',rij,rs
            print*,'x(ix0),xp,x(ix1)=',x(ix0),xp,x(ix1)
            print*,'y(iy0),yp,y(iy1)=',y(iy0),yp,y(iy1)
            print*,'dirvar,dirconst,topbot,iz0=',dirvar,dirconst,topbot,iz0
             call fatal_error('close_interpolation',&
                'A valid radius is not found!')            
           endif
!
!  Check if the endpoints in the variable direction are
!  outside the cylinder. If they are not then define the endpoints
!  as where the grid line cross the cylinder surface.
!  Find the variable value at the endpoints.
!
           quadratic=.true.
           min=1
           if (dirconst == 2) then
             varval=f(borderindex(dirvar,1),borderindex(dirconst,topbot),&
                 iz0,ivar1)
           else
             varval=f(borderindex(dirconst,topbot),borderindex(dirvar,1),&
                 iz0,ivar1)
           endif
           call find_point(rij_min,rs,varval,inputvalue,x1,&
               bordervalue(dirvar,1),bordervalue(dirvar,2),&
               min,f1,cylinder(icyl,dirvar+1))
!
! If we want quadratic interpolation of the radial velocity we
! must find both the interploated x and y velocity in order to 
! do interpolations for the radial and theta directions.
!
           if (quadratic .and. ivar1==iux) then
             if (dirconst == 2) then
               varval=f(borderindex(dirvar,1),borderindex(dirconst,topbot),&
                   iz0,iuy)
             else
               varval=f(borderindex(dirconst,topbot),borderindex(dirvar,1),&
                   iz0,iuy)
             endif
             call find_point(rij_min,rs,varval,inputvalue,x1,&
                 bordervalue(dirvar,1),bordervalue(dirvar,2),&
                 min,f1y,cylinder(icyl,dirvar+1))
             f1x=f1
           endif
!
           min=0
           if (dirconst == 2) then
             varval=f(borderindex(dirvar,2),borderindex(dirconst,topbot),&
                 iz0,ivar1)
           else
             varval=f(borderindex(dirconst,topbot),borderindex(dirvar,2),&
                 iz0,ivar1)
           endif
           call find_point(rij_max,rs,varval,inputvalue,x2,&
               bordervalue(dirvar,1),bordervalue(dirvar,2),&
               min,f2,cylinder(icyl,dirvar+1))
!
! If we want quadratic interpolation of the radial velocity we
! must find both the interploated x and y velocity in order to 
! do interpolations for the radial and theta directions.
!
           if (quadratic .and. ivar1==iux) then
             if (dirconst == 2) then
               varval=f(borderindex(dirvar,2),borderindex(dirconst,topbot),&
                   iz0,iuy)
             else
               varval=f(borderindex(dirconst,topbot),borderindex(dirvar,2),&
                   iz0,iuy)
             endif
             call find_point(rij_max,rs,varval,inputvalue,x2,&
                 bordervalue(dirvar,1),bordervalue(dirvar,2),&
                 min,f2y,cylinder(icyl,dirvar+1))
             f2x=f2
           endif
!
!  Find the interpolation values between the two endpoints of
!  the line and the normal from the cylinder.
!
          rint1=xyint(dirvar)-x1
          rint2=x2-xyint(dirvar)
!
          if (quadratic .and. (ivar1 .ne. iuz)) then
            if (ivar1==iux) then
              fintx=(rint1*f2x+rint2*f1x)/(x2-x1)
              finty=(rint1*f2y+rint2*f1y)/(x2-x1)
              fint_ur    =fintx*xp_cylinder/rs+finty*yp_cylinder/rs
              fint_ut=finty*xp_cylinder/rs-fintx*yp_cylinder/rs
              drp=rp-rs
              dri=Rsmall-rs
              urp=(drp/dri)**2*fint_ur
              utp=(drp/dri)*fint_ut
              gpp=urp*xp_cylinder/rs-utp*yp_cylinder/rs
            elseif (ivar1==iuy) then
              gpp=urp*yp_cylinder/rs+utp*xp_cylinder/rs
            else
              call fatal_error('close_interpolation',&
                  'Yor ivar1 is not correct!') 
            endif
          else
!
!  Find the interpolated value on the line
!
            fint=(rint1*f2+rint2*f1)/(x2-x1)
!
!  Find the weigthing factors for the point on the line
!  and the point on the cylinder surface.
!          
            rps=rp-rs
            rintp=Rsmall-rp
!
!  Perform the final interpolation
!
            gpp=(rps*fint+rintp*0)/(Rsmall-rs)
          endif
        endif
      endif
!
    endsubroutine close_interpolation
!***********************************************************************  
    function in_solid_cell(part_pos,part_rad)
!
!  Check if the position px,py,pz is within a colid cell
!
!  02-dec-2008/nils: coded
!
      logical :: in_solid_cell
      real, dimension(3) :: cyl_pos, part_pos
      real :: cyl_rad,distance2,part_rad
      integer :: icyl, i
!
      in_solid_cell=.false.
!
      do icyl=1,ncylinders
        cyl_rad=cylinder(icyl,1)
        cyl_pos=cylinder(icyl,2:4)
        distance2=0
!
!  Loop only over x and y direction since this is a cylindrical geometry
!
        do i=1,2
          distance2=distance2+(cyl_pos(i)-part_pos(i))**2
        enddo
!
!  The cylinder_skin is the closest a particle can get to the solid 
!  cell before it is captured (this variable is normally zero).
!
        if (sqrt(distance2)<cyl_rad+part_rad+cylinder_skin) then
          in_solid_cell=.true.
        endif
      enddo
!
    endfunction in_solid_cell
!***********************************************************************  
    subroutine freeze_solid_cells(df)
!
!  If we are in a solid cell (or in a cell where the value of the variables are
!  found from interpolation) set df=0 for all variables
!
!  19-nov-2008/nils: coded
!
      real, dimension (mx,my,mz,mvar) :: df
      integer :: i,j,k
!
      do i=l1,l2
        if (&
            (ba(i,m,n,1).ne.0).or.&
            (ba(i,m,n,2).ne.0).or.&
            (ba(i,m,n,3).ne.0)) then
!
!  If this is a fluid point which has to be interpolated because it is very
!  close to the solid geometry (i.e. ba(i,m,n,1) == 10) then only the 
!  velocity components should be frozen.
!
          if (ba(i,m,n,1) == 10) then
            df(i,m,n,iux:iuz)=0
          else
            df(i,m,n,:)=0
          endif
        endif
      enddo
!
    endsubroutine freeze_solid_cells
!***********************************************************************
    subroutine read_solid_cells_init_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=solid_cells_init_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=solid_cells_init_pars,ERR=99)
      endif

99    return
    endsubroutine read_solid_cells_init_pars
!***********************************************************************
    subroutine read_solid_cells_run_pars(unit,iostat)
      integer, intent(in) :: unit
      integer, intent(inout), optional :: iostat

      if (present(iostat)) then
        read(unit,NML=solid_cells_run_pars,ERR=99, IOSTAT=iostat)
      else
        read(unit,NML=solid_cells_run_pars,ERR=99)
      endif

99    return
    endsubroutine read_solid_cells_run_pars
!***********************************************************************
    subroutine write_solid_cells_init_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=solid_cells_init_pars)

    endsubroutine write_solid_cells_init_pars
!***********************************************************************
    subroutine write_solid_cells_run_pars(unit)
      integer, intent(in) :: unit

      write(unit,NML=solid_cells_run_pars)

    endsubroutine write_solid_cells_run_pars
!***********************************************************************
    subroutine find_solid_cell_boundaries
!
!  Find the boundaries of the geometries such that we can set the
!  ghost points inside the solid geometry in order to achieve the
!  correct no-slip boundaries.
!  
!  Store data in the ba array.
!  If ba(ip,jp,kp,1)= 0 we are in a fluid cell (i.e. NOT inside a solid geometry)
!  If ba(ip,jp,kp,1)=10 we are in a fluid cell which are so close to the 
!                       surface of the solid geometry that we set the value of
!                       this point by interpolating between the value at the 
!                       solid surface and the interpolated value at the first
!                       grid line crossed by the normal to the solid surface.
!  If ba(ip,jp,kp,1)= 9 we are inside a solid geometry, but far from the boundary
!  If ba(ip,jp,kp,1)=-1 we are inside a solid geometry, and the point at ip+1
!                       is outside the geometry. 
!  If ba(ip,jp,kp,1)=-3 we are inside a solid geometry, and the point at ip+3
!                       is outside the geometry. 
!  If ba(ip,jp,kp,2)=-3 we are inside a solid geometry, and the point at jp+3
!                       is outside the geometry. 
!  If ba(ip,jp,kp,2)=11 we are inside a solid geometry, either close to or far 
!                       from the boundary, but the position (ip,jp,kp) is a ghost
!                       point at the current processor.
!
!  The number stored in ba(ip,jp,kp,4) is the number of the cylinder
!
!  19-nov-2008/nils: coded
!
      integer :: i,j,k,icyl,cw
      real :: x2,y2,xval_p,xval_m,yval_p,yval_m
      real :: dr,r_point,x_cyl,y_cyl,r_cyl
!
!  Initialize ba
!
      ba=0
!
!  Loop over all cylinders (this should actually be a loop over all
!  geometries!)
!
      do icyl=1,ncylinders
        x_cyl=cylinder(icyl,ixpos)
        y_cyl=cylinder(icyl,iypos)
        r_cyl=cylinder(icyl,iradius)
!
!  First we look in x-direction
!
        k=l1
        do j=m1,m2
!
!  Check if we are inside the cylinder for y(j) (i.e. if x2>0)
!
          x2=cylinder(icyl,1)**2-(y(j)-cylinder(icyl,3))**2
          if (x2>0) then
!
!  Find upper and lower x-values for the surface of the cylinder for y(j)
!
            xval_p=cylinder(icyl,2)+sqrt(x2)
            xval_m=cylinder(icyl,2)-sqrt(x2)            
            do i=l1,l2
              if (x(i)<xval_p .and. x(i)>xval_m) then
                !
                if (x(i+1)>xval_p) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,1)=-1
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==1) ba(i,j,:,1)=-1
                  endif
                endif
                !
                if (x(i+2)>xval_p .and. x(i+1)<xval_p) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,1)=-2
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==1) ba(i,j,:,1)=-2
                  endif
                endif
                !
                if (x(i+3)>xval_p .and. x(i+2)<xval_p) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,1)=-3
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==1) ba(i,j,:,1)=-3
                  endif
                endif
                !
                if (x(i-1)<xval_m) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,1)=1
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==-1) ba(i,j,:,1)=1
                  endif
                endif
                !
                if (x(i-2)<xval_m .and. x(i-1)>xval_m) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,1)=2
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==-1) ba(i,j,:,1)=2
                  endif
                endif
                !
                if (x(i-3)<xval_m .and. x(i-2)>xval_m) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,1)=3
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==-1) ba(i,j,:,1)=3
                  endif
                endif
                !
                if (ba(i,j,k,1)==0) then
                  ba(i,j,:,1)=9
                  ba(i,j,:,4)=icyl
                endif
                !
              endif
            enddo
          endif
        enddo
!
!  Then we look in y-direction
!
        do i=l1,l2
!
!  Check if we are inside the cylinder for x(i) (i.e. if y2>0)
!
          y2=cylinder(icyl,1)**2-(x(i)-cylinder(icyl,2))**2
          if (y2>0) then
!
!  Find upper and lower y-values for the surface of the cylinder for x(i)
!
            yval_p=cylinder(icyl,3)+sqrt(y2)
            yval_m=cylinder(icyl,3)-sqrt(y2)            
            do j=m1,m2
              if (y(j)<yval_p .and. y(j)>yval_m) then
                if (y(j+1)>yval_p) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,2)=-1
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==2) ba(i,j,:,2)=-1                  
                  endif
                endif
!
                if (y(j+2)>yval_p .and. y(j+1)<yval_p) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,2)=-2
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==2) ba(i,j,:,2)=-2                  
                  endif
                endif
!
                if (y(j+3)>yval_p .and. y(j+2)<yval_p) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,2)=-3
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==2) ba(i,j,:,2)=-3                  
                  endif
                endif
!
                if (y(j-1)<yval_m) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,2)=1
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==-2) ba(i,j,:,2)=1                  
                  endif
                endif
!
                if (y(j-2)<yval_m .and. y(j-1)>yval_m) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,2)=2
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==-2) ba(i,j,:,2)=2                  
                  endif
                endif
!
                if (y(j-3)<yval_m .and. y(j-2)>yval_m) then
                  if (.not. ba_defined(i,j)) then
                    ba(i,j,:,2)=3
                    ba(i,j,:,4)=icyl
                  else
                    call find_closest_wall(i,j,k,icyl,cw)
                    if (cw==-2) ba(i,j,:,2)=3                  
                  endif
                endif
!
                if (ba(i,j,k,2)==0) then
                  ba(i,j,:,2)=9
                  ba(i,j,:,4)=icyl
                endif
              endif
            enddo
          endif
        enddo
!
!  If we interpolate points which are very close to the solid surface
!  these points has to be "marked" for later use.
!
        if (lclose_linear) then
!
!  Loop over all points
!
          do i=l1,l2
            do j=m1,m2
              r_point=sqrt(((x(i)-x_cyl)**2+(y(j)-y_cyl)**2))
              dr=r_point-r_cyl
              if ((dr .ge. 0) .and. (dr<limit_close_linear*dxmin)) then
                ba(i,j,:,1)=10
                ba(i,j,:,4)=icyl
              endif
            enddo
          enddo
        endif
!
!  Fill ba array also for ghost points - need only know whether
!  we are actually inside cylinder (then ba = 11), not how close we are to 
!  the border.
!
!  Lower and upper ghost points in y direction
!
        do j=1,nghost
          do i=1,mx
            !  Lower ghost points
            r_point=sqrt((((x(i)-x_cyl)**2+(y(j)-y_cyl)**2)))
            if (r_point .lt. r_cyl) then
              ba(i,j,:,1:3)=11
              ba(i,j,:,4)=icyl
            end if
            !  Upper ghost points
            r_point=sqrt((((x(i)-x_cyl)**2+(y(my-nghost+j)-y_cyl)**2)))
            if (r_point .lt. r_cyl) then
              ba(i,my-nghost+j,:,1:3)=11
              ba(i,my-nghost+j,:,4)=icyl
            end if
          enddo
        enddo
!
! Lower and upper ghost points in x direction
!
        do j=m1,m2
          do i=1,nghost
            !  Lower (left) ghost points
            r_point=sqrt((((x(i)-x_cyl)**2+(y(j)-y_cyl)**2)))
            if (r_point .lt. r_cyl) then
              ba(i,j,:,1:3)=11
              ba(i,j,:,4)=icyl
            end if
            !  Upper (right) ghost points
            r_point=sqrt((((x(mx-nghost+i)-x_cyl)**2+(y(j)-y_cyl)**2)))
            if (r_point .lt. r_cyl) then
              ba(mx-nghost+i,j,:,1:3)=11
              ba(mx-nghost+i,j,:,4)=icyl
            end if
          enddo
        enddo
!
! Finalize loop over all cylinders
!
      enddo
!
    endsubroutine find_solid_cell_boundaries
!***********************************************************************
    subroutine calculate_shift_matrix
!
!  Set up the shift matrix
!
!  19-nov-2008/nils: coded
!
      integer :: i,j,k,idir
      integer :: sgn
!
      ba_shift=0
!
      do i=l1,l2
      do j=m1,m2
      do k=n1,n2
        do idir=1,3
!
!  If ba is non-zero find the shift matrix
!
          if (ba(i,j,k,idir).ne.0 .and. ba(i,j,k,idir).ne.9) then
            sgn=-ba(i,j,k,idir)/abs(ba(i,j,k,idir))
            ba_shift(i,j,k,idir)=2*ba(i,j,k,idir)+sgn
            ba_shift(i,j,k,4)=ba(i,j,k,4)
          endif
        enddo
      enddo
      enddo
      enddo
!
    endsubroutine calculate_shift_matrix
!***********************************************************************  
    subroutine find_closest_wall(i,j,k,icyl,cw)
!
!  Find the direction of the closest wall for given grid point and cylinder
!
!  28-nov-2008/nils: coded
!
      integer :: i,j,k,cw,icyl
      real :: xval_p,xval_m,yval_p,yval_m,maxval,x2,y2,minval,dist
!
      x2=cylinder(icyl,1)**2-(y(j)-cylinder(icyl,3))**2
      y2=cylinder(icyl,1)**2-(x(i)-cylinder(icyl,2))**2
      xval_p=cylinder(icyl,2)+sqrt(x2)
      xval_m=cylinder(icyl,2)-sqrt(x2)            
      yval_p=cylinder(icyl,3)+sqrt(y2)
      yval_m=cylinder(icyl,3)-sqrt(y2)            
!
      minval=impossible
      cw=0
!
      dist=xval_p-x(i)
      if (dist<minval) then
        minval=dist
        cw=1
      endif
!
      dist=yval_p-y(j)
      if (dist<minval) then
        minval=dist
        cw=2
      endif
!
      dist=x(i)-xval_m
      if (dist<minval) then
        minval=dist
        cw=-1
      endif
!
      dist=y(j)-yval_m
      if (dist<minval) then
        minval=dist
        cw=-2
      endif
!
    endsubroutine find_closest_wall
!***********************************************************************  
    function ba_defined(i,j)
!
!  28-nov-2008/nils: coded
!
!  Check if ba for the point of interest has been defined for another direction.
!  This is only interesting if interpolation_method=='staircase',
!  otherwise this function always return .false.
!
      integer :: i,j,k
      logical :: lba1=.true.,lba2=.true.
      logical :: ba_defined
!
      k=3
!
      if (interpolation_method=='staircase') then
        if (ba(i,j,k,1)==0 .or. ba(i,j,k,1)==9) then
          lba1=.false.
        endif
!
        if (ba(i,j,k,2)==0 .or. ba(i,j,k,2)==9) then
          lba2=.false.
        endif
!
        if (lba1 .or. lba2) then
          ba_defined=.true.
        else
          ba_defined=.false.
        endif
      else
        ba_defined=.false.
      endif
!
    endfunction ba_defined
!***********************************************************************  
    subroutine find_point(rij,rs,f,yin,xout,xmin,xmax,min,fout,x0)
!
!  20-mar-2009/nils: coded
!
!  Check if a grid line has any of it ends inside a solid cell - if so
!  find the point where the grid line enters the solid cell.
!
      integer, intent(in) :: min
      real, intent(in) :: xmin,xmax,rij,rs,f,yin,x0
      real, intent(out) :: fout,xout
      real :: xvar,xout0
!
      if (min == 1) then
        xvar=xmin
      else
        xvar=xmax
      endif
!
      if (rij > rs) then
        xout=xvar
        fout=f
      else
        xout0=sqrt(rs**2-yin**2)
        xout=xout0+x0
        if ((xout > xmax) .or. (xout < xmin)) then
          xout=x0-xout0
        endif
        fout=0
      endif
!
    endsubroutine find_point
!***********************************************************************  
    subroutine pencil_criteria_solid_cells()
!
!  All pencils that the Solid_Cells module depends on are specified here.
!
!  mar-2009/kragset: coded
!
      use Cdata
!
!  Request p and sij-pencils here
!  Request rho-pencil
      lpenc_requested(i_pp)=.true.
      lpenc_requested(i_sij)=.true.
      lpenc_requested(i_rho)=.true.
    endsubroutine pencil_criteria_solid_cells
!***********************************************************************  
endmodule Solid_Cells
