# verilog_recorder.py
# Recorder for Python → Verilog snapshot testbench
# Updated for 3-enemy hardware game_design.v

import os
import subprocess
import re

class Recorder:
    def __init__(self):
        self.events = []
        self.cycle = 0

    def start(self):
        self.events = []
        self.cycle = 0

    def tick(self):
        self.cycle += 1

    def record(self, action, args=None):
        if args is None:
            args = {}
        self.events.append({
            "cycle": self.cycle,
            "action": action,
            "args": args
        })

    # --------------------------------------------------
    # Generate snapshot_tb.v compatible with multi-enemy DUT
    # --------------------------------------------------
    def write_testbench(self, filename="snapshot_tb.v", module="snapshot_tb", max_cycles=2000):
        evts = sorted(self.events, key=lambda e: e["cycle"])

        with open(filename, "w") as f:
            f.write("`timescale 1ns/1ps\n")
            f.write(f"module {module};\n\n")

            # Inputs to DUT
            f.write("  reg clk, rst_n;\n")
            f.write("  reg left, right, shoot;\n")
            f.write("  reg enemy_spawn;\n")
            f.write("  reg [4:0] enemy_init_x;\n")
            f.write("  reg [3:0] enemy_init_y;\n\n")

            # Outputs from DUT
            f.write("  wire [4:0] player_x;\n")
            f.write("  wire [3:0] player_y;\n")
            f.write("  wire [4:0] bullet_x;\n")
            f.write("  wire [3:0] bullet_y;\n")
            f.write("  wire        bullet_active;\n\n")

            # MULTI-ENEMY ports
            f.write("  wire [4:0] enemy0_x, enemy1_x, enemy2_x;\n")
            f.write("  wire [3:0] enemy0_y, enemy1_y, enemy2_y;\n")
            f.write("  wire        enemy0_active, enemy1_active, enemy2_active;\n\n")

            f.write("  wire        hit;\n")
            f.write("  wire [7:0]  hit_count;\n")
            f.write("  wire [7:0]  score;\n\n")

            # Instantiate DUT with updated port list
            f.write("  game_design dut(\n")
            f.write("    .clk(clk), .rst_n(rst_n),\n")
            f.write("    .left(left), .right(right), .shoot(shoot),\n")
            f.write("    .enemy_spawn(enemy_spawn), .enemy_init_x(enemy_init_x), .enemy_init_y(enemy_init_y),\n")
            f.write("    .player_x(player_x), .player_y(player_y),\n")
            f.write("    .bullet_x(bullet_x), .bullet_y(bullet_y), .bullet_active(bullet_active),\n")
            f.write("    .enemy0_x(enemy0_x), .enemy0_y(enemy0_y), .enemy0_active(enemy0_active),\n")
            f.write("    .enemy1_x(enemy1_x), .enemy1_y(enemy1_y), .enemy1_active(enemy1_active),\n")
            f.write("    .enemy2_x(enemy2_x), .enemy2_y(enemy2_y), .enemy2_active(enemy2_active),\n")
            f.write("    .hit(hit), .hit_count(hit_count), .score(score)\n")
            f.write("  );\n\n")

            # Clock
            f.write("  initial begin clk = 0; forever #1 clk = ~clk; end\n\n")

            f.write("  integer cycle;\n")
            f.write("  initial begin\n")
            f.write("    $dumpfile(\"snapshot.vcd\");\n")
            f.write("    $dumpvars(0, snapshot_tb);\n\n")

            f.write("    left=0; right=0; shoot=0;\n")
            f.write("    enemy_spawn=0; enemy_init_x=0; enemy_init_y=0;\n")
            f.write("    rst_n=0; #5; rst_n=1; #2;\n")
            f.write("    cycle = 0;\n\n")

            last = 0
            for e in evts:
                delta = e["cycle"] - last
                if delta < 0: delta = 0
                f.write(f"    #({delta}*2);\n")

                if e["action"] == "left":
                    f.write("    left = 1; #2; left = 0;\n")
                elif e["action"] == "right":
                    f.write("    right = 1; #2; right = 0;\n")
                elif e["action"] == "shoot":
                    f.write("    shoot = 1; #2; shoot = 0;\n")
                elif e["action"] == "enemy_spawn":
                    x = e["args"]["x"]
                    y = e["args"]["y"]
                    f.write(f"    enemy_init_x = 5'd{x}; enemy_init_y = 4'd{y}; enemy_spawn = 1; #2; enemy_spawn = 0;\n")

                last = e["cycle"]

            f.write(f"    #({max_cycles}*2);\n")
            f.write("    $finish;\n")
            f.write("  end\nendmodule\n")

        print("[Recorder] Wrote testbench:", filename)

    # --------------------------------------------------
    # Compile + Run + GTKWave
    # --------------------------------------------------
    def run_tb(self, filename="snapshot_tb.v", out="snapshot_vvp"):
        print("[Recorder] Compiling...")
        try:
            subprocess.run(["iverilog", "-o", out, "game_design.v", filename],
                           check=True, capture_output=True, text=True)
        except subprocess.CalledProcessError as e:
            print("Compile error:\n", e.stdout, e.stderr)
            return

        print("[Recorder] Running simulation...")
        sim = subprocess.run(["vvp", out], capture_output=True, text=True)
        print(sim.stdout)

        # Open GTKWave if VCD exists
        if os.path.exists("snapshot.vcd"):
            try:
                subprocess.run(["gtkwave", "snapshot.vcd"])
            except:
                print("GTKWave not in PATH – open snapshot.vcd manually.")

    def snapshot(self):
        self.write_testbench()
        self.run_tb()
