/*############################################# Mini Project ##################################################################*/

/*********************************************** RTL *************************************************************************/

module counter(input clk,input [3:0]data_in,input reset,load,up_down,output reg [3:0]count);

always@(posedge clk)
	begin
		if(reset)
			count <= 4'b0000;

		else if(load)
			count <= data_in;

		else
                  begin
			case(up_down)

			  1'b0:  if(count == 4'b0000)
				   count <= 4'b1011;
			     	else
				   count <= count - 1'b1;
			 
			  1'b1:	 if(count == 4'b1011)
			           count <= 4'b0000;
				else
				   count <= count + 1'b1;
		  	endcase
		  end
	end

endmodule

/******************************************* Physical Interface ***************************************************************/

interface counter_if(input bit clk);

//interface signals

logic reset;
logic load;
logic up_down;
logic [3:0]data_in;
logic [3:0]count;

//Driver Clocking Block

clocking wr_drv_cb@(posedge clk);
default input #1 output #1;

output reset;
output load;
output up_down;
output data_in;

endclocking

//Write Monitor Clocking Block

clocking wr_mon_cb@(posedge clk);
default input #1 output #1;

input reset;
input load;
input up_down;
input data_in;

endclocking

//Read Monitor Clocking Block

clocking rd_mon_cb@(posedge clk);
default input #1 output #1;

input count;

endclocking

//Write driver Modport
modport WR_DRV_MP (clocking wr_drv_cb);

//Write monitor Modport
modport WR_MON_MP (clocking wr_mon_cb);

//Read monitor Modport
modport RD_MON_MP (clocking rd_mon_cb);

endinterface

/*********************************************** TRANSACTION CLASS *************************************************************/

class counter_trans;

//interface signals

rand logic reset;
rand logic load;
rand logic up_down;
rand logic [3:0]data_in;

logic [3:0]count;

static int trans_id;
static int no_of_up_count_trans;
static int no_of_down_count_trans;

//constraints

constraint VALID_RESET{reset dist{1:=30, 0:=70};}
constraint VALID_LOAD{load dist{0:=70, 1:=30};}
constraint VALID_MODE{up_down dist{0:=50, 1:=50};}
constraint VALID_DATA{data_in inside{[0:11]};}
//constraint LOAD_UP_DOWN{{load,up_down} != 2'b11;}

virtual function void display(input string message);
	$display("-----------------------------------------------------------");
	$display("%s",message);
	$display("\ttransaction_id = %d",trans_id);
	$display("\tno_of_up_count_trans = %d",no_of_up_count_trans);
	$display("\tno_of_down_count_trans = %d",no_of_down_count_trans);
	$display("\treset = %d",reset);
	$display("\tload = %d",load);
	$display("\tup_down = %d",up_down);
	$display("\tdata_in = %d",data_in);
	$display("\tcount = %d",count);
endfunction

function void post_randomize();

	trans_id++;
//	if(this.reset==0 && this.load==0 && this.up_down==1);
	if(up_down==1)
		no_of_up_count_trans++;
//	if(this.reset==0 && this.load==0 && this.up_down==0);
	if(up_down==0)
		no_of_down_count_trans++;
	this.display("\tRANDOMIZED DATA");

endfunction

endclass

/*********************************************** GENERATOR CLASS **************************************************************/

class counter_gen;

  counter_trans gen_trans;
  counter_trans data2send;

  mailbox #(counter_trans) gen2wr;

  function new(mailbox #(counter_trans) gen2wr);
	this.gen2wr = gen2wr;
	this.gen_trans = new();
  endfunction

  virtual task start();
	fork
		begin
			for(int i=0;i<100;i++)
			   begin
				assert(gen_trans.randomize());
				data2send = new gen_trans;
				gen2wr.put(data2send);
			   end
		end
	join_none
   endtask

endclass

/********************************************* WRITE DRIVER CLASS *************************************************************/

class counter_wr_drv;

   virtual counter_if.WR_DRV_MP wr_drv_if;

   counter_trans data2duv;

   mailbox #(counter_trans) gen2wr;

  function new(virtual counter_if.WR_DRV_MP wr_drv_if, mailbox #(counter_trans) gen2wr);
	this.wr_drv_if = wr_drv_if;
	this.gen2wr = gen2wr;
  endfunction       

  virtual task drive();
     @(wr_drv_if.wr_drv_cb);
	wr_drv_if.wr_drv_cb.reset <= data2duv.reset;
	wr_drv_if.wr_drv_cb.load <= data2duv.load;
	wr_drv_if.wr_drv_cb.up_down <= data2duv.up_down;
	wr_drv_if.wr_drv_cb.data_in <= data2duv.data_in;
	
	repeat(2)	//continuous 2 clock cycles load will be 1'b0 
	@(wr_drv_if.wr_drv_cb);
	  wr_drv_if.wr_drv_cb.load <= 1'b0;

   endtask

  virtual task start();
      fork
	forever
	    begin
		gen2wr.get(data2duv);
		drive();
	    end
      join_none
  endtask

endclass

/********************************************* WRITE MONITOR CLASS ***************************************************************/

class counter_wr_mon;

  virtual counter_if.WR_MON_MP wr_mon_if;

  mailbox #(counter_trans) wr2rm;
  
 // counter_trans wr_data;
  counter_trans wrmon2rm;

  function new(virtual counter_if.WR_MON_MP wr_mon_if, mailbox #(counter_trans) wr2rm);
	this.wr_mon_if = wr_mon_if;
	this.wr2rm = wr2rm;
	this.wrmon2rm = new();
  endfunction

  virtual task monitor();

  @(wr_mon_if.wr_mon_cb);
//  wait(wr_mon_if.wr_mon_cb.load==1)
//  @(wr_mon_if.wr_mon_cb);

  begin
	wrmon2rm.reset = wr_mon_if.wr_mon_cb.reset;
	wrmon2rm.load = wr_mon_if.wr_mon_cb.load;
	wrmon2rm.up_down = wr_mon_if.wr_mon_cb.up_down;
	wrmon2rm.data_in = wr_mon_if.wr_mon_cb.data_in;
	
	wrmon2rm.display("DATA FROM WRITE MONITOR");
  end

  endtask

  virtual task start();
	fork
		forever
		    begin
			monitor();
		//	data2rm = new wrmon2rm;
			wr2rm.put(wrmon2rm);
		    end
	join_none
  endtask

endclass

/************************************************ READ MONITOR CLASS *******************************************************/

class counter_rd_mon;

  virtual counter_if.RD_MON_MP rd_mon_if;

  mailbox #(counter_trans) mon2sb;

  counter_trans rd_data;
  counter_trans data2sb;

  function new(virtual counter_if.RD_MON_MP rd_mon_if, mailbox #(counter_trans) mon2sb);
	this.rd_mon_if = rd_mon_if;
	this.mon2sb = mon2sb;
	this.rd_data = new();
  endfunction

  virtual task monitor();

  @(rd_mon_if.rd_mon_cb);
 // wait(rd_mon_if.rd_mon_cb.load==0)
 // @(rd_mon_if.rd_mon_cb);

  begin
	rd_data.count = rd_mon_if.rd_mon_cb.count;
	
	rd_data.display("DATA FROM READ MONITOR");
  end

  endtask

  virtual task start();

	fork
		forever
		     begin
			monitor();
			data2sb = new rd_data;
			mon2sb.put(data2sb);
		     end
	join_none

  endtask

endclass

/********************************************** REFERENCE MODEL Class *********************************************************/

class counter_ref_model;

  counter_trans wr_mon_data;

  mailbox #(counter_trans) wr2rm;
  mailbox #(counter_trans) rm2sb;

  function new(mailbox #(counter_trans) wr2rm, mailbox #(counter_trans) rm2sb);
	this.wr2rm = wr2rm;
	this.rm2sb = rm2sb;
  endfunction

  virtual task counter_fun(counter_trans wr_mon_data);
	begin
		if(wr_mon_data.reset)
			wr_mon_data.count <= 4'd0;

		else if(wr_mon_data.load)
			wr_mon_data.count <= wr_mon_data.data_in;

		else
		    begin
			case(wr_mon_data.up_down)

			  1'b0:  if(wr_mon_data.count == 4'b0000)
				   wr_mon_data.count <= 4'b1011;
			     	else
				   wr_mon_data.count <= wr_mon_data.count - 1'b1;
			 
			  1'b1:	 if(wr_mon_data.count == 4'b1011)
			           wr_mon_data.count <= 4'b0000;
				else
				   wr_mon_data.count <= wr_mon_data.count + 1'b1;
		  	endcase
		   end
	end
  endtask

  virtual task start();
	fork
		begin
			forever
			     begin
				wr2rm.get(wr_mon_data);
				counter_fun(wr_mon_data);
				rm2sb.put(wr_mon_data);
			     end
		end
	join_none
  endtask

endclass

/**************************************************** SCOREBOARD Class **************************************************/

class counter_sb;

  event DONE;
 
  int reference_data;
  int read_mon_data;
  int data_verified;

  counter_trans rm_data;
  counter_trans rd_mon_data;
  counter_trans coverage_data;

  mailbox #(counter_trans) rm2sb;
  mailbox #(counter_trans) rd2sb;

  covergroup mem_coverage;

  RESET:   coverpoint coverage_data.reset;

  LOAD:    coverpoint coverage_data.load;

  UP_DOWN: coverpoint coverage_data.up_down;

  DATA_IN: coverpoint coverage_data.data_in{
					bins LOW = {[0:5]};
  					bins MAX = {[6:11]};}

  RESETxLOADxDATA_IN: cross RESET,LOAD,DATA_IN;

  endgroup
   

  function  new(mailbox #(counter_trans) rm2sb, mailbox #(counter_trans) rd2sb);
	this.rm2sb = rm2sb;
	this.rd2sb = rd2sb;
        this.coverage_data = new();
	this.mem_coverage = new();
  endfunction

  virtual task check(counter_trans rc_data);
 	begin
		if(rm_data.count == rc_data.count)
			$display("COUNTER DATA MATCH");
		else
			begin
				$display("COUNTER DATA NOT MATCH");
			end

		coverage_data = new rm_data;
		mem_coverage.sample();
		data_verified++;

	if(data_verified >= 100)
		  begin
			->DONE;
		  end
	end
  endtask

  virtual task start();
	fork
		forever
			begin
				rm2sb.get(rm_data);
				reference_data++;

				rd2sb.get(rd_mon_data);
				read_mon_data++;

				check(rd_mon_data);
			end
	join_none
  endtask

  function void report();

  $display("---------------------- SCOREBOARD REPORT ------------------------------");
  $display("%0d REF_DATA, %0d RD_MON_DATA, %0d DATA_VERIFIED\n",reference_data,read_mon_data,data_verified);
  $display("-----------------------------------------------------------------------");

  endfunction

endclass

/************************************************ ENVIRONMENT Class ************************************************************/

class counter_env;

  // instantiation of modport interfaces

  virtual counter_if.WR_DRV_MP wr_drv_if;
  virtual counter_if.WR_MON_MP wr_mon_if;
  virtual counter_if.RD_MON_MP rd_mon_if;

  // creating object for mailboxes

  mailbox #(counter_trans)gen2wr = new();
  mailbox #(counter_trans)wr2rm = new();
  mailbox #(counter_trans)rd2sb = new();
  mailbox #(counter_trans)rm2sb = new();

  // creating handlers for TB Components

  counter_gen		gen_h;
  counter_wr_drv	wr_drv_h;
  counter_wr_mon	wr_mon_h;
  counter_rd_mon	rd_mon_h;
  counter_ref_model	ref_mod_h;
  counter_sb		sb_h;

  function new( virtual counter_if.WR_DRV_MP wr_drv_if,
 		 virtual counter_if.WR_MON_MP wr_mon_if,
  		virtual counter_if.RD_MON_MP rd_mon_if);

	this.wr_drv_if = wr_drv_if;
	this.wr_mon_if = wr_mon_if;
	this.rd_mon_if = rd_mon_if;

  endfunction

  //task to creating objects for TB Components 

  task build;

  		gen_h		= new(gen2wr);
 	        wr_drv_h	= new(wr_drv_if,gen2wr);
 	        wr_mon_h	= new(wr_mon_if,wr2rm);
  		rd_mon_h	= new(rd_mon_if,rd2sb);
 	        ref_mod_h	= new(wr2rm,rm2sb);
 	        sb_h		= new(rm2sb,rd2sb);
  endtask

  //task start

  task start();

	gen_h.start();
	wr_drv_h.start();
	wr_mon_h.start();
	rd_mon_h.start();
	ref_mod_h.start();
	sb_h.start();

  endtask

  //task stop
  
  task stop();
	wait(sb_h.DONE.triggered);
  endtask

  //task run

  task run();
 	start();
	stop();
	sb_h.report();
  endtask

endclass

/****************************************************** TESTCASE-1 ****************************************************/

class test;

  virtual counter_if.WR_DRV_MP wr_drv_if;
  virtual counter_if.WR_MON_MP wr_mon_if;
  virtual counter_if.RD_MON_MP rd_mon_if;

  //Declare a handle for the Environment

  counter_env env_h;

  function new(virtual counter_if.WR_DRV_MP wr_drv_if,
  		virtual counter_if.WR_MON_MP wr_mon_if,
 		 virtual counter_if.RD_MON_MP rd_mon_if);

	this.wr_drv_if = wr_drv_if;
	this.wr_mon_if = wr_mon_if;
	this.rd_mon_if = rd_mon_if;
	env_h = new(wr_drv_if,wr_mon_if,rd_mon_if);

  endfunction

  //task which builds the TB Enviroment and runs the simulation

  task build_and_run();
	begin
	//	number_of_transactions = 500;
		
		//Build the Environment
		env_h.build();

		//Run the TB Environment
		env_h.run();

		$finish;
	end
  endtask

endclass 

/***************************************************** COUNTER TOP **********************************************************/

module top();

  parameter cycle = 10;
  reg clock;
  
  //Instantiate the interface
  counter_if DUV_IF(clock);

  //Declare a handle for the Testcase-1
  test test_h;

  //Instantiate the DUV
  counter DUV(.clk(DUV_IF.clk),.data_in(DUV_IF.data_in),.reset(DUV_IF.reset),.load(DUV_IF.load),.up_down(DUV_IF.up_down),.count(DUV_IF.count));

  //Generate the clock
  initial
	begin
		clock = 1'b0;
		forever #(cycle/2) clock = ~clock;
	end

  initial
	begin

	//	if($test$piusargs("TEST1"))
	//	  begin
			//Create the object for test and pass the interface instance as arguements

			test_h = new(DUV_IF,DUV_IF,DUV_IF);	//connect physical interface instance with virtual interface handles

			//Call the task build and run

			test_h.build_and_run();
	//	  end
	end

endmodule
