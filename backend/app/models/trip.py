from datetime import datetime, timezone

from sqlalchemy import DateTime, ForeignKey, Integer, String, Table, Column
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.core.database import Base

# Association table — used directly for inserts and as secondary for the relationship
trip_participants = Table(
    "trip_participants",
    Base.metadata,
    Column("trip_id", Integer, ForeignKey("trips.id", ondelete="CASCADE"), primary_key=True),
    Column("user_id", Integer, ForeignKey("users.id", ondelete="CASCADE"), primary_key=True),
)


class Trip(Base):
    __tablename__ = "trips"

    id: Mapped[int] = mapped_column(Integer, primary_key=True, index=True)
    name: Mapped[str] = mapped_column(String, nullable=False)
    description: Mapped[str | None] = mapped_column(String, nullable=True)
    created_by: Mapped[int] = mapped_column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=False
    )
    created_at: Mapped[datetime] = mapped_column(
        DateTime(timezone=True),
        default=lambda: datetime.now(timezone.utc),
    )

    # Gives list[User] directly — matches ParticipantRead schema
    participants: Mapped[list["User"]] = relationship(  # noqa: F821
        "User", secondary=trip_participants
    )
