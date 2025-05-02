# ChatGPT Clone using GROQ API

A powerful and lightweight ChatGPT clone built using the **GROQ API**, featuring a **Flutter frontend** and a **Node.js backend**. This clone supports advanced features like image uploading (via Cloudinary), chat history management, model selection, and more.

## 🔗 Live Backend URL

**Backend Deployment:** https://galaxy-ai-assignment.onrender.com

---

## ✨ Features

- 🧠 Chat with LLMs via **GROQ API**
- 📸 Upload and display images using **Cloudinary**
- 🧾 View and manage **Chat History**
- 🧩 **Choose from available LLM models**
- 🗑️ **Clear chats** individually or completely
- ➕ Start a **New Chat**
- ⚡ Clean and responsive UI with Flutter

---

## 🏗️ Project Structure

```bash
chatgpt-clone/
│
├── backend/          # Node.js + Express server for GROQ API & Cloudinary handling
├── frontend/         # Flutter project for UI
├── README.md
```

---

## 🚀 Getting Started

### 📦 Backend Setup (Node.js)

1. Navigate to the backend directory:

   ```bash
   cd backend
   ```

2. Install dependencies:

   ```bash
   npm install
   ```

3. Create a `.env` file and add your keys:

   ```env
   GROQ_API_KEY=your_groq_api_key
   CLOUDINARY_CLOUD_NAME=your_cloud_name
   CLOUDINARY_API_KEY=your_api_key
   CLOUDINARY_API_SECRET=your_api_secret
   ```

4. Run the server:

   ```bash
   npm start
   ```

   The server will start on `http://localhost:3000` or your configured port.

---

### 📱 Flutter Setup (Frontend)

1. Navigate to the frontend directory:

   ```bash
   cd frontend
   ```

2. Get dependencies:

   ```bash
   flutter pub get
   ```

3. Run the app on your connected device or emulator:

   ```bash
   flutter run
   ```

4. Make sure to update the API base URL in the Flutter project (usually in a `constants.dart` or `api_service.dart` file) with your backend deployment link.

---

## 🖼️ Image Upload

- Images are uploaded using **Cloudinary** via the backend.
- Users can attach and preview images in the chat window.
- Image URLs are stored with the chat history.

---

## 📚 Chat History & Models

- All chats are stored locally or via backend (based on your implementation).
- Users can:
  - View previous chats
  - Start a new chat
  - Select different models (e.g., `llama2-70b`, `mixtral-8x7b`, etc.)
  - Clear individual chats or all chats

---

## 🧪 Technologies Used

- **Frontend:** Flutter, Dart
- **Backend:** Node.js, Express, Cloudinary
- **API:** GROQ LLM API
