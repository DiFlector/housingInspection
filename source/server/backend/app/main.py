import firebase_admin
from firebase_admin import credentials, messaging
import os
from fastapi import FastAPI, Depends, HTTPException, status, APIRouter, Query, UploadFile, File, Form
from sqlalchemy import create_engine, text, desc, asc
from sqlalchemy.orm import sessionmaker, Session
from typing import List, Optional
from fastapi.middleware.cors import CORSMiddleware
from . import models, schemas
from .auth import get_password_hash, verify_password, create_access_token, decode_token
from .models import Base, Message
from .schemas import Message, MessageCreate
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

FIREBASE_CREDENTIALS_PATH = os.environ.get("FIREBASE_CREDENTIALS_PATH")
firebase_project_id = None

if FIREBASE_CREDENTIALS_PATH and os.path.exists(FIREBASE_CREDENTIALS_PATH):
    try:
        with open(FIREBASE_CREDENTIALS_PATH, 'r') as f:
           cred_data = json.load(f)
           firebase_project_id = cred_data.get('project_id')
           if not firebase_project_id:
               print("WARNING: Could not find 'project_id' in Firebase credentials file.")

        cred = credentials.Certificate(FIREBASE_CREDENTIALS_PATH)

        if not firebase_admin._apps:
            init_options = {'projectId': firebase_project_id} if firebase_project_id else None
            firebase_admin.initialize_app(cred, init_options)
            print(f"Firebase Admin SDK initialized successfully (Project ID: {firebase_project_id}).")
        else:
            current_app = firebase_admin.get_app()
            if firebase_project_id and current_app.project_id != firebase_project_id:
                 print(f"WARNING: Firebase Admin SDK already initialized with a different project ID ({current_app.project_id}). Expected: {firebase_project_id}")
            else:
                 print("Firebase Admin SDK already initialized.")

    except Exception as e:
        print(f"ERROR initializing Firebase Admin SDK: {e}")
else:
    print("WARNING: Firebase credentials path not set or file not found. Push notifications will not work.")
    print(f"Firebase credentials path from env: {FIREBASE_CREDENTIALS_PATH}")
    
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

async def send_fcm_notification(user_id: int, title: str, body: str, data: Optional[dict] = None, db: Session = Depends(get_db)):
    if not firebase_admin._apps:
         print("Firebase Admin SDK not initialized. Cannot send notification.")
         return

    tokens = db.query(models.DeviceToken.fcm_token).filter(models.DeviceToken.user_id == user_id).all()
    registration_tokens = [token for (token,) in tokens]

    if not registration_tokens:
        print(f"No FCM tokens found for user_id: {user_id}")
        return

    print(f"DEBUG: Sending notifications individually to tokens for user_id {user_id}: {registration_tokens}")

    success_count = 0
    failure_count = 0
    failed_tokens = []

    for token in registration_tokens:
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            data=data if data else {},
            token=token,
        )
        try:
            response = messaging.send(message)
            print(f"Successfully sent message to token {token[-10:]}: {response}")
            success_count += 1
        except messaging.UnregisteredError:
             print(f"Token {token[-10:]} is unregistered. Consider removing from DB.")
             failure_count += 1
             failed_tokens.append(token)
        except messaging.FirebaseError as e:
             print(f"Firebase error sending to token {token[-10:]}: {e}")
             failure_count += 1
             failed_tokens.append(token)
             if hasattr(e, 'http_response'):
                  print(f"HTTP Response Body: {e.http_response.text}")
        except Exception as e:
             print(f"General error sending to token {token[-10:]}: {e}")
             failure_count += 1
             failed_tokens.append(token)

    print(f"Finished sending notifications for user_id {user_id}. Success: {success_count}, Failures: {failure_count}")
    if failure_count > 0:
        print(f"Failed tokens: {[t[-10:] for t in failed_tokens]}")

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
    prefix = f"knowledge_base/{category}/"

    try:
        objects = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=prefix)
        file_urls = []

        if 'Contents' in objects:
            for obj in objects['Contents']:
                file_key = obj['Key']
                if not file_key.endswith('/'):
                    file_url = f"https://storage.yandexcloud.net/{bucket_name}/{file_key}"
                    file_urls.append(file_url)

        return file_urls

    except ClientError as e:
        print(f"Error accessing Yandex Cloud Object Storage: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
        print(f"Unexpected error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

    except ClientError as e:
        print(f"Error accessing Yandex Cloud Object Storage: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    except Exception as e:
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
    files: List[UploadFile] = File(...)
):
    if not files or len(files) != 2:
         raise HTTPException(status_code=400, detail="Необходимо прикрепить ровно два файла: одно изображение и один PDF.")

    image_file = None
    pdf_file = None
    image_ext = {'.jpg', '.jpeg', '.png', '.gif', '.bmp'}
    pdf_ext = {'.pdf'}

    for file in files:
        file_extension = os.path.splitext(file.filename)[1].lower()
        if file_extension in image_ext and image_file is None:
            image_file = file
        elif file_extension in pdf_ext and pdf_file is None:
            pdf_file = file
        else:
             raise HTTPException(status_code=400, detail=f"Недопустимый тип файла '{file.filename}' или превышено количество файлов одного типа.")

    if image_file is None or pdf_file is None:
         raise HTTPException(status_code=400, detail="Необходимо прикрепить одно изображение (JPG, PNG и т.д.) и один PDF файл.")


    default_status = db.query(models.AppealStatus).filter(models.AppealStatus.name == "Новое").first()
    if not default_status:
        raise HTTPException(status_code=500, detail="Статус по умолчанию 'Новое' не найден в базе данных.")
    status_id_default = default_status.id

    db_appeal = models.Appeal(
        address=address,
        category_id=category_id,
        description=description,
        user_id=current_user.id,
        status_id=status_id_default
    )
    db.add(db_appeal)
    db.flush()

    s3_client = get_s3_client()
    bucket_name = os.environ.get("YC_BUCKET_NAME")
    saved_file_paths = []

    user_folder = sanitize_filename(current_user.username)
    appeal_folder = f"{db_appeal.id}_{sanitize_filename(address)}/"
    chat_folder = "chat"

    files_to_upload = [image_file, pdf_file]

    for file in files_to_upload:
        try:
            file_ext = os.path.splitext(file.filename)[1].lower()
            file_name_in_s3 = f"{db_appeal.id}_{sanitize_filename(os.path.splitext(file.filename)[0])}{file_ext}"

            file_key = f"{user_folder}/{appeal_folder}/{file_name_in_s3}"

            file.file.seek(0)
            s3_client.upload_fileobj(
                Fileobj=file.file,
                Bucket=bucket_name,
                Key=file_key,
                ExtraArgs={'ACL': 'public-read'}
            )

            file_url = f"https://storage.yandexcloud.net/{bucket_name}/{file_key}"
            saved_file_paths.append(file_url)

        except ClientError as e:
            print(f"Error uploading file to Yandex Cloud: {e}")
            db.rollback()
            raise HTTPException(status_code=500, detail=f"Ошибка загрузки файла '{file.filename}': {e}")
        except Exception as e:
             db.rollback()
             raise HTTPException(status_code=500, detail=f"Непредвиденная ошибка при загрузке файла '{file.filename}': {e}")

    db_appeal.file_paths = json.dumps(saved_file_paths)

    db.commit()
    db.refresh(db_appeal)

    inspectors = db.query(models.User).filter(models.User.role == 'inspector', models.User.is_active == True).all()
    if inspectors:
        notification_title = "Новое обращение"
        sender_name = current_user.username
        notification_body = f"Поступило новое обращение '{db_appeal.address}' от пользователя {sender_name}."
        notification_data = {'appeal_id': str(db_appeal.id)}
        for inspector in inspectors:
            await send_fcm_notification(
                user_id=inspector.id,
                title=notification_title,
                body=notification_body,
                data=notification_data,
                db=db
            )

    if db_appeal.file_paths:
        db_appeal.file_paths = json.loads(db_appeal.file_paths)
    else:
        db_appeal.file_paths = []

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

    if status_id is not None:
        query = query.filter(models.Appeal.status_id == status_id)
    if category_id is not None:
        query = query.filter(models.Appeal.category_id == category_id)

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
        appeal.file_paths = json.loads(appeal.file_paths) if appeal.file_paths else []

    return appeals

@router.get("/appeals/{appeal_id}", response_model=schemas.Appeal)
def read_appeal(appeal_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")
    if current_user.role == "citizen" and db_appeal.user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorized to access this appeal")

    if db_appeal.file_paths:
        db_appeal.file_paths = json.loads(db_appeal.file_paths)
    else:
         db_appeal.file_paths = []

    return db_appeal

@router.put("/appeals/{appeal_id}", response_model=schemas.Appeal)
async def update_appeal(
    appeal_id: int,
    appeal_update: schemas.AppealUpdate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")

    if current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to update this appeal")

    update_data = appeal_update.model_dump(exclude_unset=True)
    status_changed = False
    new_status_id = None
    old_status_id = db_appeal.status_id

    if 'address' in update_data:
        db_appeal.address = update_data['address']
    if 'category_id' in update_data:
        db_appeal.category_id = update_data['category_id']
    if 'description' in update_data:
        db_appeal.description = update_data['description']
    if 'status_id' in update_data:
        if db_appeal.status_id != update_data['status_id']:
             db_appeal.status_id = update_data['status_id']
             status_changed = True
             new_status_id = update_data['status_id']

    db.commit()
    db.refresh(db_appeal)

    if status_changed and new_status_id is not None:
        new_status = db.query(models.AppealStatus).filter(models.AppealStatus.id == new_status_id).first()
        status_name = new_status.name if new_status else "Неизвестный статус"
        notification_data = {'appeal_id': str(appeal_id)}

        user_id_to_notify_citizen = db_appeal.user_id
        citizen_title = "Статус обращения обновлен"
        citizen_body = f"Статус вашего обращения '{db_appeal.address}' изменен на '{status_name}'."
        if status_name == "Требует уточнений":
            citizen_body += " Пожалуйста, проверьте чат."

        await send_fcm_notification(
            user_id=user_id_to_notify_citizen,
            title=citizen_title,
            body=citizen_body,
            data=notification_data,
            db=db
        )

        if status_name == "Требует уточнений":
            inspectors = db.query(models.User).filter(models.User.role == 'inspector', models.User.is_active == True).all()
            inspector_title = "Обращение требует уточнений"
            inspector_body = f"Обращение '{db_appeal.address}' переведено в статус 'Требует уточнений'."
            for inspector in inspectors:
                 await send_fcm_notification(
                     user_id=inspector.id,
                     title=inspector_title,
                     body=inspector_body,
                     data=notification_data,
                     db=db
                 )

    if db_appeal.file_paths:
        db_appeal.file_paths = json.loads(db_appeal.file_paths)
    else:
         db_appeal.file_paths = []

    return db_appeal

# @router.delete("/appeals/{appeal_id}")
# def delete_appeal(appeal_id: int, db: Session = Depends(get_db), current_user: models.User = Depends(get_current_active_user)):
#     db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
#     if db_appeal is None:
#         raise HTTPException(status_code=404, detail="Appeal not found")
#     if current_user.role == "citizen" and db_appeal.user_id != current_user.id:
#         raise HTTPException(status_code=403, detail="Not authorized to delete this appeal")
#     if current_user.role != "inspector" and current_user.role != "citizen":
#         raise HTTPException(status_code=403, detail="Not authorized to delete this appeal")

#     s3_client = get_s3_client()
#     bucket_name = os.environ.get("YC_BUCKET_NAME")
#     user_folder = db_appeal.user.username
#     appeal_folder = f"{db_appeal.id}_{sanitize_filename(db_appeal.address)}/"
#     # default_folder = "default"
#     chat_folder = "chat"


#     if db_appeal.file_paths:
#         file_paths = db_appeal.file_paths.split(",")
#         for file_path in file_paths:
#             try:
#                 file_path = file_path.strip()
#                 if file_path:
#                     file_name = file_path.split('/')[-1]
#                     file_key = f"{user_folder}/{appeal_folder}/{file_name}"
#                     s3_client.delete_object(Bucket=bucket_name, Key=file_key)

#             except ClientError as e:
#                 print(f"Error deleting file from Yandex Cloud: {e}")

#     # try:
#     #     s3_client.delete_object(Bucket=bucket_name, Key=f"{user_folder}/{appeal_folder}/{default_folder}/")
#     # except:
#     #     pass

#     try:
#         s3_client.delete_object(Bucket=bucket_name, Key=f"{user_folder}/{appeal_folder}/{chat_folder}/")
#     except:
#         pass

#     try:
#         objects_to_delete = s3_client.list_objects_v2(Bucket=bucket_name, Prefix=f"{user_folder}/{appeal_folder}/")
#         if 'Contents' in objects_to_delete:
#             delete_keys = {'Objects': []}
#             for obj in objects_to_delete['Contents']:
#                 delete_keys['Objects'].append({'Key': obj['Key']})
#             s3_client.delete_objects(Bucket=bucket_name, Delete=delete_keys)

#     except ClientError as e:
#         print(f"Error deleting appeal folder: {e}")

#     db.delete(db_appeal)
#     db.commit()
#     return {"message": "Appeal deleted"}

@router.get("/appeals/{appeal_id}/messages", response_model=List[schemas.Message])
def read_messages(
    appeal_id: int,
    skip: int = 0,
    limit: int = 100,
    last_message_id: Optional[int] = None,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")

    query = db.query(models.Message).filter(models.Message.appeal_id == appeal_id)

    if last_message_id is not None:
        query = query.filter(models.Message.id > last_message_id)

    messages = query.order_by(models.Message.id).offset(skip).limit(limit).all()

    return messages

@router.post("/appeals/{appeal_id}/messages", response_model=schemas.Message)
async def create_message(
    appeal_id: int,
    message: schemas.MessageCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user),
):
    db_appeal = db.query(models.Appeal).filter(models.Appeal.id == appeal_id).first()
    if db_appeal is None:
        raise HTTPException(status_code=404, detail="Appeal not found")

    if current_user.id != db_appeal.user_id and current_user.role != "inspector":
        raise HTTPException(status_code=403, detail="Not authorized to send messages to this appeal")

    db_message = models.Message(
        appeal_id=appeal_id,
        sender_id=current_user.id,
        content=message.content,
    )
    db.add(db_message)
    db.commit()
    db.refresh(db_message)

    notification_data = {'appeal_id': str(appeal_id)}
    sender_name = current_user.username

    if current_user.id == db_appeal.user_id:
        inspectors = db.query(models.User).filter(models.User.role == 'inspector', models.User.is_active == True).all()
        if inspectors:
            notification_title = "Новое сообщение от гражданина"
            notification_body = f"Пользователь {sender_name} отправил сообщение по обращению '{db_appeal.address}'."
            for inspector in inspectors:
                if inspector.id != current_user.id:
                    await send_fcm_notification(
                        user_id=inspector.id,
                        title=notification_title,
                        body=notification_body,
                        data=notification_data,
                        db=db
                    )
    elif current_user.role == 'inspector':
        user_id_to_notify = db_appeal.user_id
        if user_id_to_notify != current_user.id:
            notification_title = "Новое сообщение"
            notification_body = f"Инспектор {sender_name} отправил сообщение по вашему обращению '{db_appeal.address}'."
            await send_fcm_notification(
                user_id=user_id_to_notify,
                title=notification_title,
                body=notification_body,
                data=notification_data,
                db=db
            )

    if db_message.file_paths:
        db_message.file_paths = json.loads(db_message.file_paths)

    return db_message

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

@router.post("/users/me/devices", status_code=status.HTTP_201_CREATED)
def register_device(
    token_data: schemas.DeviceTokenCreate,
    db: Session = Depends(get_db),
    current_user: models.User = Depends(get_current_active_user)
):
    existing_token = db.query(models.DeviceToken).filter(models.DeviceToken.fcm_token == token_data.fcm_token).first()
    if existing_token:
        if existing_token.user_id == current_user.id:
            return {"message": "Device already registered"}
        else:
            existing_token.user_id = current_user.id
            db.commit()
            return {"message": "Device registration updated"}

    db_token = models.DeviceToken(
        user_id=current_user.id,
        fcm_token=token_data.fcm_token,
        device_type=token_data.device_type
    )
    db.add(db_token)
    db.commit()
    return {"message": "Device registered successfully"}

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