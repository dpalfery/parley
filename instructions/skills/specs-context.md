# Skill: Project Specifications Context Discovery

## Purpose
This skill teaches agents how to discover, read, and consume project specifications from the `specs/` folder to understand project context, requirements, design decisions, and implementation guidelines.

## When to Use
- At the beginning of any task to understand project context
- When you need to understand requirements before implementing a feature
- When making architectural decisions that need to align with project vision
- When clarifying ambiguous requirements or design questions
- When writing new code that must fit into existing architecture
- When troubleshooting issues that may relate to design specifications

## Location
All project specifications are located in the `specs/` directory at the project root:
```
specs/
├── design.md                      # Technical design & architecture
├── meeting_recorder_vision.md     # Product vision & features
├── requirements.md                # Formal requirements with user stories
└── speaker_ident_design_spec.md  # Speaker identification design
```

## What Each File Contains

### 1. design.md - Technical Design Document
**Purpose**: Comprehensive technical design and architecture documentation

**Key Sections to Reference**:
- **Architecture**: High-level system architecture, layer responsibilities, component diagrams
- **Components and Interfaces**: Detailed service protocols and implementations
  - RecordingService: Audio capture lifecycle management
  - TranscriptionService: Speech-to-text conversion
  - SpeakerService: Voice identification and diarization
  - StorageManager: Local and cloud persistence
  - CloudSyncService: iCloud synchronization
- **Data Models**: Core Data schema, file system structure, JSON schemas
- **Error Handling**: Custom error types, handling strategies, logging patterns
- **Testing Strategy**: Unit, integration, UI, and performance testing guidelines
- **Security and Privacy**: Permissions, data protection, compliance requirements
- **Performance Optimizations**: Audio processing, transcription, storage, UI rendering
- **Design Decisions**: Rationale for technology choices (SwiftUI, Core Data, etc.)

**When to Reference**:
- Before implementing any service or component
- When adding new features that interact with existing services
- When troubleshooting architectural issues
- When making technology stack decisions

### 2. meeting_recorder_vision.md - Product Vision
**Purpose**: High-level product vision, features, and business strategy

**Key Sections to Reference**:
- **Product Vision**: Mission statement, target users, core value propositions
- **Core Features**: Complete feature list with details
  - Recording capabilities (real-time, background, pause/resume)
  - Transcription engine (native + AI fallback)
  - Speaker identification & management
  - Organization & metadata (tags, notes)
  - Export & sharing formats
  - Apple Watch integration (Phase 2+)
- **Technical Architecture**: Mobile stack, backend approach, data flow
- **User Experience Flow**: Primary user journey from start to export
- **Differentiating Features**: BYOAI model, one-time purchase, privacy-first design
- **Monetization Strategy**: Pricing model, API flexibility, no subscription trap
- **Development Roadmap**: MVP phases and future enhancements
- **Competitive Analysis**: How we compare to competitors

**When to Reference**:
- When understanding the "why" behind feature decisions
- When prioritizing features or making product trade-offs
- When ensuring new features align with product vision
- When understanding target user needs and use cases

### 3. requirements.md - Formal Requirements
**Purpose**: Structured requirements using user stories and acceptance criteria

**Structure**: 12 formal requirements covering:
1. Quick recording start (< 2 seconds)
2. Pause/resume functionality
3. Real-time transcription (< 3 second delay)
4. Speaker identification and labeling
5. Save with metadata (tags, timestamps)
6. iCloud automatic backup
7. Browse past recordings (list, filter, search)
8. Playback with synchronized transcript
9. Edit transcripts post-recording
10. Export in multiple formats (TXT, MD, M4A)
11. Add notes during/after recording
12. Manage local storage and cleanup

**Format**: Each requirement includes:
- User Story: "As a [user], I want [feature], so that [benefit]"
- Acceptance Criteria: 5 WHEN-THE-SHALL statements with measurable targets

**When to Reference**:
- When implementing a new feature to understand exact requirements
- When writing tests to ensure acceptance criteria are met
- When clarifying ambiguous feature behavior
- When validating that implementation meets specifications

### 4. speaker_ident_design_spec.md - Speaker Identification Spec
**Purpose**: Detailed technical design for speaker diarization system

**Key Sections**:
- **Objective**: Accuracy (>90%), capacity (10+ speakers), latency (<500ms), on-device processing
- **Feasibility Analysis**: Why native iOS APIs are insufficient, open source alternatives
- **Recommended Solution**: Sherpa-ONNX implementation details
  - VAD model (Silero)
  - Embedding model (wespeaker-resnet34)
  - Online clustering algorithm
- **System Architecture**: Complete dataflow from microphone to transcript alignment
- **Detailed Workflow**: Audio capture, VAD, embedding extraction, clustering, alignment
- **Implementation Steps**: Dependencies, model management, service creation, integration

**When to Reference**:
- When implementing speaker diarization features
- When debugging speaker identification issues
- When optimizing speaker detection performance
- When evaluating third-party ML models or APIs

## How to Use This Skill

### Step 1: Initial Context Discovery
At the start of any task, read the relevant spec files to understand context:

```markdown
1. Read specs/requirements.md to understand WHAT needs to be built
2. Read specs/design.md to understand HOW it should be architected
3. Read specs/meeting_recorder_vision.md to understand WHY (product vision)
4. Read specific specs like speaker_ident_design_spec.md for detailed subsystems
```

### Step 2: Extract Relevant Information
When reading specs, extract:
- **Interfaces**: Protocol definitions, method signatures, data models
- **Constraints**: Performance targets, quality requirements, technical limitations
- **Dependencies**: Required frameworks, external services, data flows
- **Best Practices**: Recommended patterns, error handling, testing strategies

### Step 3: Apply Context to Task
Use the extracted information:
- Implement features according to defined protocols and interfaces
- Meet acceptance criteria defined in requirements
- Follow architectural patterns from design document
- Align with product vision and user needs

### Step 4: Reference During Development
Keep specs accessible during implementation:
- Check acceptance criteria when writing tests
- Verify interface compliance when implementing services
- Consult error handling strategy when adding error cases
- Review data models when persisting information

## Example Usage Patterns

### Pattern 1: Implementing a New Feature
```markdown
Task: "Add speaker name editing functionality"

1. Read specs/requirements.md > Requirement 4 (speaker identification)
   - Extract: "allow users to assign custom names to speaker labels"
   
2. Read specs/design.md > Speaker Service section
   - Extract: updateSpeakerName(speakerID:name:) protocol method
   - Extract: SpeakerProfile data model structure
   
3. Read specs/design.md > Testing Strategy > Speaker Service Tests
   - Extract: "Test name assignment functionality"
   
4. Implement following the discovered patterns and protocols
5. Write tests matching acceptance criteria
```

### Pattern 2: Troubleshooting an Issue
```markdown
Problem: "Transcription latency is too high"

1. Read specs/requirements.md > Requirement 3
   - Target: "< 3 seconds from spoken words"
   
2. Read specs/design.md > Performance Optimizations > Transcription
   - Extract: "Process audio in 1-minute segments"
   - Extract: "Use background queue for transcription processing"
   - Extract: "Implement debouncing for UI updates (max 10 updates/second)"
   
3. Compare current implementation against recommended optimizations
4. Apply missing optimizations
```

### Pattern 3: Making Architectural Decisions
```markdown
Decision: "Should we use Realm or Core Data?"

1. Read specs/design.md > Design Decisions > Why Core Data over Realm?
   - Extract rationale: "Native, well-integrated with iCloud, zero third-party dependencies"
   
2. Read specs/design.md > Data Models > Core Data Schema
   - Extract: Defined RecordingEntity and SpeakerProfileEntity schemas
   
3. Follow established decision: Use Core Data
4. Implement using provided schema definitions
```

## Memory and Context Management

### Loading the Specs
When you need project context:
1. **Use read_file tool** to load relevant spec files
2. **Extract key information** relevant to current task
3. **Reference in responses** with file paths and line numbers when applicable

### Keeping Context Fresh
- Treat specs as source of truth
- When requirements seem unclear, consult requirements.md
- When architecture questions arise, consult design.md
- When product direction is ambiguous, consult meeting_recorder_vision.md

### Citing Specifications
When referencing specs in your responses, use clear citations:
```markdown
According to [requirements.md](specs/requirements.md#requirement-3), 
the transcription engine SHALL display transcribed text with a 
maximum delay of 3 seconds from spoken words.

The [design.md](specs/design.md:119) defines TranscriptionServiceProtocol
with the startLiveTranscription(audioBuffer:) method.
```

## Integration with Agent Instructions

This skill complements [`AGENT_INSTRUCTIONS.md`](../AGENT_INSTRUCTIONS.md):
- **Agent Instructions**: How to work with the codebase (architecture, build commands, patterns)
- **Specs Context Skill**: What to build and why (requirements, design decisions, product vision)

**Workflow**:
1. Read [`AGENT_INSTRUCTIONS.md`](../AGENT_INSTRUCTIONS.md) to understand codebase structure
2. Load this skill to understand project specifications
3. Read relevant spec files for task-specific requirements
4. Implement following both sets of guidelines

## Common Pitfalls to Avoid

❌ **Don't**: Assume requirements without checking specs
✅ **Do**: Read requirements.md to verify exact acceptance criteria

❌ **Don't**: Invent new data models or interfaces
✅ **Do**: Use models and protocols defined in design.md

❌ **Don't**: Make architectural decisions without rationale
✅ **Do**: Consult design decisions section for established patterns

❌ **Don't**: Implement features that contradict product vision
✅ **Do**: Verify features align with meeting_recorder_vision.md

❌ **Don't**: Skip specs because task seems simple
✅ **Do**: Quick scan of relevant specs even for small tasks

## Quick Reference Commands

### Discover all specs
```bash
ls -la specs/
```

### Read a specific spec
Use the read_file tool with relevant spec paths:
- `specs/requirements.md` - User stories and acceptance criteria
- `specs/design.md` - Technical architecture and design
- `specs/meeting_recorder_vision.md` - Product vision and roadmap
- `specs/speaker_ident_design_spec.md` - Speaker diarization design

### Search across specs
```bash
# Find all mentions of "transcription"
rg "transcription" specs/ -i

# Find specific protocols
rg "protocol.*Service" specs/ -i

# Find acceptance criteria
rg "WHEN.*THE.*SHALL" specs/requirements.md
```

## Validation Checklist

Before completing any task, verify:
- [ ] Read relevant spec files for context
- [ ] Implementation matches defined protocols/interfaces
- [ ] Acceptance criteria from requirements.md are met
- [ ] Design patterns from design.md are followed
- [ ] Feature aligns with product vision
- [ ] Tests cover acceptance criteria
- [ ] Error handling follows established patterns
- [ ] Performance targets are met (if specified)

## Summary

This skill ensures you:
1. **Discover** project specifications in the specs/ folder
2. **Understand** requirements, design, and product vision
3. **Apply** specifications to implementation tasks
4. **Validate** work against acceptance criteria
5. **Maintain** consistency with architectural decisions

**Remember**: The specs/ folder is your source of truth for "what to build" and "how to build it". Always consult it before, during, and after implementation.
