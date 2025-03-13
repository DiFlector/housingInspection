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
import boto3
from botocore.exceptions import ClientError
from io import BytesIO
import re
import json


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
oauth2_scheme = OAuth2PasswordBearer(tokenUrl="token")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
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
    
def sanitize_filename(filename):
    return re.sub(r'[\\/*?:"<>|]', "", filename).replace(" ", "_")

async def get_current_user(db: Session = Depends(get_db), token: str = Depends(oauth2_scheme)):
    credentials_exception = HTTPException(
        status_code=status.HTTP_401_UNAUTHORIZED,
        detail="Could not validate credentials",
        headers={"WWW-Authenticate": "Bearer"},
    )
    try:
        payload = jwt.decode(token, os.environ.get("SECRET_KEY"), algorithms=[os.environ.get("ALGORITHM")])
        username: str = payload.get("sub")
        role: str = payload.get("role")
        if username is None:
            raise credentials_exception
    except JWTError:
        raise credentials_exception
    user = db.query(models.User).filter(models.User.username == username).first()
    if user is None:
        raise credentials_exception
    if user.role != role:
        raise credentials_exception

    return user

async def get_current_active_user(current_user: models.User = Depends(get_current_user)):
    if not current_user.is_active:
        raise HTTPException(status_code=400, detail="Inactive user")
    return current_user
    

@router.get("/knowledge_base/{category}", response_model=List[str])
async def get_knowledge_base_category(category: str, s3_client = Depends(get_s3_client)):
    """
    Получает список URL файлов в заданной категории (папке) в Object Storage.
    """
    bucket_name = os.environ.get("YC_BUCKET_NAME")
    prefix = f"knowledge_base/{category}/"  # Папка knowledge_base

    try:
        objects = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        file_urls = []

        if 'Contents' in objects:  # Проверяем наличие ключа 'Contents'
            for obj in objects['Contents']:
                file_key = obj['Key']
                #  ФИЛЬТРУЕМ:  Добавляем только если ключ НЕ заканчивается на /
                if not file_key.endswith('/'):
                    file_url = f"https://storage.yandexcloud.net/{bucket_name}/{file_key}"
                    file_urls.append(file_url)
        #  Если 'Contents' нет, то и делать ничего не нужно, file_urls останется пустым

        return file_urls  # Возвращаем список (пустой или с URL файлов)

    except ClientError as e:
        print(f"Error accessing Yandex Cloud Object Storage: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        print(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    except ClientError as e:
        print(f"Error accessing Yandex Cloud Object Storage: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e: # Добавили обработку других ошибок
        print(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

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
        role = "citizen"
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
    is_active: bool = True,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to view user list")

    query = db.query(models.User)

    if is_active is not None:
        query = query.filter(models.User.is_active == is_active)

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
    elif sort_by == "created_at":
        if sort_order == "asc":
            query = query.order_by(asc(models.User.created_at))
        else:
            query = query.order_by(desc(models.User.created_at))

    else:
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

    if user.username != db_user.username:
        existing_user = db.query(models.User).filter(models.User.username == user.username).first()
        if existing_user:
            raise HTTPException(status_code=400, detail="Пользователь с таким именем уже существует")

    if user.email != db_user.email:
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
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to delete users")

    db_user = db.query(models.User).filter(models.User.id == user_id).first()
    if db_user is None:
        raise HTTPException(status_code=404, detail="User not found")

    if db_user.role != "citizen":
        db_user.role = "citizen"

    active_appeals_exist = db.query(models.Appeal).join(models.AppealStatus).filter(
        models.Appeal.user_id == user_id,
        models.AppealStatus.name.notin_(["Выполнено", "Отклонено"])
    ).first() is not None

    if active_appeals_exist:
        raise HTTPException(status_code=400, detail="Cannot delete user: User has active appeals")

    db_user.is_active = False
    db.commit()

    return {"message": "User deactivated"}

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
    db.flush()  # Получаем ID нового обращения, до commit

    s3_client = get_s3_client()
    bucket_name = os.environ.get("YC_BUCKET_NAME")
    file_paths = []

    # Создаем структуру папок
    user_folder = current_user.username
    appeal_folder = f"{db_appeal.id}_{sanitize_filename(address)}/"  #  ID и адрес, с заменой + СЛЭШ
    # default_folder = "default"  #  Убираем подпапку default
    chat_folder = "chat"


    if files:
        for file in files:
            try:
                file_ext = os.path.splitext(file.filename)[1]
                # file_name = f"{uuid.uuid4()}{file_ext}"  #  Убираем UUID
                #  Формируем имя файла:
                file_name = f"{db_appeal.id}_{sanitize_filename(address)}_default{file_ext}"

                #  Путь к файлу в Yandex Cloud
                file_key = f"{user_folder}/{appeal_folder}/{file_name}" #  Убрали default

                # Загружаем в Yandex Cloud
                s3_client.upload_fileobj(
                    Fileobj=BytesIO(await file.read()),
                    Bucket=bucket_name,
                    Key=file_key,  #  Используем полный путь
                    ExtraArgs={
                        'ACL': 'public-read',
                    }
                )

                # Формируем URL
                file_url = f"https://storage.yandexcloud.net/{bucket_name}/{file_key}"
                file_paths.append(file_url)

                # Получаем размер и тип файла.
                file_size = file.size
                file_type = file.content_type

            except ClientError as e:
                print(f"Error uploading file to Yandex Cloud: {e}")
                raise HTTPException(status_code=500, detail=str(e)) #  Более информативное сообщение


    db_appeal.file_paths = json.dumps(file_paths)
    db_appeal.file_size = file_size
    db_appeal.file_type = file_type
    db.commit()
    db.refresh(db_appeal)
    if db_appeal.file_paths:
        db_appeal.file_paths = json.loads(db_appeal.file_paths)

     # Создаем папку chat (пустую)
    try:
        chat_key = f"{user_folder}/{appeal_folder}/{chat_folder}/"  #  Слэш в конце!
        s3_client.put_object(Bucket=bucket_name, Key=chat_key) #  Пустой объект
    except ClientError as e:
        print(f"Error creating chat folder: {e}")
        #  Не критично, если не удалось создать папку чата, продолжаем выполнение

    return db_appeal

@router.get("/appeals/", response_model=List[schemas.Appeal])
def read_appeals(
    skip: int = 0,
    limit: int = 100,
    sort_by: str = "created_at",
    sort_order: str = "desc",
    status_id: Optional[int] = None,
    category_id: Optional[int] = None,
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
    for appeal in appeals:
        appeal.file_paths = json.loads(appeal.file_paths) if appeal.file_paths else []  # Декодируем JSON

    return appeals

@router.get("/appeals/{appeal_id}", response_model=schemas.Appeal)
def read_appeal(appeal_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
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
    # files: List[UploadFile] = File(None)  # Убираем возможность загрузки файлов
):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")

    if current_user.role != "inspector":  #  Редактировать может только инспектор
        raise HTTPException(status_code=403, detail="Not authorized to update this appeal")

    # --- 1. Обновляем простые поля ---
    if address is not None:
        db_appeal.address = address
    if category_id is not None:
        db_appeal.category_id = category_id
    if description is not None:
        db_appeal.description = description
    if status_id is not None:
        db_appeal.status_id = status_id

    # --- 2.  Удаление файлов (если инспектор меняет статус, например) ---
    s3_client = get_s3_client()
    bucket_name = os.environ.get("YC_BUCKET_NAME")
    old_file_paths = json.loads(db_appeal.file_paths) if db_appeal.file_paths else [] #  Декодируем JSON

    #  Удаление файлов, если необходимо
    if status_id: #Если статус меняется, то файлы удаляются
        for file_path in old_file_paths:
            try:
                # Извлекаем key из URL
                file_name = file_path.split('/')[-1]
                user_folder = db_appeal.user.username  #  Имя пользователя
                appeal_folder = f"{db_appeal.id} {db_appeal.address}"  # ID и адрес
                default_folder = "default"
                file_key = f"{user_folder}/{appeal_folder}/{default_folder}/{file_name}"

                s3_client.delete_object(Bucket=bucket_name, Key=file_key)

            except ClientError as e:
                print(f"Error deleting file from Yandex Cloud: {e}")
        db_appeal.file_paths = "[]"  #  Очищаем список файлов в БД, записывая пустой JSON массив!
        db_appeal.file_size = None
        db_appeal.file_type = None

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
    user_folder = db_appeal.user.username
    appeal_folder = f"{db_appeal.id}_{sanitize_filename(db_appeal.address)}/" #  Исправлено
    # default_folder = "default" #  Убрали
    chat_folder = "chat"


    if db_appeal.file_paths:
        file_paths = db_appeal.file_paths.split(",")
        for file_path in file_paths:
            try:
                file_path = file_path.strip() #Убираем пробелы
                if file_path:
                    #  Извлекаем key из URL
                    file_name = file_path.split('/')[-1]
                    file_key = f"{user_folder}/{appeal_folder}/{file_name}" #  Исправлено
                    s3_client.delete_object(Bucket=bucket_name, Key=file_key)

            except ClientError as e:
                print(f"Error deleting file from Yandex Cloud: {e}")
                #  Не выбрасываем исключение, продолжаем удалять другие файлы

    #Удаляем папку "default" -  уже не нужна
    # try:
    #     s3_client.delete_object(Bucket=bucket_name, Key=f"{user_folder}/{appeal_folder}/{default_folder}/")
    # except:
    #     pass

    #Удаляем папку "chat"
    try:
        s3_client.delete_object(Bucket=bucket_name, Key=f"{user_folder}/{appeal_folder}/{chat_folder}/")
    except:
        pass

    # Удаляем папку обращения
    try:
        objects_to_delete = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=f"{user_folder}/{appeal_folder}/")
        if 'Contents' in objects_to_delete:
            delete_keys = {'Objects': []}
            for obj in objects_to_delete['Contents']:
                delete_keys['Objects'].append({'Key': obj['Key']})
            s3_client.delete_objects(Bucket=bucket_name, Delete=delete_keys)

    except ClientError as e:
        print(f"Error deleting appeal folder: {e}")

    db.delete(db_appeal)
    db.commit()
    return {"message": "Appeal deleted"}

@router.post("/appeal_statuses/", response_model=schemas.AppealStatus)
def create_appeal_status(status: schemas.AppealStatusCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")

    existing_status = db.query(models.AppealStatus).filter(models.AppealStatus.name == status.name).first()
    if existing_status:
        raise HTTPException(status_code=400, detail="Статус с таким названием уже существует")

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
def update_appeal_status(status_id: int, status: schemas.AppealStatusCreate, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized")

    db_status = db.query(models.AppealStatus).filter(models.AppealStatus.id == status_id).first()
    if db_status is None:
        raise HTTPException(status_code=404, detail="Status not found")
    if db_status.name != status.name:
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

    existing_category = db.query(models.AppealCategory).filter(models.AppealCategory.name == category.name).first()
    if existing_category:
        raise HTTPException(status_code=400, detail="Категория с таким названием уже существует")

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

    if db_category.name != category.name:
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

    if not user.is_active:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User is inactive",
            headers={"WWW-Authenticate": "Bearer"},
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