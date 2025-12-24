## 👥 Collaborative Project

This project was developed collaboratively with @Het1236.

My contributions include:
- Hardware–software co-simulation design
- Verification using HDL testbenches
- Documentation and system-level explanation
# 🕹️ **20×15 Space Shooter Engine — Hardware + Software Co-Simulation**

### **Verilog Game Engine + Automated HDL Testbenches + Python Real-Time Frontend + Snapshot-Based Verification**

---

# 📌 **Table of Contents**

1. [Project Overview](#project-overview)
2. [System Architecture](#system-architecture)
3. [Verilog Hardware Engine (`game_design.v`)](#verilog-hardware-engine)

   * Grid, Player, Bullet
   * Multi-Enemy System (3 Enemies)
   * Fast Simulation Timers
   * Hit Logic & Scorekeeping
   * Automatic Random Enemy Spawning
   * Design Goals
4. [Traditional HDL Testbenches](#traditional-hdl-testbenches)

   * TB1: Perfect Hit
   * TB2: Left Edge Test
   * TB3: Miss & Retry
   * TB4: Right Edge Test
   * VCD & GTKWave Verification
5. [Python Real-Time Game Frontend (`game_py.py`)](#python-realtime-frontend)

   * Visual Grid Renderer
   * Player Controls
   * Real-Time Enemy Falling
   * Recording User Inputs
6. [Python → Verilog Snapshot System (`verilog_recorder.py`)](#snapshot-verification-system)

   * What is a Snapshot?
   * How It Works Internally
   * How to Generate & View Snapshots
7. [Co-Simulation Workflow](#co-simulation-workflow)
8. [Directory Structure](#directory-structure)
9. [Tools Required](#tools-required)
10. [How to Run Everything](#how-to-run)
11. [Conclusion & Learning Outcomes](#conclusion)

---

# 📌 **1. Project Overview** <a name="project-overview"></a>

This project implements a **20×15 Space Shooter** game engine entirely in **Verilog**, verified using:

* **Traditional deterministic HDL testbenches**
* **A modern Python-based real-time frontend (pygame)**
* **Automated Python-to-Verilog snapshot testbench generation**
* **Waveform analysis using GTKWave**

This hybrid approach allows us to:

✔ Demonstrate classical hardware verification
✔ Demonstrate co-simulation with software
✔ Show real-time game behavior connected to synthesizable Verilog
✔ Create reproducible HDL testbenches from real gameplay

---

# 📌 **2. System Architecture** <a name="system-architecture"></a>

```
                 ┌───────────────────────┐
                 │      Player Input     │
                 │ (Left, Right, Shoot)  │
                 └───────────┬───────────┘
                             |
               ┌────────────▼──────────────┐
               │      game_py.py (Python)  │
               │  • Real-time gameplay     │
               │  • 20x15 grid drawing     │
               │  • Movement & enemy logic │
               │  • Records actions        │
               └────────────┬──────────────┘
                            │
                            │ Snapshot (S key)
                            ▼
               ┌──────────────────────────────┐
               │ verilog_recorder.py (Python) │
               │  • Converts user inputs       │
               │    → Verilog testbench        │
               │  • Compiles Icarus Verilog    │
               │  • Runs simulation             │
               │  • Opens GTKWave automatically │
               └───────────────────┬───────────┘
                                   │
                                   ▼
                        ┌──────────────────┐
                        │ game_design.v    │
                        │ The hardware DUT │
                        │ (multi-enemy     │
                        │  space shooter)  │
                        └──────────────────┘
```

This architecture demonstrates **pure HDL testing + hybrid co-simulation** in a clean and academically rigorous way.

---

# 📌 **3. Verilog Hardware Engine (`game_design.v`)** <a name="verilog-hardware-engine"></a>

### **3.1 Grid Layout**

The grid is **20 columns × 15 rows**:

* Coordinate range: **x = 0–19**, **y = 0–14**
* Player sits at **bottom row y = 14**
* Bullets travel upward (y--)
* Enemies fall downward (y++)

### **3.2 Player Logic**

* Player starts at **x = 10**
* Moves **left** or **right** one cell per pulse
* Cannot leave boundaries (0 to 19)

### **3.3 Bullet Logic**

* One bullet active at a time
* Spawns at player_x, row **13**
* Moves upward every **2 clock cycles** (fast timer)

### **3.4 Three Independent Enemies**

Each enemy has:

```
enemyN_x, enemyN_y
enemyN_active
enemyN_timer_cnt
```

Features:

✔ All 3 behave independently
✔ Each moves downward every **3 clock cycles**
✔ Each can be hit individually
✔ Score increments per hit
✔ hit goes high for 1 clock

### **3.5 Automatic Random Spawning**

A small **8-bit LFSR** generates pseudo-random x positions.

Every **10 cycles**:

* If fewer than 2 enemies → spawn to reach 2
* Random chance to spawn a 3rd

This makes the game active, without external input.

### **3.6 Hit Detection**

If:

```
bullet_active == 1 &&
enemyN_active == 1 &&
bullet_x == enemyN_x &&
bullet_y == enemyN_y
```

Then:

* `hit <= 1`
* `enemyN_active <= 0`
* `bullet_active <= 0`
* `score++`
* `hit_count++`

### **3.7 Outputs Used for GTKWave**

All these are visible in VCD:

* player_x, player_y
* bullet_x, bullet_y, bullet_active
* enemy0_x/y/active
* enemy1_x/y/active
* enemy2_x/y/active
* hit
* hit_count
* score

---

# 📌 **4. Traditional HDL Testbenches** <a name="traditional-hdl-testbenches"></a>

The project includes 4 deterministic HDL testbenches (no Python involved).
They demonstrate classical HDL testing, required for academic grading.

---

## **TB1 — Perfect Hit (`game_tb.v`)**

* Spawn enemy at (10,5)
* Player at center (10)
* Shoot immediately
* Guaranteed hit
* Score increases to 1

**Purpose:** Demonstrates basic firing & collision.

---

## **TB2 — Left Edge Test (`game_tb2.v`)**

* Move player to x=0
* Spawn enemy at (0,4)
* Shoot → hit

**Purpose:** Boundary behavior + deterministic hit.

---

## **TB3 — Miss & Retry (`game_tb3.v`)**

* Spawn enemy at center
* Player moves right → misalignment
* Shoot = miss
* Move back under enemy
* Shoot again → hit

**Purpose:** Demonstrates miss detection and second-attempt collision.

---

## **TB4 — Right Edge Test (`game_tb4.v`)**

* Move player to x=19
* Spawn enemy at rightmost column
* Fire → hit

**Purpose:** Tests maximum boundary logic.

---

## **Waveform Verification**

All testbenches generate:

* `tb1.vcd`, `tb2.vcd`, `tb3.vcd`, `tb4.vcd`

Open in GTKWave:

```
gtkwave tb1.vcd
```

Observe:

* enemy paths
* bullet movement
* hit pulses
* score increments
* state machine behavior

---

# 📌 **5. Python Real-Time Frontend (`game_py.py`)** <a name="python-realtime-frontend"></a>

A fully playable **pygame** game that visually simulates the hardware.

### Features:

✔ 20×15 grid drawn on screen
✔ Player movement (Left/Right)
✔ Shooting (Spacebar)
✔ 3 falling enemies (matching HDL behavior)
✔ Score and hit info
✔ Smooth animations (30 FPS)
✔ Real-time movement timers matched to Verilog logic
✔ Records every action for snapshot reproduction

### Controls:

| Key       | Action                              |
| --------- | ----------------------------------- |
| Left / A  | Move left                           |
| Right / D | Move right                          |
| Space     | Shoot                               |
| S         | Generate Verilog snapshot testbench |
| Q or Esc  | Quit                                |

---

# 📌 **6. Python → Verilog Snapshot System (`verilog_recorder.py`)** <a name="snapshot-verification-system"></a>

### **What is a Snapshot?**

A snapshot is a **Verilog testbench generated automatically from your gameplay**.

Whenever you press **S**, the following happens:

1. Recorder writes a custom `snapshot_tb.v`
2. Testbench replays **exact movements and shots** you performed
3. Icarus Verilog simulates the hardware
4. A `snapshot.vcd` is created
5. GTKWave opens to show actual hardware behavior

### **Why this is powerful?**

Because it creates:

✔ Fully reproducible hardware simulations
✔ No manual writing of testbenches
✔ Direct proof that Python interface matches the Verilog design
✔ A hybrid verification flow (industry standard)

---

# 📌 **7. Co-Simulation Workflow** <a name="co-simulation-workflow"></a>

### **Play Game → Generate Snapshot → View HDL Waveforms**

1. Run Python game:

```
python game_py.py
```

2. Play normally
3. Press **S**
4. Recorder creates:

```
snapshot_tb.v
snapshot_vvp
snapshot.vcd
```

5. GTKWave automatically opens showing:

* bullet paths
* enemy paths
* hit pulses
* score
* multi-enemy interactions

You're effectively **debugging hardware using a real game**.

---

# 📌 **8. Directory Structure** <a name="directory-structure"></a>

```
project/
│
├── game_design.v           # Verilog Space Shooter Engine (3 enemies)
│
├── game_tb.v               # Testbench 1 - Perfect Hit
├── game_tb2.v              # Testbench 2 - Left Edge
├── game_tb3.v              # Testbench 3 - Miss & Retry
├── game_tb4.v              # Testbench 4 - Right Edge
│
├── game_py.py              # Real-time Python game (pygame)
├── verilog_recorder.py     # Snapshot generator + compiler
│
├── snapshot_tb.v           # Auto-generated snapshot testbench
├── snapshot.vcd            # Waveform from snapshot
│
└── README.md               # (this file)
```

---

# 📌 **9. Tools Required** <a name="tools-required"></a>

| Tool                              | Purpose                       |
| --------------------------------- | ----------------------------- |
| **Icarus Verilog (iverilog/vvp)** | Compiles & simulates hardware |
| **GTKWave**                       | View waveforms (VCD files)    |
| **Python 3**                      | Runs game + recorder          |
| **pygame**                        | Game rendering & input        |
| **PowerShell (optional)**         | Script automations            |

---

# 📌 **10. How to Run Everything** <a name="how-to-run"></a>

### **Run real-time game**

```
python game_py.py
```

### **Press S to generate a snapshot testbench**

Snapshot files generated:

* `snapshot_tb.v`
* `snapshot_vvp`
* `snapshot.vcd`
* GTKWave auto-opens

### **Run traditional testbench**

Example:

```
iverilog -o tb1 game_design.v game_tb.v
vvp tb1
gtkwave tb1.vcd
```

---

# 📌 **11. Conclusion & Learning Outcomes** <a name="conclusion"></a>

This project demonstrates:

✔ **Hardware game design** on a 20×15 grid
✔ **Fast-timed Verilog simulation** suitable for Icarus Verilog
✔ **Multi-enemy concurrent hardware logic**
✔ **Collision detection and scoring**
✔ **Testbench-driven verification**
✔ **Randomized hardware-controlled enemy spawning**
✔ **Software–hardware co-simulation**
✔ **Automatic snapshot testbench generation**
✔ **Waveform debugging using GTKWave**
✔ **Bridging HDL with Python visualization**

It represents a modern, robust, and academically rigorous approach to **digital design**, **verification**, and **system-level integration**.


