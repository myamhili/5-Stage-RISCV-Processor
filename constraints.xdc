# Create a 100 MHz clock on the 'clk' port (10 ns period)
create_clock -period 10.000 -name clk [get_ports clk]

# By default, Vivado will attempt to insert IO buffers for the top-level ports.
# Since we are just analyzing the processor core and not wiring it to physical pins right now:
set_property IO_BUFFER_TYPE NONE [get_ports *]
