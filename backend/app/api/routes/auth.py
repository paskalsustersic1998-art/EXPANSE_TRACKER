from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.core.database import get_db
from app.core.deps import get_current_user
from app.core.security import create_access_token, create_refresh_token, decode_refresh_token
from app.models.user import User
from app.schemas.user import RefreshRequest, Token, UserCreate, UserRead
from app.services.auth import authenticate_user, register_user

router = APIRouter()


@router.post("/register", response_model=UserRead, status_code=201)
def register(data: UserCreate, db: Session = Depends(get_db)):
    return register_user(db, data)


@router.post("/login", response_model=Token)
def login(data: UserCreate, db: Session = Depends(get_db)):
    user = authenticate_user(db, data.email, data.password)
    return Token(
        access_token=create_access_token(subject=str(user.id)),
        refresh_token=create_refresh_token(subject=str(user.id)),
    )


@router.post("/refresh", response_model=Token)
def refresh(data: RefreshRequest, db: Session = Depends(get_db)):
    user_id = decode_refresh_token(data.refresh_token)
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired refresh token",
        )
    user = db.get(User, int(user_id))
    if user is None or not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found or inactive",
        )
    return Token(
        access_token=create_access_token(str(user.id)),
        refresh_token=create_refresh_token(str(user.id)),
    )


@router.get("/me", response_model=UserRead)
def me(current_user: User = Depends(get_current_user)):
    return current_user
