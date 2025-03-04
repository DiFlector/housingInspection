import os
from fastapi import FastAPI, Depends, HTTPException, status, APIRouter, Query
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker, Session
from typing import List, Optional
from fastapi.middleware.cors import CORSMiddleware

from . import models, schemas
from .auth import get_password_hash, verify_password, create_access_token, decode_token  # Импорты
from .models import Base
from jose import jwt, JWTError

from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from datetime import timedelta

from fastapi import UploadFile, File, Form
import shutil

import uuid

router = APIRouter()

DATABASE_URL = os.environ.get("DATABASE_URL")
engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

app = FastAPI()
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token") #  OAuth2, tokenUrl - относительный путь

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],  # Allow all methods (GET, POST, PUT, DELETE, etc.)
    allow_headers=["*"],  # Allow all headers
)

@app.get("/")
def read_root():
    return {"Hello": "World"}

@app.get("/test_db")
def test_db(db: Session = Depends(get_db)):
    try:
        result = db.execute(text("SELECT 1"))
        return {"status": "success", "result": result.scalar()}
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

async def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, os.environ.get("SECRET_KEY"), algorithms=[os.environ.get("ALGORITHM")]) # ИСПРАВЛЕНО
        username: str = payload.get("sub")
        role: str = payload.get("role")  #  Получаем роль
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None:
        raise credentials_exception
    if user.role != role:  #  Проверяем, совпадает ли роль в токене с ролью в БД
        raise credentials_exception

    return user

async def get_current_active_user(current_user: models.User = Depends(get_current_user)): # Используем get_current_active_user
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user

@router.post("/users/", response_model=schemas.User)
def create_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    existing_user = db.query(models.User).filter(
        (models.User.username == user.username) | (models.User.email == user.email)
    ).first()
    if existing_user:
        raise HTTPException(status_code=400, detail="Username or email already registered")

    if user.password != user.password_confirm:
        raise HTTPException(status_code=400, detail="Passwords do not match")

    hashed_password = get_password_hash(user.password)
    db_user = models.User(
        username=user.username,
        email=user.email,
        password=hashed_password,
        full_name=user.full_name,
        role = "citizen" #По умолчанию ставим роль citizen
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.get("/users/", response_model=List[schemas.User])
def read_users(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to view user list")

    users = db.query(models.User).offset(skip).limit(limit).all()
    return users

@router.get("/users/{user_id}", response_model=schemas.User)
def read_user(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    if current_user.role != "inspector" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to view this user")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")
    return db_user

@router.put("/users/{user_id}", response_model=schemas.User)
def update_user(user_id: int, user: schemas.UserUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    if current_user.role == "inspector":
        db_user = db.query(models.User).filter(models.User.id == user_id).first()
        if db_user is None:
            raise HTTPException(status_code=404, detail="User not found")

        for var, value in user.model_dump().items():
            if value is not None:
                setattr(db_user, var, value)
        db.commit()
        db.refresh(db_user)
        return db_user

    if current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to update this user")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    for var, value in user.model_dump().items():
        if value is not None:
            setattr(db_user, var, value)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/users/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to update this user")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    db.delete(db_user)
    db.commit()
    return {"message": "User deleted"}

@router.post("/appeals/", response_model=schemas.Appeal)
async def create_appeal(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user), # Исправлено
    address: str = Form(...),
    category_id: int = Form(...),
    description: Optional[str] = Form(None),
    files: List[UploadFile] = File(None)
):
    db_appeal = models.Appeal(address=address, category_id=category_id, description=description, user_id=current_user.id, status_id=1)
    db.add(db_appeal)
    db.flush()

    file_paths = []
    if files:
        for file in files:
            try:
                file_ext = os.path.splitext(file.filename)[1]
                file_name = f"{uuid.uuid4()}{file_ext}"
                file_path = os.path.join("uploads", file_name)

                with open(file_path, "wb") as buffer:
                    shutil.copyfileobj(file.file, buffer)

                file_paths.append(file_path)
            except Exception:
                raise HTTPException(status_code=500, detail="Error saving file")
            finally:
                await file.close()

    db_appeal.file_paths = ",".join(file_paths)
    db.commit()
    db.refresh(db_appeal)
    return db_appeal

@router.get("/appeals/", response_model=List[schemas.Appeal])
def read_appeals(skip: int = 0, limit: int = 100, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    if current_user.role == "citizen":
      appeals = db.query(models.Appeal).filter(models.Appeal.user_id == current_user.id).offset(skip).limit(limit).all()
    elif current_user.role == "inspector":
      appeals = db.query(models.Appeal).offset(skip).limit(limit).all()
    else:
      raise HTTPException(status_code=403, detail="Not enough permissions")
    return appeals

@router.get("/appeals/{appeal_id}", response_model=schemas.Appeal)
def read_appeal(appeal_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")
    if current_user.role == "citizen" and db_appeal.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this appeal")
    return db_appeal

@router.put("/appeals/{appeal_id}", response_model=schemas.Appeal)
async def update_appeal(
    appeal_id: int,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user), # Исправлено
    address: Optional[str] = Form(None),
    category_id: Optional[int] = Form(None),
    description: Optional[str] = Form(None),
    status_id: Optional[int] = Form(None),
    files: List[UploadFile] = File(None)
):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")

    if current_user.role == "inspector":
        pass
    elif current_user.id != db_appeal.user_id:
        raise HTTPException(status_code=403, detail="Not authorized to update this appeal")

    # --- 1. Сохраняем старый список файлов ---
    old_file_paths = db_appeal.file_paths.split(",") if db_appeal.file_paths else []
    old_file_paths = [path.strip() for path in old_file_paths if path.strip()] #Убираем пробелы и пустые

    # --- 2. Обновляем простые поля ---
    if address is not None:
        db_appeal.address = address
    if category_id is not None:
        db_appeal.category_id = category_id
    if description is not None:
        db_appeal.description = description
    if status_id is not None:
        db_appeal.status_id = status_id

    # --- 3. Обрабатываем новые файлы ---
    new_file_paths = []  #  Список для *новых* файлов
    if files:
        for file in files:
            try:
                file_ext = os.path.splitext(file.filename)[1]
                file_name = f"{uuid.uuid4()}{file_ext}"
                file_path = os.path.join("uploads", file_name)

                with open(file_path, "wb") as buffer:
                    shutil.copyfileobj(file.file, buffer)

                new_file_paths.append(file_path)
            except Exception:
                raise HTTPException(status_code=500, detail="Error saving file")
            finally:
                await file.close()

    # --- 4. Объединяем старые и новые файлы (с учётом дубликатов) ---

    # Добавляем старые файлы, *если* они есть
    if db_appeal.file_paths:
        current_file_paths = db_appeal.file_paths.split(",")
        current_file_paths = [path.strip() for path in current_file_paths if path.strip()]#Убираем пробелы
    else:
        current_file_paths = []

    # Добавляем новые файлы *без дубликатов*
    for file_path in new_file_paths:
        if file_path not in current_file_paths: #Проверяем
            current_file_paths.append(file_path)


    # --- 5. Удаляем "лишние" файлы ---
    for file_path in old_file_paths:
        if file_path not in current_file_paths:
            try:
                os.remove(file_path)
            except FileNotFoundError:
                print(f"File not found: {file_path}")
            except Exception as e:
                print(f"Error deleting file {file_path}: {e}")

    # --- 6. Сохраняем новый список файлов в БД ---
    db_appeal.file_paths = ",".join(current_file_paths)

    db.commit()
    db.refresh(db_appeal)
    return db_appeal

@router.delete("/appeals/{appeal_id}")
def delete_appeal(appeal_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")
    if current_user.role == "citizen" and db_appeal.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to delete this appeal")
    if current_user.role != "inspector" and current_user.role != "citizen":
        raise HTTPException(status_code=403, detail="Not authorized to delete this appeal")

    if db_appeal.file_paths:
        file_paths = db_appeal.file_paths.split(",")
        for file_path in file_paths:
            try:
                file_path = file_path.strip() #Убираем пробелы
                if file_path:
                    os.remove(file_path)
            except FileNotFoundError:
                print(f"File not found: {file_path}")
            except Exception as e:
                print(f"Error deleting file {file_path}: {e}")

    db.delete(db_appeal)
    db.commit()
    return {"message": "Appeal deleted"}

@router.post("/appeal_statuses/", response_model=schemas.AppealStatus)
def create_appeal_status(status: schemas.AppealStatusCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)): # Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")
    db_status = models.AppealStatus(**status.model_dump())
    db.add(db_status)
    db.commit()
    db.refresh(db_status)
    return db_status

@router.get("/appeal_statuses/", response_model=List[schemas.AppealStatus])
def read_appeal_statuses(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    statuses = db.query(models.AppealStatus).offset(skip).limit(limit).all()
    return statuses

@router.put("/appeal_statuses/{status_id}", response_model=schemas.AppealStatus)
def update_appeal_status(status_id: int, status: schemas.AppealStatusCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):# Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")
    db_status = db.query(models.AppealStatus).filter(models.AppealStatus.id == status_id).first()
    if db_status is None:
        raise HTTPException(status_code=404, detail="Status not found")
    for var, value in status.model_dump().items():
        setattr(db_status, var, value)
    db.commit()
    db.refresh(db_status)
    return db_status

@router.delete("/appeal_statuses/{status_id}")
def delete_appeal_status(status_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):# Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")
    db_status = db.query(models.AppealStatus).filter(models.AppealStatus.id == status_id).first()
    if db_status is None:
        raise HTTPException(status_code=404, detail="Status not found")

    if db.query(models.Appeal).filter(models.Appeal.status_id == status_id).first():
        raise HTTPException(status_code=400, detail="Cannot delete status: it's in use")

    db.delete(db_status)
    db.commit()
    return {"message": "Status deleted"}

@router.post("/appeal_categories/", response_model=schemas.AppealCategory)
def create_appeal_category(category: schemas.AppealCategoryCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):# Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")
    db_category = models.AppealCategory(**category.model_dump())
    db.add(db_category)
    db.commit()
    db.refresh(db_category)
    return db_category

@router.get("/appeal_categories/", response_model=List[schemas.AppealCategory])
def read_appeal_categories(skip: int = 0, limit: int = 100, db: Session = Depends(get_db)):
    categories = db.query(models.AppealCategory).offset(skip).limit(limit).all()
    return categories

@router.put("/appeal_categories/{category_id}", response_model=schemas.AppealCategory)
def update_appeal_category(category_id: int, category: schemas.AppealCategoryCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):# Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")
    db_category = db.query(models.AppealCategory).filter(models.AppealCategory.id == category_id).first()
    if db_category is None:
        raise HTTPException(status_code=404, detail="Category not found")
    for var, value in category.model_dump().items():
        setattr(db_category, var, value)
    db.commit()
    db.refresh(db_category)
    return db_category

@router.delete("/appeal_categories/{category_id}")
def delete_appeal_category(category_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):# Исправлено
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")
    db_category = db.query(models.AppealCategory).filter(models.AppealCategory.id == category_id).first()
    if db_category is None:
        raise HTTPException(status_code=404, detail="Category not found")

    if db.query(models.Appeal).filter(models.Appeal.category_id == category_id).first():
        raise HTTPException(status_code=400, detail="Cannot delete category: it's in use")

    db.delete(db_category)
    db.commit()
    return {"message": "Category deleted"}

@router.post("/token", response_model=schemas.Token)
async def login_for_access_token(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(models.User).filter(models.User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES")))
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "user_id": user.id},  #  Передаём user_id
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

app.include_router(router)

@app.on_event("startup")
async def startup_event():
    from . import models  #  Импортируем models здесь
    models.Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        if not db.query(models.AppealStatus).first():
            statuses = [
                models.AppealStatus(name="Новое"),
                models.AppealStatus(name="В работе"),
                models.AppealStatus(name="Требует уточнений"),
                models.AppealStatus(name="Отклонено"),
                models.AppealStatus(name="Одобрено"),
            ]
            db.add_all(statuses)
            db.commit()
        if not db.query(models.AppealCategory).first():
            categories = [
                models.AppealCategory(name="Объединение комнат"),
                models.AppealCategory(name="Перенос санузла"),
                models.AppealCategory(name="Перенос кухни"),
                models.AppealCategory(name="Устройство проемов в несущих стенах"),
                models.AppealCategory(name="Другое"),
            ]
            db.add_all(categories)
            db.commit()