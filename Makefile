#=====================================================================
# Makefile - Proyecto 1, verificacion del bus bs_gnrtr_n_rbtr
#
#   make                 -> compila y corre el top por defecto
#   make comp            -> solo compila
#   make run             -> solo corre
#   make smoke           -> prueba de humo (DUT + interfaz, sin clases)
#   make wave            -> corre y abre DVE
#   make verdi           -> corre y abre Verdi
#   make vcd             -> corre generando VCD para GTKWave
#   make files           -> muestra la lista de fuentes resueltas
#   make check           -> verifica que todas las fuentes existan
#   make clean           -> borra lo generado
#   make help            -> lista los objetivos
#

#   make smoke
#   make run TOP=TestGeneral
#   make run TOP=TestGeneral PCKG_SZ=32 SEED=42 MAX_CYCLES=2000
#   make run TOP=TestGeneral PCKG_SZ=64 PLUSARGS="+n_txn=50 +verbose=1"
#=====================================================================


#---------------------------------------------------------------------
# Directorios
#---------------------------------------------------------------------
RTL_DIR  = DUT/Referencias
TB_DIR   = Scripts
TOP_DIR  = TestBench


#---------------------------------------------------------------------
# Parametros estructurales del ambiente
#
# Paquete.sv toma estos valores mediante:
#   TB_BITS
#   TB_DRVRS
#   TB_PCKG_SZ
#   TB_BROADCAST
#
# 255 equivale a 8'hFF.
#---------------------------------------------------------------------
BITS       ?= 1
DRVRS      ?= 4
PCKG_SZ    ?= 16
BROADCAST  ?= 255


TB_DEFINES = +define+TB_BITS=$(BITS) \
             +define+TB_DRVRS=$(DRVRS) \
             +define+TB_PCKG_SZ=$(PCKG_SZ) \
             +define+TB_BROADCAST=$(BROADCAST)


#---------------------------------------------------------------------
# FUENTES
#---------------------------------------------------------------------

# DUT recortado utilizado en la verificacion.
RTL_SRCS = $(RTL_DIR)/DUT.sv


# Interfaz entre DUT y ambiente.
# Debe compilarse antes de Paquete.sv.
IF_SRCS = $(TB_DIR)/bus_if_prov.sv


# Package principal del ambiente.
PKG_SRC = $(TB_DIR)/Paquete.sv


# Clases incluidas internamente por Paquete.sv.
# No se compilan individualmente.
CLASS_SRCS = $(TB_DIR)/bus_config.svh \
             $(TB_DIR)/bus_txn.svh \
             $(TB_DIR)/bus_mon_txn.svh \
             $(TB_DIR)/bus_expec_item.svh \
             $(TB_DIR)/driver.svh \
             $(TB_DIR)/Monitor.sv \
             $(TB_DIR)/Agente.sv \
             $(TB_DIR)/Scoreboard.svh \
             $(TB_DIR)/Checker.svh \
             $(TB_DIR)/Ambiente.sv


#---------------------------------------------------------------------
# Top de simulacion
#---------------------------------------------------------------------

# Prueba general por defecto.
TOP ?= TestGeneral

TOP_SRC = $(TOP_DIR)/$(TOP).sv


#---------------------------------------------------------------------
# Seleccion de fuentes segun el TOP
#
# pruebaMF es una prueba de humo:
#   DUT + interfaz + pruebaMF
#
# El resto de pruebas utilizan Paquete.sv y las clases.
#---------------------------------------------------------------------
ifeq ($(TOP),pruebaMF)

TB_COMPILE_SRCS =
TB_DEP_SRCS =

else

TB_COMPILE_SRCS = $(PKG_SRC)
TB_DEP_SRCS = $(PKG_SRC) $(CLASS_SRCS)

endif


#---------------------------------------------------------------------
# Orden de compilacion
#
#   1) DUT
#   2) bus_if
#   3) Paquete
#   4) top
#---------------------------------------------------------------------
COMPILE_SRCS = $(RTL_SRCS) \
               $(IF_SRCS) \
               $(TB_COMPILE_SRCS) \
               $(TOP_SRC)


# Archivos que fuerzan recompilacion si cambian.
ALL_SRCS = $(COMPILE_SRCS) $(TB_DEP_SRCS)


#---------------------------------------------------------------------
# Configuracion de la corrida
#---------------------------------------------------------------------

# Ejecutable diferente para cada configuracion estructural.
SIMV ?= simv_$(TOP)_b$(BITS)_d$(DRVRS)_p$(PCKG_SZ)_bc$(BROADCAST)

SEED       ?= 1
MAX_CYCLES ?= 400
PLUSARGS   ?=


# Logs separados por top y ancho de paquete.
COMP_LOG = comp_$(TOP)_p$(PCKG_SZ).log
RUN_LOG  = run_$(TOP)_p$(PCKG_SZ).log


#---------------------------------------------------------------------
# Opciones de VCS
#---------------------------------------------------------------------
VCS_OPTS = -sverilog \
           -full64 \
           -debug_access+all \
           -timescale=1ns/1ps \
           +incdir+$(TB_DIR)+$(TOP_DIR) \
           $(TB_DEFINES) \
           +lint=TFIPC-L \
           +v2k \
           -l $(COMP_LOG) \
           -o $(SIMV)


RUN_OPTS = +max_cycles=$(MAX_CYCLES) \
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


$(SIMV): $(ALL_SRCS)
	@echo "=== Compilando $(TOP) con VCS ==="
	@echo "    BITS=$(BITS)"
	@echo "    DRVRS=$(DRVRS)"
	@echo "    PCKG_SZ=$(PCKG_SZ)"
	@echo "    BROADCAST=$(BROADCAST)"
	vcs $(VCS_OPTS) $(COMPILE_SRCS)
	@echo "=== Compilacion lista: $(SIMV) ==="


## run: corre la simulacion
run: $(SIMV)
	@echo "=== Corriendo $(TOP) (seed=$(SEED)) ==="
	./$(SIMV) $(RUN_OPTS)
	@echo ""
	@grep -E "RESULTADO|ERRORES|Error|FALLO|PASS|FAIL" $(RUN_LOG) || echo "(sin resumen automatico)"


## smoke: prueba minima de DUT + interfaz
smoke:
	@$(MAKE) run TOP=pruebaMF


## wave: corre y abre DVE
wave: $(SIMV)
	./$(SIMV) $(RUN_OPTS) +vcs+dumpvars+$(TOP).vpd
	dve -vpd $(TOP).vpd &


## verdi: recompila con KDB, corre y abre Verdi
verdi:
	vcs $(VCS_OPTS) -kdb -lca $(COMPILE_SRCS)
	./$(SIMV) $(RUN_OPTS) +fsdb+all
	verdi -ssf novas.fsdb &


## vcd: corre solicitando VCD
vcd: $(SIMV)
	./$(SIMV) $(RUN_OPTS) +dump=1


## files: muestra fuentes y parametros
files:
	@echo "TOP: $(TOP)"
	@echo "SIMV: $(SIMV)"
	@echo "BITS=$(BITS)"
	@echo "DRVRS=$(DRVRS)"
	@echo "PCKG_SZ=$(PCKG_SZ)"
	@echo "BROADCAST=$(BROADCAST)"
	@echo ""
	@echo "COMPILE_SRCS:"
	@for f in $(COMPILE_SRCS); do echo "   $$f"; done
	@echo ""
	@if [ -n "$(TB_DEP_SRCS)" ]; then \
	  echo "Dependencias de Paquete.sv:"; \
	  for f in $(TB_DEP_SRCS); do echo "   $$f"; done; \
	else \
	  echo "Smoke test: Paquete.sv y clases no se compilan."; \
	fi


## check: verifica que todas las fuentes existan
check:
	@err=0; \
	for f in $(ALL_SRCS); do \
	  if [ -f "$$f" ]; then \
	    echo "  OK    $$f"; \
	  else \
	    echo "  FALTA $$f"; \
	    err=1; \
	  fi; \
	done; \
	if [ $$err -ne 0 ]; then \
	  echo ""; \
	  echo "Revisar RTL_DIR / TB_DIR / TOP_DIR o TOP."; \
	  exit 1; \
	fi


## clean: borra archivos generados
clean:
	rm -rf simv simv_* simv.daidir simv_*.daidir \
	       csrc ucli.key \
	       comp*.log run*.log \
	       *.vpd *.vcd *.fsdb \
	       novas* verdiLog \
	       DVEfiles .vcs_lib_lock AN.DB inter.vpd


## help: lista los objetivos disponibles
help:
	@grep -E '^## ' $(MAKEFILE_LIST) | sed 's/## /  /'