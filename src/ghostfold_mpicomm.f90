! $Id: ghostfold_mpicomm.f90,v 1.11 2007-10-02 07:39:11 ajohan Exp $
!
!  This module performs some special mpifunctions that
!  also require the Fourier routines.
!
module GhostFold

  use Cparam
  use Messages

  implicit none

  private

  public :: fold_df, fold_f

  contains
!***********************************************************************
    subroutine fold_df(df,ivar1,ivar2)
!
!  Fold first ghost zone of df into main part of df.
!
!  20-may-2006/anders: coded
!
      use Cdata
      use Mpicomm
      use Fourier
!
      real, dimension (mx,my,mz,mvar) :: df
      integer :: ivar1, ivar2
!
      real, dimension (nx+2,ny+2,1,ivar2-ivar1+1) :: df_tmp_xy
      real, dimension (nx+2,1,nz,ivar2-ivar1+1) :: df_tmp_xz
      real, dimension (ny,nz) :: df_tmp_yz
      integer :: nvar_fold, iproc_rcv, ivar
!
      nvar_fold=ivar2-ivar1+1
!  The first ghost zone in the z-direction is folded (the corners will find
!  their proper positions after folding in x and y as well).
      if (nzgrid/=1) then
        if (nprocz==1) then
          df(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2)= &
              df(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2)+ &
              df(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)
          df(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2)= &
              df(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2)+ &
              df(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)
        else
          do iproc_rcv=0,ncpus-1
            if (iproc==iproc_rcv) then
              call mpirecv_real(df_tmp_xy, &
                  (/nx+2,ny+2,1,nvar_fold/), zlneigh, 10000)
            elseif (iproc_rcv==zuneigh) then
              call mpisend_real(df(l1-1:l2+1,m1-1:m2+1,n2+1:n2+1,ivar1:ivar2), &
                  (/nx+2,ny+2,1,nvar_fold/), zuneigh, 10000)
            endif
            if (iproc==iproc_rcv) df(l1-1:l2+1,m1-1:m2+1,n1:n1,ivar1:ivar2)= &
                df(l1-1:l2+1,m1-1:m2+1,n1:n1,ivar1:ivar2) + df_tmp_xy
            if (iproc==iproc_rcv) then
              call mpirecv_real(df_tmp_xy, &
                  (/nx+2,ny+2,1,nvar_fold/), zuneigh, 10001)
            elseif (iproc_rcv==zlneigh) then
              call mpisend_real(df(l1-1:l2+1,m1-1:m2+1,n1-1:n1-1,ivar1:ivar2), &
                  (/nx+2,ny+2,1,nvar_fold/), zlneigh, 10001)
            endif
            if (iproc==iproc_rcv) df(l1-1:l2+1,m1-1:m2+1,n2:n2,ivar1:ivar2)= &
                df(l1-1:l2+1,m1-1:m2+1,n2:n2,ivar1:ivar2) + df_tmp_xy
          enddo
        endif
        df(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)=0.0
        df(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)=0.0
      endif
! Then y.
      if (nygrid/=1) then
        if (nprocy==1) then
          df(l1-1:l2+1,m1,n1:n2,ivar1:ivar2)= &
              df(l1-1:l2+1,m1,n1:n2,ivar1:ivar2) + &
              df(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)
          df(l1-1:l2+1,m2,n1:n2,ivar1:ivar2)= &
              df(l1-1:l2+1,m2,n1:n2,ivar1:ivar2) + &
              df(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)
        else
          do iproc_rcv=0,ncpus-1
            if (iproc==iproc_rcv) then
              call mpirecv_real(df_tmp_xz, &
                  (/nx+2,1,nz,nvar_fold/), ylneigh, 10002)
            elseif (iproc_rcv==yuneigh) then
              call mpisend_real(df(l1-1:l2+1,m2+1:m2+1,n1:n2,ivar1:ivar2), &
                  (/nx+2,1,nz,nvar_fold/), yuneigh, 10002)
            endif
            if (iproc==iproc_rcv) df(l1-1:l2+1,m1:m1,n1:n2,ivar1:ivar2)= &
                df(l1-1:l2+1,m1:m1,n1:n2,ivar1:ivar2) + df_tmp_xz
            if (iproc==iproc_rcv) then
              call mpirecv_real(df_tmp_xz, &
                  (/nx+2,1,nz,nvar_fold/), yuneigh, 10003)
            elseif (iproc_rcv==ylneigh) then
              call mpisend_real(df(l1-1:l2+1,m1-1:m1-1,n1:n2,ivar1:ivar2), &
                  (/nx+2,1,nz,nvar_fold/), ylneigh, 10003)
            endif
            if (iproc==iproc_rcv) df(l1-1:l2+1,m2:m2,n1:n2,ivar1:ivar2)= &
                df(l1-1:l2+1,m2:m2,n1:n2,ivar1:ivar2) + df_tmp_xz
          enddo
!
        endif
!
!  With shearing boundary conditions we must take care that the information is
!  shifted properly before the final fold.
!
        if (nxgrid>1 .and. lshear) then
          do ivar=ivar1,ivar2
            df_tmp_yz=df(l1-1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(df_tmp_yz,-deltay)
            df(l1-1,m1:m2,n1:n2,ivar)=df_tmp_yz
            df_tmp_yz=df(l2+1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(df_tmp_yz,+deltay)
            df(l2+1,m1:m2,n1:n2,ivar)=df_tmp_yz
          enddo
        endif
!
        df(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)=0.0
        df(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)=0.0
      endif
! Then x (always at the same processor).
      if (nxgrid/=1) then
        df(l1,m1:m2,n1:n2,ivar1:ivar2)=df(l1,m1:m2,n1:n2,ivar1:ivar2) + &
            df(l2+1,m1:m2,n1:n,ivar1:ivar2)
        df(l2,m1:m2,n1:n2,ivar1:ivar2)=df(l2,m1:m2,n1:n2,ivar1:ivar2) + &
            df(l1-1,m1:m2,n1:n2,ivar1:ivar2)
        df(l1-1,m1:m2,n1:n2,ivar1:ivar2)=0.0
        df(l2+1,m1:m2,n1:n2,ivar1:ivar2)=0.0
      endif
!
    endsubroutine fold_df
!***********************************************************************
    subroutine fold_f(f,ivar1,ivar2)
!
!  Fold first ghost zone of f into main part of f.
!
!  20-may-2006/anders: coded
!
      use Cdata
      use Mpicomm
      use Fourier
!
      real, dimension (mx,my,mz,mfarray) :: f
      integer :: ivar1, ivar2
!
      real, dimension (nx+2,ny+2,1,ivar2-ivar1+1) :: f_tmp_xy
      real, dimension (nx+2,1,nz,ivar2-ivar1+1) :: f_tmp_xz
      real, dimension (ny,nz) :: f_tmp_yz
      integer :: nvar_fold, iproc_rcv, ivar
!
      nvar_fold=ivar2-ivar1+1
!  The first ghost zone in the z-direction is folded (the corners will find
!  their proper positions after folding in x and y as well).
      if (nzgrid/=1) then
        if (nprocz==1) then
          f(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2)= &
              f(l1-1:l2+1,m1-1:m2+1,n1,ivar1:ivar2)+ &
              f(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)
          f(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2)= &
              f(l1-1:l2+1,m1-1:m2+1,n2,ivar1:ivar2)+ &
              f(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)
        else
          do iproc_rcv=0,ncpus-1
            if (iproc==iproc_rcv) then
              call mpirecv_real(f_tmp_xy, &
                  (/nx+2,ny+2,1,nvar_fold/), zlneigh, 10000)
            elseif (iproc_rcv==zuneigh) then
              call mpisend_real(f(l1-1:l2+1,m1-1:m2+1,n2+1:n2+1,ivar1:ivar2), &
                  (/nx+2,ny+2,1,nvar_fold/), zuneigh, 10000)
            endif
            if (iproc==iproc_rcv) f(l1-1:l2+1,m1-1:m2+1,n1:n1,ivar1:ivar2)= &
                f(l1-1:l2+1,m1-1:m2+1,n1:n1,ivar1:ivar2) + f_tmp_xy
            if (iproc==iproc_rcv) then
              call mpirecv_real(f_tmp_xy, &
                  (/nx+2,ny+2,1,nvar_fold/), zuneigh, 10001)
            elseif (iproc_rcv==zlneigh) then
              call mpisend_real(f(l1-1:l2+1,m1-1:m2+1,n1-1:n1-1,ivar1:ivar2), &
                  (/nx+2,ny+2,1,nvar_fold/), zlneigh, 10001)
            endif
            if (iproc==iproc_rcv) f(l1-1:l2+1,m1-1:m2+1,n2:n2,ivar1:ivar2)= &
                f(l1-1:l2+1,m1-1:m2+1,n2:n2,ivar1:ivar2) + f_tmp_xy
          enddo
        endif
        f(l1-1:l2+1,m1-1:m2+1,n1-1,ivar1:ivar2)=0.0
        f(l1-1:l2+1,m1-1:m2+1,n2+1,ivar1:ivar2)=0.0
      endif
! Then y.
      if (nygrid/=1) then
        if (nprocy==1) then
          f(l1-1:l2+1,m1,n1:n2,ivar1:ivar2)= &
              f(l1-1:l2+1,m1,n1:n2,ivar1:ivar2) + &
              f(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)
          f(l1-1:l2+1,m2,n1:n2,ivar1:ivar2)= &
              f(l1-1:l2+1,m2,n1:n2,ivar1:ivar2) + &
              f(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)
        else
          do iproc_rcv=0,ncpus-1
            if (iproc==iproc_rcv) then
              call mpirecv_real(f_tmp_xz, &
                  (/nx+2,1,nz,nvar_fold/), ylneigh, 10002)
            elseif (iproc_rcv==yuneigh) then
              call mpisend_real(f(l1-1:l2+1,m2+1:m2+1,n1:n2,ivar1:ivar2), &
                  (/nx+2,1,nz,nvar_fold/), yuneigh, 10002)
            endif
            if (iproc==iproc_rcv) f(l1-1:l2+1,m1:m1,n1:n2,ivar1:ivar2)= &
                f(l1-1:l2+1,m1:m1,n1:n2,ivar1:ivar2) + f_tmp_xz
            if (iproc==iproc_rcv) then
              call mpirecv_real(f_tmp_xz, &
                  (/nx+2,1,nz,nvar_fold/), yuneigh, 10003)
            elseif (iproc_rcv==ylneigh) then
              call mpisend_real(f(l1-1:l2+1,m1-1:m1-1,n1:n2,ivar1:ivar2), &
                  (/nx+2,1,nz,nvar_fold/), ylneigh, 10003)
            endif
            if (iproc==iproc_rcv) f(l1-1:l2+1,m2:m2,n1:n2,ivar1:ivar2)= &
                f(l1-1:l2+1,m2:m2,n1:n2,ivar1:ivar2) + f_tmp_xz
          enddo
!
        endif
!
!  With shearing boundary conditions we must take care that the information is
!  shifted properly before the final fold.
!
        if (nxgrid>1 .and. lshear) then
          do ivar=ivar1,ivar2
            f_tmp_yz=f(l1-1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(f_tmp_yz,-deltay)
            f(l1-1,m1:m2,n1:n2,ivar)=f_tmp_yz
            f_tmp_yz=f(l2+1,m1:m2,n1:n2,ivar)
            call fourier_shift_yz(f_tmp_yz,+deltay)
            f(l2+1,m1:m2,n1:n2,ivar)=f_tmp_yz
          enddo
        endif
!
        f(l1-1:l2+1,m1-1,n1:n2,ivar1:ivar2)=0.0
        f(l1-1:l2+1,m2+1,n1:n2,ivar1:ivar2)=0.0
      endif
! Then x (always at the same processor).
      if (nxgrid/=1) then
        f(l1,m1:m2,n1:n2,ivar1:ivar2)=f(l1,m1:m2,n1:n2,ivar1:ivar2) + &
            f(l2+1,m1:m2,n1:n,ivar1:ivar2)
        f(l2,m1:m2,n1:n2,ivar1:ivar2)=f(l2,m1:m2,n1:n2,ivar1:ivar2) + &
            f(l1-1,m1:m2,n1:n2,ivar1:ivar2)
        f(l1-1,m1:m2,n1:n2,ivar1:ivar2)=0.0
        f(l2+1,m1:m2,n1:n2,ivar1:ivar2)=0.0
      endif
!
    endsubroutine fold_f
!***********************************************************************
endmodule GhostFold
