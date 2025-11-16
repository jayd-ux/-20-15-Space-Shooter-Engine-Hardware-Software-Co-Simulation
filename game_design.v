// game_design.v (3 enemies, hit counter, auto-random spawns, Verilog-2001 safe)

`timescale 1ns/1ps

module game_design #(
    parameter AUTO_SPAWN = 1   // 1 = game mode, 0 = deterministic testbench mode
)(
    input  wire clk,
    input  wire rst_n,
    input  wire left,
    input  wire right,
    input  wire shoot,

    // external testbench spawn
    input  wire        enemy_spawn,
    input  wire [4:0]  enemy_init_x,
    input  wire [3:0]  enemy_init_y,

    // outputs
    output reg  [4:0]  player_x,
    output reg  [3:0]  player_y,
    output reg  [4:0]  bullet_x,
    output reg  [3:0]  bullet_y,
    output reg         bullet_active,

    output reg  [4:0]  enemy0_x,
    output reg  [3:0]  enemy0_y,
    output reg         enemy0_active,

    output reg  [4:0]  enemy1_x,
    output reg  [3:0]  enemy1_y,
    output reg         enemy1_active,

    output reg  [4:0]  enemy2_x,
    output reg  [3:0]  enemy2_y,
    output reg         enemy2_active,

    output reg         hit,
    output reg  [7:0]  hit_count,
    output reg  [7:0]  score
);

    // constants
    localparam COLS = 20;
    localparam ROWS = 15;
    localparam PLAYER_ROW = ROWS - 1;   // y=14
    localparam BULLET_TIMER = 2;
    localparam ENEMY_TIMER  = 3;
    localparam SPAWN_TIMER  = 10;

    // counters
    reg [3:0] bullet_timer_cnt;
    reg [3:0] enemy0_timer_cnt;
    reg [3:0] enemy1_timer_cnt;
    reg [3:0] enemy2_timer_cnt;
    reg [7:0] spawn_timer_cnt;

    // simple LFSR
    reg [7:0] lfsr;

    // integers must be declared outside always blocks
    integer active_count;

    // -------------------------------
    // sequential logic
    // -------------------------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            player_x <= 10;
            player_y <= PLAYER_ROW[3:0];

            bullet_active <= 0;
            bullet_x <= 0;
            bullet_y <= 0;
            bullet_timer_cnt <= 0;

            enemy0_active <= 0; enemy0_x <= 0; enemy0_y <= 0; enemy0_timer_cnt <= 0;
            enemy1_active <= 0; enemy1_x <= 0; enemy1_y <= 0; enemy1_timer_cnt <= 0;
            enemy2_active <= 0; enemy2_x <= 0; enemy2_y <= 0; enemy2_timer_cnt <= 0;

            hit <= 0;
            hit_count <= 0;
            score <= 0;

            spawn_timer_cnt <= 0;
            lfsr <= 8'hA5;
        end
        else begin
            hit <= 0;

            // LFSR update
            lfsr <= {lfsr[6:0],
                     (lfsr[7] ^ lfsr[5] ^ lfsr[4] ^ lfsr[3])
                    };

            // PLAYER movement
            if (left && !right) begin
                if (player_x > 0) player_x <= player_x - 1;
            end
            else if (right && !left) begin
                if (player_x < COLS-1) player_x <= player_x + 1;
            end

            // SHOOT
            if (shoot && !bullet_active) begin
                bullet_active <= 1'b1;
                bullet_x <= player_x;
                bullet_y <= PLAYER_ROW - 1;
                bullet_timer_cnt <= 0;
            end

            // EXTERNAL enemy spawn
            if (enemy_spawn) begin
                if (!enemy0_active) begin
                    enemy0_active <= 1;
                    enemy0_x <= enemy_init_x;
                    enemy0_y <= enemy_init_y;
                    enemy0_timer_cnt <= 0;
                end
                else if (!enemy1_active) begin
                    enemy1_active <= 1;
                    enemy1_x <= enemy_init_x;
                    enemy1_y <= enemy_init_y;
                    enemy1_timer_cnt <= 0;
                end
                else if (!enemy2_active) begin
                    enemy2_active <= 1;
                    enemy2_x <= enemy_init_x;
                    enemy2_y <= enemy_init_y;
                    enemy2_timer_cnt <= 0;
                end
            end

// --------------------------------------------------------
// AUTO SPAWN CONTROL (only if AUTO_SPAWN == 1)
// --------------------------------------------------------
if (AUTO_SPAWN) begin
    spawn_timer_cnt <= spawn_timer_cnt + 1;

    if (spawn_timer_cnt >= SPAWN_TIMER) begin
        spawn_timer_cnt <= 0;

        // count active enemies
 active_count = 0;
if (enemy0_active) active_count = active_count + 1;
if (enemy1_active) active_count = active_count + 1;
if (enemy2_active) active_count = active_count + 1;


        // maintain at least 2 enemies
        if (active_count < 2) begin
            if (!enemy0_active) begin
                enemy0_active <= 1;
                enemy0_x <= (lfsr[4:0] & 5'h13);   // FIXED — NO %
                enemy0_y <= 0;
                enemy0_timer_cnt <= 0;
            end
            else if (!enemy1_active) begin
                enemy1_active <= 1;
                enemy1_x <= (lfsr[4:0] & 5'h13);   // FIXED
                enemy1_y <= 0;
                enemy1_timer_cnt <= 0;
            end
            else if (!enemy2_active) begin
                enemy2_active <= 1;
                enemy2_x <= (lfsr[4:0] & 5'h13);   // FIXED
                enemy2_y <= 0;
                enemy2_timer_cnt <= 0;
            end
        end
        else begin
            // chance to spawn 3rd enemy
            if (lfsr[0] == 1'b1 && !enemy2_active) begin
                enemy2_active <= 1;
                enemy2_x <= (lfsr[4:0] & 5'h13);   // FIXED
                enemy2_y <= 0;
                enemy2_timer_cnt <= 0;
            end
        end
    end
end



            // BULLET movement
            if (bullet_active) begin
                bullet_timer_cnt <= bullet_timer_cnt + 1;
                if (bullet_timer_cnt >= BULLET_TIMER-1) begin
                    bullet_timer_cnt <= 0;
                    if (bullet_y > 0) bullet_y <= bullet_y - 1;
                    else bullet_active <= 0;
                end
            end

            // ENEMY 0 movement
            if (enemy0_active) begin
                enemy0_timer_cnt <= enemy0_timer_cnt + 1;
                if (enemy0_timer_cnt >= ENEMY_TIMER-1) begin
                    enemy0_timer_cnt <= 0;
                    if (enemy0_y < ROWS-1) enemy0_y <= enemy0_y + 1;
                    else enemy0_active <= 0;
                end
            end

            // ENEMY 1
            if (enemy1_active) begin
                enemy1_timer_cnt <= enemy1_timer_cnt + 1;
                if (enemy1_timer_cnt >= ENEMY_TIMER-1) begin
                    enemy1_timer_cnt <= 0;
                    if (enemy1_y < ROWS-1) enemy1_y <= enemy1_y + 1;
                    else enemy1_active <= 0;
                end
            end

            // ENEMY 2
            if (enemy2_active) begin
                enemy2_timer_cnt <= enemy2_timer_cnt + 1;
                if (enemy2_timer_cnt >= ENEMY_TIMER-1) begin
                    enemy2_timer_cnt <= 0;
                    if (enemy2_y < ROWS-1) enemy2_y <= enemy2_y + 1;
                    else enemy2_active <= 0;
                end
            end

            // COLLISION DETECTION
            if (bullet_active) begin
                // enemy0
                if (enemy0_active &&
                    bullet_x == enemy0_x &&
                    bullet_y == enemy0_y) begin
                    hit <= 1;
                    bullet_active <= 0;
                    enemy0_active <= 0;
                    score <= score + 1;
                    hit_count <= hit_count + 1;
                end
                // enemy1
                else if (enemy1_active &&
                         bullet_x == enemy1_x &&
                         bullet_y == enemy1_y) begin
                    hit <= 1;
                    bullet_active <= 0;
                    enemy1_active <= 0;
                    score <= score + 1;
                    hit_count <= hit_count + 1;
                end
                // enemy2
                else if (enemy2_active &&
                         bullet_x == enemy2_x &&
                         bullet_y == enemy2_y) begin
                    hit <= 1;
                    bullet_active <= 0;
                    enemy2_active <= 0;
                    score <= score + 1;
                    hit_count <= hit_count + 1;
                end
            end

        end
    end

endmodule
