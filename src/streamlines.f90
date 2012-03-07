! $Id$
!
!** AUTOMATIC CPARAM.INC GENERATION ****************************
! Declare (for generation of cparam.inc) the number of f array
! variables and auxiliary variables added by this module
!
!***************************************************************
module Streamlines
!
  use Cdata
  use Cparam
  use Messages
!
  implicit none
!
  include 'mpif.h'
!
! a few constants
  integer :: VV_RQST = 10
  integer :: VV_RCV = 20
  integer :: FINISHED = 99
! the traced vector field
  real, dimension (nx,ny,nz,3) :: vv
! the arrays with the values for x, y and z for all cores (global xyz)
  real, dimension(nxgrid) :: xg
  real, dimension(nygrid) :: yg
  real, dimension(nzgrid) :: zg
! borrowed position on the grid
  integer :: grid_pos_b(3)
! variables for the non-blocking mpi communication
  integer, dimension (MPI_STATUS_SIZE) :: status
  integer :: request, flag, receive = 0, all_finished = 0
!
  contains
!  
!*********************************************************************** 
  subroutine get_grid_pos(phys_pos, grid_pos, outside)
!
! Determines the grid cell in this core for the physical location.
!
! 13-feb-12/simon: coded
!
    real, dimension(3) :: phys_pos
    integer, dimension(3) :: grid_pos
    real :: delta
    integer :: j, outside
!
    intent(in) :: phys_pos
    intent(out) :: grid_pos, outside
!
    outside = 0
!
    delta = Lx
    do j=1,nxgrid
      if (abs(phys_pos(1) - xg(j)) < delta) then
        grid_pos(1) = j
        delta = abs(phys_pos(1) - xg(j))
      endif
    enddo
!   check if the point lies outside the domain
    if (delta > dx/2.) outside = 1
!      
    delta = Ly
    do j=1,nygrid
      if (abs(phys_pos(2) - yg(j)) < delta) then
        grid_pos(2) = j
        delta = abs(phys_pos(2) - yg(j))
      endif
    enddo
!   check if the point lies outside the domain
    if (delta > dy/2.) outside = 1
!
    delta = Lz
    do j=1,nzgrid
      if (abs(phys_pos(3) - zg(j)) < delta) then
        grid_pos(3) = j
        delta = abs(phys_pos(3) - zg(j))
      endif
    enddo
!   check if the point lies outside the domain
    if (delta > dz/2.) outside = 1
!
!   consider the processor indices
    grid_pos(1) = grid_pos(1) - nx*ipx
    grid_pos(2) = grid_pos(2) - ny*ipy
    grid_pos(3) = grid_pos(3) - nz*ipz
!
  endsubroutine get_grid_pos
!*********************************************************************** 
  subroutine get_vector(grid_pos, vvb)
!
! Gets the vector field value from another core.
!
! 20-feb-12/simon: coded
!
    integer :: grid_pos(3), grid_pos_send(3)
    real, dimension(3) :: vvb, vvb_send
    integer :: proc_id, x_proc, y_proc, z_proc, ierr
!   variables for the non-blocking mpi communication
    integer, dimension (MPI_STATUS_SIZE) :: status_send, status_recv
    integer :: sent, receiving, request_send, request_rcv, flag_rcv
!
    intent(out) :: vvb
!
    sent = 0; receiving = 0; flag_rcv = 0
!
!   find the corresponding core
    x_proc = ipx + floor((grid_pos(1)-1)/real(nx))
    y_proc = ipy + floor((grid_pos(2)-1)/real(ny))
    z_proc = ipz + floor((grid_pos(3)-1)/real(nz))
    proc_id = x_proc + nprocx*y_proc + nprocx*nprocy*z_proc
!
!   find the grid position in the other core
    grid_pos_send(1) = grid_pos(1) - (x_proc - ipx)*nx
    grid_pos_send(2) = grid_pos(2) - (y_proc - ipy)*ny
    grid_pos_send(3) = grid_pos(3) - (z_proc - ipz)*nz
!
    if (proc_id == iproc) call fatal_error("streamlines", "sending and receiving core are the same")
!
    do
!
!     To avoid deadlocks check if there is any request to this core.
      do
        if (receive == 0) then
!         create a receive request
          grid_pos_b(:) = 0
          call MPI_IRECV(grid_pos_b,3,MPI_integer,MPI_ANY_SOURCE,VV_RQST,MPI_comm_world,request,ierr)
          if (ierr .ne. MPI_SUCCESS) then
            call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
            exit
          endif
          receive = 1
        endif
!
!       check if there is any request for the vector field from another core
        if (receive == 1) then
          flag = 0
          call MPI_TEST(request,flag,status,ierr)
          if (flag == 1) then
!           receive completed, send the vector field
            vvb_send = vv(grid_pos_b(1),grid_pos_b(2),grid_pos_b(3),:)
            call MPI_SEND(vvb_send,3,MPI_REAL,status(MPI_SOURCE),VV_RCV,MPI_comm_world,ierr)
            if (ierr .ne. MPI_SUCCESS) then
              call fatal_error("streamlines", "MPI_SEND could not send")
              exit
            endif
            receive = 0
          endif
        endif
        if (receive == 1) exit
      enddo
!
!     Now it should be safe to make a blocking send request.
!
!     start blocking send and non-blocking receive
      if (sent == 0) then        
        call MPI_SSEND(grid_pos_send,3,MPI_integer,proc_id,VV_RQST,MPI_comm_world,ierr)
        if (ierr .ne. MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_SSEND could not send request")
        sent = 1
      endif
      if (receiving == 0) then
        call MPI_IRECV(vvb,3,MPI_REAL,proc_id,VV_RCV,MPI_comm_world,request_rcv,ierr)
        if (ierr .ne. MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
        receiving = 1
      else
        call MPI_TEST(request_rcv,flag_rcv,status_recv,ierr)
        if (ierr .ne. MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_TEST failed")
      endif
!
      if (flag_rcv == 1) exit
    enddo
!
  endsubroutine get_vector
!***********************************************************************
  subroutine trace_streamlines(f,tracers,n_tracers,h_max,h_min,l_max,tol,trace_field)
!
!   trace stream lines of the vetor field stored in f(:,:,:,:)
!
!   13-feb-12/simon: coded
!
    use Sub
!
    real, dimension (mx,my,mz,mfarray) :: f
!     real, dimension (nx*ny,7) :: tracers
    real, pointer, dimension (:,:) :: tracers
    character (len=labellen) :: trace_field
    integer :: n_tracers, tracer_idx, j, ierr, proc_idx
!   the "borrowed" vector from the other core
    real, dimension (3) :: vvb, vvb_buf
    real :: h_max, h_min, l_max, tol, dh, dist2
!   auxilliary vectors for the tracing
    real, dimension(3) :: x_mid, x_single, x_half, x_double
!   current position on the grid
    integer :: grid_pos(3)
    integer :: loop_count, outside = 0
!   filename for the tracer output
    character(len=1024) :: filename
!   array with all finished cores
    integer :: finished_tracing(nprocx*nprocy*nprocz)
!   variables for the final non-blocking mpi communication
    integer :: request_finished_send(nprocx*nprocy*nprocz)
    integer :: request_finished_rcv(nprocx*nprocy*nprocz)
!
    intent(in) :: f,n_tracers,h_max,h_min,l_max,tol,trace_field
!
!   tracing stream lines
!
!   compute the array with the global xyz values
    do j=1,nxgrid
      xg(j) = x(1+nghost) - ipx*nx*dx + (j-1)*dx
    enddo
    do j=1,nygrid
      yg(j) = y(1+nghost) - ipy*ny*dy + (j-1)*dy
    enddo
    do j=1,nzgrid
      zg(j) = z(1+nghost) - ipz*nz*dz + (j-1)*dz
    enddo
!
!   TODO: implement for any vector field
    if (trace_field == 'bb') then
      do proc_idx=0,(nprocx*nprocy*nprocz-1)
        if (proc_idx == iproc) then
!         convert the magnetic vector potential into the magnetic field
          do m=m1,m2
            do n=n1,n2
              call curl(f,iaa,vv(:,m-nghost,n-nghost,:))
            enddo
          enddo
        endif
        call MPI_BARRIER(MPI_comm_world, ierr)
      enddo
    endif
!
!   open the destination file
    write(filename, "(A,I1.1,A)") 'data/proc', iproc, '/tracers.dat'
    open(unit = 1, file = filename, form = "unformatted")
!
!   make sure all threads are synchronized
    call MPI_BARRIER(MPI_comm_world, ierr)
    if (ierr .ne. MPI_SUCCESS) then
      call fatal_error("streamlines", "MPI_BARRIER could not be invoced")
    endif
!
    do tracer_idx=1,n_tracers
      tracers(tracer_idx, 6) = 0.
!     initial step length dh
      dh = sqrt(h_max*h_min/2.)
      loop_count = 0
!
      do
!       create a receive request for the core communication
        do
          if (receive == 0) then
!           create a receive request
            grid_pos_b(:) = 0
            call MPI_IRECV(grid_pos_b,3,MPI_integer,MPI_ANY_SOURCE,VV_RQST,MPI_comm_world,request,ierr)
            if (ierr .ne. MPI_SUCCESS) then
              call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
              exit
            endif
            receive = 1
          endif
!
!         check if there is any request for the vector field from another core
          if (receive == 1) then
            flag = 0
            call MPI_TEST(request,flag,status,ierr)
            if (flag == 1) then
!             receive completed, send the vector field
              vvb = vv(grid_pos_b(1),grid_pos_b(2),grid_pos_b(3),:)
              call MPI_SEND(vvb,3,MPI_REAL,status(MPI_SOURCE),VV_RCV,MPI_comm_world,ierr)
              if (ierr .ne. MPI_SUCCESS) then
                call fatal_error("streamlines", "MPI_SEND could not send")
                exit
              endif
              receive = 0
            endif
          endif
!
          if (receive == 1) exit
        enddo
!
!       (a) Single step (midpoint method):
        call get_grid_pos(tracers(tracer_idx,3:5),grid_pos,outside)
        if (outside == 1) exit
        if (any(grid_pos <= 0) .or. (grid_pos(1) > nx) .or. &
            (grid_pos(2) > ny) .or. (grid_pos(3) > nz)) then
          call get_vector(grid_pos, vvb)
          x_mid = tracers(tracer_idx,3:5) + 0.5*dh*vvb
        else
          x_mid = tracers(tracer_idx,3:5) + 0.5*dh*vv(grid_pos(1),grid_pos(2),grid_pos(3),:)
        endif
!
        call get_grid_pos(x_mid,grid_pos,outside)
        if (outside == 1) exit
        if (any(grid_pos <= 0) .or. (grid_pos(1) > nx) .or. &
            (grid_pos(2) > ny) .or. (grid_pos(3) > nz)) then
          call get_vector(grid_pos, vvb)
          x_single = tracers(tracer_idx,3:5) + dh*vvb
        else
          x_single = tracers(tracer_idx,3:5) + dh*vv(grid_pos(1),grid_pos(2),grid_pos(3),:)
        endif
!
!       (b) Two steps with half stepsize:
        call get_grid_pos(tracers(tracer_idx,3:5),grid_pos,outside)
        if (outside == 1) exit
        if (any(grid_pos <= 0) .or. (grid_pos(1) > nx) .or. &
            (grid_pos(2) > ny) .or. (grid_pos(3) > nz)) then
          call get_vector(grid_pos, vvb)
          x_mid = tracers(tracer_idx,3:5) + 0.25*dh*vvb
        else
          x_mid = tracers(tracer_idx,3:5) + 0.25*dh*vv(grid_pos(1),grid_pos(2),grid_pos(3),:)
        endif
!
        call get_grid_pos(x_mid,grid_pos,outside)
        if (outside == 1) exit
        if (any(grid_pos <= 0) .or. (grid_pos(1) > nx) .or. &
            (grid_pos(2) > ny) .or. (grid_pos(3) > nz)) then
          call get_vector(grid_pos, vvb)
          x_half = tracers(tracer_idx,3:5) + 0.5*dh*vvb
        else
          x_half = tracers(tracer_idx,3:5) + 0.5*dh*vv(grid_pos(1),grid_pos(2),grid_pos(3),:)
        endif
!
        call get_grid_pos(x_half,grid_pos,outside)        
        if (outside == 1) exit
        if (any(grid_pos <= 0) .or. (grid_pos(1) > nx) .or. &
            (grid_pos(2) > ny) .or. (grid_pos(3) > nz)) then
          call get_vector(grid_pos, vvb)
          x_mid = x_half + 0.25*dh*vvb
        else
          x_mid = x_half + 0.25*dh*vv(grid_pos(1),grid_pos(2),grid_pos(3),:)
        endif
!
        call get_grid_pos(x_mid,grid_pos,outside)
        if (outside == 1) exit
        if (any(grid_pos <= 0) .or. (grid_pos(1) > nx) .or. &
            (grid_pos(2) > ny) .or. (grid_pos(3) > nz)) then
          call get_vector(grid_pos, vvb)
          x_double = x_half + 0.5*dh*vvb
        else
          x_double = x_half + 0.5*dh*vv(grid_pos(1),grid_pos(2),grid_pos(3),:)
        endif
!
!       (c) Check error (difference between methods):
        dist2 = dot_product((x_single-x_double),(x_single-x_double))
        if (dist2 > tol**2) then
          dh = 0.5*dh
          if (abs(dh) < h_min) then
            write(*,*) "Error: stepsize underflow"
            exit
          endif
        else
!           dist2 = sqrt(dot_product((x_double - tracers(tracer_idx,3:5)),(x_double - tracers(tracer_idx,3:5))))
          tracers(tracer_idx,3:5) = x_double
          tracers(tracer_idx, 6) = tracers(tracer_idx, 6) + dh
          if (abs(dh) < h_min) dh = 2*dh
        endif
!
        if (tracers(tracer_idx, 6) >= l_max) exit
!
        loop_count = loop_count + 1
      enddo
!
!     write into output file
      if (n_tracers > 4) write(1) tracers(tracer_idx,:)
      write(*,*) iproc, tracers(tracer_idx,:)
    enddo
!
!     write(*,*) iproc, "finished field line tracing"
    close(1)
!
!   Tell every other core that we have finished.
    finished_tracing(:) = 0
    finished_tracing(iproc+1) = 1
    do proc_idx=0,(nprocx*nprocy*nprocz-1)
      if (proc_idx .ne. iproc) then
        call MPI_ISEND(finished_tracing(iproc+1), 1, MPI_integer, proc_idx, FINISHED, &
            MPI_comm_world, request_finished_send(proc_idx+1), ierr)
        if (ierr .ne. MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_ISEND could not send")
        call MPI_IRECV(finished_tracing(proc_idx+1), 1, MPI_integer, proc_idx, FINISHED, &
            MPI_comm_world, request_finished_rcv(proc_idx+1), ierr)
        if (ierr .ne. MPI_SUCCESS) &
            call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
      endif
    enddo
!
!   make sure that we can receive any request as long as not all cores are finished
    do
      if (receive == 0) then
!       create a receive request
        grid_pos_b(:) = 0
        call MPI_IRECV(grid_pos_b,3,MPI_integer,MPI_ANY_SOURCE,VV_RQST,MPI_comm_world,request,ierr)
        if (ierr .ne. MPI_SUCCESS) then
          call fatal_error("streamlines", "MPI_IRECV could not create a receive request")
          exit
        endif
        receive = 1
      endif
!
!     check if there is any request for the vector field from another core
      if (receive == 1) then
        flag = 0
        call MPI_TEST(request,flag,status,ierr)
        if (flag == 1) then
!         receive completed, send the vector field
          vvb = vv(grid_pos_b(1),grid_pos_b(2),grid_pos_b(3),:)
          call MPI_SEND(vvb,3,MPI_REAL,status(MPI_SOURCE),VV_RCV,MPI_comm_world,ierr)
          if (ierr .ne. MPI_SUCCESS) then
            call fatal_error("streamlines", "MPI_SEND could not send")
            exit
          endif
          receive = 0
        endif
      endif
!
!     Check if a core has finished and update finished_tracing array.
      do proc_idx=0,(nprocx*nprocy*nprocz-1)
        if ((proc_idx .ne. iproc) .and. (finished_tracing(proc_idx+1) == 0)) then
          flag = 0
          call MPI_TEST(request_finished_rcv(proc_idx+1),flag,status,ierr)
          if (ierr .ne. MPI_SUCCESS) &
              call fatal_error("streamlines", "MPI_TEST failed")
          if (flag == 1) then
            finished_tracing(proc_idx+1) = 1
          endif
        endif
      enddo
!
      if (sum(finished_tracing) == nprocx*nprocy*nprocz) exit
    enddo
!     write(*,*) iproc, "all finished"
!
  endsubroutine trace_streamlines
!***********************************************************************
endmodule Streamlines
