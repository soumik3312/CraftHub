# 🚀 CraftHub

<div align="center">

### Build. Collaborate. Ship.

A full-stack mobile collaboration platform that helps developers, creators, and innovators discover teammates, communicate in real time, manage projects, and contribute together — all from a single application.

![Flutter](https://img.shields.io/badge/Flutter-Mobile%20App-02569B?logo=flutter)
![Dart](https://img.shields.io/badge/Dart-Language-0175C2?logo=dart)
![Node.js](https://img.shields.io/badge/Node.js-Backend-339933?logo=node.js)
![MongoDB](https://img.shields.io/badge/MongoDB-Database-47A248?logo=mongodb)
![Socket.IO](https://img.shields.io/badge/Socket.IO-Realtime-black?logo=socketdotio)
![GitHub OAuth](https://img.shields.io/badge/GitHub-OAuth-181717?logo=github)
![Gemini AI](https://img.shields.io/badge/Gemini-AI-blue)

</div>

---

## 📖 Overview

Most creators and developers still rely on multiple disconnected platforms:

- LinkedIn for networking
- GitHub for source code
- Discord or Slack for communication
- Portfolio websites for showcasing work
- Separate tools for project management and collaboration

This fragmented workflow creates friction between finding the right people and actually building together.

**CraftHub solves this problem by bringing discovery, collaboration, communication, project management, and contribution workflows into one unified platform.**

---

## 🎯 Problem Statement

In hackathons, startup teams, student projects, and freelance collaborations, people often:

1. Find teammates on one platform
2. Explain ideas somewhere else
3. Share project details through another tool
4. Move to GitHub only after significant coordination

This constant context switching slows progress and reduces productivity.

CraftHub was designed to make collaboration feel seamless:

```text
Discover
   ↓
Connect
   ↓
Collaborate
   ↓
Chat
   ↓
Create Workspace
   ↓
Contribute
   ↓
Ship Product
```

---

# ✨ Features

## 🔐 Authentication System

- OTP-based verification
- Secure login and signup
- Persistent user sessions
- JWT authentication

---

## 📰 Social Feed

- Share project updates
- Create posts
- Upload images
- Like and comment on posts
- Community engagement system

---

## 📁 Project Publishing

Users can create rich project profiles including:

- Project title
- Description
- Technology stack
- Categories and genres
- Multiple images
- Source files

---

## 🤖 AI-Powered Matchmaking

CraftHub intelligently helps users discover:

- Relevant collaborators
- Potential teammates
- Project opportunities
- Similar interests and skills

---

## 🤝 Collaboration System

Instead of generic networking requests:

- Send project-specific collaboration requests
- Accept or reject requests
- Create project-based teams
- Manage collaborators efficiently

---

## 💬 Realtime Communication

### Personal Chat

- One-to-one conversations
- Instant messaging

### Workspace Chat

- Project-specific group conversations
- Team collaboration discussions

### Realtime Infrastructure

- Socket.IO powered communication
- Live message delivery
- Mobile-friendly synchronization

---

## 🔗 GitHub Integration

Users can connect GitHub through OAuth and unlock:

- GitHub profile integration
- Repository workflows
- Collaboration-ready project environments

---

## 💻 In-App Coding Workspace

CraftHub includes a Monaco-powered coding environment allowing collaborators to:

- Open files
- Edit code
- Review contributions
- Work without leaving the application

---

## 🔎 Search & Discovery

Unified search system for:

- Users
- Projects
- Collaborators
- Communities

---

## 👤 Advanced Profile System

Profiles showcase:

- Projects
- Posts
- Collaborations
- Followers
- GitHub activity
- Connected teammates

---

# 🏗️ System Architecture

```text
                    ┌─────────────────┐
                    │ Flutter Client  │
                    └────────┬────────┘
                             │
                             ▼
                 ┌──────────────────────┐
                 │ Node.js + Express API│
                 └──────────┬───────────┘
                            │
          ┌─────────────────┼─────────────────┐
          ▼                 ▼                 ▼
      MongoDB          Socket.IO        Cloudinary
          │
          ▼
     GitHub OAuth
          │
          ▼
       Gemini AI
```

---

# 🚀 Application Flow

```text
Launch App
    │
    ▼
Login / Register
    │
    ▼
Browse Feed & Projects
    │
    ▼
Discover Collaborators
    │
    ▼
Send Collaboration Request
    │
    ▼
Request Accepted
    │
    ▼
Workspace Created
    │
    ▼
Connect GitHub
    │
    ▼
Collaborate & Build
```

---

# 🛠️ Tech Stack

## Frontend

| Technology | Purpose |
|------------|----------|
| Flutter | Cross-platform mobile development |
| Dart | Programming language |
| Provider | State management |
| Dio | API communication |
| Socket.IO Client | Realtime messaging |
| Shared Preferences | Local storage |
| Cached Network Image | Optimized image loading |
| Flutter Local Notifications | Notifications |
| Image Picker | Media upload |
| File Picker | Document handling |
| URL Launcher | External links |

---

## Backend

| Technology | Purpose |
|------------|----------|
| Node.js | Runtime environment |
| Express.js | Backend framework |
| MongoDB | Database |
| Mongoose | ODM |
| JWT | Authentication |
| Socket.IO | Realtime communication |
| Multer | File uploads |
| Nodemailer | Email services |
| Helmet | Security |
| CORS | Cross-origin support |
| Express Rate Limit | API protection |

---

## Integrations

| Service | Purpose |
|----------|----------|
| GitHub OAuth | Authentication & repository integration |
| GitHub API | Repository workflows |
| Cloudinary | Media storage |
| Gemini AI | AI-powered recommendations |

---

# 📂 Project Structure

```bash
craft_hub/
│
├── craft_hub_app/      # Flutter mobile application
│
├── backend/            # Node.js + Express backend
│
├── docs/               # Project documentation
│
└── SETUP.md            # Local setup guide
```

---

# 📦 Core Modules

## Frontend

- Authentication
- Feed System
- Project Discovery
- Matchmaking
- Collaboration Hub
- Personal Messaging
- Workspace Chat
- Search
- Profile Management
- GitHub Integration
- Code Workspace

---

## Backend

- Authentication Routes
- User Routes
- Project Routes
- Feed Routes
- Collaboration Routes
- Search Routes
- Messaging Routes
- GitHub Integration Routes
- AI Services
- Workspace Utilities

---

# 🧠 Engineering Highlights

### 🎯 Product-First Collaboration Design

Collaboration begins within project context rather than generic connection requests.

### ⚡ Hybrid Realtime Architecture

Socket.IO provides instant updates while periodic synchronization prevents stale state.

### 🏗️ Modular Backend Structure

Independent route modules improve maintainability and scalability.

### 🔄 Workspace-First Workflow

Teams can immediately start discussions even before repository setup is completed.

### 📡 Centralized API Layer

Improves consistency and maintainability across the application.

---

# ✅ Problems Solved

- Eliminates platform switching during collaboration
- Simplifies teammate discovery
- Creates structured project collaboration workflows
- Reduces setup friction between idea and execution
- Centralizes communication and project management
- Improves collaboration efficiency for students and builders
- Connects networking directly to project contribution

---

# 🎖️ Recruiter Highlights

This project demonstrates:

- Full-Stack Mobile Development
- Flutter Application Architecture
- Realtime Systems Engineering
- Authentication & Authorization
- MongoDB Database Design
- REST API Development
- AI Integration
- Cloud Media Management
- GitHub OAuth Integration
- Product Thinking
- System Design
- Scalable Backend Architecture

---

# 📸 Screenshots

Add screenshots here:

```text
assets/screenshots/
├── login.png
├── feed.png
├── projects.png
├── matchmaking.png
├── chat.png
├── workspace.png
└── profile.png
```

---

# 👨‍💻 Author

### Soumik Chaudhuri

**AIML Developer | Flutter Developer | Full Stack Developer**

---

# ⭐ Support

If you found this project useful, consider giving it a star.

**Build Together • Create Faster • Ship Smarter 🚀**
