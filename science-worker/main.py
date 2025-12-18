from fastapi import FastAPI

app = FastAPI()

@app.get("/health")
def health_check():
    return {"status": "ok", "service": "science-worker"}

@app.get("/")
def read_root():
    return {"message": "Zone14 Science Worker"}
