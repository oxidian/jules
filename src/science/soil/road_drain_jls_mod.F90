! *****************************COPYRIGHT*******************************
! (C) Crown copyright Met Office. All rights reserved.
! For further details please refer to the file COPYRIGHT.txt
! which you should have received as part of this distribution.
! *****************************COPYRIGHT*******************************

!  SUBROUTINE ROAD_DRAIN------------------------------------------------------

!  PURPOSE : TO CALCULATE THE DRAINAGE OF WATER FROM THE ROAD SURFACE STORE
!            DUE TO ROAD CAMBER. ONLY APPLIED TO THE ROAD SURFACE TYPE.

!            SNOWMELT IS ADDED TO THE STORE. ABOVE THE FILM THRESHOLD, AND
!            WHEN THE SURFACE IS ABOVE FREEZING, THE STORE DRAINS WITH A
!            HALF-LIFE. WATER ABOVE THE STORE CAPACITY SPILLS. THE DRAINED
!            AND SPILLED WATER IS ADDED TO THE THROUGHFALL.

!  SUITABLE FOR SINGLE COLUMN MODEL USE

!-----------------------------------------------------------------------------

MODULE road_drain_mod
CHARACTER(LEN=*), PARAMETER, PRIVATE :: ModuleName='ROAD_DRAIN_MOD'

CONTAINS

SUBROUTINE road_drain ( npnts, surft_pts, surft_index, timestep, can_wcnt,     &
                        drain_film_thresh, drain_hlife, tstar_surft, frac,     &
                        can_cpy, tot_tfall, tot_tfall_surft, snow_melt )

USE conversions_mod, ONLY: zerodegc

USE yomhook, ONLY: lhook, dr_hook
USE parkind1, ONLY: jprb, jpim

USE um_types, ONLY: real_jlslsm

IMPLICIT NONE

!-----------------------------------------------------------------------------
! Arguments with INTENT(IN):
!-----------------------------------------------------------------------------
INTEGER, INTENT(IN) ::                                                         &
  npnts,                                                                       &
    ! Total number of land points.
  surft_pts,                                                                   &
    ! Number of tile points.
  surft_index(npnts)
    ! Index of tile points.

REAL(KIND=real_jlslsm), INTENT(IN) ::                                          &
  drain_film_thresh,                                                           &
    ! Film for which drainage does not occur (kg/m2).
  drain_hlife,                                                                 &
    ! Half-life for water drainage (s).
  timestep,                                                                    &
    ! Timestep (s).
  can_cpy(npnts),                                                              &
    ! Canopy capacity (kg/m2).
  frac(npnts),                                                                 &
    ! Tile fraction.
  tstar_surft(npnts),                                                          &
    ! Tile surface temperature (K).
  snow_melt(npnts)
    ! Gridbox snowmelt (kg/m2/s).

!-----------------------------------------------------------------------------
! Arguments with INTENT(IN OUT):
!-----------------------------------------------------------------------------
REAL(KIND=real_jlslsm), INTENT(IN OUT) ::                                      &
  tot_tfall(npnts),                                                            &
    ! Cumulative canopy throughfall (kg/m2/s).
  tot_tfall_surft(npnts),                                                      &
    ! Throughfall contributions for this tile (kg/m2/s).
  can_wcnt(npnts)
    ! Canopy water content (kg/m2).

!-----------------------------------------------------------------------------
! Local variables:
!-----------------------------------------------------------------------------
INTEGER ::                                                                     &
  i, j
    ! Loop counters:
    ! i for land point
    ! j for tile point

REAL(KIND=real_jlslsm) ::                                                      &
  tfall(npnts)
    ! Local throughfall (kg/m2/s).

INTEGER(KIND=jpim), PARAMETER :: zhook_in  = 0
INTEGER(KIND=jpim), PARAMETER :: zhook_out = 1
REAL(KIND=jprb)               :: zhook_handle

CHARACTER(LEN=*), PARAMETER :: RoutineName='ROAD_DRAIN'

IF (lhook) CALL dr_hook(ModuleName//':'//RoutineName,zhook_in,zhook_handle)
!-----------------------------------------------------------------------------

!$OMP PARALLEL DO DEFAULT(NONE) PRIVATE(j, i)                                  &
!$OMP SHARED(surft_pts, surft_index, timestep, can_wcnt,                       &
!$OMP        drain_film_thresh, drain_hlife, tstar_surft, can_cpy, snow_melt,  &
!$OMP        tfall, tot_tfall, frac, tot_tfall_surft)                          &
!$OMP SCHEDULE(STATIC)
DO j = 1,surft_pts
  i = surft_index(j)
  can_wcnt(i) = can_wcnt(i) + snow_melt(i) * timestep

  IF (can_wcnt(i) > drain_film_thresh .AND. tstar_surft(i) > zerodegc) THEN
    tfall(i) = (can_wcnt(i) - (can_wcnt(i) - drain_film_thresh)                &
                   * 0.5 ** (timestep/drain_hlife)                             &
                   + drain_film_thresh) / timestep
  ELSE
    tfall(i) = 0.0
  END IF
  can_wcnt(i)  = can_wcnt(i) - tfall(i) * timestep
  IF ( can_wcnt(i) > can_cpy(i) ) THEN
    tfall(i) = tfall(i) + (can_wcnt(i) - can_cpy(i)) / timestep
    can_wcnt(i) = can_cpy(i)
  END IF

  tot_tfall(i) = tot_tfall(i) + frac(i) * tfall(i)

  ! Increment the tile throughfall
  tot_tfall_surft(i) = tot_tfall_surft(i) + tfall(i)
END DO
!$OMP END PARALLEL DO

IF (lhook) CALL dr_hook(ModuleName//':'//RoutineName,zhook_out,zhook_handle)
RETURN
END SUBROUTINE road_drain
END MODULE road_drain_mod
