from fastapi import HTTPException, status
from sqlalchemy.orm import Session

from app.models.user import User, UserRole


def list_users(db: Session) -> list[User]:
    return db.query(User).all()


def update_user_role(db: Session, user_id: int, role: UserRole) -> User:
    user = db.get(User, user_id)
    if user is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    user.role = role
    db.commit()
    db.refresh(user)
    return user
