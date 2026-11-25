`timescale 1ns / 1ps
`default_nettype none

module tt_um_top_module_16_mips (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,
    input  wire       clk,
    input  wire       rst_n
);

    wire [6:0] addr;
    wire       we;
    wire [7:0] dout;

    mips_cpu cpu (
        .clk(clk),
        .rst_n(rst_n),
        .ena(ena),
        .ui_in(ui_in),
        .din(uio_in),
        .addr(addr),
        .we(we),
        .dout(dout)
    );

    assign uo_out  = {we, addr};
    assign uio_out = dout;
    assign uio_oe  = {8{we}};

endmodule

module alu (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire [2:0]  op,
    output reg  [15:0] y
);
    always @(*) begin
        case (op)
            3'd1: y = a - b;
            3'd2: y = a | b;
            3'd3: y = a ^ b;
            default: y = a + b;
        endcase
    end
endmodule

module regfile (
    input  wire       clk,
    input  wire [1:0] readReg1,
    input  wire [1:0] readReg2,
    input  wire [1:0] writeReg,
    input  wire [15:0] writeData,
    input  wire       RegWrite,
    output wire [15:0] readData1,
    output wire [15:0] readData2
);
    reg [15:0] registers [3:0];

    assign readData1 = (readReg1 == 2'b00) ? 16'h0000 : registers[readReg1];
    assign readData2 = (readReg2 == 2'b00) ? 16'h0000 : registers[readReg2];

    always @(posedge clk) begin
        if (RegWrite && writeReg != 2'b00)
            registers[writeReg] <= writeData;
    end
endmodule

module mips_cpu (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       ena,
    input  wire [7:0] ui_in,
    input  wire [7:0] din,
    output reg  [6:0] addr,
    output reg        we,
    output reg  [7:0] dout
);
    localparam FETCH0 = 3'd0;
    localparam FETCH1 = 3'd1;
    localparam EXEC   = 3'd2;
    localparam LD0    = 3'd3;
    localparam LD1    = 3'd4;
    localparam ST0    = 3'd5;
    localparam ST1    = 3'd6;
    localparam LDPORT = 3'd7;

    reg [2:0] state;
    reg [6:0] pc;
    reg [15:0] ir;
    reg [7:0] lo;

    wire [3:0] op = ir[15:12];
    wire [7:0] rdbyte = (addr == 7'h7f) ? ui_in : din;
    wire [15:0] imm_s = {{8{ir[7]}}, ir[7:0]};
    wire [15:0] rs_val;
    wire [15:0] rt_val;
    wire [15:0] alu_b = (op == 4'h6) ? imm_s : rt_val;
    wire [2:0] alu_op =
        (op == 4'h1) ? 3'd1 :
        (op == 4'h2) ? 3'd3 :
        (op == 4'h3) ? 3'd2 : 3'd0;
    wire [15:0] alu_y;
    wire [15:0] sum = rs_val + imm_s;
    wire [6:0] ea = sum[6:0];
    wire arith = (state == EXEC) && (op <= 4'h3 || op == 4'h6);
    wire reg_we = arith || (state == LD1) || (state == LDPORT);
    wire [1:0] wreg = (op <= 4'h3) ? ir[7:6] : ir[9:8];
    wire [15:0] wr_data =
        (state == LDPORT) ? {8'h00, ui_in} :
        (state == LD1)    ? {rdbyte, lo} :
        alu_y;

    regfile rf (
        .clk(clk),
        .readReg1(ir[11:10]),
        .readReg2(ir[9:8]),
        .writeReg(wreg),
        .writeData(wr_data),
        .RegWrite(reg_we & ena & rst_n),
        .readData1(rs_val),
        .readData2(rt_val)
    );

    alu alu_unit (
        .a(rs_val),
        .b(alu_b),
        .op(alu_op),
        .y(alu_y)
    );

    always @(posedge clk) begin
        if (!rst_n) begin
            pc <= 7'd0;
            ir <= 16'd0;
            lo <= 8'd0;
            addr <= 7'd0;
            we <= 1'b0;
            dout <= 8'd0;
            state <= FETCH0;
        end else if (!ena) begin
            we <= 1'b0;
        end else begin
            case (state)
                FETCH0: begin
                    lo <= rdbyte;
                    addr <= pc + 7'd1;
                    we <= 1'b0;
                    state <= FETCH1;
                end
                FETCH1: begin
                    ir <= {rdbyte, lo};
                    we <= 1'b0;
                    state <= EXEC;
                end
                EXEC: begin
                    we <= 1'b0;
                    case (op)
                        4'h0, 4'h1, 4'h2, 4'h3, 4'h6: begin
                            pc <= pc + 7'd2;
                            addr <= pc + 7'd2;
                            state <= FETCH0;
                        end
                        4'h4: begin
                            addr <= ea;
                            if (ea == 7'h7f)
                                state <= LDPORT;
                            else
                                state <= LD0;
                        end
                        4'h5: begin
                            addr <= ea;
                            dout <= rt_val[7:0];
                            we <= 1'b1;
                            state <= ST0;
                        end
                        4'h7: begin
                            pc <= ir[6:0];
                            addr <= ir[6:0];
                            state <= FETCH0;
                        end
                        4'h8: begin
                            if (rs_val == rt_val) begin
                                pc <= ir[6:0];
                                addr <= ir[6:0];
                            end else begin
                                pc <= pc + 7'd2;
                                addr <= pc + 7'd2;
                            end
                            state <= FETCH0;
                        end
                        default: begin
                            pc <= pc + 7'd2;
                            addr <= pc + 7'd2;
                            state <= FETCH0;
                        end
                    endcase
                end
                LD0: begin
                    lo <= rdbyte;
                    addr <= addr + 7'd1;
                    we <= 1'b0;
                    state <= LD1;
                end
                LD1: begin
                    pc <= pc + 7'd2;
                    addr <= pc + 7'd2;
                    we <= 1'b0;
                    state <= FETCH0;
                end
                ST0: begin
                    addr <= ea + 7'd1;
                    dout <= rt_val[15:8];
                    we <= 1'b1;
                    state <= ST1;
                end
                ST1: begin
                    pc <= pc + 7'd2;
                    addr <= pc + 7'd2;
                    we <= 1'b0;
                    state <= FETCH0;
                end
                LDPORT: begin
                    pc <= pc + 7'd2;
                    addr <= pc + 7'd2;
                    we <= 1'b0;
                    state <= FETCH0;
                end
                default: begin
                    we <= 1'b0;
                    state <= FETCH0;
                end
            endcase
        end
    end
endmodule
