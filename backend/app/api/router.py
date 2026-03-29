from fastapi import APIRouter

from app.api.routes import admin, auth, expenses, trips

api_router = APIRouter()

api_router.include_router(auth.router, prefix="/auth", tags=["auth"])
api_router.include_router(admin.router, prefix="/admin", tags=["admin"])
api_router.include_router(trips.router, prefix="/trips", tags=["trips"])
api_router.include_router(expenses.router, prefix="/trips", tags=["expenses"])
