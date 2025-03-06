from typing import List, Optional, Union
from pydantic import BaseModel, Field, EmailStr, validator
from datetime import datetime

class Token(BaseModel):
    access_token: str
    token_type: str

# --- Схемы для User ---
class UserBase(BaseModel):
    username: str = Field(..., example="john_doe", min_length=3, max_length=20)
    email: EmailStr = Field(..., example="john.doe@example.com")
    full_name: Optional[str] = Field(None, example="John Doe")
    role: str = Field(..., example="citizen")

class UserCreate(UserBase):
    password: str = Field(..., example="secret_password", min_length=8)
    password_confirm: str = Field(..., example="secret_password")

    @validator("password")
    def password_strength(cls, v):
        if not any(char.isdigit() for char in v):
            raise ValueError('Password must contain at least one digit')
        if not any(char.isupper() for char in v):
            raise ValueError('Password must contain at least one uppercase letter')
        return v

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class UserUpdate(UserBase):
    is_active: Optional[bool] = None
    full_name: Optional[str] = None
    role: Optional[str] = None

# Базовый класс для Appeal, содержащий общие поля
class AppealBase(BaseModel):
    address: str = Field(..., example="ул. Пушкина, д. Колотушкина")
    description: Optional[str] = Field(None, example="Описание проблемы")
    category_id: int = Field(..., example=1)
    file_size: Optional[int] = None  # Добавляем file_size
    file_type: Optional[str] = None  # Добавляем file_type
    #file_paths: Optional[str] = None  # Добавляем в AppealBase

# Схема для создания обращения (Create)
class AppealCreate(AppealBase):
    pass

# Схема для чтения обращения (Read)
class Appeal(AppealBase):
    id: int
    user_id: int
    status_id: int
    created_at: datetime
    updated_at: datetime
    file_paths: Optional[str] = None  # Добавляем в Appeal
    user: User  # Добавляем вложенную схему User
    class Config:
        from_attributes = True

class AppealUpdate(AppealBase):
  status_id: Optional[int] = None #Позволяем менять статус.
  category_id: Optional[int] = Field(None, example=1)
  address: Optional[str] = Field(None, example="ул. Пушкина, д. Колотушкина")
  description: Optional[str] = Field(None, example="Описание проблемы")
  file_paths: Optional[str] = None # Добавляем в AppealUpdate

# --- Схемы для статусов (AppealStatus) ---
class AppealStatusBase(BaseModel):
  name: str = Field(..., example="New")

class AppealStatusCreate(AppealStatusBase):
  pass

class AppealStatus(AppealStatusBase):
  id: int
  class Config:
      from_attributes = True

# --- Схемы для категорий (AppealCategory) ---
class AppealCategoryBase(BaseModel):
  name: str = Field(..., example="Room merge")

class AppealCategoryCreate(AppealCategoryBase):
  pass

class AppealCategory(AppealCategoryBase):
  id: int
  class Config:
      from_attributes = True