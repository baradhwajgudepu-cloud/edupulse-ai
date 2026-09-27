import uuid
import math
import logging
from datetime import date, datetime, timezone
from typing import Optional, Dict, Any, Tuple, Union
from fastapi import HTTPException, status
from sqlalchemy import select

from app.models.staff_attendance import StaffAttendance
from app.models.school import School
from app.models.teacher import Teacher
from app.models.teacher_leave import TeacherLeave, LeaveStatus as TeacherLeaveStatus
from app.repositories.staff_attendance import StaffAttendanceRepository
from app.repositories.teacher import TeacherRepository
from app.repositories.school import SchoolRepository
from app.schemas.staff_attendance import StaffCheckInRequest, StaffCheckOutRequest

logger = logging.getLogger(__name__)

class StaffAttendanceService:
    """
    Service Layer implementing business validations and logic for Teacher Staff Attendance.
    """
    def __init__(
        self,
        staff_attendance_repo: StaffAttendanceRepository,
        teacher_repo: TeacherRepository,
        school_repo: SchoolRepository
    ) -> None:
        self.staff_attendance_repo = staff_attendance_repo
        self.teacher_repo = teacher_repo
        self.school_repo = school_repo

    def haversine_distance(self, lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculates distance between two GPS coordinates in meters using the Haversine formula.
        """
        R = 6371008.8  # Radius of earth in meters
        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        
        a = (math.sin(dlat / 2) ** 2 + 
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * 
             math.sin(dlon / 2) ** 2)
             
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    def _calculate_duration(self, check_in: datetime, check_out: datetime) -> int:
        """
        Safely calculates duration between check-in and check-out times,
        normalizing timezones to naive representation to support SQLite seamlessly.
        """
        t_in = check_in.replace(tzinfo=None) if check_in.tzinfo is not None else check_in
        t_out = check_out.replace(tzinfo=None) if check_out.tzinfo is not None else check_out
        return int((t_out - t_in).total_seconds())

    async def get_today_status(self, tenant_id: uuid.UUID, user_id: uuid.UUID) -> Optional[Dict[str, Any]]:
        """
        Fetches today's staff attendance record for the logged-in teacher.
        """
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found for authenticated user."
            )

        # Check if there is an approved leave request covering today
        stmt_leave = select(TeacherLeave).where(
            TeacherLeave.teacher_id == teacher.id,
            TeacherLeave.tenant_id == tenant_id,
            TeacherLeave.status == TeacherLeaveStatus.APPROVED,
            TeacherLeave.start_date <= date.today(),
            TeacherLeave.end_date >= date.today(),
            TeacherLeave.deleted_at.is_(None)
        )
        leave_res = await self.staff_attendance_repo.db.execute(stmt_leave)
        active_leave = leave_res.scalar_one_or_none()
        
        record = await self.staff_attendance_repo.get_by_date(teacher.id, date.today(), tenant_id)
        if not record:
            if active_leave:
                return {
                    "status": "ON_LEAVE",
                    "id": None,
                    "tenant_id": tenant_id,
                    "teacher_id": teacher.id,
                    "school_id": teacher.school_id,
                    "attendance_date": date.today(),
                    "check_in_time": None,
                    "check_in_distance_meters": 0.0,
                    "check_out_time": None,
                    "check_out_distance_meters": None,
                    "duration_seconds": None,
                    "is_mocked_location": False,
                    "remarks": f"On Leave: {active_leave.reason}"
                }
            return {
                "status": "NOT_CHECKED_IN",
                "id": None,
                "tenant_id": tenant_id,
                "teacher_id": teacher.id,
                "school_id": teacher.school_id,
                "attendance_date": date.today(),
                "check_in_time": None,
                "check_in_distance_meters": 0.0,
                "check_out_time": None,
                "check_out_distance_meters": None,
                "duration_seconds": None,
                "is_mocked_location": False,
                "remarks": None
            }

        duration_seconds = None
        if record.check_out_time:
            duration_seconds = self._calculate_duration(record.check_in_time, record.check_out_time)

        status_str = "CHECKED_OUT" if record.check_out_time else "CHECKED_IN"

        return {
            "id": record.id,
            "tenant_id": record.tenant_id,
            "teacher_id": record.teacher_id,
            "school_id": record.school_id,
            "attendance_date": record.attendance_date,
            "check_in_time": record.check_in_time,
            "check_in_latitude": record.check_in_latitude,
            "check_in_longitude": record.check_in_longitude,
            "check_in_distance_meters": record.check_in_distance_meters,
            "check_out_time": record.check_out_time,
            "check_out_latitude": record.check_out_latitude,
            "check_out_longitude": record.check_out_longitude,
            "check_out_distance_meters": record.check_out_distance_meters,
            "is_mocked_location": record.is_mocked_location,
            "remarks": record.remarks,
            "duration_seconds": duration_seconds,
            "status": status_str
        }

    def _evaluate_geofence_and_record_policy(
        self,
        school: School,
        latitude: float,
        longitude: float,
        accuracy: Optional[float],
        is_mocked: bool,
        action_name: str,
        tenant_id: uuid.UUID,
        teacher_id: uuid.UUID,
    ) -> Tuple[Optional[float], Optional[str]]:
        """
        Validates geofence attendance policy strictly on the server.

        Returns:
            Tuple[Optional[float], Optional[str]]: (distance_meters, exemption_tag)

        Enforcement rules:
        1. If geofence is disabled by authorized admin in school configuration:
           - Allow sign-in/out.
           - Calculate distance if coordinates exist.
           - Generate structured audit log without coordinate PII.
           - Return (distance, exemption_tag) to record in remarks.
        2. If geofence is enabled:
           - Reject immediately if is_mocked is True (simulated/mocked GPS providers cannot bypass geofence).
           - Verify school has configured coordinates and positive radius (fail safely with HTTP 400 if not).
           - Verify client provided valid GPS accuracy (reject if None or > 100.0m with HTTP 400).
           - Calculate Haversine distance.
           - Apply deterministic GPS tolerance: min(accuracy, 15.0, radius * 0.1).
           - Reject with HTTP 400 if distance > radius + tolerance.
           - Return (distance, None).
        """
        gf_settings = (school.settings or {}).get("geofence", {}) if school.settings else {}
        geofence_enabled = gf_settings.get("enabled", True)
        actor_id = gf_settings.get("updated_by") or (str(school.updated_by) if school.updated_by else "SYSTEM_DEFAULT")
        updated_at = gf_settings.get("updated_at") or (school.updated_at.isoformat() if school.updated_at else "UNKNOWN_TIME")

        if not geofence_enabled:
            # Policy explicitly disabled by authorized administrator
            distance = None
            if school.latitude is not None and school.longitude is not None:
                distance = self.haversine_distance(latitude, longitude, school.latitude, school.longitude)

            logger.warning(
                "Geofence exemption applied for %s: tenant_id=%s, school_id=%s, teacher_id=%s, actor_id=%s, config_updated_at=%s",
                action_name, tenant_id, school.id, teacher_id, actor_id, updated_at
            )
            exemption_tag = f"[GEOFENCE_EXEMPTION: Authorized school geofence restriction disabled | Actor: {actor_id}]"
            return distance, exemption_tag

        # Geofence is ENABLED: Reject mocked/simulated GPS locations
        if is_mocked:
            logger.warning(
                "Mocked GPS location rejected for %s: tenant_id=%s, school_id=%s, teacher_id=%s",
                action_name, tenant_id, school.id, teacher_id
            )
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"Mocked GPS location detected. {action_name} cannot be verified using simulated location providers."
            )

        # Geofence is ENABLED: Fail-safe verification
        if school.latitude is None or school.longitude is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"School geolocation coordinates are not configured. {action_name} cannot be verified."
            )

        if school.geofence_radius_meters is None or school.geofence_radius_meters <= 0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"School geofence radius is not configured. {action_name} cannot be verified."
            )

        if accuracy is None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="GPS accuracy reading is required to verify school attendance location. Please enable high-accuracy location services."
            )

        if accuracy > 100.0:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=f"GPS accuracy is too low ({accuracy:.1f}m > 100m). Please wait for a better GPS fix."
            )

        distance = self.haversine_distance(latitude, longitude, school.latitude, school.longitude)

        # Deterministic GPS accuracy model
        tolerance = min(accuracy, 15.0, float(school.geofence_radius_meters) * 0.1)
        effective_max_distance = float(school.geofence_radius_meters) + tolerance

        if distance > effective_max_distance:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail=(
                    f"{action_name} failed. You are outside the school attendance location. "
                    f"Please move within the permitted area and try again. "
                    f"(Distance: {round(distance, 1)}m, Allowed: {school.geofence_radius_meters}m; "
                    f"outside the permitted school geofence)"
                )
            )

        return distance, None

    async def check_in(self, tenant_id: uuid.UUID, user_id: uuid.UUID, payload: StaffCheckInRequest) -> Dict[str, Any]:
        """
        Records today's staff check-in after validation against school geofence.
        """
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found for authenticated user."
            )

        school = await self.school_repo.get_by_id(teacher.school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found for teacher profile."
            )

        # Coordinate validity check
        if math.isnan(payload.latitude) or math.isinf(payload.latitude) or \
           math.isnan(payload.longitude) or math.isinf(payload.longitude):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid location coordinates provided."
            )

        # Geofence validation & policy evaluation
        distance, exemption_tag = self._evaluate_geofence_and_record_policy(
            school=school,
            latitude=payload.latitude,
            longitude=payload.longitude,
            accuracy=payload.accuracy,
            is_mocked=payload.is_mocked,
            action_name="Check-in",
            tenant_id=tenant_id,
            teacher_id=teacher.id,
        )

        # Duplicate check-in prevention
        existing = await self.staff_attendance_repo.get_by_date(teacher.id, date.today(), tenant_id)
        if existing:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail="Today's check-in has already been recorded."
            )

        remarks = payload.remarks
        if exemption_tag:
            remarks = f"{remarks} | {exemption_tag}" if remarks else exemption_tag

        now = datetime.now(timezone.utc)
        db_obj = StaffAttendance(
            id=uuid.uuid4(),
            tenant_id=tenant_id,
            teacher_id=teacher.id,
            school_id=school.id,
            attendance_date=date.today(),
            check_in_time=now,
            check_in_latitude=payload.latitude,
            check_in_longitude=payload.longitude,
            check_in_distance_meters=distance,
            is_mocked_location=payload.is_mocked,
            remarks=remarks,
            created_by=user_id,
            updated_by=user_id
        )

        await self.staff_attendance_repo.create(db_obj)
        await self.staff_attendance_repo.db.commit()
        
        return {
            "id": db_obj.id,
            "tenant_id": db_obj.tenant_id,
            "teacher_id": db_obj.teacher_id,
            "school_id": db_obj.school_id,
            "attendance_date": db_obj.attendance_date,
            "check_in_time": db_obj.check_in_time,
            "check_in_latitude": db_obj.check_in_latitude,
            "check_in_longitude": db_obj.check_in_longitude,
            "check_in_distance_meters": db_obj.check_in_distance_meters,
            "check_out_time": None,
            "check_out_latitude": None,
            "check_out_longitude": None,
            "check_out_distance_meters": None,
            "is_mocked_location": db_obj.is_mocked_location,
            "remarks": db_obj.remarks,
            "duration_seconds": None,
            "status": "CHECKED_IN"
        }

    async def check_out(self, tenant_id: uuid.UUID, user_id: uuid.UUID, payload: StaffCheckOutRequest) -> Dict[str, Any]:
        """
        Records today's staff check-out after validation against school geofence.
        """
        teacher = await self.teacher_repo.get_by_user_id(user_id, tenant_id)
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found for authenticated user."
            )

        school = await self.school_repo.get_by_id(teacher.school_id, tenant_id)
        if not school:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="School not found for teacher profile."
            )

        # Coordinate validity check
        if math.isnan(payload.latitude) or math.isinf(payload.latitude) or \
           math.isnan(payload.longitude) or math.isinf(payload.longitude):
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Invalid location coordinates provided."
            )

        # Geofence validation & policy evaluation
        distance, exemption_tag = self._evaluate_geofence_and_record_policy(
            school=school,
            latitude=payload.latitude,
            longitude=payload.longitude,
            accuracy=payload.accuracy,
            is_mocked=payload.is_mocked,
            action_name="Check-out",
            tenant_id=tenant_id,
            teacher_id=teacher.id,
        )

        record = await self.staff_attendance_repo.get_by_date(teacher.id, date.today(), tenant_id)
        if not record:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Check-out failed. No active check-in session found for today."
            )

        if record.check_out_time is not None:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Already checked out for today."
            )

        now = datetime.now(timezone.utc)
        record.check_out_time = now
        record.check_out_latitude = payload.latitude
        record.check_out_longitude = payload.longitude
        record.check_out_distance_meters = distance
        record.updated_by = user_id
        
        if payload.is_mocked:
            record.is_mocked_location = True
            
        out_remarks_parts = []
        if payload.remarks:
            out_remarks_parts.append(f"Out: {payload.remarks}")
        if exemption_tag and (not record.remarks or exemption_tag not in record.remarks):
            out_remarks_parts.append(exemption_tag)

        if out_remarks_parts:
            joined_out = " | ".join(out_remarks_parts)
            record.remarks = f"{record.remarks} | {joined_out}" if record.remarks else joined_out

        await self.staff_attendance_repo.update(record)
        await self.staff_attendance_repo.db.commit()

        duration_seconds = self._calculate_duration(record.check_in_time, record.check_out_time)

        return {
            "id": record.id,
            "tenant_id": record.tenant_id,
            "teacher_id": record.teacher_id,
            "school_id": record.school_id,
            "attendance_date": record.attendance_date,
            "check_in_time": record.check_in_time,
            "check_in_latitude": record.check_in_latitude,
            "check_in_longitude": record.check_in_longitude,
            "check_in_distance_meters": record.check_in_distance_meters,
            "check_out_time": record.check_out_time,
            "check_out_latitude": record.check_out_latitude,
            "check_out_longitude": record.check_out_longitude,
            "check_out_distance_meters": record.check_out_distance_meters,
            "is_mocked_location": record.is_mocked_location,
            "remarks": record.remarks,
            "duration_seconds": duration_seconds,
            "status": "CHECKED_OUT"
        }

    async def get_daily_report(self, tenant_id: uuid.UUID, school_id: uuid.UUID, attendance_date: date) -> Dict[str, Any]:
        """
        Generates daily staff attendance summary and records for a target school and date.
        """
        # 1. Fetch all teachers in this school & tenant that are not deleted/inactive
        stmt_teachers = select(Teacher).where(
            Teacher.school_id == school_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        teachers_result = await self.staff_attendance_repo.db.execute(stmt_teachers)
        teachers = list(teachers_result.scalars().all())

        # 2. Fetch all staff check-in logs for this date, school & tenant
        stmt_logs = select(StaffAttendance).where(
            StaffAttendance.school_id == school_id,
            StaffAttendance.attendance_date == attendance_date,
            StaffAttendance.tenant_id == tenant_id,
            StaffAttendance.deleted_at.is_(None)
        )
        logs_result = await self.staff_attendance_repo.db.execute(stmt_logs)
        logs = {log.teacher_id: log for log in logs_result.scalars().all()}

        # 3. Fetch approved leaves covering this date
        stmt_leaves = select(TeacherLeave).where(
            TeacherLeave.school_id == school_id,
            TeacherLeave.tenant_id == tenant_id,
            TeacherLeave.status == TeacherLeaveStatus.APPROVED,
            TeacherLeave.start_date <= attendance_date,
            TeacherLeave.end_date >= attendance_date,
            TeacherLeave.deleted_at.is_(None)
        )
        leaves_result = await self.staff_attendance_repo.db.execute(stmt_leaves)
        leaves = {leave.teacher_id: leave for leave in leaves_result.scalars().all()}

        records = []
        present_count = 0
        absent_count = 0
        late_count = 0
        half_day_count = 0
        on_leave_count = 0
        not_marked_count = 0

        for t in teachers:
            check_in_latitude = None
            check_in_longitude = None
            check_in_distance_meters = None
            check_out_latitude = None
            check_out_longitude = None
            check_out_distance_meters = None
            is_mocked_location = False

            # Check if teacher has an approved leave request on this date
            if t.id in leaves:
                status_str = "ON_LEAVE"
                on_leave_count += 1
                check_in_time = None
                check_out_time = None
                remarks = leaves[t.id].reason
            # Else check if there is a check-in log
            elif t.id in logs:
                log = logs[t.id]
                check_in_time = log.check_in_time
                check_out_time = log.check_out_time
                remarks = log.remarks
                check_in_latitude = log.check_in_latitude
                check_in_longitude = log.check_in_longitude
                check_in_distance_meters = log.check_in_distance_meters
                check_out_latitude = log.check_out_latitude
                check_out_longitude = log.check_out_longitude
                check_out_distance_meters = log.check_out_distance_meters
                is_mocked_location = log.is_mocked_location
                
                # Check-in time comparison:
                # Late if after 09:15:00 local time
                # Half-day if after 11:30:00 local time
                if check_in_time:
                    hour = check_in_time.hour
                    minute = check_in_time.minute
                    
                    # Convert to IST if UTC context (Indian Standard Time is UTC+5:30)
                    if check_in_time.tzinfo is not None:
                        from datetime import timezone, timedelta
                        ist = timezone(timedelta(hours=5, minutes=30))
                        local_dt = check_in_time.astimezone(ist)
                        h = local_dt.hour
                        m = local_dt.minute
                    else:
                        h = hour
                        m = minute
                    
                    if h > 11 or (h == 11 and m >= 30):
                        status_str = "HALF_DAY"
                        half_day_count += 1
                    elif h > 9 or (h == 9 and m >= 15):
                        status_str = "LATE"
                        late_count += 1
                    else:
                        status_str = "PRESENT"
                        present_count += 1
                else:
                    status_str = "PRESENT"
                    present_count += 1
            else:
                status_str = "NOT_MARKED"
                not_marked_count += 1
                check_in_time = None
                check_out_time = None
                remarks = None

            records.append({
                "teacher_id": t.id,
                "teacher_name": f"{t.first_name} {t.last_name}",
                "designation": t.designation,
                "department": t.department,
                "attendance_status": status_str,
                "check_in_time": check_in_time,
                "check_out_time": check_out_time,
                "remarks": remarks,
                "check_in_latitude": check_in_latitude,
                "check_in_longitude": check_in_longitude,
                "check_in_distance_meters": check_in_distance_meters,
                "check_out_latitude": check_out_latitude,
                "check_out_longitude": check_out_longitude,
                "check_out_distance_meters": check_out_distance_meters,
                "is_mocked_location": is_mocked_location
            })

        total_teachers = len(teachers)
        denominator = total_teachers - on_leave_count
        attendance_rate = 0.0
        if denominator > 0:
            total_present = present_count + late_count + half_day_count
            attendance_rate = round((total_present / denominator) * 100, 1)

        return {
            "date": attendance_date,
            "total_teachers": total_teachers,
            "present_count": present_count,
            "absent_count": absent_count,
            "late_count": late_count,
            "half_day_count": half_day_count,
            "on_leave_count": on_leave_count,
            "not_marked_count": not_marked_count,
            "attendance_rate": attendance_rate,
            "records": records
        }

    async def get_teacher_attendance_history(
        self,
        tenant_id: uuid.UUID,
        teacher_id: uuid.UUID,
        start_date: Optional[date] = None,
        end_date: Optional[date] = None,
        skip: int = 0,
        limit: int = 100
    ) -> list[dict]:
        """
        Fetches attendance records for a specific teacher, verifying that the teacher profile exists under this tenant context.
        """
        stmt = select(Teacher).where(
            Teacher.id == teacher_id,
            Teacher.tenant_id == tenant_id,
            Teacher.deleted_at.is_(None)
        )
        res = await self.staff_attendance_repo.db.execute(stmt)
        teacher = res.scalar_one_or_none()
        if not teacher:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND,
                detail="Teacher profile not found."
            )

        logs = await self.staff_attendance_repo.get_history(
            teacher_id=teacher_id,
            tenant_id=tenant_id,
            start_date=start_date,
            end_date=end_date,
            skip=skip,
            limit=limit
        )

        results = []
        for h in logs:
            duration_seconds = None
            if h.check_in_time and h.check_out_time:
                duration_seconds = self._calculate_duration(h.check_in_time, h.check_out_time)
            
            results.append({
                "id": h.id,
                "tenant_id": h.tenant_id,
                "teacher_id": h.teacher_id,
                "school_id": h.school_id,
                "attendance_date": h.attendance_date,
                "check_in_time": h.check_in_time,
                "check_in_latitude": h.check_in_latitude,
                "check_in_longitude": h.check_in_longitude,
                "check_in_distance_meters": h.check_in_distance_meters,
                "check_out_time": h.check_out_time,
                "check_out_latitude": h.check_out_latitude,
                "check_out_longitude": h.check_out_longitude,
                "check_out_distance_meters": h.check_out_distance_meters,
                "is_mocked_location": h.is_mocked_location,
                "remarks": h.remarks,
                "duration_seconds": duration_seconds,
                "status": "CHECKED_OUT" if h.check_out_time else "CHECKED_IN"
            })
        return results

