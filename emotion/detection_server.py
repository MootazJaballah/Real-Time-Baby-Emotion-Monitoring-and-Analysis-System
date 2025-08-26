import cv2
import time
from datetime import datetime
from flask import Flask, jsonify
from flask_cors import CORS
import threading
from ultralytics import YOLO
from uuid import uuid4
import os

from supabase import create_client, Client

# 🔐 Your Supabase credentials
SUPABASE_URL = "https://gxjukqprkcuofgqsokao.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Imd4anVrcXBya2N1b2ZncXNva2FvIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0ODEwMzY0NSwiZXhwIjoyMDYzNjc5NjQ1fQ.4Cm-5pPQ9v544RQyZh04ebIHB1IFUpamQsNNELcstv4"

# Initialize Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# Flask app
app = Flask(__name__)
CORS(app)

latest = {
    "emotion": "None",
    "confidence": 0.0,
    "time": "00:00:00",
    "image_url": ""
}

@app.route("/emotion-logs", methods=["GET"])
def get_logs():
    try:
        data = supabase.table("emotion_logs").select("*").order("timestamp", desc=True).limit(100).execute()
        return jsonify(data.data)
    except Exception as e:
        return jsonify({"error": str(e)}), 500


@app.route("/emotion", methods=["GET"])
def get_emotion():
    return jsonify(latest)

def upload_image(file_path: str):
    file_name = f"{uuid4()}.jpg"
    with open(file_path, "rb") as f:
        supabase.storage.from_("emotions").upload(file_name, f, {"content-type": "image/jpeg"})
    public_url = supabase.storage.from_("emotions").get_public_url(file_name)
    return public_url

def start_detection():
    global latest
    model = YOLO("best.pt")
    cap = cv2.VideoCapture(0)

    DETECTION_INTERVAL = 1
    last_detection_time = 0
    last_emotion = None
    last_confidence = 0

    while True:
        ret, frame = cap.read()
        if not ret:
            break

        current_time = time.time()
        if current_time - last_detection_time >= DETECTION_INTERVAL:
            results = model(frame)
            annotated_frame = results[0].plot()
            last_detection_time = current_time

            for box in results[0].boxes:
                cls_id = int(box.cls[0])
                confidence = float(box.conf[0])
                label = model.names[cls_id]

                if confidence < 0.60:
                    continue

                if label != last_emotion or abs(confidence - last_confidence) >= 0.01:
                    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
                    filename = f"temp_{uuid4().hex}.jpg"
                    cv2.imwrite(filename, frame)
                    image_url = upload_image(filename)
                    os.remove(filename)

                    # Update for API
                    latest = {
                        "emotion": label,
                        "confidence": round(confidence, 2),
                        "timestamp": timestamp,
                        "image_url": image_url
                    }

                    # Insert into Supabase
                    supabase.table("emotion_logs").insert(latest).execute()

                    print(f"[{timestamp}] Emotion: {label} ({round(confidence, 2)})")

                    last_emotion = label
                    last_confidence = confidence
                break

        cv2.imshow("YOLOv11 Webcam", annotated_frame)
        if cv2.waitKey(1) & 0xFF == ord("q"):
            break

    cap.release()
    cv2.destroyAllWindows()

if __name__ == "__main__":
    threading.Thread(target=start_detection, daemon=True).start()
    app.run(host="0.0.0.0", port=5000)
