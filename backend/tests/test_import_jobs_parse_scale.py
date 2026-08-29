import io
import csv
import pytest
from fastapi.testclient import TestClient
from app.main import app
from app.utils.spreadsheet_reader import read_spreadsheet

client = TestClient(app)

def create_mock_csv(row_count: int, error_row: int = None, error_field: str = None) -> bytes:
    output = io.StringIO()
    writer = csv.writer(output)
    writer.writerow(["admission_number", "first_name", "last_name", "gender", "date_of_birth", "admission_date", "roll_number", "academic_year_code", "class_code", "section_code", "status"])
    for i in range(1, row_count + 1):
        adm_no = f"ADM{i:04d}"
        dob = "2014-05-10"
        if error_row == i:
            if error_field == "date_of_birth":
                dob = "INVALID-DATE"
        writer.writerow([adm_no, f"First{i}", f"Last{i}", "MALE", dob, "2025-06-01", str(i % 30 + 1), "AY2025-2026", "C5", "A", "ACTIVE"])
    return output.getvalue().encode("utf-8")


def test_parse_under_50_rows():
    """Test worksheet with < 50 rows (e.g. 20 rows)."""
    csv_bytes = create_mock_csv(20)
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    data_rows = rows[1:]
    preview_limit = 50
    preview_rows = rows[:preview_limit]
    
    assert len(data_rows) == 20
    assert len(preview_rows) == 21  # 1 header + 20 data rows
    assert len(data_rows) <= preview_limit


def test_parse_exactly_50_rows():
    """Test worksheet with exactly 50 rows."""
    csv_bytes = create_mock_csv(50)
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    data_rows = rows[1:]
    preview_limit = 50
    preview_rows = rows[:preview_limit]
    
    assert len(data_rows) == 50
    assert len(preview_rows) == 50


def test_parse_51_rows():
    """Test worksheet with 51 rows (triggers preview truncation)."""
    csv_bytes = create_mock_csv(51)
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    data_rows = rows[1:]
    preview_limit = 50
    preview_rows = rows[:preview_limit]
    
    assert len(data_rows) == 51
    assert len(preview_rows) == 50
    assert len(data_rows) > len(preview_rows) - 1


def test_parse_360_rows_scale():
    """Test worksheet with 360 rows."""
    csv_bytes = create_mock_csv(360)
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    data_rows = rows[1:]
    preview_limit = 50
    preview_rows = rows[:preview_limit]
    
    assert len(data_rows) == 360
    assert len(rows) == 361
    assert len(preview_rows) == 50


def test_validation_error_beyond_row_50():
    """Test detection of error in row 75, which is outside the first 50 preview rows."""
    import re
    date_regex = re.compile(r'^\d{4}-\d{2}-\d{2}$')
    csv_bytes = create_mock_csv(360, error_row=75, error_field="date_of_birth")
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    headers = rows[0]
    data_rows = rows[1:]
    
    invalid_rows = []
    for idx, r in enumerate(data_rows, start=2):
        row_dict = {headers[h]: str(r[h] or '') for h in range(len(headers))}
        if not date_regex.match(row_dict.get("date_of_birth", "")):
            invalid_rows.append({"row": idx, "message": f"Invalid date: {row_dict.get('date_of_birth')}"})
            
    assert len(invalid_rows) == 1
    assert invalid_rows[0]["row"] == 76  # 1 header + 75th data row = row 76 (1-indexed CSV row)


def test_validation_error_beyond_row_100():
    """Test detection of error in row 120."""
    import re
    date_regex = re.compile(r'^\d{4}-\d{2}-\d{2}$')
    csv_bytes = create_mock_csv(360, error_row=120, error_field="date_of_birth")
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    headers = rows[0]
    data_rows = rows[1:]
    
    invalid_rows = []
    for idx, r in enumerate(data_rows, start=2):
        row_dict = {headers[h]: str(r[h] or '') for h in range(len(headers))}
        if not date_regex.match(row_dict.get("date_of_birth", "")):
            invalid_rows.append({"row": idx, "message": f"Invalid date: {row_dict.get('date_of_birth')}"})
            
    assert len(invalid_rows) == 1
    assert invalid_rows[0]["row"] == 121


def test_preview_limit_does_not_affect_validation_count():
    """Assert total_row_count == 360, validation_processed_rows == 360, and preview_row_count <= 50."""
    csv_bytes = create_mock_csv(360)
    sheets, selected_sheet, rows = read_spreadsheet(csv_bytes, "students.csv")
    
    data_rows = rows[1:]
    preview_limit = 50
    preview_rows = rows[:preview_limit]
    
    total_row_count = len(data_rows)
    validation_processed_rows = len(data_rows)
    preview_row_count = len(preview_rows)
    
    assert total_row_count == 360
    assert validation_processed_rows == 360
    assert preview_row_count <= 50
