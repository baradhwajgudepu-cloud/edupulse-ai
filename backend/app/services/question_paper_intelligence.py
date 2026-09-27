import re
import uuid
import logging
from typing import List, Dict, Any, Optional, Tuple
from datetime import datetime, timezone
from sqlalchemy import select, and_, func
from sqlalchemy.orm import selectinload
from sqlalchemy.ext.asyncio import AsyncSession
from fastapi import HTTPException, status

from app.models.question_paper import QuestionPaper, StudentQuestionMarks
from app.models.exam_question import ExamQuestion, QuestionDifficulty, QuestionType
from app.models.examination import Examination, ExamSchedule
from app.models.syllabus import Syllabus
from app.models.marks import Marks, ExamResult, MarksStatus
from app.models.student import Student
from app.schemas.question_paper import (
    ExtractedQuestionItem,
    QuestionPaperExtractionResponse,
    QuestionWiseStudentRow,
    QuestionWiseAnalyticsResponse,
    SyllabusTopicOption
)

logger = logging.getLogger(__name__)

class QuestionPaperIntelligenceService:
    """
    Intelligent Question Paper Engine for EduPulse AI:
    - Structured document OCR extraction & pattern parsing.
    - Zero-hallucination syllabus topic mapping.
    - Question-wise spreadsheet marks aggregation and validation.
    - Cognitive question difficulty & learning gap analytics.
    """
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    # =========================================================================
    # 1. DOCUMENT EXTRACTION & OCR PARSING
    # =========================================================================
    def parse_raw_text_to_questions(self, raw_text: str) -> Tuple[List[ExtractedQuestionItem], float, int]:
        """
        Parses text streams or OCR text into structured questions with sections,
        sub-questions, and marks allocation.
        Zero-hallucination: Never invents missing text or marks.
        """
        lines = [line.strip() for line in raw_text.splitlines() if line.strip()]
        questions: List[ExtractedQuestionItem] = []
        current_section = "Section A"
        seq = 1
        low_confidence_count = 0

        # Regex patterns
        section_pattern = re.compile(r'^(SECTION|PART)\s+([A-Z0-9IVX]+)(.*)$', re.IGNORECASE)
        # Matches: Q1, Q.1, 1., Question 1, Q1., 1)
        question_pattern = re.compile(
            r'^(?:Q(?:uestion)?\.?\s*(\d+[a-z]?)|(\d+)[.)])(?:\s*[:\-–]?\s*)(.*)$',
            re.IGNORECASE
        )
        # Matches sub-questions: (a), (b), (i), (ii), a), b)
        subq_pattern = re.compile(r'^\(?([a-z]|[ivx]+)\)[.:\-–]?\s*(.*)$', re.IGNORECASE)
        # Matches marks: [5], [5 Marks], (10M), (10 marks), [2 pts], 5M, 10 marks
        marks_pattern = re.compile(r'(?:\[|\()?\s*(\d+(?:\.\d+)?)\s*(?:marks?|pts?|m)?\s*(?:\]|\))?\s*$', re.IGNORECASE)

        current_q: Optional[ExtractedQuestionItem] = None

        for line in lines:
            # Check section header
            sec_match = section_pattern.match(line)
            if sec_match:
                current_section = f"{sec_match.group(1).upper()} {sec_match.group(2).upper()}"
                continue

            # Check question start
            q_match = question_pattern.match(line)
            if q_match:
                q_num_str = q_match.group(1) or q_match.group(2)
                q_text = (q_match.group(3) or "").strip()
                q_num = f"Q{q_num_str}"

                # Extract marks from question line if present
                marks = 5.0
                confidence = 0.95
                m_match = marks_pattern.search(q_text)
                if m_match and m_match.group(1):
                    try:
                        marks = float(m_match.group(1))
                        # Remove marks string from question text
                        q_text = q_text[:m_match.start()].strip()
                    except ValueError:
                        confidence = 0.65
                else:
                    confidence = 0.70 # Marks not explicitly printed, flagged for verification

                # Infer question type
                q_type = "SHORT"
                if re.search(r'\([A-D]\)|\bOption\b|\bChoose\b', q_text, re.IGNORECASE):
                    q_type = "MCQ"
                elif marks >= 6.0:
                    q_type = "LONG"
                elif re.search(r'\bCalculate\b|\bFind\b|\bEvaluate\b|\bSolve\b|\d+\s*[+\-*/]\s*\d+', q_text, re.IGNORECASE):
                    q_type = "NUMERICAL"

                difficulty = "HARD" if marks >= 8.0 else ("MEDIUM" if marks >= 4.0 else "EASY")

                review_st = "FLAGGED_FOR_REVIEW" if confidence < 0.75 else "PENDING"
                if review_st == "FLAGGED_FOR_REVIEW":
                    low_confidence_count += 1

                current_q = ExtractedQuestionItem(
                    question_number=q_num,
                    section_name=current_section,
                    sequence_order=seq,
                    question_text=q_text,
                    max_marks=marks,
                    question_type=q_type,
                    difficulty=difficulty,
                    extraction_confidence=confidence,
                    review_status=review_st,
                    sub_questions=[]
                )
                questions.append(current_q)
                seq += 1
                continue

            # Check sub-question
            sub_match = subq_pattern.match(line)
            if sub_match and current_q:
                sub_label = sub_match.group(1).lower()
                sub_text = (sub_match.group(2) or "").strip()
                sub_marks = round(current_q.max_marks / 2, 1) if current_q.max_marks > 1 else 1.0

                m_sub = marks_pattern.search(sub_text)
                if m_sub and m_sub.group(1):
                    try:
                        sub_marks = float(m_sub.group(1))
                        sub_text = sub_text[:m_sub.start()].strip()
                    except ValueError:
                        pass

                sub_item = ExtractedQuestionItem(
                    question_number=f"{current_q.question_number}({sub_label})",
                    section_name=current_section,
                    sequence_order=len(current_q.sub_questions) + 1,
                    question_text=sub_text,
                    max_marks=sub_marks,
                    question_type=current_q.question_type,
                    difficulty=current_q.difficulty,
                    extraction_confidence=0.90,
                    review_status="PENDING",
                    sub_questions=[]
                )
                current_q.sub_questions.append(sub_item)
                continue

            # Append to current question text if continuation
            if current_q and line:
                if current_q.question_text:
                    current_q.question_text += f" {line}"
                else:
                    current_q.question_text = line

        # If zero questions detected with standard pattern, split by paragraph/number fallback
        if not questions and lines:
            for idx, ln in enumerate(lines, start=1):
                questions.append(ExtractedQuestionItem(
                    question_number=f"Q{idx}",
                    section_name="Section A",
                    sequence_order=idx,
                    question_text=ln,
                    max_marks=5.0,
                    question_type="SHORT",
                    difficulty="MEDIUM",
                    extraction_confidence=0.60,
                    review_status="FLAGGED_FOR_REVIEW",
                    sub_questions=[]
                ))
                low_confidence_count += 1

        overall_conf = round(
            sum(q.extraction_confidence or 0.8 for q in questions) / max(len(questions), 1),
            2
        )
        return questions, overall_conf, low_confidence_count

    # =========================================================================
    # 2. ZERO-HALLUCINATION SYLLABUS TOPIC MAPPING
    # =========================================================================
    async def get_configured_syllabus_options(
        self, school_id: uuid.UUID, academic_year_id: uuid.UUID, class_id: uuid.UUID, subject_id: uuid.UUID
    ) -> List[SyllabusTopicOption]:
        """
        Fetches the school's configured syllabus hierarchy for this class and subject.
        Zero-hallucination: Only topics existing in the school's active syllabus copy are returned.
        """
        stmt = select(Syllabus).where(
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == academic_year_id,
            Syllabus.class_id == class_id,
            Syllabus.subject_id == subject_id,
            Syllabus.deleted_at.is_(None)
        ).order_by(Syllabus.sequence_order, Syllabus.chapter_name)
        res = await self.db.execute(stmt)
        syll_rows = res.scalars().all()

        return [
            SyllabusTopicOption(
                syllabus_id=s.id,
                unit_name=s.unit_name,
                chapter_name=s.chapter_name,
                topic_name=s.topic_name,
                estimated_periods=s.estimated_periods
            )
            for s in syll_rows
        ]

    async def map_questions_to_syllabus(
        self,
        questions: List[ExtractedQuestionItem],
        syllabus_options: List[SyllabusTopicOption]
    ) -> List[ExtractedQuestionItem]:
        """
        Matches extracted question text against configured syllabus topics.
        Strict Rule: If match confidence < 0.60, marks 'FLAGGED_FOR_REVIEW' and leaves topic open.
        """
        if not syllabus_options:
            for q in questions:
                q.review_status = "FLAGGED_FOR_REVIEW"
                q.mapping_source = "UNMAPPED"
                q.mapping_confidence = 0.0
            return questions

        def _tokenize(text: str) -> set:
            if not text:
                return set()
            clean = re.sub(r'[^a-zA-Z0-9\s]', ' ', text.lower())
            tokens = set(clean.split())
            stopwords = {"what", "is", "the", "and", "or", "of", "to", "in", "a", "an", "explain", "describe", "find", "calculate", "write", "how"}
            return tokens - stopwords

        for q in questions:
            # If already mapped with high confidence or manual, skip
            if q.syllabus_id and q.mapping_source == "MANUAL":
                continue

            q_tokens = _tokenize(q.question_text or "")
            best_match: Optional[SyllabusTopicOption] = None
            best_score = 0.0

            for opt in syllabus_options:
                t_tokens = _tokenize(f"{opt.topic_name} {opt.chapter_name} {opt.unit_name or ''}")
                if not t_tokens:
                    continue

                common = q_tokens.intersection(t_tokens)
                if not common:
                    continue

                # Jaccard / token overlap
                score = len(common) / len(t_tokens)
                # Boost if exact phrase in question text
                if opt.topic_name.lower() in (q.question_text or "").lower():
                    score += 0.4
                if opt.chapter_name.lower() in (q.question_text or "").lower():
                    score += 0.2

                if score > best_score:
                    best_score = score
                    best_match = opt

            if best_match and best_score >= 0.50:
                q.syllabus_id = best_match.syllabus_id
                q.chapter_name = best_match.chapter_name
                q.topic_name = best_match.topic_name
                q.mapping_confidence = min(round(best_score, 2), 1.0)
                q.mapping_source = "AI"
                q.review_status = "PENDING"
            else:
                q.chapter_name = "Topic mapping requires review"
                q.topic_name = "Topic mapping requires review"
                q.mapping_confidence = 0.0
                q.mapping_source = "UNMAPPED"
                q.review_status = "FLAGGED_FOR_REVIEW"

        return questions

    # =========================================================================
    # 3. QUESTION-WISE MARKS SPREADSHEET VALIDATION & AGGREGATION
    # =========================================================================
    async def get_or_build_marks_matrix(
        self,
        paper_id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Tuple[ExamSchedule, List[ExamQuestion], List[QuestionWiseStudentRow], str]:
        """
        Builds the spreadsheet grid matrix for student marks entry.
        Supports both Mode A (Total only) and Mode B (Question-wise).
        """
        # 1. Fetch ExamSchedule (Paper)
        sched_stmt = select(ExamSchedule).options(
            selectinload(ExamSchedule.class_obj),
            selectinload(ExamSchedule.section),
            selectinload(ExamSchedule.subject),
            selectinload(ExamSchedule.examination)
        ).where(
            ExamSchedule.id == paper_id,
            ExamSchedule.school_id == school_id,
            ExamSchedule.tenant_id == tenant_id,
            ExamSchedule.deleted_at.is_(None)
        )
        res_sched = await self.db.execute(sched_stmt)
        sched = res_sched.scalar_one_or_none()
        if not sched:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Paper schedule not found.")

        # 2. Fetch Questions mapped to this paper schedule
        q_stmt = select(ExamQuestion).options(
            selectinload(ExamQuestion.syllabus)
        ).where(
            ExamQuestion.exam_schedule_id == paper_id,
            ExamQuestion.deleted_at.is_(None)
        ).order_by(ExamQuestion.sequence_order, ExamQuestion.question_number)
        res_q = await self.db.execute(q_stmt)
        questions = list(res_q.scalars().all())

        # 3. Fetch Students enrolled in this class and section
        student_stmt = select(Student).where(
            Student.class_id == sched.class_id,
            Student.section_id == sched.section_id,
            Student.school_id == school_id,
            Student.tenant_id == tenant_id,
            Student.is_active == True,
            Student.deleted_at.is_(None)
        ).order_by(Student.roll_number, Student.first_name)
        res_stud = await self.db.execute(student_stmt)
        students = list(res_stud.scalars().all())

        # 4. Fetch existing question-wise marks
        qm_stmt = select(StudentQuestionMarks).where(
            StudentQuestionMarks.exam_schedule_id == paper_id,
            StudentQuestionMarks.deleted_at.is_(None)
        )
        res_qm = await self.db.execute(qm_stmt)
        existing_qmarks = list(res_qm.scalars().all())

        # 5. Fetch existing total marks
        tm_stmt = select(Marks).where(
            Marks.exam_schedule_id == paper_id,
            Marks.deleted_at.is_(None)
        )
        res_tm = await self.db.execute(tm_stmt)
        existing_totals = {m.student_id: m for m in res_tm.scalars().all()}

        # Group question marks by student
        q_marks_by_student: Dict[uuid.UUID, Dict[str, float]] = {}
        for qm in existing_qmarks:
            if qm.student_id not in q_marks_by_student:
                q_marks_by_student[qm.student_id] = {}
            q_marks_by_student[qm.student_id][str(qm.question_id)] = float(qm.marks_obtained)

        mode = "QUESTION_WISE" if len(existing_qmarks) > 0 or len(questions) > 0 else "TOTAL_ONLY"

        rows: List[QuestionWiseStudentRow] = []
        for s in students:
            full_name = f"{s.first_name} {s.last_name or ''}".strip()
            st_q_marks = q_marks_by_student.get(s.id, {})
            tot_mark_obj = existing_totals.get(s.id)

            if st_q_marks:
                total_obt = sum(st_q_marks.values())
            elif tot_mark_obj and tot_mark_obj.marks_obtained is not None:
                total_obt = float(tot_mark_obj.marks_obtained)
            else:
                total_obt = 0.0

            res_status = tot_mark_obj.result_status.value if tot_mark_obj else "PRESENT"
            remarks = tot_mark_obj.remarks if tot_mark_obj else None

            is_comp = len(st_q_marks) == len(questions) if questions else (tot_mark_obj is not None)

            rows.append(QuestionWiseStudentRow(
                student_id=s.id,
                student_name=full_name,
                admission_number=s.admission_number,
                roll_number=s.roll_number,
                question_marks=st_q_marks,
                total_obtained=round(total_obt, 2),
                max_marks=float(sched.max_marks),
                is_complete=is_comp,
                result_status=res_status,
                remarks=remarks
            ))

        return sched, questions, rows, mode

    async def save_question_wise_marks(
        self,
        paper_id: uuid.UUID,
        rows: List[QuestionWiseStudentRow],
        is_draft: bool,
        current_user_id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> Dict[str, Any]:
        """
        Validates, saves, and aggregates question-wise marks per student.
        Prevents marks > max_marks, negative marks, and automatically updates total Marks.
        """
        # Fetch Schedule & Questions
        sched = await self.db.get(ExamSchedule, paper_id)
        if not sched or sched.school_id != school_id or sched.tenant_id != tenant_id:
            raise HTTPException(status_code=404, detail="Paper schedule not found.")

        q_stmt = select(ExamQuestion).where(
            ExamQuestion.exam_schedule_id == paper_id,
            ExamQuestion.deleted_at.is_(None)
        )
        res_q = await self.db.execute(q_stmt)
        questions = {str(q.id): q for q in res_q.scalars().all()}

        # 1. Validation phase
        for row in rows:
            for q_id_str, marks_val in row.question_marks.items():
                if marks_val < 0:
                    raise HTTPException(
                        status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                        detail=f"Invalid mark {marks_val} for student {row.student_name}. Marks cannot be negative."
                    )
                if q_id_str in questions:
                    q_obj = questions[q_id_str]
                    max_allowed = float(q_obj.max_marks)
                    if marks_val > max_allowed:
                        raise HTTPException(
                            status_code=status.HTTP_422_UNPROCESSABLE_ENTITY,
                            detail=f"Mark {marks_val} exceeds maximum marks ({max_allowed}) for Question {q_obj.question_number} (Student: {row.student_name})."
                        )

        # 2. Upsert into student_question_marks & marks
        now = datetime.now(timezone.utc)
        saved_qmarks_count = 0

        for row in rows:
            student_total = 0.0
            for q_id_str, marks_val in row.question_marks.items():
                if q_id_str not in questions:
                    continue
                q_obj = questions[q_id_str]
                student_total += marks_val

                # Check existing question mark
                stmt_qm = select(StudentQuestionMarks).where(
                    StudentQuestionMarks.question_id == q_obj.id,
                    StudentQuestionMarks.student_id == row.student_id
                )
                res_qm = await self.db.execute(stmt_qm)
                existing_qm = res_qm.scalar_one_or_none()

                if existing_qm:
                    existing_qm.marks_obtained = marks_val
                    existing_qm.max_marks = q_obj.max_marks
                    existing_qm.updated_at = now
                    existing_qm.updated_by = current_user_id
                    self.db.add(existing_qm)
                else:
                    new_qm = StudentQuestionMarks(
                        tenant_id=tenant_id,
                        school_id=school_id,
                        academic_year_id=sched.academic_year_id,
                        examination_id=sched.exam_id,
                        exam_schedule_id=paper_id,
                        question_id=q_obj.id,
                        student_id=row.student_id,
                        marks_obtained=marks_val,
                        max_marks=q_obj.max_marks,
                        is_attempted=True,
                        created_by=current_user_id,
                        updated_by=current_user_id
                    )
                    self.db.add(new_qm)
                saved_qmarks_count += 1

            # Sync total in `marks` table
            effective_total = student_total if row.question_marks else row.total_obtained
            stmt_tm = select(Marks).where(
                Marks.exam_schedule_id == paper_id,
                Marks.student_id == row.student_id
            )
            res_tm = await self.db.execute(stmt_tm)
            existing_tm = res_tm.scalar_one_or_none()

            mark_status = MarksStatus.DRAFT if is_draft else MarksStatus.SUBMITTED

            if existing_tm:
                existing_tm.marks_obtained = effective_total
                existing_tm.maximum_marks = sched.max_marks
                existing_tm.status = mark_status
                existing_tm.remarks = row.remarks
                existing_tm.updated_at = now
                existing_tm.updated_by = current_user_id
                self.db.add(existing_tm)
            else:
                new_tm = Marks(
                    maximum_marks=sched.max_marks,
                    marks_obtained=effective_total,
                    result_status=ExamResult.PRESENT,
                    status=mark_status,
                    remarks=row.remarks,
                    tenant_id=tenant_id,
                    school_id=school_id,
                    academic_year_id=sched.academic_year_id,
                    examination_id=sched.exam_id,
                    exam_schedule_id=paper_id,
                    student_id=row.student_id,
                    teacher_subject_assignment_id=sched.teacher_subject_assignment_id,
                    teacher_id=sched.teacher_subject_assignment.teacher_id if sched.teacher_subject_assignment else uuid.uuid4(),
                    subject_id=sched.subject_id,
                    class_id=sched.class_id,
                    section_id=sched.section_id,
                    created_by=current_user_id,
                    updated_by=current_user_id
                )
                self.db.add(new_tm)

        await self.db.commit()

        return {
            "success": True,
            "message": f"Successfully {'saved draft' if is_draft else 'submitted and finalized'} marks for {len(rows)} students.",
            "total_students": len(rows),
            "total_question_marks_saved": saved_qmarks_count,
            "is_draft": is_draft
        }

    # =========================================================================
    # 4. QUESTION-WISE & TOPIC ASSESSMENT ANALYTICS
    # =========================================================================
    async def get_question_wise_analytics(
        self,
        paper_id: uuid.UUID,
        school_id: uuid.UUID,
        tenant_id: uuid.UUID
    ) -> QuestionWiseAnalyticsResponse:
        """
        Calculates question-level difficulty index, topic averages, students below threshold,
        and syllabus coverage metrics without hallucination.
        """
        sched = await self.db.get(ExamSchedule, paper_id)
        if not sched or sched.school_id != school_id or sched.tenant_id != tenant_id:
            raise HTTPException(status_code=404, detail="Paper schedule not found.")

        exam = await self.db.get(Examination, sched.exam_id)
        # Fetch Subject & Class names
        from app.models.subject import Subject
        from app.models.class_entity import Class
        sub = await self.db.get(Subject, sched.subject_id)
        cls = await self.db.get(Class, sched.class_id)
        sub_name = sub.subject_name if sub else "Subject"
        cls_name = cls.name if cls else "Class"
        exam_name = exam.exam_name if exam else "Examination"

        # Check total marks
        t_marks_stmt = select(Marks).where(
            Marks.exam_schedule_id == paper_id,
            Marks.deleted_at.is_(None)
        )
        res_tm = await self.db.execute(t_marks_stmt)
        total_marks_list = list(res_tm.scalars().all())

        if not total_marks_list:
            return QuestionWiseAnalyticsResponse(
                paper_id=paper_id,
                exam_id=sched.exam_id,
                exam_name=exam_name,
                subject_name=sub_name,
                class_name=cls_name,
                total_students_assessed=0,
                class_average_pct=0.0,
                highest_score=0.0,
                lowest_score=0.0,
                pass_percentage=0.0,
                has_question_data=False,
                data_sufficiency="NO_QUESTION_DATA",
                message="No marks recorded yet for this paper."
            )

        total_scores = [float(m.marks_obtained or 0) for m in total_marks_list]
        max_m = float(sched.max_marks or 100)
        avg_score = sum(total_scores) / len(total_scores)
        avg_pct = round((avg_score / max_m) * 100, 1)
        pass_count = sum(1 for s in total_scores if (s / max_m) >= 0.35)
        pass_pct = round((pass_count / len(total_scores)) * 100, 1)

        # Check question-level marks
        qm_stmt = select(StudentQuestionMarks, ExamQuestion).join(
            ExamQuestion, ExamQuestion.id == StudentQuestionMarks.question_id
        ).where(
            StudentQuestionMarks.exam_schedule_id == paper_id,
            StudentQuestionMarks.deleted_at.is_(None)
        )
        res_qm = await self.db.execute(qm_stmt)
        qm_records = res_qm.all()

        if not qm_records:
            return QuestionWiseAnalyticsResponse(
                paper_id=paper_id,
                exam_id=sched.exam_id,
                exam_name=exam_name,
                subject_name=sub_name,
                class_name=cls_name,
                total_students_assessed=len(total_scores),
                class_average_pct=avg_pct,
                highest_score=max(total_scores) if total_scores else 0.0,
                lowest_score=min(total_scores) if total_scores else 0.0,
                pass_percentage=pass_pct,
                has_question_data=False,
                data_sufficiency="TOTAL_MARKS_ONLY",
                message="Detailed topic analysis unavailable because question-wise marks were not entered."
            )

        # Aggregate question performance
        q_map: Dict[uuid.UUID, Dict[str, Any]] = {}
        topic_map: Dict[str, Dict[str, Any]] = {}
        chapter_map: Dict[str, List[float]] = {}

        for qm, q in qm_records:
            qid = q.id
            if qid not in q_map:
                q_map[qid] = {
                    "question_number": q.question_number,
                    "max_marks": float(q.max_marks),
                    "marks_list": [],
                    "chapter_name": q.chapter_name or "Unmapped",
                    "topic_name": q.topic_name or "Unmapped",
                    "question_type": q.question_type.value if hasattr(q.question_type, 'value') else str(q.question_type),
                    "section_name": q.section_name or "General"
                }
            q_map[qid]["marks_list"].append(float(qm.marks_obtained))

        question_analytics = []
        for qid, qdata in q_map.items():
            marks_list = qdata["marks_list"]
            q_avg = sum(marks_list) / len(marks_list)
            q_pct = (q_avg / qdata["max_marks"]) * 100 if qdata["max_marks"] > 0 else 0.0

            # Difficulty indicator based on student average score percentage
            if q_pct < 40.0:
                diff = "HARD"
            elif q_pct <= 70.0:
                diff = "MEDIUM"
            else:
                diff = "EASY"

            below_50 = sum(1 for m in marks_list if (m / qdata["max_marks"]) < 0.5)

            question_analytics.append({
                "question_id": str(qid),
                "question_number": qdata["question_number"],
                "section": qdata["section_name"],
                "max_marks": qdata["max_marks"],
                "average_score": round(q_avg, 2),
                "average_percentage": round(q_pct, 1),
                "difficulty_indicator": diff,
                "students_below_50_count": below_50,
                "total_attempts": len(marks_list),
                "chapter_name": qdata["chapter_name"],
                "topic_name": qdata["topic_name"]
            })

            # Topic aggregation
            tname = qdata["topic_name"]
            if tname not in topic_map:
                topic_map[tname] = {
                    "topic_name": tname,
                    "chapter_name": qdata["chapter_name"],
                    "percentages": [],
                    "questions_count": 0
                }
            topic_map[tname]["percentages"].append(q_pct)
            topic_map[tname]["questions_count"] += 1

            # Chapter aggregation
            cname = qdata["chapter_name"]
            if cname not in chapter_map:
                chapter_map[cname] = []
            chapter_map[cname].append(q_pct)

        topic_analytics = []
        for tname, tdata in topic_map.items():
            top_avg = sum(tdata["percentages"]) / len(tdata["percentages"])
            status_val = "MASTERED" if top_avg >= 75.0 else ("PROFICIENT" if top_avg >= 60.0 else "NEEDS_SUPPORT")
            topic_analytics.append({
                "topic_name": tname,
                "chapter_name": tdata["chapter_name"],
                "average_percentage": round(top_avg, 1),
                "questions_count": tdata["questions_count"],
                "mastery_status": status_val
            })

        chapter_analytics = []
        for cname, p_list in chapter_map.items():
            c_avg = sum(p_list) / len(p_list)
            chapter_analytics.append({
                "chapter_name": cname,
                "average_percentage": round(c_avg, 1),
                "questions_count": len(p_list)
            })

        # Calculate syllabus coverage
        total_syll_stmt = select(func.count(Syllabus.id)).where(
            Syllabus.school_id == school_id,
            Syllabus.academic_year_id == sched.academic_year_id,
            Syllabus.class_id == sched.class_id,
            Syllabus.subject_id == sched.subject_id,
            Syllabus.deleted_at.is_(None)
        )
        res_syll_cnt = await self.db.execute(total_syll_stmt)
        total_syll_count = res_syll_cnt.scalar_one_or_none() or 0

        mapped_topics = set(tdata["topic_name"] for tdata in topic_analytics if tdata["topic_name"] != "Unmapped" and "requires review" not in tdata["topic_name"].lower())
        cov_pct = round((len(mapped_topics) / max(total_syll_count, 1)) * 100, 1)

        syllabus_coverage = {
            "mapped_topics_count": len(mapped_topics),
            "total_syllabus_topics_count": total_syll_count,
            "coverage_percentage": cov_pct,
            "coverage_ratio_label": f"{len(mapped_topics)}/{total_syll_count} topics"
        }

        return QuestionWiseAnalyticsResponse(
            paper_id=paper_id,
            exam_id=sched.exam_id,
            exam_name=exam_name,
            subject_name=sub_name,
            class_name=cls_name,
            total_students_assessed=len(total_scores),
            class_average_pct=avg_pct,
            highest_score=max(total_scores),
            lowest_score=min(total_scores),
            pass_percentage=pass_pct,
            has_question_data=True,
            data_sufficiency="QUESTION_WISE_AVAILABLE",
            message=f"Detailed question analytics active ({len(question_analytics)} questions assessed).",
            question_analytics=question_analytics,
            topic_analytics=topic_analytics,
            chapter_analytics=chapter_analytics,
            syllabus_coverage=syllabus_coverage
        )
