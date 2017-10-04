
  // I2C interface translator
  // MASTER <-> FPGA <-> SLAVE's

module i2c_translator
  (
    iclk        , // 96 MHz

    isck        ,
    isda_bf     ,
    isda_periph ,

    osck        ,
    osda_bf     ,
    osda_periph
  );

  input               iclk        ;

  input               isck        ;
  input               isda_bf     ;
  input               isda_periph ;

  output              osck        ;
  output              osda_bf     ;
  output              osda_periph ;

  //--------------------------------------------------------------
  // Declaration internal variables
  //--------------------------------------------------------------

  reg      [2:0]      sda_bf         ;
  reg      [2:0]      sda_ph         ;
  reg                 dir            ;
  // Fast input reg
  reg                 f_iscl         ;
  reg                 f_ibf          ;
  reg                 f_iperiph      ;
  // Fast output regs
  reg                 f_obf          ;
  reg                 f_operiph      ;
  reg                 f_osclk        ;
  // Some other variables
  logic               fr_scl         ;
  logic               f_iscl_        ;
  logic               no_tr          ;
  logic    [9:0]      cnt_scl        ;
  logic    [3:0]      cnt_bits       ;
  logic               head_tx        ;
  logic               rw_bit         ;
  logic               rw_st          ;
  logic               pre_rw_st      ;
  logic               ack_bit        ;
  logic               pre_dir        ;
  logic               end_pack       ;
  logic               end_byte       ;
  logic               obf            ;
  logic               oph            ;

  //--------------------------------------------------------------
  // BODY
  //--------------------------------------------------------------

  // Fast input registers
  always@(posedge iclk) begin
    f_iscl    <= isck        ;
    f_ibf     <= isda_bf     ;
    f_iperiph <= isda_periph ;
  end

  // Input signals with metastability & rattling compensate
  // Mb up size??? to one byte...
  always@(posedge iclk) begin
    sda_bf <= sda_bf << 1 | f_ibf ;
    sda_ph <= sda_ph << 1 | f_iperiph ;
  end

  // Detecting out transmition from MASTER
  always@(posedge iclk) begin
    if (!f_iscl)         cnt_scl <= '0 ;
    else if (~&cnt_scl)  cnt_scl <= cnt_scl + 1'b1 ;

    no_tr <= cnt_scl>=768 ;
  end

  // Counter of transmitted bits, always negedge MASTER oscl
  always@(posedge iclk) begin
    f_iscl_ <= f_iscl ;
    fr_scl  <= ~f_iscl & f_iscl_ ;

    if (no_tr)               cnt_bits <= '0 ;
    else if (cnt_bits >= 9)  cnt_bits <= '0 ;
      else if (fr_scl)       cnt_bits <= cnt_bits + 1'b1 ;
  end

  // Services bits in packet
  assign rw_bit   = (cnt_bits == 7) & ~head_tx ;
  assign ack_bit  = (cnt_bits == 8) ;
  assign end_byte = (cnt_bits >= 9) ;

  always@(posedge iclk) begin
    // Transmitted header of I2C packet
    if (no_tr || end_pack)    head_tx   <= 1'b0 ;
    else if (end_byte)        head_tx   <= 1'b1 ;

    // Set read/write status of packet
    if (no_tr)                pre_rw_st <= 1'b0 ;
    else if (rw_bit)          pre_rw_st <= (sda_bf==0) ; // 1 - WR, 0 - RD

    if (no_tr)                rw_st     <= 1'b0 ;
    else if (end_byte)        rw_st     <= pre_rw_st ;

    // Set direction of I2C data stream
    if (rw_bit)               pre_dir   <= &sda_bf ;

    if (no_tr)                       dir <= 1'b0    ;
    else if (ack_bit)                dir <= (!rw_st & ~head_tx) || (rw_st & head_tx) ;
      else if (end_byte & ~head_tx)  dir <= pre_dir ;
        else if (end_byte)           dir <= pre_dir ;
          else if (end_pack)         dir <= 1'b0    ;

    // Detect end of all I2C data packet
    if (end_byte & rw_st)  end_pack <= &sda_bf ;
    else                   end_pack <= '0 ;
  end

  // Commutation output I2C stream
  assign obf =  dir & (sda_ph==0) ;
  assign oph = !dir & (sda_bf==0) ;

  // Fast output registers
  always@(posedge iclk) begin
    f_obf     <= (obf)     ? (1'b0) : (1'bz) ;
    f_operiph <= (oph)     ? (1'b0) : (1'bz) ;
    f_osclk   <= (!f_iscl) ? (1'b0) : (1'bz) ;
  end

  //--------------------------------------------------------------
  // Output signals
  //--------------------------------------------------------------

  assign osda_bf     = f_obf ;
  assign osda_periph = f_operiph ;
  assign osck        = f_osclk ;

endmodule