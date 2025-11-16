`timescale 1ns/1ps
module game_tb3;

    reg clk, rst_n;
    reg left, right, shoot;
    reg enemy_spawn;
    reg [4:0] enemy_init_x;
    reg [3:0] enemy_init_y;

    wire [4:0] player_x;
    wire [3:0] player_y;
    wire [4:0] bullet_x;
    wire [3:0] bullet_y;
    wire        bullet_active;

    wire [4:0] enemy0_x, enemy1_x, enemy2_x;
    wire [3:0] enemy0_y, enemy1_y, enemy2_y;
    wire        enemy0_active, enemy1_active, enemy2_active;

    wire hit;
    wire [7:0] hit_count;
    wire [7:0] score;

game_design #(.AUTO_SPAWN(0)) dut(

        .clk(clk), .rst_n(rst_n),
        .left(left), .right(right), .shoot(shoot),
        .enemy_spawn(enemy_spawn),
        .enemy_init_x(enemy_init_x),
        .enemy_init_y(enemy_init_y),
        .player_x(player_x), .player_y(player_y),
        .bullet_x(bullet_x), .bullet_y(bullet_y),
        .bullet_active(bullet_active),
        .enemy0_x(enemy0_x), .enemy0_y(enemy0_y), .enemy0_active(enemy0_active),
        .enemy1_x(enemy1_x), .enemy1_y(enemy1_y), .enemy1_active(enemy1_active),
        .enemy2_x(enemy2_x), .enemy2_y(enemy2_y), .enemy2_active(enemy2_active),
        .hit(hit), .hit_count(hit_count), .score(score)
    );

    initial begin clk = 0; forever #1 clk = ~clk; end

    initial begin
        $dumpfile("tb3.vcd");
        $dumpvars(0, game_tb3);

        left=0; right=0; shoot=0;
        enemy_spawn=0; enemy_init_x=0; enemy_init_y=0;
        rst_n=0; #5 rst_n=1;

        // spawn enemy at center
        #2 enemy_init_x=5'd10; enemy_init_y=4'd5;
           enemy_spawn=1; #2 enemy_spawn=0;

        // fire but not aligned (player starts at x=10; move right first)
        #2 right=1; #2 right=0;
        #4 shoot=1; #2 shoot=0;  // MISS (player at x=11)

        // now align back under enemy
        #4 left=1; #2 left=0;

        // fire again – this time hit
        #4 shoot=1; #2 shoot=0;

        #250;

        $display("TB3: score=%0d hit_count=%0d", score, hit_count);
        $finish;
    end

endmodule
