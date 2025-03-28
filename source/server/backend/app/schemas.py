from typing import List, Optional, Union
from pydantic import BaseModel, Field, EmailStr, validator
from datetime import datetime

class Token(BaseModel):
    access_token: str
    token_type: str

class UserBase(BaseModel):
    username: str = Field(..., example="john_doe", min_length=3, max_length=20)
    email: EmailStr = Field(..., example="john.doe@example.com")
    full_name: Optional[str] = Field(None, example="John Doe", max_length=100)
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

    @validator("password_confirm")
    def passwords_match(cls, v, values, **kwargs):
        if 'password' in values and v != values['password']:
            raise ValueError('Passwords do not match')
        return v

class User(UserBase):
    id: int
    is_active: bool
    created_at: datetime

    class Config:
        from_attributes = True

class UserUpdate(UserBase):
    username: str = Field(..., example="john_doe", min_length=3, max_length=20)
    email: EmailStr = Field(..., example="john.doe@example.com")
    full_name: Optional[str] = Field(None, example="John Doe", max_length=100)
    role: Optional[str] = None
    is_active: Optional[bool] = None


class AppealBase(BaseModel):
    address: str = Field(..., example="ул. Пушкина, д. Колотушкина", min_length=5, max_length=255)
    description: Optional[str] = Field(None, example="Описание проблемы", max_length=1000)
    category_id: int = Field(..., example=1)
    file_size: Optional[int] = None
    file_type: Optional[str] = None

class AppealCreate(AppealBase):
    pass

class Appeal(AppealBase):
    id: int
    user_id: int
    status_id: int
    created_at: datetime
    updated_at: datetime
    file_paths: Optional[List[str]] = None
    user: User
    class Config:
        from_attributes = True

class AppealUpdate(AppealBase):
  status_id: Optional[int] = None
  category_id: Optional[int] = Field(None, example=1)
  address: Optional[str] = Field(None, example="ул. Пушкина, д. Колотушкина", min_length=5, max_length=255)
  description: Optional[str] = Field(None, example="Описание проблемы", max_length=1000)

class AppealStatusBase(BaseModel):
  name: str = Field(..., example="New", max_length=50)

class AppealStatusCreate(AppealStatusBase):
  pass

class AppealStatus(AppealStatusBase):
  id: int
  class Config:
      from_attributes = True

class AppealCategoryBase(BaseModel):
  name: str = Field(..., example="Room merge", max_length=50)

class AppealCategoryCreate(AppealCategoryBase):
  pass

class AppealCategory(AppealCategoryBase):
  id: int
  class Config:
      from_attributes = True

class MessageBase(BaseModel):
    content: str = Field(..., example="Текст сообщения", min_length=1)
    file_size: Optional[int] = None
    file_type: Optional[str] = None

class MessageCreate(MessageBase):
    pass

class Message(MessageBase):
    id: int
    appeal_id: int
    sender_id: int
    created_at: datetime
    file_paths: Optional[List[str]] = None
    sender: User

    class Config:
        from_attributes = True

class DeviceTokenCreate(BaseModel):
    fcm_token: str
    device_type: Optional[str] = None