import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parent.parent))

from app.db.base import Base
# Import all models to ensure they are registered with Base.metadata
import app.models

print("=== ALL REGISTERED SQLALCHEMY TABLES ===")
tables = Base.metadata.tables
for name, table in sorted(tables.items()):
    cols = [c.name for c in table.columns]
    has_tenant = "tenant_id" in cols
    has_school = "school_id" in cols
    fk_list = []
    for fk in table.foreign_keys:
        fk_list.append(f"{fk.parent.name}->{fk.target_fullname}(cascade={fk.ondelete})")
    print(f"Table: {name:<30} | tenant_id: {str(has_tenant):<5} | school_id: {str(has_school):<5} | FKs: {', '.join(fk_list)}")
