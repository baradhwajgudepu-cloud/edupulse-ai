import uuid
from typing import List, Optional
from datetime import date
from sqlalchemy import select, and_
from sqlalchemy.ext.asyncio import AsyncSession

from app.models.state_holiday_master import StateHolidayMaster

VERIFIED_TELANGANA_2026_HOLIDAYS = [
    {"date": date(2026, 1, 26), "name": "Republic Day", "desc": "National Holiday"},
    {"date": date(2026, 3, 4), "name": "Maha Shivaratri", "desc": "State Public Holiday"},
    {"date": date(2026, 3, 20), "name": "Eid-ul-Fitr (Ramzan)", "desc": "State Public Holiday"},
    {"date": date(2026, 3, 21), "name": "Ugadi (Telugu New Year)", "desc": "State Public Holiday"},
    {"date": date(2026, 4, 3), "name": "Good Friday", "desc": "Public Holiday"},
    {"date": date(2026, 4, 14), "name": "Dr. B.R. Ambedkar Jayanti", "desc": "National / State Holiday"},
    {"date": date(2026, 5, 1), "name": "May Day", "desc": "Labor Day Holiday"},
    {"date": date(2026, 6, 2), "name": "Telangana Formation Day", "desc": "State Holiday"},
    {"date": date(2026, 6, 17), "name": "Bakrid (Eid-ul-Adha)", "desc": "State Public Holiday"},
    {"date": date(2026, 8, 15), "name": "Independence Day", "desc": "National Holiday"},
    {"date": date(2026, 9, 4), "name": "Sri Krishna Janmashtami", "desc": "State Public Holiday"},
    {"date": date(2026, 9, 14), "name": "Vinayaka Chavithi (Ganesh Chaturthi)", "desc": "State Public Holiday"},
    {"date": date(2026, 10, 2), "name": "Mahatma Gandhi Jayanti", "desc": "National Holiday"},
    {"date": date(2026, 10, 20), "name": "Vijaya Dasami (Dussehra)", "desc": "State Festival Holiday"},
    {"date": date(2026, 11, 8), "name": "Deepavali", "desc": "Festival of Lights Holiday"},
    {"date": date(2026, 12, 25), "name": "Christmas", "desc": "Public Holiday"},
]

class StateHolidayMasterRepository:
    def __init__(self, db: AsyncSession) -> None:
        self.db = db

    async def get_holidays(
        self, state: str, academic_year_code: str
    ) -> List[StateHolidayMaster]:
        stmt = select(StateHolidayMaster).where(
            StateHolidayMaster.state.ilike(state.strip()),
            StateHolidayMaster.academic_year_code == academic_year_code.strip(),
            StateHolidayMaster.deleted_at.is_(None)
        ).order_by(StateHolidayMaster.holiday_date.asc())
        res = await self.db.execute(stmt)
        return list(res.scalars().all())

    async def seed_verified_defaults_if_empty(self) -> int:
        stmt = select(StateHolidayMaster).limit(1)
        res = await self.db.execute(stmt)
        if res.scalar_one_or_none():
            return 0

        count = 0
        for h in VERIFIED_TELANGANA_2026_HOLIDAYS:
            m = StateHolidayMaster(
                state="TELANGANA",
                academic_year_code="2026-2027",
                holiday_date=h["date"],
                holiday_name=h["name"],
                description=h["desc"],
                source="Government of Telangana G.A. (Spl.E) Dept G.O.Rt.No. 2026/GAD",
                source_version="G.O.Rt.No. 2026/V1",
                source_date=date(2025, 11, 15),
                verification_status="VERIFIED"
            )
            self.db.add(m)
            count += 1

            # Also seed matching for ANDHRA_PRADESH with AP G.O.
            m_ap = StateHolidayMaster(
                state="ANDHRA_PRADESH",
                academic_year_code="2026-2027",
                holiday_date=h["date"],
                holiday_name=h["name"],
                description=h["desc"],
                source="Government of Andhra Pradesh G.A.D G.O.Rt.No. 2026/AP",
                source_version="G.O.Rt.No. 2026/AP-V1",
                source_date=date(2025, 11, 20),
                verification_status="VERIFIED"
            )
            self.db.add(m_ap)
            count += 1

        await self.db.flush()
        return count
