from datetime import datetime

from pydantic import BaseModel, EmailStr, field_validator


class TripCreate(BaseModel):
    name: str
    description: str | None = None


class TripUpdate(BaseModel):
    name: str | None = None
    description: str | None = None

    @field_validator("name")
    @classmethod
    def name_not_empty(cls, v: str | None) -> str | None:
        if v is not None and not v.strip():
            raise ValueError("name cannot be empty")
        return v


class AddParticipantRequest(BaseModel):
    email: EmailStr


class ParticipantRead(BaseModel):
    id: int
    email: str

    model_config = {"from_attributes": True}


class TripRead(BaseModel):
    id: int
    name: str
    description: str | None
    created_by: int
    created_at: datetime
    participants: list[ParticipantRead]

    model_config = {"from_attributes": True}
