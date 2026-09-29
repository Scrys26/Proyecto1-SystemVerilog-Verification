#=====================================================================
# Makefile - Proyecto 1, verificacion del bus bs_gnrtr_n_rbtr
#
#   make              -> compila y corre el top por defecto
#   make comp         -> solo compila
#   make run          -> solo corre
#   make smoke        -> prueba de humo (DUT + interfaz, sin clases)
#   make wave         -> corre y abre DVE
#   make verdi        -> corre y abre Verdi
#   make vcd          -> corre generando VCD para GTKWave
#   make files        -> muestra la lista de fuentes resueltas
#   make check        -> verifica que todas las fuentes existan
#   make clean        -> borra lo generado
#   make help         -> lista los objetivos
#
#   make run SEED=42 MAX_CYCLES=2000
#   make run PLUSARGS="+n_txn=50 +verbose=1"
#=====================================================================

#---------------------------------------------------------------------
# Directorios
#
# Rutas relativas a la ubicacion de este Makefile.
# <<< AJUSTAR RTL_DIR con el nombre real de la carpeta del DUT >>>
#---------------------------------------------------------------------
# Library.sv (DUT del profesor)
RTL_DIR  = DUT/Referencias
# clases del ambiente + interfaz
TB_DIR   = Scripts
# tops de simulacion
TOP_DIR  = TestBench

# OJO: no poner comentarios al final de estas lineas. Make se traga
# los espacios previos al '#' y los mete dentro de la variable, lo
# que parte las rutas en dos.

#---------------------------------------------------------------------
# FUENTES
#
# Hay dos grupos y se tratan distinto:
#
#  COMPILE_SRCS : modulos e interfaces. Van en la linea de comandos
#                 de VCS como archivos de compilacion normales.
#
#  INCLUDE_SRCS : archivos de clases. NO se compilan sueltos: el top
#                 los mete con `include para que queden todos en la
#                 misma unidad de compilacion y se vean entre si.
#                 Aqui solo se listan para dos cosas: armar el
#                 +incdir y que make recompile si alguno cambia.
#---------------------------------------------------------------------

# RTL del profesor (version recortada, no requiere fifo.sv)
RTL_SRCS      = $(RTL_DIR)/DUT.sv

# Interfaz del bus. Es un modulo, se compila; no va por include.
IF_SRCS       = $(TB_DIR)/bus_if_prov.sv

# Paquete del ambiente. Este SI se compila: adentro hace `include de
# todas las clases, que asi quedan en una sola unidad de compilacion
# y se ven entre si.
PKG_SRCS      = $(TB_DIR)/Paquete.sv

# Clases del ambiente. NO se compilan sueltas: Paquete.sv las incluye.
# Se listan aqui solo para armar el +incdir y para que make recompile
# cuando alguna cambie.
INCLUDE_SRCS  = $(TB_DIR)/bus_config.svh \
                $(TB_DIR)/bus_txn.svh \
                $(TB_DIR)/bus_mon_txn.svh \
                $(TB_DIR)/bus_expec_item.svh \
                $(TB_DIR)/driver.svh \
                $(TB_DIR)/Monitor.sv \
                $(TB_DIR)/Agente.sv \
                $(TB_DIR)/Scoreboard.svh \
                $(TB_DIR)/Checker.svh \
		$(TB_DIR)/Ambiente.sv

# Top de la simulacion.
#   top_tb    -> ambiente completo
#   pruebaMF  -> prueba de humo (solo DUT + interfaz)
TOP          ?= TestGeneral
TOP_SRC       = $(TOP_DIR)/$(TOP).sv

# El orden importa: el paquete antes del top que lo importa.
COMPILE_SRCS  = $(RTL_SRCS) $(IF_SRCS) $(PKG_SRCS) $(TOP_SRC)

# Todo lo que, si cambia, obliga a recompilar
ALL_SRCS      = $(COMPILE_SRCS) $(INCLUDE_SRCS)

#---------------------------------------------------------------------
# Configuracion de la corrida
#---------------------------------------------------------------------
SIMV        ?= simv
SEED        ?= 1
MAX_CYCLES  ?= 50000
PLUSARGS    ?=

COMP_LOG     = comp.log
RUN_LOG      = run.log

#---------------------------------------------------------------------
# Opciones de VCS
#
#  -sverilog          habilita SystemVerilog
#  -full64            binario de 64 bits
#  -debug_access+all  permite sondear y forzar senales (para DVE)
#  -timescale         Library.sv no trae `timescale propio y el diseno
#                     tiene retardos de compuerta (buf #(3,3))
#  +incdir            DOS directorios: el top hace `include de las
#                     clases que estan en Scripts, y puede incluir
#                     cosas de su propia carpeta
#  +lint=TFIPC-L      avisa si queda un puerto sin conectar, facil de
#                     cometer con los inout de tri-estado de este diseno
#---------------------------------------------------------------------
VCS_OPTS  = -sverilog \
            -full64 \
            -debug_access+all \
            -timescale=1ns/1ps \
            +incdir+$(TB_DIR)+$(TOP_DIR) \
            +lint=TFIPC-L \
            +v2k \
            -l $(COMP_LOG) \
            -o $(SIMV)

RUN_OPTS  = +max_cycles=$(MAX_CYCLES) \
            +ntb_random_seed=$(SEED) \
            $(PLUSARGS) \
            -l $(RUN_LOG)

#---------------------------------------------------------------------
# Objetivos
#---------------------------------------------------------------------
.PHONY: all comp run smoke wave verdi vcd files check clean help

all: run

## comp: compila el diseno y el testbench
comp: $(SIMV)

# El binario depende de TODAS las fuentes, incluidas las que van por
# include, para que make no se salte una recompilacion necesaria.
$(SIMV): $(ALL_SRCS)
	@echo "=== Compilando $(TOP) con VCS ==="
	vcs $(VCS_OPTS) $(COMPILE_SRCS)
	@echo "=== Compilacion lista ==="

## run: corre la simulacion
run: $(SIMV)
	@echo "=== Corriendo $(TOP) (seed=$(SEED)) ==="
	./$(SIMV) $(RUN_OPTS)
	@echo ""
	@grep -E "RESULTADO|ERRORES|Error|FALLO" $(RUN_LOG) || echo "(sin errores reportados)"

## smoke: prueba de humo, solo DUT + interfaz
smoke:
	@$(MAKE) run TOP=TestGeneral

## wave: corre volcando VPD y abre DVE
wave: $(SIMV)
	./$(SIMV) $(RUN_OPTS) +vcs+dumpvars+$(TOP).vpd
	dve -vpd $(TOP).vpd &

## verdi: corre volcando FSDB y abre Verdi
verdi:
	vcs $(VCS_OPTS) -kdb -lca $(COMPILE_SRCS)
	./$(SIMV) $(RUN_OPTS) +fsdb+all
	verdi -ssf novas.fsdb &

## vcd: corre volcando un VCD portable (GTKWave)
vcd: $(SIMV)
	./$(SIMV) $(RUN_OPTS) +dump=1

## files: muestra que se compila y que se incluye
files:
	@echo "COMPILE_SRCS (fuentes de VCS):"
	@for f in $(COMPILE_SRCS); do echo "   $$f"; done
	@echo "INCLUDE_SRCS (van por \`include dentro de Paquete.sv):"
	@for f in $(INCLUDE_SRCS); do echo "   $$f"; done

## check: verifica que todas las fuentes existan antes de llamar a VCS
check:
	@err=0; \
	for f in $(ALL_SRCS); do \
	  if [ -f "$$f" ]; then echo "  OK    $$f"; \
	  else echo "  FALTA $$f"; err=1; fi; \
	done; \
	if [ $$err -ne 0 ]; then \
	  echo ""; echo "Revisar RTL_DIR / TB_DIR / TOP_DIR en el Makefile."; \
	  exit 1; \
	fi

## clean: borra todo lo generado
clean:
	rm -rf $(SIMV) $(SIMV).daidir csrc ucli.key \
	       *.log *.vpd *.vcd *.fsdb novas* verdiLog \
	       DVEfiles .vcs_lib_lock AN.DB inter.vpd

## help: lista los objetivos disponibles
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'
