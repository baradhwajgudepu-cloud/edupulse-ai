from typing import List, Dict, Any

class AIPrompts:
    """
    Central repository for all AI prompts and system instructions used in EduPulse AI.
    Separates prompt engineering from core academic business logic.
    """
    
    # 1. Report Card AI narrative prompts
    REPORT_CARD_SYSTEM_INSTRUCTION = (
        "You are an experienced, encouraging, and analytical academic advisor. "
        "Your task is to analyze the student's performance data and generate a structured "
        "and supportive narrative report summary. Highlight strengths, offer actionable tips for "
        "improvement in weaker subjects, and comment on attendance patterns."
    )
    
    @staticmethod
    def format_report_card_prompt(
        student_name: str,
        subject_marks: List[Dict[str, Any]],
        attendance_percentage: float,
        overall_percentage: float,
        overall_grade: str,
        promotion_status: str
    ) -> str:
        subjects_formatted = "\n".join([
            f"- {m['subject_name']}: {m['marks_obtained']}/{m['maximum_marks']} (Result: {m['result_status']}, Grade: {m['grade']})"
            for m in subject_marks
        ])
        return (
            f"Please write a report card academic narrative summary for the following student:\n\n"
            f"Student Name: {student_name}\n"
            f"Attendance Percentage: {attendance_percentage}%\n"
            f"Overall Academic Percentage: {overall_percentage}%\n"
            f"Overall Grade: {overall_grade}\n"
            f"Promotion Decision: {promotion_status}\n\n"
            f"Subject Scores:\n{subjects_formatted}\n\n"
            f"Requirements:\n"
            f"1. Keep it under 150 words.\n"
            f"2. Write in a constructive and parent-friendly tone.\n"
            f"3. Make specific references to subjects where they scored well or need support."
        )

    # 2. Student performance drop-out risk flags
    RISK_ANALYSIS_SYSTEM_INSTRUCTION = (
        "You are an AI child psychologist and educational retention specialist. "
        "Assess the student's risk metrics and output a structured JSON analysis detailing "
        "the dropout risk level (LOW, MEDIUM, HIGH), core risk reasons, and recommended interventions."
    )
    
    @staticmethod
    def format_risk_analysis_prompt(
        student_name: str,
        failed_subjects_count: int,
        attendance_percentage: float,
        late_frequency: int,
        absence_streak: int
    ) -> str:
        return (
            f"Assess the academic and attendance metrics for this student:\n\n"
            f"Student: {student_name}\n"
            f"Failed Subjects Count: {failed_subjects_count}\n"
            f"Attendance: {attendance_percentage}%\n"
            f"Late Arrivals Count: {late_frequency}\n"
            f"Absence Streak (consecutive days absent): {absence_streak} days\n\n"
            f"Instructions:\n"
            f"Quantify the student's risk profile and suggest 2 key intervention steps."
        )
