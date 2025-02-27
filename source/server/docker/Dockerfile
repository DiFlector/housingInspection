FROM python:3.11

WORKDIR /app

COPY requirements.txt .

RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

RUN pip install --no-cache-dir -r requirements.txt

COPY app/ .

CMD ["uvicorn", "app.main:app", "--host", "0.0.0.0", "--port", "8000", "--reload"]
