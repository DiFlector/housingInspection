import os
from fastapi import FastAPI, Depends, HTTPException, status, APIRouter, Query, UploadFile, File, Form
from sqlalchemy import create_engine, text, desc, asc
from sqlalchemy.orm import sessionmaker, Session
from typing import List, Optional
from fastapi.middleware.cors import CORSMiddleware
from . import models, schemas
from .auth import get_password_hash, verify_password, create_access_token, decode_token
from .models import Base
from jose import jwt, JWTError
from fastapi.security import OAuth2PasswordBearer, OAuth2PasswordRequestForm
from datetime import timedelta, datetime
import shutil
import uuid
import boto3  # Добавляем boto3
from botocore.exceptions import ClientError # Добавляем для обработки ошибок


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

# Добавляем функцию для получения клиента Yandex Cloud
def get_s3_client():
    session = boto3.session.Session()
    s3 = session.client(
        service_name='s3',
        endpoint_url=os.environ.get("YC_ENDPOINT_URL"),
        aws_access_key_id=os.environ.get("YC_AWS_ACCESS_KEY_ID"),
        aws_secret_access_key=os.environ.get("YC_AWS_SECRET_ACCESS_KEY"),
    )
    return s3

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
def read_users(
    skip: int = 0,
    limit: int = 100,
    sort_by: str = "username",
    sort_order: str = "asc",
    is_active: bool = True,  # Добавляем параметр is_active, по умолчанию True
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to view user list")

    query = db.query(models.User)

    #  ФИЛЬТРАЦИЯ по активности
    if is_active is not None:  #  Добавляем фильтрацию
        query = query.filter(models.User.is_active == is_active)

    #  СОРТИРОВКА (оставляем как есть)
    if sort_by == "email":
        if sort_order == "asc":
            query = query.order_by(asc(models.User.email))
        else:
            query = query.order_by(desc(models.User.email))
    elif sort_by == "role":
        if sort_order == "asc":
            query = query.order_by(asc(models.User.role))
        else:
            query = query.order_by(desc(models.User.role))
    elif sort_by == "created_at":  #  Добавим сортировку по дате создания
        if sort_order == "asc":
            query = query.order_by(asc(models.User.created_at))
        else:
            query = query.order_by(desc(models.User.created_at))

    # ... (default)
    else:  # Если sort_by не одно из перечисленных, сортируем по имени
        if sort_order == "asc":
            query = query.order_by(asc(models.User.username))
        else:
            query = query.order_by(desc(models.User.username))

    users = query.offset(skip).limit(limit).all()
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
def update_user(user_id: int, user: schemas.UserUpdate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    if current_user.role != "inspector" and current_user.id != user_id:
        raise HTTPException(status_code=403, detail="Not authorized to update this user")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    #  ПРОВЕРКА УНИКАЛЬНОСТИ USERNAME и EMAIL
    if user.username != db_user.username:  #  Если username изменился
        existing_user = db.query(models.User).filter(models.User.username == user.username).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Пользователь с таким именем уже существует")

    if user.email != db_user.email:  #  Если email изменился
        existing_user = db.query(models.User).filter(models.User.email == user.email).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Пользователь с таким email уже существует")


    for var, value in user.model_dump(exclude_unset=False).items():
        setattr(db_user, var, value)
    db.commit()
    db.refresh(db_user)
    return db_user

@router.delete("/users/{user_id}")
def delete_user(user_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    #  Проверяем права доступа (только инспектор может удалять)
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to delete users")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    #  Проверяем, можно ли удалить пользователя
    if db_user.role != "citizen": #Если не гражданин
        db_user.role = "citizen"  #  Меняем роль на "citizen"

    # Проверяем, есть ли у пользователя НЕЗАВЕРШЕННЫЕ обращения.
    active_appeals_exist = db.query(models.Appeal).join(models.AppealStatus).filter(
        models.Appeal.user_id == user_id,
        models.AppealStatus.name.notin_(["Выполнено", "Отклонено"]) #  НЕ "Выполнено" И НЕ "Отклонено"
    ).first() is not None

    if active_appeals_exist:
        raise HTTPException(status_code=400, detail="Cannot delete user: User has active appeals")

    #  "Мягкое" удаление:  устанавливаем is_active = False
    db_user.is_active = False  #  НЕ удаляем пользователя, а деактивируем
    db.commit()

    return {"message": "User deactivated"}  #  Сообщение об успешной деактивации

@router.post("/appeals/", response_model=schemas.Appeal)
async def create_appeal(
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
    address: str = Form(...),
    category_id: int = Form(...),
    description: Optional[str] = Form(None),
    files: List[UploadFile] = File(None)
):
    db_appeal = models.Appeal(
        address=address,
        category_id=category_id,
        description=description,
        user_id=current_user.id,
        status_id=1
    )
    db.add(db_appeal)
    db.flush()  # Получаем ID нового обращения

    s3_client = get_s3_client()  # Получаем клиент S3
    bucket_name = os.environ.get("YC_BUCKET_NAME")
    file_paths = []

    if files:
        for file in files:
            try:
                file_ext = os.path.splitext(file.filename)[1]
                file_name = f"{uuid.uuid4()}{file_ext}"  # Уникальное имя файла

                # Загружаем файл в Yandex Cloud
                s3_client.upload_fileobj(
                    Fileobj=file.file,
                    Bucket=bucket_name,
                    Key=file_name,  # Используем уникальное имя
                    ExtraArgs={
                        'ACL': 'public-read',  # Делаем файл публично доступным (для скачивания)
                    }
                )

                # Формируем URL файла
                file_url = f"{os.environ.get('YC_ENDPOINT_URL')}/{bucket_name}/{file_name}"
                file_paths.append(file_url)

                # Получаем размер и тип файла
                file.file.seek(0, os.SEEK_END)  # Переходим в конец файла
                file_size = file.file.tell()  # Получаем размер в байтах
                file.file.seek(0)  # Возвращаемся в начало файла
                file_type = file.content_type


            except ClientError as e:
                print(f"Error uploading file to Yandex Cloud: {e}")
                raise HTTPException(status_code=500, detail=f"Error uploading file to Yandex Cloud: {e}")
            finally:
                await file.close()

    db_appeal.file_paths = ",".join(file_paths)
    db_appeal.file_size = file_size      # Сохраняем размер
    db_appeal.file_type = file_type      # Сохраняем тип
    db.commit()
    db.refresh(db_appeal)
    return db_appeal

@router.get("/appeals/", response_model=List[schemas.Appeal])
def read_appeals(
    skip: int = 0,
    limit: int = 100,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    status_id: Optional[int] = None,  # Оставляем фильтр по status_id
    category_id: Optional[int] = None,  # Оставляем фильтр по category_id
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    if current_user.role == "citizen":
        query = db.query(models.Appeal).filter(models.Appeal.user_id == current_user.id)
    elif current_user.role == "inspector":
        query = db.query(models.Appeal)
    else:
        raise HTTPException(status_code=403, detail="Not enough permissions")

    # ФИЛЬТРАЦИЯ (оставляем только по status_id и category_id)
    if status_id is not None:
        query = query.filter(models.Appeal.status_id == status_id)
    if category_id is not None:
        query = query.filter(models.Appeal.category_id == category_id)

    # СОРТИРОВКА
    if sort_by == "address":
        if sort_order == "asc":
            query = query.order_by(asc(models.Appeal.address))
        else:
            query = query.order_by(desc(models.Appeal.address))
    elif sort_by == "status_id":
        if sort_order == "asc":
            query = query.order_by(asc(models.Appeal.status_id))
        else:
            query = query.order_by(desc(models.Appeal.status_id))
    elif sort_by == "category_id":
        if sort_order == "asc":
            query = query.order_by(asc(models.Appeal.category_id))
        else:
            query = query.order_by(desc(models.Appeal.category_id))
    else:
        if sort_order == "asc":
            query = query.order_by(asc(models.Appeal.created_at))
        else:
            query = query.order_by(desc(models.Appeal.created_at))

    appeals = query.offset(skip).limit(limit).all()
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
    current_user: models.User = Depends(get_current_active_user),
    address: Optional[str] = Form(None),
    category_id: Optional[int] = Form(None),
    description: Optional[str] = Form(None),
    status_id: Optional[int] = Form(None),
    files: List[UploadFile] = File(None)
):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")

    if current_user.role != "inspector":  #  Редактировать может только инспектор
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
    s3_client = get_s3_client()  # Клиент S3
    bucket_name = os.environ.get("YC_BUCKET_NAME")
    new_file_paths = []

    if files:
        for file in files:
            try:
                file_ext = os.path.splitext(file.filename)[1]
                file_name = f"{uuid.uuid4()}{file_ext}"

                # Загружаем в Yandex Cloud
                s3_client.upload_fileobj(
                    Fileobj=file.file,
                    Bucket=bucket_name,
                    Key=file_name,
                    ExtraArgs={
                        'ACL': 'public-read',  # Публичный доступ
                    }
                )
                file_url = f"{os.environ.get('YC_ENDPOINT_URL')}/{bucket_name}/{file_name}"
                new_file_paths.append(file_url)

                 # Получаем размер и тип файла
                file.file.seek(0, os.SEEK_END)
                file_size = file.file.tell()
                file.file.seek(0)
                file_type = file.content_type


            except ClientError as e:
                print(f"Error uploading file to Yandex Cloud: {e}")
                raise HTTPException(status_code=500, detail=f"Error uploading file to Yandex Cloud: {e}")
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


    # --- 5. Удаляем "лишние" файлы из Yandex Cloud ---
    for file_path in old_file_paths:
        if file_path not in current_file_paths:
            try:
                #  Извлекаем key из URL
                file_name = file_path.split('/')[-1]
                s3_client.delete_object(Bucket=bucket_name, Key=file_name)
            except ClientError as e:
                print(f"Error deleting file from Yandex Cloud: {e}")
                #  Не выбрасываем исключение, продолжаем удалять другие файлы


    # --- 6. Сохраняем новый список файлов в БД ---
    db_appeal.file_paths = ",".join(current_file_paths)
    db_appeal.file_size = file_size  # Обновляем размер
    db_appeal.file_type = file_type  # Обновляем тип
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

    s3_client = get_s3_client()  # Клиент S3
    bucket_name = os.environ.get("YC_BUCKET_NAME")

    if db_appeal.file_paths:
        file_paths = db_appeal.file_paths.split(",")
        for file_path in file_paths:
            try:
                file_path = file_path.strip() #Убираем пробелы
                if file_path:
                    #  Извлекаем key из URL
                    file_name = file_path.split('/')[-1]
                    s3_client.delete_object(Bucket=bucket_name, Key=file_name)

            except ClientError as e:
                print(f"Error deleting file from Yandex Cloud: {e}")
                #  Не выбрасываем исключение, продолжаем удалять другие файлы


    db.delete(db_appeal)
    db.commit()
    return {"message": "Appeal deleted"}

@router.post("/appeal_statuses/", response_model=schemas.AppealStatus)
def create_appeal_status(status: schemas.AppealStatusCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")

     #  ПРОВЕРЯЕМ, ЕСТЬ ЛИ УЖЕ СТАТУС С ТАКИМ ИМЕНЕМ
    existing_status = db.query(models.AppealStatus).filter(models.AppealStatus.name == status.name).first()
    if existing_status:
        raise HTTPException(status_code=400, detail="Статус с таким названием уже существует")

    for var, value in status.model_dump(exclude_unset=False).items():
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
def create_appeal_category(category: schemas.AppealCategoryCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")

    #  ПРОВЕРЯЕМ, ЕСТЬ ЛИ УЖЕ КАТЕГОРИЯ С ТАКИМ ИМЕНЕМ
    existing_category = db.query(models.AppealCategory).filter(models.AppealCategory.name == category.name).first()
    if existing_category:
        raise HTTPException(status_code=400, detail="Категория с таким названием уже существует")  #  ИНФОРМАТИВНОЕ СООБЩЕНИЕ

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
def update_appeal_category(category_id: int, category: schemas.AppealCategoryCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")

    db_category = db.query(models.AppealCategory).filter(models.AppealCategory.id == category_id).first()
    if db_category is None:
        raise HTTPException(status_code=404, detail="Category not found")

    #  ПРОВЕРКА УНИКАЛЬНОСТИ ИМЕНИ
    if db_category.name != category.name:  #  Если имя изменилось
        existing_category = db.query(models.AppealCategory).filter(models.AppealCategory.name == category.name).first()
        if existing_category:
            raise HTTPException(status_code=400, detail="Категория с таким названием уже существует")

    for var, value in category.model_dump(exclude_unset=False).items():
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

    #  ДОБАВЛЯЕМ ПРОВЕРКУ АКТИВНОСТИ ПОЛЬЗОВАТЕЛЯ:
    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,  #  Или другой код, например, 403 Forbidden
            detail="User is inactive",
            headers={"WWW-Authenticate": "Bearer"},  #  Можно не добавлять, но лучше оставить
        )

    access_token_expires = timedelta(minutes=int(os.environ.get("ACCESS_TOKEN_EXPIRE_MINUTES")))
    access_token = create_access_token(
        data={"sub": user.username, "role": user.role, "user_id": user.id},
        expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

app.include_router(router)

@app.on_event("startup")
async def startup_event():
    Base.metadata.create_all(bind=engine)
    with SessionLocal() as db:
        if not db.query(models.AppealStatus).first():
            statuses = [
                models.AppealStatus(name="Новое"),
                models.AppealStatus(name="В работе"),
                models.AppealStatus(name="Требует уточнений"),
                models.AppealStatus(name="Отклонено"),
                models.AppealStatus(name="Выполнено"),
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