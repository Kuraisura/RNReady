# RN Ready

A Flutter nursing-review app combining study modules, practice quizzes, anatomy exercises, and AI-assisted review.

**Flutter / Cross-platform** · **In Development** · 2026

[Portfolio](https://kuraisler.xyz)

## Purpose

RN Ready brings nursing review activities into one application. Students can read module material, test knowledge, work through clinical scenarios, review anatomy, and keep notes instead of switching between separate review tools.

## Intended users

Nursing students and graduates preparing for the Philippine Nursing Licensure Examination or reviewing nursing topics.

## Main capabilities

- Read bundled study modules and slide-based review content.
- Take timed quizzes and review answer rationales and progress.
- Practice anatomy labeling and clinical-case exercises.
- Use an AI tutor, care-plan assistance, and a personal notes section.

## How it was built

### Cross-platform application

Flutter and Dart provide the interface. Feature folders separate tutor, anatomy, clinical cases, quizzes, modules, and notes; Riverpod manages application state.

### Study and AI services

JSON assets provide bundled material. A shared HTTP-based language-model service supports multiple AI providers and fallback handling.

### Local persistence

SharedPreferences and local file storage retain settings, notes, and cached study state. Bundled fonts and assets support local reading, while AI features need network access.

## Technology stack

| Responsibility | Technologies |
| --- | --- |
| Application | Flutter, Dart, Riverpod |
| AI & networking | HTTP, Groq, Gemini, OpenRouter |
| Study content & storage | JSON assets, SharedPreferences, path_provider |
| Reading interface | Flutter Markdown, Bundled fonts |

## Project scope and current state

A personal learning project in development with Flutter platform targets. It is a study aid rather than clinical decision support, an official exam product, or a guarantee of exam coverage. AI answers and rationales need review.

## Source guide

- [`lib/features/`](lib/features/)
- [`lib/data/services/llm_service.dart`](lib/data/services/llm_service.dart)
- [`assets/study/`](assets/study/)
- [`test/`](test/)

## Development setup

Use a Flutter/Dart SDK compatible with pubspec.yaml and your chosen platform tooling. Create the local .env asset expected by the pubspec and configure the LLM service for online AI features. Distributed app assets are not a place for privileged service credentials. Bundled material supports local reading; AI features require connectivity.

```sh
flutter pub get
flutter run

# Included tests
flutter test
```

## Screenshots

<table>
<tr>
<td align="center"><img src="screenshots/1.png" alt="Study hub" width="260"><br>Study hub</td>
<td align="center"><img src="screenshots/2.png" alt="AI Tutor" width="260"><br>AI Tutor</td>
</tr>
</table>

<details>
<summary>View all 12 screenshots</summary>

### 1. Study hub

![Study hub](screenshots/1.png)

### 2. AI Tutor

![AI Tutor](screenshots/2.png)

### 3. Clinical case library

![Clinical case library](screenshots/3.png)

### 4. Expanded case categories

![Expanded case categories](screenshots/4.png)

### 5. Personal study journal

![Personal study journal](screenshots/8.png)

### 6. Anatomy Lab menu

![Anatomy Lab menu](screenshots/9.png)

### 7. Interactive anatomy exercise

![Interactive anatomy exercise](screenshots/10.png)

### 8. Quiz topic browser

![Quiz topic browser](screenshots/11.png)

### 9. Quiz configuration

![Quiz configuration](screenshots/12.png)

### 10. Timed quiz in progress

![Timed quiz in progress](screenshots/13.png)

### 11. Results with rationale

![Results with rationale](screenshots/14.png)

### 12. Study material reader

![Study material reader](screenshots/15.png)

</details>

---

Project by [Mark Crysler Baddo](https://github.com/Kuraisura) · [Portfolio](https://kuraisler.xyz)
