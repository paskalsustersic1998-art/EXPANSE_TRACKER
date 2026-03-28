from fastapi import APIRouter, Depends
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_admin
from app.models.user import User
from app.schemas.user import UserRead, UserRoleUpdate
from app.services import admin as admin_service

router = APIRouter()


@router.get("/users", response_model=list[UserRead])
def list_users(db: Session = Depends(get_db), _: User = Depends(get_current_admin)):
    return admin_service.list_users(db)


@router.patch("/users/{user_id}/role", response_model=UserRead)
def update_role(
    user_id: int,
    data: UserRoleUpdate,
    db: Session = Depends(get_db),
    _: User = Depends(get_current_admin),
):
    return admin_service.update_user_role(db, user_id, data.role)
