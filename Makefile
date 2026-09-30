# ============================================================
# Makefile - Proyecto 1 SystemVerilog Verification
# ============================================================

# ------------------------------------------------------------
# Configuracion
# ------------------------------------------------------------

TOP       ?= TestGeneral
BITS      ?= 1
DRVRS     ?= 4
PCKG_SZ   ?= 16
BROADCAST ?= 255
SEED      ?= 1

N_TXN        ?= 50
MAX_CYCLES   ?= 10000
DRAIN_CYCLES ?= 5000

REPORT_DIR ?= Reportes
CSV        ?= $(REPORT_DIR)/latencias.csv


# ------------------------------------------------------------
# Nombre del ejecutable
# ------------------------------------------------------------

SIMV = simv_$(TOP)_b$(BITS)_d$(DRVRS)_p$(PCKG_SZ)_bc$(BROADCAST)


# ------------------------------------------------------------
# Archivos de reporte
# ------------------------------------------------------------

COMP_LOG = $(REPORT_DIR)/comp_$(TOP)_p$(PCKG_SZ).log
RUN_LOG  = $(REPORT_DIR)/run_$(TOP)_p$(PCKG_SZ).log


# ------------------------------------------------------------
# Archivos fuente
# ------------------------------------------------------------

DUT_FILES = \
	DUT/Referencias/DUT.sv

SCRIPT_FILES = \
	Scripts/bus_if_prov.sv \
	Scripts/Paquete.sv

TOP_FILE = TestBench/$(TOP).sv

ALL_FILES = \
	$(DUT_FILES) \
	$(SCRIPT_FILES) \
	$(TOP_FILE)


# ------------------------------------------------------------
# Opciones de VCS
# ------------------------------------------------------------

VCS_FLAGS = \
	-sverilog \
	-full64 \
	-debug_access+all \
	-timescale=1ns/1ps \
	+incdir+Scripts+TestBench \
	+define+TB_BITS=$(BITS) \
	+define+TB_DRVRS=$(DRVRS) \
	+define+TB_PCKG_SZ=$(PCKG_SZ) \
	+define+TB_BROADCAST=$(BROADCAST) \
	+lint=TFIPC-L \
	+v2k


# ------------------------------------------------------------
# Targets
# ------------------------------------------------------------

.PHONY: all check comp run reports clean clean_reports help


# ============================================================
# Ejecutar todo
# ============================================================

all: run


# ============================================================
# Crear carpeta de reportes
# ============================================================

reports:
	@mkdir -p $(REPORT_DIR)


# ============================================================
# Verificar archivos
# ============================================================

check: reports
	@echo "============================================================"
	@echo " Verificando archivos"
	@echo "============================================================"
	@echo "TOP       = $(TOP)"
	@echo "BITS      = $(BITS)"
	@echo "DRVRS     = $(DRVRS)"
	@echo "PCKG_SZ   = $(PCKG_SZ)"
	@echo "BROADCAST = $(BROADCAST)"
	@echo ""

	@test -f DUT/Referencias/DUT.sv || (echo "ERROR: No existe DUT/Referencias/DUT.sv" && exit 1)
	@test -f Scripts/bus_if_prov.sv || (echo "ERROR: No existe Scripts/bus_if_prov.sv" && exit 1)
	@test -f Scripts/Paquete.sv || (echo "ERROR: No existe Scripts/Paquete.sv" && exit 1)
	@test -f $(TOP_FILE) || (echo "ERROR: No existe $(TOP_FILE)" && exit 1)

	@echo "Todos los archivos fueron encontrados."
	@echo "============================================================"


# ============================================================
# Compilar
# ============================================================

comp: check
	@echo ""
	@echo "=== Compilando $(TOP) con VCS ==="
	@echo "    BITS=$(BITS)"
	@echo "    DRVRS=$(DRVRS)"
	@echo "    PCKG_SZ=$(PCKG_SZ)"
	@echo "    BROADCAST=$(BROADCAST)"
	@echo ""

	vcs $(VCS_FLAGS) \
		-l $(COMP_LOG) \
		-o $(SIMV) \
		$(ALL_FILES)

	@echo ""
	@echo "=== Compilacion lista: $(SIMV) ==="
	@echo "=== Log de compilacion: $(COMP_LOG) ==="


# ============================================================
# Ejecutar simulacion
# ============================================================

run: comp
	@echo ""
	@echo "=== Corriendo $(TOP) ==="
	@echo "    Seed=$(SEED)"
	@echo "    N_TXN=$(N_TXN)"
	@echo "    MAX_CYCLES=$(MAX_CYCLES)"
	@echo "    DRAIN_CYCLES=$(DRAIN_CYCLES)"
	@echo ""

	./$(SIMV) \
		+n_txn=$(N_TXN) \
		+max_cycles=$(MAX_CYCLES) \
		+drain_cycles=$(DRAIN_CYCLES) \
		+csv=$(CSV) \
		+ntb_random_seed=$(SEED) \
		-l $(RUN_LOG)

	@echo ""
	@echo "============================================================"
	@echo " Simulacion terminada"
	@echo "============================================================"
	@echo "TOP        : $(TOP)"
	@echo "Run log    : $(RUN_LOG)"
	@if [ -f "$(CSV)" ]; then echo "CSV        : $(CSV)"; fi
	@echo "============================================================"
	@echo ""
	@echo "Resumen:"
	@grep -E "ERRORES|RESULTADO|\[PASS\]|\[FAIL\]" $(RUN_LOG) || true


# ============================================================
# Limpiar archivos de compilacion
# ============================================================

clean:
	@echo "=== Limpiando archivos de compilacion ==="

	rm -rf simv*
	rm -rf csrc
	rm -rf *.daidir
	rm -rf ucli.key
	rm -rf vc_hdrs.h
	rm -rf DVEfiles
	rm -rf novas.conf
	rm -rf novas.rc
	rm -rf verdiLog
	rm -rf core
	rm -rf core.*

	@echo "=== Limpieza terminada ==="
	@echo "Los reportes NO fueron eliminados."


# ============================================================
# Limpiar reportes
# ============================================================

clean_reports:
	@echo "=== Eliminando carpeta $(REPORT_DIR) ==="
	rm -rf $(REPORT_DIR)
	@echo "=== Reportes eliminados ==="


# ============================================================
# Ayuda
# ============================================================

help:
	@echo ""
	@echo "============================================================"
	@echo " Proyecto 1 - SystemVerilog Verification"
	@echo "============================================================"
	@echo ""
	@echo "Comandos disponibles:"
	@echo ""
	@echo "  make check TOP=TestTP1"
	@echo "      Verifica que existan los archivos necesarios."
	@echo ""
	@echo "  make comp TOP=TestTP1"
	@echo "      Compila una prueba."
	@echo ""
	@echo "  make run TOP=TestTP1"
	@echo "      Compila y ejecuta una prueba."
	@echo ""
	@echo "  make run TOP=TestLatencia"
	@echo "      Ejecuta la prueba de latencia."
	@echo ""
	@echo "  make run TOP=TestLatencia N_TXN=100"
	@echo "      Ejecuta 100 transacciones por terminal."
	@echo ""
	@echo "  make run TOP=TestLatencia N_TXN=100 SEED=20"
	@echo "      Ejecuta con una semilla especifica."
	@echo ""
	@echo "  make run TOP=TestLatencia CSV=Reportes/latencias_seed20.csv"
	@echo "      Permite seleccionar el nombre del CSV."
	@echo ""
	@echo "  make clean"
	@echo "      Elimina archivos generados por VCS."
	@echo ""
	@echo "  make clean_reports"
	@echo "      Elimina todos los reportes."
	@echo ""
	@echo "============================================================"