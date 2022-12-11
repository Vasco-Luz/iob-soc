#!/usr/bin/env python3

import os, sys
sys.path.insert(0, os.getcwd()+'/submodules/LIB/scripts')
from setup import setup, setup_submodule
from submodule_utils import get_n_periphs, get_n_periphs_w, get_periphs_id_as_macros
from ios import get_peripheral_ios
from blocks import get_peripheral_blocks

import periphs_tmp
import createSystem
import createTestbench
import createTopSystem

top = 'iob_soc'
version = 'V0.70'

blocks = \
[
    {'name':'cpu', 'descr':'CPU module', 'blocks': [
        {'name':'cpu', 'descr':'PicoRV32 CPU'},
    ]},
    {'name':'bus_split', 'descr':'Split modules for buses', 'blocks': [
        {'name':'ibus_split', 'descr':'Split CPU instruction bus into internal and external memory buses'},
        {'name':'dbus_split', 'descr':'Split CPU data bus into internal and external memory buses'},
        {'name':'int_dbus_split', 'descr':'Split internal data bus into internal memory and peripheral buses'},
        {'name':'pbus_split', 'descr':'Split peripheral bus into a bus for each peripheral'},
    ]},
    {'name':'memories', 'descr':'Memory modules', 'blocks': [
        {'name':'int_mem0', 'descr':'Internal SRAM memory'},
        {'name':'ext_mem0', 'descr':'External DDR memory'},
    ]},
    {'name':'peripherals', 'descr':'peripheral modules', 'blocks': [
        {'name':'UART0', 'type':'UART', 'descr':'Default UART interface', 'params':{}},
    ]},
]
# Get peripherals list from 'peripherals' table in blocks list
peripherals_list=next(i['blocks'] for i in blocks if i['name'] == 'peripherals')

dirs = {
'soc':'.',
'build':f"../{top+'_'+version}",
}
dirs |= {
'picorv32':f"{dirs['soc']}/submodules/PICORV32",
'cache':f"{dirs['soc']}/submodules/CACHE",
'uart':f"{dirs['soc']}/submodules/UART",
'lib':f"{dirs['soc']}/submodules/LIB",
}

confs = \
[
    # SoC defines
    {'name':'USE_MUL_DIV',   'type':'D', 'val':'1', 'min':'0', 'max':'1', 'descr':"Enable MUL and DIV CPU instrunctions"},
    {'name':'USE_COMPRESSED','type':'D', 'val':'1', 'min':'0', 'max':'1', 'descr':"Use compressed CPU instructions"},
    {'name':'INIT_MEM',      'type':'D', 'val':'1', 'min':'0', 'max':'1', 'descr':"Enable memory initialization"},
    {'name':'RUN_EXTMEM',    'type':'D', 'val':'0', 'min':'0', 'max':'1', 'descr':"Run firmware from external memory"}, #This is the new USE_DDR

    # SoC macros
    {'name':'E',             'type':'M', 'val':'31', 'min':'1', 'max':'32', 'descr':"Address selection bit for external memory"},
    {'name':'P',             'type':'M', 'val':'30', 'min':'1', 'max':'32', 'descr':"Address selection bit for peripherals"},
    {'name':'B',             'type':'M', 'val':'29', 'min':'1', 'max':'32', 'descr':"Address selection bit for boot ROM"},
    {'name':'DCACHE_ADDR_W', 'type':'M', 'val':'24', 'min':'1', 'max':'32', 'descr':"DCACHE address width"},
    {'name':'DDR_DATA_W',    'type':'M', 'val':'32', 'min':'1', 'max':'32', 'descr':"DDR data bus width"},
    {'name':'DDR_ADDR_W',    'type':'M', 'val':'24', 'min':'1', 'max':'32', 'descr':"DDR address bus width in simulation"},
    #TODO: Need to find a way to use value below when running on fpga
    {'name':'DDR_ADDR_W_HW', 'type':'M', 'val':'30', 'min':'1', 'max':'32', 'descr':"DDR address bus width"},
    #TODO: Need to find a way to use value below when running on fpga
    {'name':'BAUD_HW',       'type':'M', 'val':'115200', 'min':'1', 'max':'NA', 'descr':"UART baud rate"},
    {'name':'BAUD',          'type':'M', 'val':'5000000', 'min':'1', 'max':'NA', 'descr':"UART baud rate for simulation"},
    {'name':'FREQ',          'type':'M', 'val':'100000000', 'min':'1', 'max':'NA', 'descr':"System clock frequency"},

    # SoC parameters
    {'name':'ADDR_W',        'type':'P', 'val':'32', 'min':'1', 'max':'32', 'descr':"Address bus width"},
    {'name':'DATA_W',        'type':'P', 'val':'32', 'min':'1', 'max':'32', 'descr':"Data bus width"},
    {'name':'BOOTROM_ADDR_W','type':'P', 'val':'12', 'min':'1', 'max':'32', 'descr':"Boot ROM address width"},
    {'name':'SRAM_ADDR_W',   'type':'P', 'val':'15', 'min':'1', 'max':'32', 'descr':"SRAM address width"},
    {'name':'AXI_ID_W',      'type':'P', 'val':'0', 'min':'1', 'max':'32', 'descr':"AXI ID bus width"},
    {'name':'AXI_ADDR_W',    'type':'P', 'val':'`IOB_SOC_DCACHE_ADDR_W', 'min':'1', 'max':'32', 'descr':"AXI address bus width"},
    {'name':'AXI_DATA_W',    'type':'P', 'val':'`IOB_SOC_DATA_W', 'min':'1', 'max':'32', 'descr':"AXI data bus width"},
    {'name':'AXI_LEN_W',     'type':'P', 'val':'4', 'min':'1', 'max':'4', 'descr':"AXI burst length width"},
]
# Append macros with ID of each peripheral
confs.extend(get_periphs_id_as_macros(peripherals_list))
# Append macro with number of peripherals
confs.append({'name':'N_SLAVES', 'type':'M', 'val':get_n_periphs(peripherals_list), 'min':'NA', 'max':'NA', 'descr':"Number of peripherals"})
# Append macro with width of peripheral bus
confs.append({'name':'N_SLAVES_W', 'type':'M', 'val':get_n_periphs_w(peripherals_list), 'min':'NA', 'max':'NA', 'descr':"Peripheral bus width"})


# regs = []

ios = \
[
    {'name': 'general', 'descr':'General interface signals', 'ports': [
        {'name':"clk_i", 'type':"I", 'n_bits':'1', 'descr':"System clock input"},
        {'name':"rst_i", 'type':"I", 'n_bits':'1', 'descr':"System reset, synchronous and active high"},
        {'name':"trap_o", 'type':"O", 'n_bits':'1', 'descr':"CPU trap signal"}
    ]},
#    {'name': 'axi_m_port', 'descr':'AXI master interface', 'ports': [
#    ]}
]
# Append peripherals IO 
ios.extend(get_peripheral_ios(peripherals_list,os.path.dirname(__file__)))

if __name__ == "__main__":
    # Setup submodules
    setup_submodule(f"../{top+'_'+version}","submodules/UART")
    setup_submodule(f"../{top+'_'+version}","submodules/CACHE")
    setup_submodule(f"../{top+'_'+version}","submodules/PICORV32")
    # Setup this system
    setup(top, version, confs, ios, None, blocks)
    # periphs_tmp.h
    periphs_tmp.create_periphs_tmp(next(i['val'] for i in confs if i['name'] == 'P'),
                                   peripherals_list, f"../{top+'_'+version}/software/periphs.h")
    # iob_soc.v
    createSystem.create_systemv(dirs['soc'], top, peripherals_list, os.path.join(dirs['build'],'hardware/src/iob_soc.v'))
    # system_tb.v
    createTestbench.create_system_testbench(dirs['soc'], peripherals_list, os.path.join(dirs['build'],'hardware/simulation/src/system_tb.v'))
    # system_top.v
    createTopSystem.create_top_system(dirs['soc'], peripherals_list, os.path.join(dirs['build'],'hardware/simulation/src/system_top.v'))