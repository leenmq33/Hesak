
# Hesak | حسّك

## 1. Project Overview

Hesak is an Android-based assistive application designed to support Deaf and hard-of-hearing individuals by improving communication and awareness of surrounding sounds.

The application provides real-time speech-to-text transcription, AI-assisted text clarification and enhancement, text-to-speech functionality, and environmental sound awareness.

## 2. Prerequisites

The following are required to set up and run the application:

- Flutter SDK and Dart
- Visual Studio Code with Flutter and Dart extensions
- Android SDK
- Android device or Android emulator
- Internet connection
- Firebase project configuration
- Valid API credentials for the integrated services
- Access to the configured speech-to-text backend service

## 3. Installation and Setup

### Step 1: Clone the Repository

Clone the project repository and navigate to its directory:

```bash
git clone https://github.com/leenmq33/Hesak.git
cd Hesak
```

### Step 2: Install Flutter Dependencies

Run the following command in the project directory:

```bash
flutter pub get
```

### Step 3: Configure API Credentials and Backend Connection

Create a file named `env.json` in the project root directory using `env.example.json` as a template.

Configure the following variables:

```json
{
  "ELEVENLABS_API_KEY": "",
  "ELEVENLABS_VOICE_ID_MALE": "",
  "ELEVENLABS_VOICE_ID_FEMALE": "",
  "OPENAI_API_KEY": "",
  "HESAK_SERVER_URL": "",
  "HESAK_SERVER_TOKEN": ""
}
```

Replace the empty values with the appropriate API credentials and speech-to-text backend connection details.

**Important:** The `env.json` file contains sensitive credentials and must remain local. It must not be uploaded to GitHub. Only the `env.example.json` template is included in the repository.

### Step 4: Configure Firebase

Ensure that the application is connected to a valid Firebase project. Configure Firebase Authentication and Cloud Firestore, and provide the required Firebase configuration files for the Android application.

The configuration must correspond to the Firebase project used by the application.

### Step 5: Verify the Speech-to-Text Backend

Ensure that the speech-to-text backend hosted on Modal is accessible and correctly configured.

Set `HESAK_SERVER_URL` and `HESAK_SERVER_TOKEN` in the `env.json` file using the appropriate backend connection details.

The speech-to-text functionality requires a valid connection to this backend service.

## 4. Running the Application

1. Open the project folder in Visual Studio Code.
2. Connect an Android device or start an Android emulator.
3. Select the target device in Visual Studio Code.
4. Run the application using the Run option in Visual Studio Code or the following command:

```bash
flutter run
```

Once launched, the application displays the Hesak interface. Features that depend on external services require valid credentials, network connectivity, and access to the configured backend.

## 5. Project Team

### Supervised by

Dr. Rehab Alahmadi

### Team Members

- Leen Mohammad Almuqhim
- Nora Abdullah Aluqaili
- Lubna Mohammed Alqifari
- Remas Salem Alayidh

### Graduation Project

College of Computer and Information Sciences

King Saud University

Fall 2026 | First Semester 1448 H

