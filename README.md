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

## Screenshot and module walkthrough

Expand a screen below to see the capture and an explanation of the module, its visible controls, and its role in the application.

<details open>
<summary><strong>01 · Nursing-review home</strong></summary>

Quick actions open the AI tutor, clinical cases, care plans, notes, anatomy lab, and practice quizzes. Nursing-practice sections continue below, making the home screen the starting point for different review activities.

<p><img src="screenshots/1.png" alt="Nursing-review home" width="360"></p>

</details>

<details>
<summary><strong>02 · AI tutor conversation</strong></summary>

The chat screen shows a learner question, a generated explanation, a message field, and a clear-history action. It supports follow-up study questions; the visible response is AI-generated material, not validated clinical guidance.

<p><img src="screenshots/2.png" alt="AI tutor conversation" width="360"></p>

</details>

<details>
<summary><strong>03 · Clinical-case category selection</strong></summary>

Topic cards group practice around physiology, emergencies, disease, prioritization, pharmacology, and communication. Learners choose the area for a generated scenario rather than starting with an unrelated random case.

<p><img src="screenshots/3.png" alt="Clinical-case category selection" width="360"></p>

</details>

<details>
<summary><strong>04 · Additional clinical-case topics</strong></summary>

The lower category list adds maternal/child care, ethics, diagnostics, infection control, and a random-topic option. It expands the same scenario-selection module to more review areas.

<p><img src="screenshots/4.png" alt="Additional clinical-case topics" width="360"></p>

</details>

<details>
<summary><strong>05 · Notes and journal</strong></summary>

A saved note card and New note button show the personal writing space. This module keeps short reflections, reminders, and study notes alongside the review tools.

<p><img src="screenshots/8.png" alt="Notes and journal" width="360"></p>

</details>

<details>
<summary><strong>06 · Anatomy topic library</strong></summary>

Illustrated cards organize labeling exercises by structure, including heart, neuron, skin, bone, eye, and respiratory topics. Each card identifies the body system and the number of parts available for practice.

<p><img src="screenshots/9.png" alt="Anatomy topic library" width="360"></p>

</details>

<details>
<summary><strong>07 · Heart-labeling exercise</strong></summary>

Numbered callouts connect a heart diagram to a list of labels, with some entries left for the learner to complete. Visible attribution identifies the illustration source; the activity focuses on recalling anatomical names.

<p><img src="screenshots/10.png" alt="Heart-labeling exercise" width="360"></p>

</details>

<details>
<summary><strong>08 · Practice-quiz topic browser</strong></summary>

Numbered subtopics and completion indicators sit under a nursing-practice section. Learners can see which topics remain unattempted and select material for a focused quiz.

<p><img src="screenshots/11.png" alt="Practice-quiz topic browser" width="360"></p>

</details>

<details>
<summary><strong>09 · Question-type selection</strong></summary>

A bottom sheet lets the learner select multiple choice, identification, enumeration, and matching. The Start button reflects the chosen types before a practice attempt begins.

<p><img src="screenshots/12.png" alt="Question-type selection" width="360"></p>

</details>

<details>
<summary><strong>10 · Timed practice question</strong></summary>

A countdown, question number, point value, answer choices, and Next button form the quiz-taking view. The interface supports timed retrieval practice without requiring the learner to leave the selected topic.

<p><img src="screenshots/13.png" alt="Timed practice question" width="360"></p>

</details>

<details>
<summary><strong>11 · Quiz results and rationales</strong></summary>

The results page combines score, correct-answer count, points, and duration with question-by-question review. Rationale text and Retry help users revisit mistakes after an attempt.

<p><img src="screenshots/14.png" alt="Quiz results and rationales" width="360"></p>

</details>

<details>
<summary><strong>12 · Study-module slide reader</strong></summary>

A paginated slide displays module notes with previous/next navigation. Ask AI and Quiz this subtopic connect reading to explanation and practice, keeping those activities tied to the current material.

<p><img src="screenshots/15.png" alt="Study-module slide reader" width="360"></p>

</details>

---

Project by [Mark Crysler Baddo](https://github.com/Kuraisura) · [Portfolio](https://kuraisler.xyz)
