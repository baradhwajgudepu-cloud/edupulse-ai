import uuid
import logging
import time
from typing import List, Optional, Dict, Any
from datetime import date

from fastapi import APIRouter, Depends, status, HTTPException
from sqlalchemy import select
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession

from app.db.session import get_db
from app.core.settings import settings
from app.models.user import User
from app.models.student import Student
from app.models.teacher import Teacher
from app.models.teacher_subject_assignment import TeacherSubjectAssignment
from app.models.marks import Marks, ExamResult
from app.models.attendance import Attendance
from app.models.subject import Subject
from app.models.class_entity import Class
from app.models.section import Section

from app.api.dependencies.auth import get_current_user
from app.api.dependencies.common import get_tenant_id
from app.api.dependencies.ai import get_ai_service
from app.services.ai.service import AIService

from app.schemas.response import APIResponse
from app.schemas.teacher_ai import (
    StudentInsightRequest,
    StudentInsightResponse,
    ClassAnalysisRequest,
    ClassAnalysisResponse,
    RemarkGenerationRequest,
    RemarkGenerationResponse,
    HomeworkGenerationRequest,
    HomeworkGenerationResponse,
    QuestionsGenerationRequest,
    QuestionsGenerationResponse
)

logger = logging.getLogger(__name__)
router = APIRouter()

SYSTEM_INSTRUCTION_STUDENT_INSIGHT = """
You are an expert AI academic analyst. Analyze the provided student's marks and attendance data.
You must construct an evidence-based academic assessment.
CRITICAL SAFETY RULES:
- Do NOT make medical, psychological, behavioral, or diagnostic claims.
- Do NOT infer sensitive personal attributes.
- Do NOT label students with terms such as "lazy", "problem child", "depressed", "ADHD", etc.
- Focus ONLY on evidence-based academic and attendance observations.
- Keep the language constructive, professional, and educational.
"""

SYSTEM_INSTRUCTION_CLASS_ANALYSIS = """
You are an expert academic data analyst. Analyze the provided class marks and attendance summary.
Generate insights detailing performance average, topics needing reinforcement, students needing attention, and suggested teaching actions.
CRITICAL SAFETY RULES:
- Only make constructive, evidence-based educational recommendations.
- Keep the analysis focused on syllabus reinforcement and teaching interventions.
"""

SYSTEM_INSTRUCTION_REMARK_GENERATION = """
You are an assistant to a school teacher. Generate a brief, constructive, and personalized academic remark for a student's report card based on their academic performance and attendance.
- Focus on strengths and specific areas of improvement.
- Use encouraging, professional language.
- The remark must be a draft that the teacher can edit.
- Do not include any placeholder text like [Teacher Name] or [Date].
"""

SYSTEM_INSTRUCTION_HOMEWORK_GENERATION = """
You are an expert curriculum and homework designer. Generate a structured homework assignment draft.
Ensure it contains a title, description, learning objective, estimated duration, and a list of questions conforming to the topic and difficulty.
Return the output strictly in the requested JSON structure.
"""

def check_ai_enabled():
    if not settings.AI_ENABLED:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="AI features are currently disabled by system configuration."
        )

async def resolve_active_teacher(user_id: uuid.UUID, tenant_id: uuid.UUID, db: AsyncSession) -> Teacher:
    # Query active teacher profile linked to the user
    stmt = select(Teacher).where(
        Teacher.user_id == user_id,
        Teacher.tenant_id == tenant_id,
        Teacher.is_active == True,
        Teacher.deleted_at.is_(None)
    )
    res = await db.execute(stmt)
    teacher = res.scalar_one_or_none()
    if not teacher:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. No active teacher profile found for user."
        )
    return teacher

@router.post(
    "/student-insight",
    response_model=APIResponse[StudentInsightResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate student academic performance insight"
)
async def generate_student_insight(
    request: StudentInsightRequest,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db),
    ai_service: AIService = Depends(get_ai_service)
) -> APIResponse[StudentInsightResponse]:
    check_ai_enabled()
    start_time = time.time()
    
    teacher = await resolve_active_teacher(current_user.id, tenant_id, db)
    student_id = request.student_id

    # 1. Fetch student & assert boundary checks
    student_stmt = select(Student).where(
        Student.id == student_id,
        Student.tenant_id == tenant_id,
        Student.deleted_at.is_(None)
    )
    student = (await db.execute(student_stmt)).scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found.")

    # Check if teacher has an active assignment for this class & section
    tsa_stmt = select(TeacherSubjectAssignment).where(
        TeacherSubjectAssignment.teacher_id == teacher.id,
        TeacherSubjectAssignment.class_id == student.class_id,
        TeacherSubjectAssignment.section_id == student.section_id,
        TeacherSubjectAssignment.tenant_id == tenant_id,
        TeacherSubjectAssignment.is_active == True,
        TeacherSubjectAssignment.deleted_at.is_(None)
    )
    tsa = (await db.execute(tsa_stmt)).first()
    if not tsa:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You are not assigned to this student's class/section."
        )

    # 2. Gather academic context (Data Minimization applied)
    marks_stmt = select(Marks).where(
        Marks.student_id == student_id,
        Marks.tenant_id == tenant_id,
        Marks.deleted_at.is_(None)
    ).options(selectinload(Marks.examination), selectinload(Marks.subject))
    marks_list = (await db.execute(marks_stmt)).scalars().all()

    attendance_stmt = select(Attendance).where(
        Attendance.student_id == student_id,
        Attendance.tenant_id == tenant_id,
        Attendance.deleted_at.is_(None)
    )
    attendance_list = (await db.execute(attendance_stmt)).scalars().all()

    # Format summaries
    marks_data = []
    for m in marks_list:
        marks_data.append({
            "subject": m.subject.subject_name if m.subject else "Unknown",
            "examination": m.examination.name if m.examination else "Assessment",
            "score": float(m.marks_obtained) if m.marks_obtained is not None else None,
            "max": m.maximum_marks,
            "result_status": m.result_status.value
        })

    total_attendance = len(attendance_list)
    present_attendance = sum(1 for a in attendance_list if a.attendance_status in ["PRESENT", "LATE", "ONLINE"])
    attendance_percentage = (present_attendance / total_attendance * 100) if total_attendance > 0 else 100.0

    # 3. Request AI Insight
    prompt = f"""
    Generate student insights using this academic record summary:
    Student Name (anonymized): {student.first_name} {student.last_name[0] if student.last_name else ''}.
    Recent Marks Details: {marks_data}
    Attendance Percentage: {attendance_percentage:.1f}% (Total sessions: {total_attendance}, Present/Late: {present_attendance})
    """

    try:
        schema = StudentInsightResponse.model_json_schema()
        structured = await ai_service.generate_json(
            prompt=prompt,
            response_schema=schema,
            client_key=str(current_user.id),
            system_instruction=SYSTEM_INSTRUCTION_STUDENT_INSIGHT
        )
        insight_response = StudentInsightResponse.model_validate(structured)
        
        # Log Audit event
        logger.info(
            "AI Audit Log: user_id=%s, tenant_id=%s, school_id=%s, operation=student-insight, status=success, latency_ms=%d, model=%s",
            str(current_user.id), str(tenant_id), str(teacher.school_id), "success", int((time.time() - start_time) * 100), settings.AI_MODEL or "gemini"
        )
        return APIResponse(success=True, message="Student insights generated successfully.", data=insight_response)

    except Exception as e:
        logger.error(f"AI Provider failure during student insight: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI Service currently unavailable: {str(e)}"
        )


@router.post(
    "/class-analysis",
    response_model=APIResponse[ClassAnalysisResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate class performance analysis"
)
async def generate_class_analysis(
    request: ClassAnalysisRequest,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db),
    ai_service: AIService = Depends(get_ai_service)
) -> APIResponse[ClassAnalysisResponse]:
    check_ai_enabled()
    start_time = time.time()

    teacher = await resolve_active_teacher(current_user.id, tenant_id, db)
    class_id = request.class_id
    section_id = request.section_id
    subject_id = request.subject_id

    # 1. Assert teacher assignment boundary check
    tsa_stmt = select(TeacherSubjectAssignment).where(
        TeacherSubjectAssignment.teacher_id == teacher.id,
        TeacherSubjectAssignment.class_id == class_id,
        TeacherSubjectAssignment.section_id == section_id,
        TeacherSubjectAssignment.subject_id == subject_id,
        TeacherSubjectAssignment.tenant_id == tenant_id,
        TeacherSubjectAssignment.is_active == True,
        TeacherSubjectAssignment.deleted_at.is_(None)
    )
    tsa = (await db.execute(tsa_stmt)).scalar_one_or_none()
    if not tsa:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You are not assigned to this class, section, and subject combination."
        )

    # 2. Extract academic performance metrics
    marks_stmt = select(Marks).where(
        Marks.class_id == class_id,
        Marks.section_id == section_id,
        Marks.subject_id == subject_id,
        Marks.tenant_id == tenant_id,
        Marks.deleted_at.is_(None)
    ).options(selectinload(Marks.student))
    marks_list = (await db.execute(marks_stmt)).scalars().all()

    if not marks_list:
        # Fallback response context if no marks are marked yet
        fallback = ClassAnalysisResponse(
            class_average=0.0,
            grade_distribution={},
            pass_percentage=0.0,
            improvement_trend="No assessment records found.",
            students_improving=[],
            students_declining=[],
            strong_areas=["No data"],
            needs_reinforcement_areas=["No data"],
            suggested_actions=["Configure exam assessments to enable performance analytics."]
        )
        return APIResponse(success=True, message="No class performance data found.", data=fallback)

    # Basic calculations
    total_score_pct = 0.0
    students_evaluated = 0
    passed_students = 0
    grade_distribution = {}
    
    student_marks_map = {}

    for m in marks_list:
        if m.marks_obtained is not None:
            pct = (float(m.marks_obtained) / m.maximum_marks) * 100.0
            total_score_pct += pct
            students_evaluated += 1
            if pct >= 40.0:  # Pass criteria
                passed_students += 1
            
            # Map grades
            g = m.grade or ("A" if pct >= 85 else "B" if pct >= 70 else "C" if pct >= 50 else "D" if pct >= 40 else "F")
            grade_distribution[g] = grade_distribution.get(g, 0) + 1

            s_name = f"{m.student.first_name} {m.student.last_name[0] if m.student.last_name else ''}"
            student_marks_map[s_name] = pct

    class_avg = (total_score_pct / students_evaluated) if students_evaluated > 0 else 0.0
    pass_pct = (passed_students / students_evaluated * 100.0) if students_evaluated > 0 else 0.0

    # Identify top/low performers (anonymized names passed to AI)
    sorted_students = sorted(student_marks_map.items(), key=lambda x: x[1])
    top_performers = [name for name, pct in sorted_students[-3:] if pct >= 80]
    low_performers = [name for name, pct in sorted_students[:3] if pct < 50]

    prompt = f"""
    Analyze the following class performance data:
    Class Average Score: {class_avg:.1f}%
    Grade Distribution: {grade_distribution}
    Pass Percentage: {pass_pct:.1f}%
    Anonymized list of high performing student indicators: {top_performers}
    Anonymized list of low performing student indicators: {low_performers}
    """

    try:
        schema = ClassAnalysisResponse.model_json_schema()
        structured = await ai_service.generate_json(
            prompt=prompt,
            response_schema=schema,
            client_key=str(current_user.id),
            system_instruction=SYSTEM_INSTRUCTION_CLASS_ANALYSIS
        )
        analysis_response = ClassAnalysisResponse.model_validate(structured)

        # Log Audit event
        logger.info(
            "AI Audit Log: user_id=%s, tenant_id=%s, school_id=%s, operation=class-analysis, status=success, latency_ms=%d, model=%s",
            str(current_user.id), str(tenant_id), str(teacher.school_id), "success", int((time.time() - start_time) * 100), settings.AI_MODEL or "gemini"
        )
        return APIResponse(success=True, message="Class analysis generated successfully.", data=analysis_response)

    except Exception as e:
        logger.error(f"AI Provider failure during class analysis: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI Service currently unavailable: {str(e)}"
        )


@router.post(
    "/generate-remark",
    response_model=APIResponse[RemarkGenerationResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate report card remark draft"
)
async def generate_remark(
    request: RemarkGenerationRequest,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db),
    ai_service: AIService = Depends(get_ai_service)
) -> APIResponse[RemarkGenerationResponse]:
    check_ai_enabled()
    start_time = time.time()

    teacher = await resolve_active_teacher(current_user.id, tenant_id, db)
    student_id = request.student_id
    subject_id = request.subject_id

    # 1. Verify student and assignment
    student_stmt = select(Student).where(
        Student.id == student_id,
        Student.tenant_id == tenant_id,
        Student.deleted_at.is_(None)
    )
    student = (await db.execute(student_stmt)).scalar_one_or_none()
    if not student:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Student not found.")

    tsa_stmt = select(TeacherSubjectAssignment).where(
        TeacherSubjectAssignment.teacher_id == teacher.id,
        TeacherSubjectAssignment.class_id == student.class_id,
        TeacherSubjectAssignment.section_id == student.section_id,
        TeacherSubjectAssignment.subject_id == subject_id,
        TeacherSubjectAssignment.tenant_id == tenant_id,
        TeacherSubjectAssignment.is_active == True,
        TeacherSubjectAssignment.deleted_at.is_(None)
    )
    tsa = (await db.execute(tsa_stmt)).first()
    if not tsa:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You are not assigned to this student for the requested subject."
        )

    # 2. Extract recent student marks for this subject
    marks_stmt = select(Marks).where(
        Marks.student_id == student_id,
        Marks.subject_id == subject_id,
        Marks.tenant_id == tenant_id,
        Marks.deleted_at.is_(None)
    ).options(selectinload(Marks.examination))
    marks_list = (await db.execute(marks_stmt)).scalars().all()

    marks_data = []
    for m in marks_list:
        marks_data.append({
            "exam": m.examination.name if m.examination else "Assessment",
            "score": float(m.marks_obtained) if m.marks_obtained is not None else None,
            "max": m.maximum_marks
        })

    prompt = f"""
    Generate a constructive draft report card remark for student {student.first_name}.
    Subject marks data: {marks_data}
    """

    try:
        schema = RemarkGenerationResponse.model_json_schema()
        structured = await ai_service.generate_json(
            prompt=prompt,
            response_schema=schema,
            client_key=str(current_user.id),
            system_instruction=SYSTEM_INSTRUCTION_REMARK_GENERATION
        )
        remark_response = RemarkGenerationResponse.model_validate(structured)

        # Log Audit event
        logger.info(
            "AI Audit Log: user_id=%s, tenant_id=%s, school_id=%s, operation=generate-remark, status=success, latency_ms=%d, model=%s",
            str(current_user.id), str(tenant_id), str(teacher.school_id), "success", int((time.time() - start_time) * 100), settings.AI_MODEL or "gemini"
        )
        return APIResponse(success=True, message="Draft remark generated successfully.", data=remark_response)

    except Exception as e:
        logger.error(f"AI Provider failure during remark generation: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI Service currently unavailable: {str(e)}"
        )


def normalize_homework_response(data: Dict[str, Any], fallback_difficulty: str) -> Dict[str, Any]:
    if not isinstance(data, dict):
        return data
        
    normalized = data.copy()
    
    # 1. Parent level normalization: learning_objective
    if "learning_objective" not in normalized:
        if "learning_objectives" in normalized:
            lo = normalized["learning_objectives"]
            if isinstance(lo, list) and lo:
                normalized["learning_objective"] = str(lo[0])
            else:
                normalized["learning_objective"] = str(lo)
        else:
            normalized["learning_objective"] = "Complete assignments to reinforce learning."
            
    # 2. Parent level normalization: estimated_minutes
    if "estimated_minutes" not in normalized:
        for opt in ["estimated_duration_minutes", "estimated_duration", "duration_minutes"]:
            if opt in normalized:
                normalized["estimated_minutes"] = int(normalized[opt])
                break
        else:
            normalized["estimated_minutes"] = 30
            
    # 3. Questions list normalization
    if "questions" in normalized and isinstance(normalized["questions"], list):
        questions_normalized = []
        for idx, q_obj in enumerate(normalized["questions"]):
            if not isinstance(q_obj, dict):
                continue
                
            q_copy = q_obj.copy()
            
            # Map q -> text
            if "text" not in q_copy and "q" in q_copy:
                q_copy["text"] = q_copy["q"]
            elif "text" not in q_copy:
                q_copy["text"] = f"Question {q_copy.get('question_number', idx + 1)}"
                
            # Derive difficulty
            if "difficulty" not in q_copy or not q_copy["difficulty"]:
                q_copy["difficulty"] = fallback_difficulty
                
            # Ensure question_number is present
            if "question_number" not in q_copy:
                q_copy["question_number"] = idx + 1
                
            # Ensure marks is present
            if "marks" not in q_copy:
                q_copy["marks"] = 2
                
            questions_normalized.append(q_copy)
            
        normalized["questions"] = questions_normalized
        
    return normalized


def normalize_questions_response(data: Dict[str, Any], fallback_difficulty: str) -> Dict[str, Any]:
    if not isinstance(data, dict):
        return data
        
    normalized = data.copy()
    if "questions" in normalized and isinstance(normalized["questions"], list):
        questions_normalized = []
        for idx, q_obj in enumerate(normalized["questions"]):
            if not isinstance(q_obj, dict):
                continue
            q_copy = q_obj.copy()
            
            # Map q -> text
            if "text" not in q_copy and "q" in q_copy:
                q_copy["text"] = q_copy["q"]
            elif "text" not in q_copy:
                q_copy["text"] = f"Question {q_copy.get('question_number', idx + 1)}"
                
            # Derive difficulty
            if "difficulty" not in q_copy or not q_copy["difficulty"]:
                q_copy["difficulty"] = fallback_difficulty
                
            # Ensure question_number is present
            if "question_number" not in q_copy:
                q_copy["question_number"] = idx + 1
                
            # Ensure marks is present
            if "marks" not in q_copy:
                q_copy["marks"] = 2
                
            questions_normalized.append(q_copy)
            
        normalized["questions"] = questions_normalized
        
    return normalized


@router.post(
    "/generate-homework",
    response_model=APIResponse[HomeworkGenerationResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate homework assignment draft template"
)
async def generate_homework(
    request: HomeworkGenerationRequest,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db),
    ai_service: AIService = Depends(get_ai_service)
) -> APIResponse[HomeworkGenerationResponse]:
    check_ai_enabled()
    start_time = time.time()

    teacher = await resolve_active_teacher(current_user.id, tenant_id, db)
    class_id = request.class_id
    section_id = request.section_id
    subject_id = request.subject_id

    # 1. Verify class subject assignment
    tsa_stmt = select(TeacherSubjectAssignment).where(
        TeacherSubjectAssignment.teacher_id == teacher.id,
        TeacherSubjectAssignment.class_id == class_id,
        TeacherSubjectAssignment.section_id == section_id,
        TeacherSubjectAssignment.subject_id == subject_id,
        TeacherSubjectAssignment.tenant_id == tenant_id,
        TeacherSubjectAssignment.is_active == True,
        TeacherSubjectAssignment.deleted_at.is_(None)
    ).options(selectinload(TeacherSubjectAssignment.subject), selectinload(TeacherSubjectAssignment.class_obj))
    tsa = (await db.execute(tsa_stmt)).scalar_one_or_none()
    if not tsa:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You are not assigned to this class, section, and subject combination."
        )

    # 2. Call AI service
    prompt = f"""
    Create a homework assignment draft.
    Subject: {tsa.subject.subject_name if tsa.subject else 'Subject'}
    Class: {tsa.class_obj.name if tsa.class_obj else 'Grade'}
    Topic: {request.topic}
    Difficulty: {request.difficulty}
    Number of questions: {request.number_of_questions}
    Total Marks: {request.marks}
    Question Type: {request.question_type or 'Mixed'}
    """

    try:
        schema = HomeworkGenerationResponse.model_json_schema()
        structured = await ai_service.generate_json(
            prompt=prompt,
            response_schema=schema,
            client_key=str(current_user.id),
            system_instruction=SYSTEM_INSTRUCTION_HOMEWORK_GENERATION
        )
        normalized = normalize_homework_response(structured, request.difficulty)
        homework_response = HomeworkGenerationResponse.model_validate(normalized)

        # Log Audit event
        logger.info(
            "AI Audit Log: user_id=%s, tenant_id=%s, school_id=%s, operation=generate-homework, status=success, latency_ms=%d, model=%s",
            str(current_user.id), str(tenant_id), str(teacher.school_id), "success", int((time.time() - start_time) * 100), settings.AI_MODEL or "gemini"
        )
        return APIResponse(success=True, message="Homework draft generated successfully.", data=homework_response)

    except Exception as e:
        logger.error(f"AI Provider failure during homework generation: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI Service currently unavailable: {str(e)}"
        )


@router.post(
    "/generate-questions",
    response_model=APIResponse[QuestionsGenerationResponse],
    status_code=status.HTTP_200_OK,
    summary="Generate raw homework test questions"
)
async def generate_questions(
    request: QuestionsGenerationRequest,
    current_user: User = Depends(get_current_user),
    tenant_id: uuid.UUID = Depends(get_tenant_id),
    db: AsyncSession = Depends(get_db),
    ai_service: AIService = Depends(get_ai_service)
) -> APIResponse[QuestionsGenerationResponse]:
    check_ai_enabled()
    start_time = time.time()

    teacher = await resolve_active_teacher(current_user.id, tenant_id, db)
    class_id = request.class_id
    section_id = request.section_id
    subject_id = request.subject_id

    # 1. Verify class subject assignment
    tsa_stmt = select(TeacherSubjectAssignment).where(
        TeacherSubjectAssignment.teacher_id == teacher.id,
        TeacherSubjectAssignment.class_id == class_id,
        TeacherSubjectAssignment.section_id == section_id,
        TeacherSubjectAssignment.subject_id == subject_id,
        TeacherSubjectAssignment.tenant_id == tenant_id,
        TeacherSubjectAssignment.is_active == True,
        TeacherSubjectAssignment.deleted_at.is_(None)
    ).options(selectinload(TeacherSubjectAssignment.subject), selectinload(TeacherSubjectAssignment.class_obj))
    tsa = (await db.execute(tsa_stmt)).scalar_one_or_none()
    if not tsa:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Access denied. You are not assigned to this class, section, and subject combination."
        )

    prompt = f"""
    Generate questions.
    Subject: {tsa.subject.subject_name if tsa.subject else 'Subject'}
    Class: {tsa.class_obj.name if tsa.class_obj else 'Grade'}
    Topic: {request.topic}
    Difficulty: {request.difficulty}
    Number of questions: {request.number_of_questions}
    Total Marks: {request.marks}
    Question Type: {request.question_type or 'Mixed'}
    """

    try:
        schema = QuestionsGenerationResponse.model_json_schema()
        structured = await ai_service.generate_json(
            prompt=prompt,
            response_schema=schema,
            client_key=str(current_user.id),
            system_instruction=SYSTEM_INSTRUCTION_HOMEWORK_GENERATION
        )
        normalized = normalize_questions_response(structured, request.difficulty)
        questions_response = QuestionsGenerationResponse.model_validate(normalized)

        # Log Audit
        logger.info(
            "AI Audit Log: user_id=%s, tenant_id=%s, school_id=%s, operation=generate-questions, status=success, latency_ms=%d, model=%s",
            str(current_user.id), str(tenant_id), str(teacher.school_id), "success", int((time.time() - start_time) * 100), settings.AI_MODEL or "gemini"
        )
        return APIResponse(success=True, message="Questions generated successfully.", data=questions_response)

    except Exception as e:
        logger.error(f"AI Provider failure during questions generation: {str(e)}", exc_info=True)
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail=f"AI Service currently unavailable: {str(e)}"
        )
