import io
import pytest
import openpyxl
import uuid
from fastapi import status
from odf.opendocument import OpenDocumentSpreadsheet
from odf.table import Table, TableRow, TableCell
from odf.text import P

from app.utils.spreadsheet_reader import detect_file_type, normalize_header, read_spreadsheet
from app.models.import_job import ImportType
from tests.test_auth_student_migration import setup_student_migration_data

def create_xlsx_buffer(rows, sheet_name="Sheet1", sheets_list=None):
    wb = openpyxl.Workbook()
    # Remove default sheet
    default_sheet = wb.active
    wb.remove(default_sheet)
    
    sheets_to_create = sheets_list if sheets_list else [(sheet_name, rows)]
    for s_name, s_rows in sheets_to_create:
        ws = wb.create_sheet(title=s_name)
        for r in s_rows:
            ws.append(r)
    
    buf = io.BytesIO()
    wb.save(buf)
    return buf.getvalue()

def create_ods_buffer(rows, sheet_name="Sheet1"):
    doc = OpenDocumentSpreadsheet()
    table = Table(name=sheet_name)
    doc.spreadsheet.addElement(table)
    
    for r in rows:
        tr = TableRow()
        table.addElement(tr)
        for val in r:
            tc = TableCell()
            tr.addElement(tc)
            p = P(text=str(val))
            tc.addElement(p)
            
    buf = io.BytesIO()
    doc.save(buf)
    return buf.getvalue()

def test_header_normalization():
    assert normalize_header("Teacher ID") == "teacher_id"
    assert normalize_header("teacher_id") == "teacher_id"
    assert normalize_header("Teacher_ID") == "teacher_id"
    assert normalize_header("TEACHER ID") == "teacher_id"
    assert normalize_header("Teacher-ID") == "teacher_id"
    assert normalize_header(" teacher id ") == "teacher_id"
    assert normalize_header("") == ""

def test_detect_file_type():
    csv_bytes = b"first_name,last_name,admission_number\nJohn,Doe,ADM001"
    assert detect_file_type(csv_bytes, "test.csv") == "csv"
    
    xlsx_bytes = create_xlsx_buffer([["a", "b"], ["1", "2"]])
    assert detect_file_type(xlsx_bytes, "test.xlsx") == "xlsx"
    assert detect_file_type(xlsx_bytes, "test.xlsm") == "xlsx"
    
    ods_bytes = create_ods_buffer([["a", "b"], ["1", "2"]])
    assert detect_file_type(ods_bytes, "test.ods") == "ods"
    
    # Check invalid bytes raising error
    with pytest.raises(ValueError):
        detect_file_type(b"\x00\x01\x02\x03", "corrupted.dat")

def test_read_spreadsheet_csv():
    csv_bytes = b"first_name,last_name,admission_number\nJohn,Doe,ADM001"
    sheets, selected, rows = read_spreadsheet(csv_bytes, "students.csv")
    assert sheets == ["CSV"]
    assert selected == "CSV"
    assert len(rows) == 2
    assert rows[0] == ["first_name", "last_name", "admission_number"]
    assert rows[1] == ["John", "Doe", "ADM001"]

def test_read_spreadsheet_xlsx():
    xlsx_rows = [
        ["first_name", "last_name", "admission_number"],
        ["John", "Doe", 12345.0], # Float representation check
        ["Jane", "Smith", "ADM002"]
    ]
    xlsx_bytes = create_xlsx_buffer(xlsx_rows)
    sheets, selected, rows = read_spreadsheet(xlsx_bytes, "students.xlsx")
    assert sheets == ["Sheet1"]
    assert selected == "Sheet1"
    assert len(rows) == 3
    assert rows[1] == ["John", "Doe", "12345"] # float is formatted to string cleanly

def test_read_spreadsheet_xlsx_multi_sheet():
    sheets_list = [
        ("Students", [["first_name", "last_name"], ["John", "Doe"]]),
        ("Guardians", [["g_first_name", "g_last_name"], ["Ramesh", "Kumar"]])
    ]
    xlsx_bytes = create_xlsx_buffer(None, sheets_list=sheets_list)
    
    # Default selection
    sheets, selected, rows = read_spreadsheet(xlsx_bytes, "migration.xlsx")
    assert sheets == ["Students", "Guardians"]
    assert selected == "Students"
    assert rows[1] == ["John", "Doe"]
    
    # Explicit sheet selection
    sheets, selected, rows = read_spreadsheet(xlsx_bytes, "migration.xlsx", sheet_name="Guardians")
    assert selected == "Guardians"
    assert rows[1] == ["Ramesh", "Kumar"]

def test_read_spreadsheet_ods():
    ods_rows = [
        ["first_name", "last_name", "admission_number"],
        ["Aarav", "Sharma", "ADM801"]
    ]
    ods_bytes = create_ods_buffer(ods_rows)
    sheets, selected, rows = read_spreadsheet(ods_bytes, "students.ods")
    assert sheets == ["Sheet1"]
    assert selected == "Sheet1"
    assert len(rows) == 2
    assert rows[0] == ["first_name", "last_name", "admission_number"]
    assert rows[1] == ["Aarav", "Sharma", "ADM801"]

@pytest.mark.anyio
async def test_api_parse_spreadsheet_file(client, db_session, setup_student_migration_data):
    data = setup_student_migration_data
    p_headers = data["p_headers"]

    xlsx_rows = [
        ["First Name", "Last Name", "Admission Number"],
        ["Aarav", "Sharma", "ADM999"]
    ]
    file_bytes = create_xlsx_buffer(xlsx_rows)
    files = {"file": ("students.xlsx", file_bytes, "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")}

    res = await client.post(
        "/api/v1/import-jobs/parse",
        files=files,
        headers=p_headers
    )
    assert res.status_code == status.HTTP_200_OK
    res_data = res.json()
    assert res_data["success"] is True
    assert res_data["data"]["row_count"] == 2
    assert res_data["data"]["columns"] == ["first_name", "last_name", "admission_number"]
    assert res_data["data"]["preview_rows"][1] == ["Aarav", "Sharma", "ADM999"]

