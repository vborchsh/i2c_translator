
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
  reg      [2:0]      sda_periph     ;
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
  wire                out_sda_bf     ;
  wire                out_sda_periph ;
  reg                 fr_scl         ;
  reg                 f_iscl_        ;
  reg                 f_ibf_         ;
  reg                 no_tr          ;
  reg                 dir_           ;
  reg                 dir__          ;
  reg      [9:0]      cnt_scl        ;
  reg      [3:0]      cnt_bits       ;
  reg                 head_tx        ;
  reg                 ack_bit        ;
  reg                 fr_ibf         ;
  reg                 obf            ;
  reg                 oph            ;

  //--------------------------------------------------------------
  // BODY
  //--------------------------------------------------------------

  // Fast input registers
  always@(posedge iclk) begin
    f_iscl    <= isck        ;
    f_ibf     <= isda_bf     ;
    f_iperiph <= isda_periph ;
  end

  // Input signals with metastability considered
  always@(posedge iclk) begin
    sda_bf     <= {sda_bf    [1:0], f_ibf    } ;
    sda_periph <= {sda_periph[1:0], f_iperiph} ;
  end


  // Detecting out tansmition from MASTER
  always@(posedge iclk) begin
    if (!f_iscl)         cnt_scl <= '0 ;
    else if (~&cnt_scl)  cnt_scl <= cnt_scl + 1'b1 ;

    no_tr <= cnt_scl>=768 ;
  end

  // Counter of transmitted bits, always negedge MASTER oscl
  always@(posedge iclk) begin
    f_iscl_ <= f_iscl ;
    fr_scl  <= ~f_iscl & f_iscl_ ;

    f_ibf_  <= f_ibf ;
    fr_ibf  <= f_ibf & ~f_ibf_ ;

    if (no_tr)               cnt_bits <= '0 ;
    else if (cnt_bits >= 9)  cnt_bits <= '0 ;
      else if (fr_scl)       cnt_bits <= cnt_bits + 1'b1 ;
  end

  // Set direction of ack bit
  always@(posedge iclk) begin
    if (cnt_bits == 8)       ack_bit <= (!dir) ? (sda_periph[1]) : (sda_bf[1]) ;
  end

  // Set flag of transmitted header (address + r/w bit)
  always@(posedge iclk) begin
    if (no_tr)               head_tx <= 1'b0 ;
    else if (cnt_bits == 9)  head_tx <= 1'b1 ;
  end

  // Change SDA data direction
  always@(posedge iclk) begin
    // Check r/w bit on head packet, for set direction
    if (no_tr)                                        dir__ <= 1'b0 ;
    else if ((cnt_bits==7) & sda_bf[1] & (!head_tx))  dir__ <= 1'b1 ;

    // Delay for not recieve ACK bit on packet
    if (cnt_scl == 127)                               dir_ <= dir__ ;

    // Change direction only after send head packet
    if (no_tr & fr_ibf)                               dir <= '0 ;
    else                                              dir <= dir__ & head_tx ;
  end

  assign out_sda_bf     =  dir & !sda_periph[1] ;
  assign out_sda_periph = !dir & !sda_bf    [1] ;

  // Change ACK bit direction in each packet
  always@(posedge iclk)  obf <= (cnt_bits == 8) ? (!ack_bit) : (out_sda_bf) ;
  always@(posedge iclk)  oph <= (cnt_bits == 8) ? (!ack_bit) : (out_sda_periph) ;

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