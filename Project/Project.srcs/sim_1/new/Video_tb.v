module Video_tb();  
    // reg rst_n,load;
    reg clk=0;
    reg sclk=0;
    // reg [6:0]seed=1;
    // reg [6:0]rand_num;
    reg [7:0] num1;//divisor
    reg [7:0] num2;//dividen
    wire [15:0] result;
    wire out_clk;
    initial begin
        #10;
        clk=1;
        num1=255;
        num2=78;
        #100;
        clk=0;
        #150;
        $stop;
    end
    always #10 sclk=~sclk;
    // always@(posedge clk or negedge rst_n)  
    //     begin  
    //         if(!rst_n)  
    //             rand_num    <=8'b0;  
    //         else if(load)  
    //             rand_num <=seed;    /*load the initial value when load is active*/  
    //         else  
    //             begin  
    //                 rand_num[0] <= rand_num[6];  
    //                 rand_num[1] <= rand_num[0];  
    //                 rand_num[2] <= rand_num[1];  
    //                 rand_num[3] <= rand_num[2]^rand_num[6]; 
    //                 rand_num[4] <= rand_num[3]^rand_num[6];  
    //                 rand_num[5] <= rand_num[4]^rand_num[6];  
    //                 rand_num[6] <= rand_num[5];  
    //             end             
    //     end 
    div test(
        .aclk(sclk),
        .s_axis_divisor_tvalid(clk),    // input wire s_axis_divisor_tvalid
        .s_axis_divisor_tdata(num1),      // input wire [7 : 0] s_axis_divisor_tdata
        .s_axis_dividend_tvalid(clk),  // input wire s_axis_dividend_tvalid
        .s_axis_dividend_tdata(num2),    // input wire [7 : 0] s_axis_dividend_tdata
        .m_axis_dout_tvalid(out_clk),          // output wire m_axis_dout_tvalid
        .m_axis_dout_tdata(result)            // output wire [15 : 0] m_axis_dout_tdata
    );
endmodule  