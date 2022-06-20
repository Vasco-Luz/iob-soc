#DEFINES

#default baud and freq for simulation
BAUD ?=5000000
FREQ ?=100000000

#define for testbench
DEFINE+=$(defmacro)BAUD=$(BAUD)
DEFINE+=$(defmacro)FREQ=$(FREQ)

#ddr controller address width
DDR_ADDR_W=$(DCACHE_ADDR_W)

#produce waveform dump
VCD ?=0

ifeq ($(VCD),1)
DEFINE+=$(defmacro)VCD
endif

include $(ROOT_DIR)/hardware/hardware.mk

ifeq ($(USE_ETHERNET),)
CONSOLE_CMD=$(CONSOLE_DIR)/console -L
else
CONSOLE_CMD=$(CONSOLE_DIR)/console -L -e $(ETHERNET_DIR) -i $(ETH_IF) -m $(RMAC_ADDR)
endif

ifeq ($(INIT_MEM),0)
CONSOLE_CMD+=-f
endif

FW_SIZE=$(shell wc -l tester_firmware.hex | awk '{print $$1}')

DEFINE+=$(defmacro)FW_SIZE=$(FW_SIZE)

#SOURCES

#verilog testbench
TB_DIR:=$(HW_DIR)/simulation/verilog_tb

#axi memory
include $(AXI_DIR)/hardware/axiram/hardware.mk

#axi interconnect
ifeq ($(USE_DDR),1)
VSRC+=$(AXI_DIR)/submodules/V_AXI/rtl/axi_interconnect.v
VSRC+=$(AXI_DIR)/submodules/V_AXI/rtl/arbiter.v
VSRC+=$(AXI_DIR)/submodules/V_AXI/rtl/priority_encoder.v
endif

VSRC+=system_top.v

#testbench
ifneq ($(SIMULATOR),verilator)
VSRC+=system_tb.v
endif

#add peripheral testbench sources
VSRC+=$(foreach p, $(sort PERIPHERALS), $(shell if test -f $($p_DIR)/hardware/testbench/module_tb.sv; then echo $($p_DIR)/hardware/testbench/module_tb.sv; fi;)) 

#RULES
build: $(VSRC) $(VHDR) $(HEXPROGS) get_vsrc get_vhdr get_tester_defines
ifeq ($(SIM_SERVER),)
	make comp
else
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --force --exclude .git $(SIM_SYNC_FLAGS) $(ROOT_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)
	rsync -avz --delete --force --exclude .git $(SIM_SYNC_FLAGS) $($(UUT_NAME)_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_UUT_DIR)
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) 'make -C $(REMOTE_ROOT_DIR) sim-build SIMULATOR=$(SIMULATOR) INIT_MEM=$(INIT_MEM) USE_DDR=$(USE_DDR) RUN_EXTMEM=$(RUN_EXTMEM) VCD=$(VCD) TEST_LOG=\"$(TEST_LOG)\"'
endif

run: sim
ifeq ($(VCD),1)
	if [ ! `pgrep -u $(USER) gtkwave` ]; then gtkwave -a ../waves.gtkw system.vcd; fi &
endif

sim:
ifeq ($(SIM_SERVER),)
	cp $(FIRM_DIR)/firmware.bin .
	@rm -f soc2cnsl cnsl2soc
	$(CONSOLE_CMD) $(TEST_LOG) &
	bash -c "trap 'make kill-sim' INT TERM KILL EXIT; make exec"
else
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --force --exclude .git $(SIM_SYNC_FLAGS) $(ROOT_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)
	bash -c "trap 'make kill-remote-sim' INT TERM KILL; ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) 'make -C $(REMOTE_ROOT_DIR)/hardware/simulation/$(SIMULATOR) $@ SIMULATOR=$(SIMULATOR) INIT_MEM=$(INIT_MEM) USE_DDR=$(USE_DDR) RUN_EXTMEM=$(RUN_EXTMEM) VCD=$(VCD) TEST_LOG=\"$(TEST_LOG)\"'"
ifneq ($(TEST_LOG),)
	scp $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)/hardware/simulation/$(SIMULATOR)/test.log $(SIM_DIR)
endif
ifeq ($(VCD),1)
	scp $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)/hardware/simulation/$(SIMULATOR)/*.vcd $(SIM_DIR)
endif
endif

#
#EDIT TOP OR TB DEPENDING ON SIMULATOR
#

system_tb.v:
	$(SW_DIR)/python/createTestbench.py $(ROOT_DIR) "$(GET_DIRS)" "$(PERIPHERALS)"

#create  simulation top module
system_top.v: $(TB_DIR)/system_top_core.v
	$(SW_DIR)/python/createTopSystem.py $(ROOT_DIR) "../../peripheral_portmap.conf" "$(GET_DIRS)" "$(PERIPHERALS)"

kill-remote-sim:
	@echo "INFO: Remote simulator $(SIMULATOR) will be killed"
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) 'killall -q -u $(SIM_USER) -9 $(SIM_PROC); \
	make -C $(REMOTE_ROOT_DIR)/hardware/simulation/$(SIMULATOR) kill-sim'
ifeq ($(VCD),1)
	scp $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)/hardware/simulation/$(SIMULATOR)/*.vcd $(SIM_DIR)
endif

kill-sim:
	@if [ "`ps aux | grep $(USER) | grep console | grep python3 | grep -v grep`" ]; then \
	kill -9 $$(ps aux | grep $(USER) | grep console | grep python3 | grep -v grep | awk '{print $$2}'); fi


test: clean-testlog test1 test2 test3 test4 test5
	diff test.log ../test.expected

test1:
	make -C $(ROOT_DIR) sim-clean
	make -C $(ROOT_DIR) sim-run INIT_MEM=1 USE_DDR=0 RUN_EXTMEM=0 TEST_LOG=">> test.log"
test2:
	make -C $(ROOT_DIR) sim-clean
	make -C $(ROOT_DIR) sim-run INIT_MEM=0 USE_DDR=0 RUN_EXTMEM=0 TEST_LOG=">> test.log"
test3:
	make -C $(ROOT_DIR) sim-clean
	make -C $(ROOT_DIR) sim-run INIT_MEM=1 USE_DDR=1 RUN_EXTMEM=0 TEST_LOG=">> test.log"
test4:
	make -C $(ROOT_DIR) sim-clean
	make -C $(ROOT_DIR) sim-run INIT_MEM=1 USE_DDR=1 RUN_EXTMEM=1 TEST_LOG=">> test.log"
test5:
	make -C $(ROOT_DIR) sim-clean
	make -C $(ROOT_DIR) sim-run INIT_MEM=0 USE_DDR=1 RUN_EXTMEM=1 TEST_LOG=">> test.log"


#clean target common to all simulators
clean-remote: hw-clean
	@rm -f soc2cnsl cnsl2soc
	@rm -f system.vcd
ifneq ($(SIM_SERVER),)
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --force --exclude .git $(SIM_SYNC_FLAGS) $(ROOT_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)
	rsync -avz --delete --force --exclude .git $(SIM_SYNC_FLAGS) $($(UUT_NAME)_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_UUT_DIR)
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) 'make -C $(REMOTE_ROOT_DIR) sim-clean SIMULATOR=$(SIMULATOR)'
endif

#clean test log only when sim testing begins
clean-testlog:
	@rm -f test.log
ifneq ($(SIM_SERVER),)
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) "if [ ! -d $(REMOTE_ROOT_DIR) ]; then mkdir -p $(REMOTE_ROOT_DIR); fi"
	rsync -avz --delete --force --exclude .git $(SIM_SYNC_FLAGS) $(ROOT_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_ROOT_DIR)
	rsync -avz --delete --force --exclude .git $(SIM_SYNC_FLAGS) $($(UUT_NAME)_DIR) $(SIM_USER)@$(SIM_SERVER):$(REMOTE_UUT_DIR)
	ssh $(SIM_SSH_FLAGS) $(SIM_USER)@$(SIM_SERVER) 'rm -f $(REMOTE_ROOT_DIR)/hardware/simulation/$(SIMULATOR)/test.log'
endif

.PRECIOUS: system.vcd test.log

.PHONY: build run sim \
	kill-remote-sim clean-remote kill-sim \
	test test1 test2 test3 test4 test5 clean-testlog
