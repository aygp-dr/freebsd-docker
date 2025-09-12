# Architecture Diagrams: Current vs Lazy Installation

## User Flow Diagram

### Current Approach (Install During Build)

```mermaid
flowchart TD
    Start([User wants FreeBSD container]) --> Push[Push to GitHub]
    Push --> GHA[GitHub Actions triggered]
    
    GHA --> Build{Docker Build}
    Build --> Download[Download ISO<br/>~2 min]
    Download --> Install[Install FreeBSD in QEMU<br/>~28 min ⚠️]
    Install --> Package[Package Image<br/>~30s]
    Package --> Publish[Publish to Registry]
    
    Publish --> Wait[User waits 30+ min]
    Wait --> Pull[User pulls image]
    Pull --> Run[User runs container]
    Run --> Ready[FreeBSD Ready ✅]
    
    style Install fill:#ff6b6b
    style Wait fill:#ffd93d
    style Ready fill:#6bcf7f
```

### Lazy Installation Approach (Install on First Run)

```mermaid
flowchart TD
    Start([User wants FreeBSD container]) --> Push[Push to GitHub]
    Push --> GHA[GitHub Actions triggered]
    
    GHA --> Build{Docker Build}
    Build --> Download[Download ISO<br/>~2 min]
    Download --> Package[Package Image + Scripts<br/>~30s]
    Package --> Publish[Publish to Registry<br/>Total: ~3 min ✅]
    
    Publish --> Pull[User pulls image]
    Pull --> FirstRun{First Run?}
    
    FirstRun -->|Yes| InstallLocal[Install FreeBSD locally<br/>with KVM acceleration<br/>~15-30 min]
    FirstRun -->|No| StartVM[Start existing VM<br/>~10s]
    
    InstallLocal --> Ready[FreeBSD Ready ✅]
    StartVM --> Ready
    
    style Package fill:#6bcf7f
    style InstallLocal fill:#ffd93d
    style Ready fill:#6bcf7f
```

## Sequence Diagram: Current Approach

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant Docker as Docker Build
    participant QEMU as QEMU (no KVM)
    participant DH as Docker Hub
    participant User as End User

    Dev->>GH: git push
    GH->>GA: Trigger workflow
    GA->>Docker: Start build
    
    rect rgb(255, 200, 200)
        Note over Docker,QEMU: Slow Section (28+ min)
        Docker->>Docker: Download ISO (2 min)
        Docker->>QEMU: Start VM without KVM
        Docker->>QEMU: Run FreeBSD installer
        loop Installation Steps
            QEMU->>QEMU: Extract packages
            QEMU->>QEMU: Configure system
            QEMU->>QEMU: Install bootloader
        end
        QEMU-->>Docker: Installation complete
    end
    
    Docker->>Docker: Package layers (30s)
    Docker->>DH: Push image
    GA-->>Dev: Build complete (30+ min)
    
    User->>DH: docker pull
    DH-->>User: Download image
    User->>User: docker run
    User->>User: FreeBSD ready immediately
```

## Sequence Diagram: Lazy Installation Approach

```mermaid
sequenceDiagram
    participant Dev as Developer
    participant GH as GitHub
    participant GA as GitHub Actions
    participant Docker as Docker Build
    participant DH as Docker Hub
    participant User as End User
    participant Container as Container
    participant QEMU as QEMU (with KVM)

    Dev->>GH: git push
    GH->>GA: Trigger workflow
    GA->>Docker: Start build
    
    rect rgb(200, 255, 200)
        Note over Docker: Fast Build (3 min)
        Docker->>Docker: Download ISO (2 min)
        Docker->>Docker: Package scripts (30s)
        Docker->>DH: Push image
    end
    
    GA-->>Dev: Build complete (3 min) ✅
    
    User->>DH: docker pull
    DH-->>User: Download image
    User->>Container: docker run
    
    alt First Run
        rect rgb(255, 255, 200)
            Note over Container,QEMU: One-time setup (15-30 min)
            Container->>Container: Check .installed marker
            Container->>Container: Not found - start installation
            Container->>QEMU: Start VM with KVM ⚡
            Container->>QEMU: Run FreeBSD installer
            loop Installation with KVM
                QEMU->>QEMU: Fast extraction
                QEMU->>QEMU: Fast configuration
            end
            QEMU-->>Container: Installation complete
            Container->>Container: Create .installed marker
        end
    else Subsequent Runs
        Container->>Container: Check .installed marker
        Container->>Container: Found - skip installation
    end
    
    Container->>QEMU: Start FreeBSD VM
    QEMU-->>User: FreeBSD ready
```

## State Diagram: Container Lifecycle

```mermaid
stateDiagram-v2
    [*] --> Building: docker build
    
    state Building {
        Download_ISO --> Package_Image
        Package_Image --> Push_Registry
    }
    
    Push_Registry --> Image_Ready: 3 min
    
    Image_Ready --> First_Run: docker run
    
    state First_Run {
        Check_Installed --> Not_Installed: No marker
        Not_Installed --> Installing: Start QEMU
        Installing --> Create_Marker: Complete
        Create_Marker --> Installed
    }
    
    state Subsequent_Run {
        Check_Installed --> Already_Installed: Marker exists
        Already_Installed --> Start_VM: Skip install
    }
    
    First_Run --> FreeBSD_Running: 15-30 min
    Subsequent_Run --> FreeBSD_Running: 10 sec
    
    FreeBSD_Running --> [*]: docker stop
    
    note right of Building: CI/CD Phase\n~3 minutes
    note right of First_Run: User's First Run\n15-30 minutes\n(with KVM)
    note right of Subsequent_Run: User's Next Runs\nInstant
```

## Performance Comparison

```mermaid
gantt
    title Build Time Comparison
    dateFormat mm:ss
    axisFormat %M:%S
    
    section Current Approach
    Download ISO          :done, curr1, 00:00, 2m
    Install FreeBSD (no KVM) :crit, curr2, after curr1, 28m
    Package Image         :done, curr3, after curr2, 30s
    Total Build          :milestone, after curr3, 0
    
    section Lazy Install
    Download ISO          :done, lazy1, 00:00, 2m
    Package Scripts       :done, lazy2, after lazy1, 30s
    Total Build          :milestone, after lazy2, 0
    User Install (KVM)    :active, lazy3, 35:00, 15m
```

## Decision Matrix

```mermaid
graph LR
    subgraph "Current Approach"
        A1[CI Build: 30+ min] --> A2[User Pull: Fast]
        A2 --> A3[First Run: Instant]
        style A1 fill:#ff6b6b
        style A3 fill:#6bcf7f
    end
    
    subgraph "Lazy Installation"
        B1[CI Build: 3 min] --> B2[User Pull: Fast]
        B2 --> B3[First Run: 15-30 min]
        B3 --> B4[Next Runs: Instant]
        style B1 fill:#6bcf7f
        style B3 fill:#ffd93d
        style B4 fill:#6bcf7f
    end
    
    A1 -.->|10x slower| B1
    A3 -.->|But instant| B3
```

## Key Insights

1. **CI/CD Wins**: 10x faster builds (3 min vs 30+ min)
2. **User Trade-off**: First run slower, but with KVM acceleration
3. **Resource Usage**: GitHub Actions minutes saved significantly
4. **Cache Benefits**: ISO download layer can be cached effectively