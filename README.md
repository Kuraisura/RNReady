# 🩺 RN Ready

**Nursing Board Exam Review App** · `Mobile`

Comprehensive nursing review app with AI tutor, clinical cases, practice quizzes, anatomy lab, and study materials for PNLE preparation.

## Why This Project

The Philippine Nursing Licensure Examination is a high-stakes, syllabus-wide exam, and students preparing for it typically juggle review centers, photocopied transes, anatomy atlases, and late-night cramming with no single tool that mirrors how the board actually tests: situational judgment, care planning, rationales, and time pressure. Generic quiz apps drill facts without clinical context; AI chatbots answer questions but don't score a student's reasoning or generate board-style items from their own reviewer notes; anatomy apps rarely connect labeling practice to the rest of the curriculum.

RN Ready was built by Mark Crysler Baddo as a solo Flutter project to consolidate that preparation into one purpose-built companion for nursing students: an AI tutor available at 2 a.m., endless AI-generated clinical cases scored by a virtual instructor, an ADPIE care-plan generator, timed practice quizzes generated from bundled module notes and cached for offline retakes, and an interactive anatomy lab — all aimed at one measurable outcome, walking into the PNLE ready rather than merely studied.

## How It Works

Kaye is a final-year nursing student eight weeks out from the November PNLE. She opens RN Ready between duty shifts and lands on the home dashboard, where quick actions for AI Tutor, Clinical Case, Care Plan, and Notes sit above her Nursing Practice sections with per-subtopic completion counts. She taps into Community Health Nursing, swipes through the generated slide deck for a subtopic she's weak on, and hits "Ask AI" mid-slide to clarify a DOH program detail the deck glossed over — the tutor answers in context and the conversation persists for later.

That night she runs "Quiz this subtopic": the generator produces board-style multiple-choice and identification questions from the bundled notes, caches them to disk so tomorrow's bus ride works offline, and launches a timed session. She scores 12/15, and the results screen shows the rationale for every item, not just the answer key. The next morning she drills the Anatomy Lab heart diagram, labeling hidden structures until the spatial memory sticks, then opens Care Plan and pastes a sepsis scenario from her case study — receiving a full ADPIE plan in the classic six-column grid she can annotate and save to her journal. When her campus Wi-Fi drops mid-tutor session she sees a friendly offline card instead of an error, and her cached quizzes keep working. One app, every modality the board rewards, one target: passing.

## Modules

### Home Dashboard

The study hub: a Riverpod provider loads the section-to-subtopic outline once, quick-action tiles route into every major tool, Nursing Practice sections render with accent icons and quiz-progress badges, and a theme toggle switches light/dark. Everything is one tap from the first frame.

**Scenario:** Kaye opens the app on a five-minute break, sees Maternal & Child Health still at 0/56 completion, and jumps straight into that section's quiz bank instead of scrolling through unrelated review apps.

### AI Tutor

A persistent chat interface for natural-language nursing questions, backed by the shared LLM service with a nursing-focused system prompt. Conversations are stored locally so they survive restarts, and an offline view appears gracefully when the network is gone rather than surfacing raw provider errors.

**Scenario:** At 1 a.m. Kaye asks why a hypokalemic patient develops muscle weakness and U-waves; the tutor explains the mechanism in plain language, she follows up with a question about replacement precautions, and the whole thread is still there the next evening when she reviews it.

### Clinical Case Simulator

Specialty-organized, endlessly AI-generated scenarios — pharmacology, emergencies, ethics, maternal & child health, infection control, and more — where students answer in free text and a "Clinical Instructor" prompt evaluates the response, returning structured feedback and a 0–100 score. Cases regenerate on demand so practice never runs out.

**Scenario:** Kaye picks the emergencies category, reads a scenario about an anaphylactic reaction, types her prioritization and interventions, and receives a scored critique pointing out the epinephrine-first ordering she missed — critical thinking drilled the way the board tests it, not rote recall.

### Care Plan Generator

Turns a pasted patient situation into a complete Nursing Care Plan — Assessment, Diagnosis, Outcomes/Planning, Interventions, Rationale, and Evaluation — parsed from structured AI output and rendered either as readable stacked cards or the classic six-column grid, with markdown support and the option to save the result into notes.

**Scenario:** For her case-study submission Kaye pastes vitals and symptoms from a simulated sepsis patient, taps generate, and reviews a full ADPIE plan with rationales in the grid format her clinical instructor expects — then saves it to her journal to annotate before rendering her return demonstration.

### Practice Quiz Bank

Every subtopic under every Nursing Practice section is listed with completion progress; tapping one generates board-style questions (multiple choice, identification, and more) from the bundled module notes via AI, merges them into an on-disk cache for offline retakes, and launches a configurable timed session. Results show score, time used, and per-item rationale, while a progress store tracks what's been completed.

**Scenario:** Kaye opens "Nursing Practice I," sees which of the 56 subtopics remain untested, generates a 15-question mixed-format quiz for one of them, takes it under a 10-minute timer on the commute, and reviews the rationale for every miss before arriving at the hospital — retakes drawing from an accumulating offline pool.

### Anatomy Lab

Bundled anatomical diagrams — heart, neurons, skin, bones, eyes, lungs, and more — rendered with custom painters; each round hides a subset of labels and scores the student as they fill the blanks, reshuffling every attempt so spatial memory is tested rather than position memorization.

**Scenario:** Kaye drills the heart diagram three mornings in a row; each round hides different labels (aorta, right atrium, mitral valve), and by the third session she can name every structure without hesitation on her anatomy practical.

### Study Modules & Slide Decks

The curriculum layer: a module-structure model maps sections to subtopics over the bundled study content, each subtopic opens a PowerPoint-style slide deck generated from the extracted module text, and every deck keeps "Ask AI" and "Quiz this subtopic" actions so passive reading converts into active review without leaving the screen.

**Scenario:** Kaye swipes through six slides on infection control during a lull at the ward, taps "Ask AI" to unpack a sterilization definition, then launches a quiz on the same subtopic — read, clarify, test, in one continuous flow.

### Notes & Journal

A local notes list and editor for clinical observations, mnemonics, and reflections, with quick capture from a floating action button on the list screen.

**Scenario:** Post-duty, Kaye jots the mnemonic her preceptor taught for Ballard signs, tags it in her journal, and finds it again during finals review three weeks later instead of lost in a notes app mixed with grocery lists.

### LLM Service Layer

The shared AI infrastructure: a provider chain (Groq → Gemini → OpenRouter) with multi-model fallback so a retired model id doesn't abort a request, dotenv-loaded keys, and distinct OfflineException / MissingKeyException types that let every feature render a friendly, specific state instead of a stack trace. Chat persistence and study-content loading sit alongside it as the app's data services.

**Scenario:** During Kaye's café session a retired Groq model starts returning errors; the service silently fails over to Gemini and her tutor reply arrives as if nothing happened — and when the café Wi-Fi dies entirely, she gets a clean offline card and retries later with her conversation intact.

## Features

- AI Tutor chat for nursing and health science questions
- Clinical case studies across 10+ specialty categories
- Timed practice quizzes with answer review and rationale
- Interactive anatomy labeling activities
- Notes & journal for personal study
- Study materials with Ask AI integration

## Tech Stack

- React Native
- Expo
- Supabase
- OpenAI API

## Screenshots

### Study hub — the home screen organizes all review tools (AI Tutor, Clinical Case, Care Plan, Anatomy Lab) into a single dashboard. The "Ready to pass the PNLE?" headline speaks directly to the student's goal.

![Study hub — the home screen organizes all review tools (AI Tutor, Clinical Case, Care Plan, Anatomy Lab) into a single dashboard. The "Ready to pass the PNLE?" headline speaks directly to the student's goal.](screenshots/1.png)

### AI Tutor — students ask any nursing question in natural language and receive instant explanations. This replaces waiting for an instructor and is available 24/7 for late-night study sessions.

![AI Tutor — students ask any nursing question in natural language and receive instant explanations. This replaces waiting for an instructor and is available 24/7 for late-night study sessions.](screenshots/2.png)

### Clinical case library — organizes real-world nursing scenarios by specialty (pharmacology, emergencies, ethics). Students choose a category to practice critical thinking in context, not just memorize facts.

![Clinical case library — organizes real-world nursing scenarios by specialty (pharmacology, emergencies, ethics). Students choose a category to practice critical thinking in context, not just memorize facts.](screenshots/3.png)

### Expanded case categories — reveals additional specialties like Maternal & Child Health and Infection Control, covering the full PNLE syllabus so no exam topic is left unpracticed.

![Expanded case categories — reveals additional specialties like Maternal & Child Health and Infection Control, covering the full PNLE syllabus so no exam topic is left unpracticed.](screenshots/4.png)

### Personal study journal — lets nurses jot down clinical observations, mnemonics, or reflection notes. The "New note" button provides quick capture during study breaks.

![Personal study journal — lets nurses jot down clinical observations, mnemonics, or reflection notes. The "New note" button provides quick capture during study breaks.](screenshots/8.png)

### Anatomy Lab menu — visual cards for each body system (heart, neurons, skin, bones, eyes, lungs) let students choose which anatomy topic to practice labeling. Visual learning reinforces textbook study.

![Anatomy Lab menu — visual cards for each body system (heart, neurons, skin, bones, eyes, lungs) let students choose which anatomy topic to practice labeling. Visual learning reinforces textbook study.](screenshots/9.png)

### Interactive anatomy exercise — students label numbered parts of the heart diagram. Immediate feedback on correct answers (Aorta, Right atrium) reinforces spatial memory of anatomical structures.

![Interactive anatomy exercise — students label numbered parts of the heart diagram. Immediate feedback on correct answers (Aorta, Right atrium) reinforces spatial memory of anatomical structures.](screenshots/10.png)

### Quiz topic browser — lists all subtopics under Nursing Practice I with completion progress (0/56). Students can see exactly which topics they haven't studied yet and prioritize accordingly.

![Quiz topic browser — lists all subtopics under Nursing Practice I with completion progress (0/56). Students can see exactly which topics they haven't studied yet and prioritize accordingly.](screenshots/11.png)

### Quiz configuration — lets students choose question types (multiple choice, identification) and start a focused session on specific subtopics rather than random questions.

![Quiz configuration — lets students choose question types (multiple choice, identification) and start a focused session on specific subtopics rather than random questions.](screenshots/12.png)

### Timed quiz in progress — 10-minute timer with multiple-choice questions simulates real PNLE pressure. The countdown trains students to manage time during the actual board exam.

![Timed quiz in progress — 10-minute timer with multiple-choice questions simulates real PNLE pressure. The countdown trains students to manage time during the actual board exam.](screenshots/13.png)

### Results with rationale — shows score, time used, and most importantly WHY each answer was right or wrong. The detailed review transforms mistakes into learning opportunities.

![Results with rationale — shows score, time used, and most importantly WHY each answer was right or wrong. The detailed review transforms mistakes into learning opportunities.](screenshots/14.png)

### Study material reader — presents structured content (DOH programs, laws, nursing theories) with pagination. "Ask AI" and "Quiz this subtopic" buttons turn passive reading into active learning.

![Study material reader — presents structured content (DOH programs, laws, nursing theories) with pagination. "Ask AI" and "Quiz this subtopic" buttons turn passive reading into active learning.](screenshots/15.png)

## About

A mobile review application for the Philippine Nursing Licensure Examination (PNLE). Combines AI-powered tutoring, clinical case simulations, anatomy exercises, and structured practice quizzes with detailed answer explanations.

---

Built by [Mark Crysler Baddo](https://github.com/Kuraisura) · [Portfolio](https://kuraisler.xyz)
