from sqlalchemy import create_engine, Column, Integer, String, Text, DateTime, ForeignKey, Boolean
from sqlalchemy.orm import relationship, declarative_base
from sqlalchemy.sql import func
import datetime

Base = declarative_base()

class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True, nullable=False)
    password = Column(String, nullable=False)  # В реальном приложении пароли нужно хранить в хешированном виде!
    email = Column(String, unique=True, index=True, nullable=False)
    full_name = Column(String)
    role = Column(String, nullable=False, default="citizen")  # "citizen" или "inspector"
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())

    appeals = relationship("Appeal", back_populates="user")

    def __repr__(self):
        return f"<User(id={self.id}, username='{self.username}')>"


class AppealStatus(Base):
    __tablename__ = "appeal_statuses"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)

    appeals = relationship("Appeal", back_populates="status")

    def __repr__(self):
        return f"<AppealStatus(id={self.id}, name='{self.name}')>"

class AppealCategory(Base):
    __tablename__ = "appeal_categories"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, unique=True, nullable=False)
    appeals = relationship("Appeal", back_populates="category")

    def __repr__(self):
        return f"<AppealCategory(id={self.id}, name='{self.name}')>"

class Appeal(Base):
    __tablename__ = "appeals"

    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, ForeignKey("users.id"), nullable=False)
    category_id = Column(Integer, ForeignKey("appeal_categories.id"), nullable=False)
    status_id = Column(Integer, ForeignKey("appeal_statuses.id"), nullable=False)
    address = Column(String, nullable=False)
    description = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    file_paths = Column(Text, nullable=True) # Храним пути к файлам через запятую
    file_size = Column(Integer, nullable=True) # Добавляем file_size
    file_type = Column(String, nullable=True)  # Добавляем file_type

    user = relationship("User", back_populates="appeals")
    status = relationship("AppealStatus", back_populates="appeals")
    category = relationship("AppealCategory", back_populates="appeals")


    def __repr__(self):
        return f"<Appeal(id={self.id}, user_id={self.user_id}, address='{self.address}')>"