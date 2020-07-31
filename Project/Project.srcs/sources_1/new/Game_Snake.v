module Game_Snake(
    input KEY_UP,
    input KEY_DOWN,
    input KEY_LEFT,
    input KEY_RIGHT,
    input KEY_State,
    input KEY_Speed,
    input clk,//74.25MHz,720P,to meet the timing requirement by avoiding using other clock
    // input RGB_VDE,
    input [11:0]Set_X,
    input [11:0]Set_Y,
    output reg[23:0]RGB_Data=24'hffffff //RBG
);
    parameter [1:0]Init = 2'd0;
    parameter [1:0]Start = 2'd1;
    parameter [1:0]Pause = 2'd2;
    parameter [1:0]End = 2'd3;
    // parameter Length_Init = 5'd2;
    parameter Size = 16; //unit size
    parameter [11:0] Box_Width = 12'd32;
    parameter bLeft = Box_Width-1;
    parameter bRight = 1280-Box_Width;
    parameter bUp = Box_Width-1;
    parameter bDown = 720-Box_Width;
    parameter [23:0]FontColor = 24'hf0000f;//foot color
    parameter [23:0]Brown = 24'hf0000f;//body color
    parameter [23:0]Black = 24'h000000;//head color
    parameter [23:0]Green = 24'h0f00f0;//food color
    parameter [23:0]Blue = 24'h00ff00;//Box frame color
    parameter [23:0]Gray = 24'hCCCCCC;//Background color
    parameter [23:0]Yellow = 24'hff00ff;//Background color
    parameter [7:0]Food_InitX = 8'd20;
    parameter [7:0]Food_InitY = 8'd25;
    parameter [1:0]Right=2'd0;
    parameter [1:0]Bottom=2'd1;
    parameter [1:0]Left=2'd2;
    parameter [1:0]Up=2'd3;
    parameter [31:0]Speed_0=32'd37_125_000;//0.5s
    parameter [31:0]Speed_1=32'd27_843_750;//0.375s
    parameter [31:0]Speed_2=32'd18_562_500;//0.25s
    parameter [31:0]Speed_3=32'd9_281_250;//0.125s
    parameter [31:0]Key_delay=32'd9_281_250;//50ms
    parameter [7:0]X_Left=8'd1;
    parameter [7:0]X_Right=8'd78;
    parameter [7:0]Y_Up=8'd1;
    parameter [7:0]Y_Bottom=8'd43;

    reg [31:0]Time_Cnt=0;//step moving timer
    reg [31:0]Step_time=Speed_0;//total time when the snake move one step
    reg [31:0]Next_Step_time=Speed_0;
    reg rst_cnt_game=0;//enable timer
    reg [31:0]Key_Cnt=0;//Key delay timer
    reg [1:0]Speed=0;//the speed of snake
    reg [1:0]State=0;//0--->Init,1--->Start,2--->Pause,3--->End
    reg [1:0]Next_State=0;//to refresh the state
    reg [7:0]Cnt_food=0;//the snake wins by eating 16 apples
    // reg [4:0]Length=Length_Init;//max length is 18(16+2),inlude the head and body
    reg [1:0]Move=Right;//0--->right,1--->up,2--->left,3--->down
    reg Food_Flag=1;//if the snake eat the food,refresh the flag
    reg [7:0] Food_X=Food_InitX;//Food position,2<-------->77,16*16 pixel
    reg [7:0] Food_Y=Food_InitY;//Food position,2<-------->42,16*16 pixel
    wire [15:0]foodX;//food pixel position
    wire [15:0]foodY;//food pixel position
    reg [7:0] Snake_X[0:16];//Snake position,2<-------->77,16*16 pixel
    reg [7:0] Snake_Y[0:16];//Snake position,2<-------->42,16*16 pixel
    wire [15:0] snakeX[0:16];//snake pixel position
    wire [15:0] snakeY[0:16];//snake pixel position
    wire Key_game=KEY_State|KEY_Speed|KEY_UP|KEY_DOWN|KEY_LEFT|KEY_RIGHT;//one key down

    reg [9:0]Address=0;
    wire [7:0]Box_R_Data;
    wire [7:0]Box_G_Data;
    wire [7:0]Box_B_Data;
    reg [13:0]AddressU1=0;
    wire [7:0]P1_R_Data;
    wire [7:0]P1_G_Data;
    wire [7:0]P1_B_Data;

    //Key delay timer
    always @ (Key_game) begin
        if(Key_game)
            rst_cnt_game<=1;//start counting
        else
            rst_cnt_game<=0;//stop counting
    end

    //detect the key to transfer the state and change the direction of snake
    always @ (posedge clk) begin
        if(rst_cnt_game)
            if(Key_Cnt<Key_delay)
                Key_Cnt<=Key_Cnt+1;
            else
                begin
                    if(KEY_State) begin//change the state
                        case(State) 
                            Init:Next_State<=Start;
                            Start:Next_State<=Pause;
                            Pause:Next_State<=Start;
                            //This state must be triggered by the game logic
                            End:begin 
                                Next_State<=Init;//init the game set
                                Move<=Right;//reset direction
                                Speed<=0;//reset speed
                                Next_Step_time<=Speed_0;//reset speed
                            end
                        endcase
                    end
                    else if(KEY_Speed) begin
                        if(State==Start) begin
                            Speed=Speed+1;//speed up,using blocking assignment
                            case(Speed)
                                0:Next_Step_time<=Speed_0;
                                1:Next_Step_time<=Speed_1;
                                2:Next_Step_time<=Speed_2;
                                3:Next_Step_time<=Speed_3;
                            endcase
                        end
                    end
                    //Judge if the snake can turn around
                    else if(KEY_UP) begin
                        if(State==Start) begin
                            if(Move==Bottom)
                                Move<=Bottom;
                            else
                                Move<=Up;
                        end
                    end
                    else if(KEY_DOWN) begin
                        if(State==Start) begin
                            if(Move==Up)
                                Move<=Up;
                            else
                                Move<=Bottom;
                        end
                    end
                    else if(KEY_LEFT) begin
                        if(State==Start) begin
                            if(Move==Right)
                                Move<=Right;
                            else
                                Move<=Left;
                        end
                    end
                    else begin//turn right
                        if(State==Start) begin
                            if(Move==Left)
                                Move<=Left;
                            else
                                Move<=Right;
                        end
                    end
                    Key_Cnt<=0;//reset
                end
        else 
            Key_Cnt<=0;//keep resetting
    end

    //core logic,to control the snake and refresh the Snake_X,Snake_Y,Food_X,Food_Y.etc.
    always @ (posedge clk) begin
        //refresh the Current State
        if(State==End) begin
            if(Next_State==Init)
                State<=Next_State;//Avoid the multi-driven error!Do not refresh the Next_State in this process.
        end
        else
            State<=Next_State;
        if(State==Init) begin
            Cnt_food<=0;
            Snake_X[0]<=8'd10;Snake_Y[0]<=8'd35;//head position
            Snake_X[1]<=8'd9;Snake_Y[1]<=8'd35;//head position
            Snake_X[2]<=8'd0;Snake_Y[2]<=8'd0;
            Snake_X[3]<=8'd0;Snake_Y[3]<=8'd0;
            Snake_X[4]<=8'd0;Snake_Y[4]<=8'd0;
            Snake_X[5]<=8'd0;Snake_Y[5]<=8'd0;
            Snake_X[6]<=8'd0;Snake_Y[6]<=8'd0;
            Snake_X[7]<=8'd0;Snake_Y[7]<=8'd0;
            Snake_X[8]<=8'd0;Snake_Y[8]<=8'd0;
            Snake_X[9]<=8'd0;Snake_Y[9]<=8'd0;
            Snake_X[10]<=8'd0;Snake_Y[10]<=8'd0;
            Snake_X[11]<=8'd0;Snake_Y[11]<=8'd0;
            Snake_X[12]<=8'd0;Snake_Y[12]<=8'd0;
            Snake_X[13]<=8'd0;Snake_Y[13]<=8'd0;
            Snake_X[14]<=8'd0;Snake_Y[14]<=8'd0;
            Snake_X[15]<=8'd0;Snake_Y[15]<=8'd0;
            Snake_X[16]<=8'd0;Snake_Y[16]<=8'd0;
        end
        //Running
        else if(State==Start) begin
            //Step moving timer
            if(Step_time!=Next_Step_time) begin
                Time_Cnt<=0;//reset the timer
                Step_time<=Next_Step_time;
            end
            else begin
                if(Time_Cnt<Step_time) begin 
                    Time_Cnt<=Time_Cnt+1;
                end
                else begin
                    /*Judge whether the snake hit the wall,hurt self or win*/
                    Time_Cnt<=0;//reset step counter
                    if(Cnt_food<15) begin//food left
                        if(Snake_X[0]>X_Left&&Snake_X[0]<X_Right&&Snake_Y[0]>Y_Up&&Snake_Y[0]<Y_Bottom) begin
                            if(Food_X==Snake_X[0]&&Food_Y==Snake_Y[0]) begin
                                // Length<=Length+1;//the snake grow up
                                Cnt_food<=Cnt_food+1;//the snake eat the food
                            end
                            case(Cnt_food)//0--->15
                                0:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                end
                                1:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                end
                                2:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                end
                                3:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                end
                                4:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                end
                                5:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                end
                                6:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                end
                                7:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                end
                                8:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                end
                                9:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                end
                                10:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                    Snake_X[11]<=Snake_X[10];Snake_Y[11]<=Snake_Y[10];
                                end
                                11:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                    Snake_X[11]<=Snake_X[10];Snake_Y[11]<=Snake_Y[10];
                                    Snake_X[12]<=Snake_X[11];Snake_Y[12]<=Snake_Y[11];
                                end
                                12:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                    Snake_X[11]<=Snake_X[10];Snake_Y[11]<=Snake_Y[10];
                                    Snake_X[12]<=Snake_X[11];Snake_Y[12]<=Snake_Y[11];
                                    Snake_X[13]<=Snake_X[12];Snake_Y[13]<=Snake_Y[12];
                                end
                                13:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                    Snake_X[11]<=Snake_X[10];Snake_Y[11]<=Snake_Y[10];
                                    Snake_X[12]<=Snake_X[11];Snake_Y[12]<=Snake_Y[11];
                                    Snake_X[13]<=Snake_X[12];Snake_Y[13]<=Snake_Y[12];
                                    Snake_X[14]<=Snake_X[13];Snake_Y[14]<=Snake_Y[13];
                                end
                                14:begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                    Snake_X[11]<=Snake_X[10];Snake_Y[11]<=Snake_Y[10];
                                    Snake_X[12]<=Snake_X[11];Snake_Y[12]<=Snake_Y[11];
                                    Snake_X[13]<=Snake_X[12];Snake_Y[13]<=Snake_Y[12];
                                    Snake_X[14]<=Snake_X[13];Snake_Y[14]<=Snake_Y[13];
                                    Snake_X[15]<=Snake_X[14];Snake_Y[15]<=Snake_Y[14];
                                end
                                15: begin
                                    if(Move==Right)
                                        Snake_X[0]<=Snake_X[0]+1;
                                    else if(Move==Bottom)
                                        Snake_Y[0]<=Snake_Y[0]+1;
                                    else if(Move==Left)
                                        Snake_X[0]<=Snake_X[0]-1;
                                    else 
                                        Snake_Y[0]<=Snake_Y[0]-1;
                                    Snake_X[1]<=Snake_X[0];
                                    Snake_Y[1]<=Snake_Y[0];
                                    Snake_X[2]<=Snake_X[1];Snake_Y[2]<=Snake_Y[1];
                                    Snake_X[3]<=Snake_X[2];Snake_Y[3]<=Snake_Y[2];
                                    Snake_X[4]<=Snake_X[3];Snake_Y[4]<=Snake_Y[3];
                                    Snake_X[5]<=Snake_X[4];Snake_Y[5]<=Snake_Y[4];
                                    Snake_X[6]<=Snake_X[5];Snake_Y[6]<=Snake_Y[5];
                                    Snake_X[7]<=Snake_X[6];Snake_Y[7]<=Snake_Y[6];
                                    Snake_X[8]<=Snake_X[7];Snake_Y[8]<=Snake_Y[7];
                                    Snake_X[9]<=Snake_X[8];Snake_Y[9]<=Snake_Y[8];
                                    Snake_X[10]<=Snake_X[9];Snake_Y[10]<=Snake_Y[9];
                                    Snake_X[11]<=Snake_X[10];Snake_Y[11]<=Snake_Y[10];
                                    Snake_X[12]<=Snake_X[11];Snake_Y[12]<=Snake_Y[11];
                                    Snake_X[13]<=Snake_X[12];Snake_Y[13]<=Snake_Y[12];
                                    Snake_X[14]<=Snake_X[13];Snake_Y[14]<=Snake_Y[13];
                                    Snake_X[15]<=Snake_X[14];Snake_Y[15]<=Snake_Y[14];
                                    Snake_X[16]<=Snake_X[15];Snake_Y[16]<=Snake_Y[15];
                                end
                            endcase
                            //hurt self.The length of snake must be over 5.
                            if(Snake_X[0]==Snake_X[4]&&Snake_Y[0]==Snake_Y[4])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[5]&&Snake_Y[0]==Snake_Y[5])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[6]&&Snake_Y[0]==Snake_Y[6])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[7]&&Snake_Y[0]==Snake_Y[7])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[8]&&Snake_Y[0]==Snake_Y[8])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[9]&&Snake_Y[0]==Snake_Y[9])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[10]&&Snake_Y[0]==Snake_Y[10])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[11]&&Snake_Y[0]==Snake_Y[11])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[12]&&Snake_Y[0]==Snake_Y[12])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[13]&&Snake_Y[0]==Snake_Y[13])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[14]&&Snake_Y[0]==Snake_Y[14])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[15]&&Snake_Y[0]==Snake_Y[15])
                                State<=End;
                            else if(Snake_X[0]==Snake_X[16]&&Snake_Y[0]==Snake_Y[16])
                                State<=End;
                            else if(Snake_X[0]>=20&&Snake_X[0]<=23&&Snake_Y[0]>=20&&Snake_Y[0]<=23)
                                State<=End;
                            else if(Snake_X[0]>=67&&Snake_X[0]<=70&&Snake_Y[0]>=32&&Snake_Y[0]<=35)
                                State<=End;
                        end
                        //Hit the wall
                        else
                            State<=End;
                    end
                    else //all food is eaten
                        State<=End;
                end
            end
        end
        //Pause
        else if(State==Pause) begin
            /*do something here,but there is no need to disable the step timer*/
        end
        //Game over
        else begin
            /*do something here*/
        end 
    end

    //refresh the food position,use pre stored data
    always @ (Cnt_food) begin
        case(Cnt_food)
            //store the food position,set maxnum is 16
            0:begin Food_X<=Food_InitX;Food_Y<=Food_InitY; end
            1:begin Food_X<=25;Food_Y<=20; end
            2:begin Food_X<=55;Food_Y<=10; end
            3:begin Food_X<=66;Food_Y<=42; end
            4:begin Food_X<=13;Food_Y<=30; end
            5:begin Food_X<=48;Food_Y<=3; end
            6:begin Food_X<=44;Food_Y<=26; end
            7:begin Food_X<=20;Food_Y<=40; end
            8:begin Food_X<=10;Food_Y<=16; end
            9:begin Food_X<=7;Food_Y<=20; end
            10:begin Food_X<=55;Food_Y<=33; end
            11:begin Food_X<=2;Food_Y<=8; end
            12:begin Food_X<=76;Food_Y<=2; end
            13:begin Food_X<=70;Food_Y<=36; end
            14:begin Food_X<=60;Food_Y<=17; end
            15:begin Food_X<=39;Food_Y<=21; end
        endcase
    end

    //refresh the screen,use Snake_X,Snake_Y,Food_X,Food_Y,Cnt_food,Move,State
    always@(*) begin
        //the snake area
        if(Set_X>=bLeft && Set_X<bRight && Set_Y>=bUp && Set_Y<bDown) begin
            case (State)
                Init: begin
                    /*Initial interface*/
                    if(Set_X>=483 && Set_X<797 && Set_Y>=280 && Set_Y<440) begin
                        //'G'
                        if(Set_X>=483&&Set_X<499&&Set_Y>=280&&Set_Y<440)
                            RGB_Data<=FontColor;
                        else if(Set_X>=567&&Set_X<583&&Set_Y>=280&&Set_Y<330)
                            RGB_Data<=FontColor;
                        else if(Set_X>=567&&Set_X<583&&Set_Y>=370&&Set_Y<440)
                            RGB_Data<=FontColor;
                        else if(Set_X>=518&&Set_X<605&&Set_Y>=370&&Set_Y<386)
                            RGB_Data<=FontColor;
                        else if(Set_X>=483&&Set_X<583&&Set_Y>=280&&Set_Y<296)
                            RGB_Data<=FontColor;
                        else if(Set_X>=567&&Set_X<583&&Set_Y>=280&&Set_Y<296)
                            RGB_Data<=FontColor;
                        else if(Set_X>=483&&Set_X<583&&Set_Y>=424&&Set_Y<440)
                            RGB_Data<=FontColor;
                        //'O'
                        else if(Set_X>=781&&Set_X<797&&Set_Y>=280&&Set_Y<440)
                            RGB_Data<=FontColor;
                        else if(Set_X>=681&&Set_X<697&&Set_Y>=280&&Set_Y<440)
                            RGB_Data<=FontColor;
                        else if(Set_X>=681&&Set_X<781&&Set_Y>=424&&Set_Y<440)
                            RGB_Data<=FontColor;
                        else if(Set_X>=681&&Set_X<781&&Set_Y>=280&&Set_Y<296)
                            RGB_Data<=FontColor;
                        else 
                            RGB_Data<=Gray; 
                    end
                    else    
                        RGB_Data<=Gray;
                end
                Start: begin
                    /*Running interface*/
                    if(Set_X>=320&&Set_X<352&&Set_Y>=320&&Set_Y<352) begin//(20,20)
                        Address=(Set_X-319)*32+(Set_Y-319);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=352&&Set_X<384&&Set_Y>=320&&Set_Y<352) begin//(21,20)
                        Address=(Set_X-351)*32+(Set_Y-319);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=320&&Set_X<352&&Set_Y>=352&&Set_Y<384) begin//(20,21)
                        Address=(Set_X-319)*32+(Set_Y-351);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=352&&Set_X<384&&Set_Y>=352&&Set_Y<384) begin//(20,21)
                        Address=(Set_X-351)*32+(Set_Y-351);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1072&&Set_X<1105&&Set_Y>=512&&Set_Y<544) begin//(67,32)
                        Address=(Set_X-1071)*32+(Set_Y-511);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1105&&Set_X<1137&&Set_Y>=512&&Set_Y<544) begin//(68,32)
                        Address=(Set_X-1104)*32+(Set_Y-511);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1072&&Set_X<1105&&Set_Y>=544&&Set_Y<576) begin//(67,33)
                        Address=(Set_X-1071)*32+(Set_Y-543);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1105&&Set_X<1137&&Set_Y>=544&&Set_Y<576) begin//(68,33)
                        Address=(Set_X-1104)*32+(Set_Y-543);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else
                        case(Cnt_food)
                            0:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            1:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            2:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            3:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            4:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            5:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            6:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            7:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            8:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            9:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            10:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            11:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            12:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            13:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            14:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[15] && Set_Y<(snakeY[15]+Size) && Set_X>=snakeX[15] && Set_X<(snakeX[15]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Blue;
                                else
                                    RGB_Data<=Gray;
                            15:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[15] && Set_Y<(snakeY[15]+Size) && Set_X>=snakeX[15] && Set_X<(snakeX[15]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[16] && Set_Y<(snakeY[16]+Size) && Set_X>=snakeX[16] && Set_X<(snakeX[16]+Size))
                                    RGB_Data<=Brown;
                                // else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                //     RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                        endcase
                end
                Pause:begin
                    /*Pause interface*/
                    if(Set_X>=320&&Set_X<352&&Set_Y>=320&&Set_Y<352) begin//(20,20)
                        Address=(Set_X-319)*32+(Set_Y-319);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=352&&Set_X<384&&Set_Y>=320&&Set_Y<352) begin//(21,20)
                        Address=(Set_X-351)*32+(Set_Y-319);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=320&&Set_X<352&&Set_Y>=352&&Set_Y<384) begin//(20,21)
                        Address=(Set_X-319)*32+(Set_Y-351);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=352&&Set_X<384&&Set_Y>=352&&Set_Y<384) begin//(20,21)
                        Address=(Set_X-351)*32+(Set_Y-351);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1072&&Set_X<1105&&Set_Y>=512&&Set_Y<544) begin//(67,32)
                        Address=(Set_X-1071)*32+(Set_Y-511);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1105&&Set_X<1137&&Set_Y>=512&&Set_Y<544) begin//(68,32)
                        Address=(Set_X-1104)*32+(Set_Y-511);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1072&&Set_X<1105&&Set_Y>=544&&Set_Y<576) begin//(67,33)
                        Address=(Set_X-1071)*32+(Set_Y-543);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else if(Set_X>=1105&&Set_X<1137&&Set_Y>=544&&Set_Y<576) begin//(68,33)
                        Address=(Set_X-1104)*32+(Set_Y-543);
                        RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                    end
                    else
                        case(Cnt_food)
                            0:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            1:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            2:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            3:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            4:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            5:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            6:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            7:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            8:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            9:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            10:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            11:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            12:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            13:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                            14:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[15] && Set_Y<(snakeY[15]+Size) && Set_X>=snakeX[15] && Set_X<(snakeX[15]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                    RGB_Data<=Blue;//the last food
                                else
                                    RGB_Data<=Gray;
                            15:
                                if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                    RGB_Data<=Black;
                                else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[15] && Set_Y<(snakeY[15]+Size) && Set_X>=snakeX[15] && Set_X<(snakeX[15]+Size))
                                    RGB_Data<=Brown;
                                else if(Set_Y>=snakeY[16] && Set_Y<(snakeY[16]+Size) && Set_X>=snakeX[16] && Set_X<(snakeX[16]+Size))
                                    RGB_Data<=Brown;
                                // else if(Set_Y>=foodY && Set_Y<(foodY+Size) && Set_X>=foodX && Set_X<(foodX+Size))
                                //     RGB_Data<=Yellow;
                                else
                                    RGB_Data<=Gray;
                        endcase
                end
                End: begin
                    /*End interface,game over or win*/
                    if(Cnt_food<15) begin//Game over
                        if(Set_X>=590 && Set_X<690 && Set_Y>=310 && Set_Y<410) begin
                            AddressU1=(Set_X-589)*100+(Set_Y-309);
                            RGB_Data<={P1_R_Data,P1_B_Data,P1_G_Data};
                        end
                        else 
                            RGB_Data<=Gray;
                    end
                    else begin//You win
                        if(Set_X>=320&&Set_X<352&&Set_Y>=320&&Set_Y<352) begin//(20,20)
                            Address=(Set_X-319)*32+(Set_Y-319);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=352&&Set_X<384&&Set_Y>=320&&Set_Y<352) begin//(21,20)
                            Address=(Set_X-351)*32+(Set_Y-319);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=320&&Set_X<352&&Set_Y>=352&&Set_Y<384) begin//(20,21)
                            Address=(Set_X-319)*32+(Set_Y-351);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=352&&Set_X<384&&Set_Y>=352&&Set_Y<384) begin//(20,21)
                            Address=(Set_X-351)*32+(Set_Y-351);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=1072&&Set_X<1105&&Set_Y>=512&&Set_Y<544) begin//(67,32)
                            Address=(Set_X-1071)*32+(Set_Y-511);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=1105&&Set_X<1137&&Set_Y>=512&&Set_Y<544) begin//(68,32)
                            Address=(Set_X-1104)*32+(Set_Y-511);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=1072&&Set_X<1105&&Set_Y>=544&&Set_Y<576) begin//(67,33)
                            Address=(Set_X-1071)*32+(Set_Y-543);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else if(Set_X>=1105&&Set_X<1137&&Set_Y>=544&&Set_Y<576) begin//(68,33)
                            Address=(Set_X-1104)*32+(Set_Y-543);
                            RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                        end
                        else begin
                            if(Set_Y>=snakeY[0] && Set_Y<(snakeY[0]+Size) && Set_X>=snakeX[0] && Set_X<(snakeX[0]+Size))
                                RGB_Data<=Black;
                            else if(Set_Y>=snakeY[1] && Set_Y<(snakeY[1]+Size) && Set_X>=snakeX[1] && Set_X<(snakeX[1]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[2] && Set_Y<(snakeY[2]+Size) && Set_X>=snakeX[2] && Set_X<(snakeX[2]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[3] && Set_Y<(snakeY[3]+Size) && Set_X>=snakeX[3] && Set_X<(snakeX[3]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[4] && Set_Y<(snakeY[4]+Size) && Set_X>=snakeX[4] && Set_X<(snakeX[4]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[5] && Set_Y<(snakeY[5]+Size) && Set_X>=snakeX[5] && Set_X<(snakeX[5]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[6] && Set_Y<(snakeY[6]+Size) && Set_X>=snakeX[6] && Set_X<(snakeX[6]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[7] && Set_Y<(snakeY[7]+Size) && Set_X>=snakeX[7] && Set_X<(snakeX[7]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[8] && Set_Y<(snakeY[8]+Size) && Set_X>=snakeX[8] && Set_X<(snakeX[8]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[9] && Set_Y<(snakeY[9]+Size) && Set_X>=snakeX[9] && Set_X<(snakeX[9]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[10] && Set_Y<(snakeY[10]+Size) && Set_X>=snakeX[10] && Set_X<(snakeX[10]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[11] && Set_Y<(snakeY[11]+Size) && Set_X>=snakeX[11] && Set_X<(snakeX[11]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[12] && Set_Y<(snakeY[12]+Size) && Set_X>=snakeX[12] && Set_X<(snakeX[12]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[13] && Set_Y<(snakeY[13]+Size) && Set_X>=snakeX[13] && Set_X<(snakeX[13]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[14] && Set_Y<(snakeY[14]+Size) && Set_X>=snakeX[14] && Set_X<(snakeX[14]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[15] && Set_Y<(snakeY[15]+Size) && Set_X>=snakeX[15] && Set_X<(snakeX[15]+Size))
                                RGB_Data<=Yellow;
                            else if(Set_Y>=snakeY[16] && Set_Y<(snakeY[16]+Size) && Set_X>=snakeX[16] && Set_X<(snakeX[16]+Size))
                                RGB_Data<=Yellow;
                            else
                                RGB_Data<=Gray;
                        end
                    end
                end
            endcase
        end
        //the frame area
        else begin
            if(Set_X>=0&&Set_X<32) begin
                if(Set_Y>=0&&Set_Y<32) begin
                    Address=(Set_X-0)*32+(Set_Y-31);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=32&&Set_Y<40)
                    RGB_Data<=Gray;
                else if(Set_Y>=40&&Set_Y<72) begin
                    Address=(Set_X-0)*32+(Set_Y-71);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=72&&Set_Y<104) begin
                    Address=(Set_X-0)*32+(Set_Y-103);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=104&&Set_Y<136) begin
                    Address=(Set_X-0)*32+(Set_Y-135);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=136&&Set_Y<168) begin
                    Address=(Set_X-0)*32+(Set_Y-167);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=168&&Set_Y<200) begin
                    Address=(Set_X-0)*32+(Set_Y-199);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=200&&Set_Y<232) begin
                    Address=(Set_X-0)*32+(Set_Y-231);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=232&&Set_Y<264) begin
                    Address=(Set_X-0)*32+(Set_Y-263);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=264&&Set_Y<296) begin
                    Address=(Set_X-0)*32+(Set_Y-295);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=296&&Set_Y<328) begin
                    Address=(Set_X-0)*32+(Set_Y-327);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=328&&Set_Y<360) begin
                    Address=(Set_X-0)*32+(Set_Y-359);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=360&&Set_Y<392) begin
                    Address=(Set_X-0)*32+(Set_Y-391);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=392&&Set_Y<424) begin
                    Address=(Set_X-0)*32+(Set_Y-423);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=424&&Set_Y<456) begin
                    Address=(Set_X-0)*32+(Set_Y-455);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=456&&Set_Y<488) begin
                    Address=(Set_X-0)*32+(Set_Y-487);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=488&&Set_Y<520) begin
                    Address=(Set_X-0)*32+(Set_Y-519);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=520&&Set_Y<552) begin
                    Address=(Set_X-0)*32+(Set_Y-551);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=552&&Set_Y<584) begin
                    Address=(Set_X-0)*32+(Set_Y-583);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=584&&Set_Y<616) begin
                    Address=(Set_X-0)*32+(Set_Y-615);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=616&&Set_Y<648) begin
                    Address=(Set_X-0)*32+(Set_Y-647);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=648&&Set_Y<680) begin
                    Address=(Set_X-0)*32+(Set_Y-679);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=680&&Set_Y<688) begin
                    RGB_Data<=Gray;
                end
                else if(Set_Y>=688&&Set_Y<720) begin
                    Address=(Set_X-0)*32+(Set_Y-719);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
            end
            else if(Set_X>=1248&&Set_X<1280) begin
                if(Set_Y>=0&&Set_Y<32) begin
                    Address=(Set_X-1248)*32+(Set_Y-32);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=32&&Set_Y<40)
                    RGB_Data<=Gray;
                else if(Set_Y>=40&&Set_Y<72) begin
                    Address=(Set_X-1248)*32+(Set_Y-72);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=72&&Set_Y<104) begin
                    Address=(Set_X-1248)*32+(Set_Y-104);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=104&&Set_Y<136) begin
                    Address=(Set_X-1248)*32+(Set_Y-136);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=136&&Set_Y<168) begin
                    Address=(Set_X-1248)*32+(Set_Y-168);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=168&&Set_Y<200) begin
                    Address=(Set_X-1248)*32+(Set_Y-200);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=200&&Set_Y<232) begin
                    Address=(Set_X-1248)*32+(Set_Y-232);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=232&&Set_Y<264) begin
                    Address=(Set_X-1248)*32+(Set_Y-264);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=264&&Set_Y<296) begin
                    Address=(Set_X-1248)*32+(Set_Y-296);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=296&&Set_Y<328) begin
                    Address=(Set_X-1248)*32+(Set_Y-328);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=328&&Set_Y<360) begin
                    Address=(Set_X-1248)*32+(Set_Y-360);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=360&&Set_Y<392) begin
                    Address=(Set_X-1248)*32+(Set_Y-392);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=392&&Set_Y<424) begin
                    Address=(Set_X-1248)*32+(Set_Y-424);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=424&&Set_Y<456) begin
                    Address=(Set_X-1248)*32+(Set_Y-456);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=456&&Set_Y<488) begin
                    Address=(Set_X-1248)*32+(Set_Y-488);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=488&&Set_Y<520) begin
                    Address=(Set_X-1248)*32+(Set_Y-520);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=520&&Set_Y<552) begin
                    Address=(Set_X-1248)*32+(Set_Y-552);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=552&&Set_Y<584) begin
                    Address=(Set_X-1248)*32+(Set_Y-584);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=584&&Set_Y<616) begin
                    Address=(Set_X-1248)*32+(Set_Y-616);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=616&&Set_Y<648) begin
                    Address=(Set_X-1248)*32+(Set_Y-648);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=648&&Set_Y<680) begin
                    Address=(Set_X-1248)*32+(Set_Y-680);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_Y>=680&&Set_Y<688) begin
                    RGB_Data<=Gray;
                end
                else if(Set_Y>=688&&Set_Y<720) begin
                    Address=(Set_X-1248)*32+(Set_Y-720);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
            end
            else if(Set_Y>=0&&Set_Y<32) begin
                if(Set_X>=32&&Set_X<64) begin
                    Address=(Set_X-32)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=64&&Set_X<96) begin
                    Address=(Set_X-64)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=96&&Set_X<128) begin
                    Address=(Set_X-96)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=128&&Set_X<160) begin
                    Address=(Set_X-128)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=160&&Set_X<192) begin
                    Address=(Set_X-160)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=192&&Set_X<224) begin
                    Address=(Set_X-192)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=224&&Set_X<256) begin
                    Address=(Set_X-224)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=256&&Set_X<288) begin
                    Address=(Set_X-256)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=288&&Set_X<320) begin
                    Address=(Set_X-288)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=320&&Set_X<352) begin
                    Address=(Set_X-320)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=352&&Set_X<384) begin
                    Address=(Set_X-352)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=384&&Set_X<416) begin
                    Address=(Set_X-384)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=416&&Set_X<448) begin
                    Address=(Set_X-416)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=448&&Set_X<480) begin
                    Address=(Set_X-448)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=480&&Set_X<512) begin
                    Address=(Set_X-480)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=512&&Set_X<544) begin
                    Address=(Set_X-512)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=544&&Set_X<576) begin
                    Address=(Set_X-544)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=576&&Set_X<608) begin
                    Address=(Set_X-576)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=608&&Set_X<640) begin
                    Address=(Set_X-608)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=640&&Set_X<672) begin
                    Address=(Set_X-640)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=672&&Set_X<704) begin
                    Address=(Set_X-672)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=704&&Set_X<736) begin
                    Address=(Set_X-704)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=736&&Set_X<768) begin
                    Address=(Set_X-736)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=768&&Set_X<800) begin
                    Address=(Set_X-768)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=800&&Set_X<832) begin
                    Address=(Set_X-800)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=832&&Set_X<864) begin
                    Address=(Set_X-832)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=864&&Set_X<896) begin
                    Address=(Set_X-864)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=896&&Set_X<928) begin
                    Address=(Set_X-896)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=928&&Set_X<960) begin
                    Address=(Set_X-928)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=960&&Set_X<992) begin
                    Address=(Set_X-960)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=992&&Set_X<1024) begin
                    Address=(Set_X-992)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1024&&Set_X<1056) begin
                    Address=(Set_X-1024)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1056&&Set_X<1088) begin
                    Address=(Set_X-1056)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1088&&Set_X<1120) begin
                    Address=(Set_X-1088)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1120&&Set_X<1152) begin
                    Address=(Set_X-1120)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1152&&Set_X<1184) begin
                    Address=(Set_X-1152)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1184&&Set_X<1216) begin
                    Address=(Set_X-1184)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1216&&Set_X<1248) begin
                    Address=(Set_X-1216)*32+(Set_Y-0);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
            end
            else if(Set_Y>=688&&Set_Y<720) begin
                if(Set_X>=32&&Set_X<64) begin
                    Address=(Set_X-32)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=64&&Set_X<96) begin
                    Address=(Set_X-64)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=96&&Set_X<128) begin
                    Address=(Set_X-96)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=128&&Set_X<160) begin
                    Address=(Set_X-128)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=160&&Set_X<192) begin
                    Address=(Set_X-160)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=192&&Set_X<224) begin
                    Address=(Set_X-192)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=224&&Set_X<256) begin
                    Address=(Set_X-224)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=256&&Set_X<288) begin
                    Address=(Set_X-256)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=288&&Set_X<320) begin
                    Address=(Set_X-288)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=320&&Set_X<352) begin
                    Address=(Set_X-320)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=352&&Set_X<384) begin
                    Address=(Set_X-352)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=384&&Set_X<416) begin
                    Address=(Set_X-384)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=416&&Set_X<448) begin
                    Address=(Set_X-416)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=448&&Set_X<480) begin
                    Address=(Set_X-448)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=480&&Set_X<512) begin
                    Address=(Set_X-480)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=512&&Set_X<544) begin
                    Address=(Set_X-512)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=544&&Set_X<576) begin
                    Address=(Set_X-544)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=576&&Set_X<608) begin
                    Address=(Set_X-576)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=608&&Set_X<640) begin
                    Address=(Set_X-608)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=640&&Set_X<672) begin
                    Address=(Set_X-640)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=672&&Set_X<704) begin
                    Address=(Set_X-672)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=704&&Set_X<736) begin
                    Address=(Set_X-704)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=736&&Set_X<768) begin
                    Address=(Set_X-736)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=768&&Set_X<800) begin
                    Address=(Set_X-768)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=800&&Set_X<832) begin
                    Address=(Set_X-800)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=832&&Set_X<864) begin
                    Address=(Set_X-832)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=864&&Set_X<896) begin
                    Address=(Set_X-864)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                if(Set_X>=896&&Set_X<928) begin
                    Address=(Set_X-896)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=928&&Set_X<960) begin
                    Address=(Set_X-928)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=960&&Set_X<992) begin
                    Address=(Set_X-960)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=992&&Set_X<1024) begin
                    Address=(Set_X-992)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1024&&Set_X<1056) begin
                    Address=(Set_X-1024)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1056&&Set_X<1088) begin
                    Address=(Set_X-1056)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1088&&Set_X<1120) begin
                    Address=(Set_X-1088)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1120&&Set_X<1152) begin
                    Address=(Set_X-1120)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1152&&Set_X<1184) begin
                    Address=(Set_X-1152)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1184&&Set_X<1216) begin
                    Address=(Set_X-1184)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
                else if(Set_X>=1216&&Set_X<1248) begin
                    Address=(Set_X-1216)*32+(Set_Y-688);
                    RGB_Data<={Box_R_Data,Box_B_Data,Box_G_Data};
                end
            end
        end
    end
    //UI
    P1_B_Rom P1_B (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .addra(AddressU1),  // input wire [13 : 0] addra
        .douta(P1_B_Data)  // output wire [7 : 0] douta
    );
    P1_R_Rom P1_R (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .addra(AddressU1),  // input wire [13 : 0] addra
        .douta(P1_R_Data)  // output wire [7 : 0] douta
    );
    P1_G_Rom P1_G (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .addra(AddressU1),  // input wire [13 : 0] addra
        .douta(P1_G_Data)  // output wire [7 : 0] douta
    );
    //display frame
    Box_R_Rom Box_R (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .addra(Address),  // input wire [9 : 0] addra
        .douta(Box_R_Data)  // output wire [7 : 0] douta
    );
    Box_G_Rom Box_G (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .addra(Address),  // input wire [9 : 0] addra
        .douta(Box_G_Data)  // output wire [7 : 0] douta
    );
    Box_B_Rom Box_B (
        .clka(clk),    // input wire clka
        .ena(1),      // input wire ena
        .addra(Address),  // input wire [9 : 0] addra
        .douta(Box_B_Data)  // output wire [7 : 0] douta
    );
    
    //use multiplier to compute pixel position of the food and snake
    mult foodx (
        .CLK(clk),  // input wire CLK
        .A(Food_X),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(foodX)      // output wire [15 : 0] P
    );
    mult foody (
        .CLK(clk),  // input wire CLK
        .A(Food_Y),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(foodY)      // output wire [15 : 0] P
    );
    mult snakex_0 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[0]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[0])      // output wire [15 : 0] P
    );
    mult snakey_0 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[0]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[0])      // output wire [15 : 0] P
    );
    mult snakex_1 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[1]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[1])      // output wire [15 : 0] P
    );
    mult snakey_1 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[1]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[1])      // output wire [15 : 0] P
    );
    mult snakex_2 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[2]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[2])      // output wire [15 : 0] P
    );
    mult snakey_2 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[2]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[2])      // output wire [15 : 0] P
    );
    mult snakex_3 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[3]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[3])      // output wire [15 : 0] P
    );
    mult snakey_3 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[3]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[3])      // output wire [15 : 0] P
    );
    mult snakex_4 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[4]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[4])      // output wire [15 : 0] P
    );
    mult snakey_4 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[4]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[4])      // output wire [15 : 0] P
    );
    mult snakex_5 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[5]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[5])      // output wire [15 : 0] P
    );
    mult snakey_5 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[5]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[5])      // output wire [15 : 0] P
    );
    mult snakex_6 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[6]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[6])      // output wire [15 : 0] P
    );
    mult snakey_6 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[6]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[6])      // output wire [15 : 0] P
    );
    mult snakex_7 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[7]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[7])      // output wire [15 : 0] P
    );
    mult snakey_7(
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[7]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[7])      // output wire [15 : 0] P
    );
    mult snakex_8 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[8]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[8])      // output wire [15 : 0] P
    );
    mult snakey_8 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[8]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[8])      // output wire [15 : 0] P
    );
    mult snakex_9 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[9]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[9])      // output wire [15 : 0] P
    );
    mult snakey_9 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[9]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[9])      // output wire [15 : 0] P
    );
    mult snakex_10 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[10]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[10])      // output wire [15 : 0] P
    );
    mult snakey_10 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[10]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[10])      // output wire [15 : 0] P
    );
    mult snakex_11 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[11]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[11])      // output wire [15 : 0] P
    );
    mult snakey_11 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[11]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[11])      // output wire [15 : 0] P
    );
    mult snakex_12 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[12]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[12])      // output wire [15 : 0] P
    );
    mult snakey_12 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[12]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[12])      // output wire [15 : 0] P
    );
    mult snakex_13 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[13]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[13])      // output wire [15 : 0] P
    );
    mult snakey_13 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[13]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[13])      // output wire [15 : 0] P
    );
    mult snakex_14 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[14]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[14])      // output wire [15 : 0] P
    );
    mult snakey_14 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[14]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[14])      // output wire [15 : 0] P
    );
    mult snakex_15 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[15]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[15])      // output wire [15 : 0] P
    );
    mult snakey_15 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[15]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[15])      // output wire [15 : 0] P
    );
    mult snakex_16 (
        .CLK(clk),  // input wire CLK
        .A(Snake_X[16]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeX[16])      // output wire [15 : 0] P
    );
    mult snakey_16 (
        .CLK(clk),  // input wire CLK
        .A(Snake_Y[16]),      // input wire [7 : 0] A
        .B(8'd16),      // input wire [7 : 0] B
        .P(snakeY[16])      // output wire [15 : 0] P
    );
endmodule