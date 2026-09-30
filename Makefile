# ============================================================
# Makefile - Proyecto 1 SystemVerilog Verification
# ============================================================


# ------------------------------------------------------------
# Configuracion general
# ------------------------------------------------------------

TOP       ?= TestGeneral
BITS      ?= 1
DRVRS     ?= 4
PCKG_SZ   ?= 16
BROADCAST ?= 255
SEED      ?= 1


# ------------------------------------------------------------
# Configuracion exclusiva de TestLatencia
# ------------------------------------------------------------

N_TXN        ?= 50
MAX_CYCLES   ?= 10000
DRAIN_CYCLES ?= 5000


# ------------------------------------------------------------
# Directorios
# ------------------------------------------------------------

REPORT_DIR ?= Reportes
BUILD_DIR  ?= $(REPORT_DIR)/build
AUX_DIR    ?= $(BUILD_DIR)/aux


# ------------------------------------------------------------
# Archivo CSV de TestLatencia
# ------------------------------------------------------------

CSV ?= $(REPORT_DIR)/latencias.csv


# ------------------------------------------------------------
# Nombre y ubicacion del ejecutable VCS
# ------------------------------------------------------------

SIMV_NAME = simv_$(TOP)_b$(BITS)_d$(DRVRS)_p$(PCKG_SZ)_bc$(BROADCAST)

SIMV = $(BUILD_DIR)/$(SIMV_NAME)


# ------------------------------------------------------------
# Logs
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
# Argumentos generales de simulacion
# ------------------------------------------------------------

RUN_ARGS = +ntb_random_seed=$(SEED)


# ------------------------------------------------------------
# Argumentos exclusivos de TestLatencia
# ------------------------------------------------------------

ifeq ($(TOP),TestLatencia)

RUN_ARGS += \
	+n_txn=$(N_TXN) \
	+max_cycles=$(MAX_CYCLES) \
	+drain_cycles=$(DRAIN_CYCLES) \
	+csv=$(CSV)

endif


# ------------------------------------------------------------
# Targets
# ------------------------------------------------------------

.PHONY: all check comp run reports clean clean_reports help


# ============================================================
# Default
# ============================================================

all: run


# ============================================================
# Crear estructura de directorios
# ============================================================

reports:
	@mkdir -p $(REPORT_DIR)
	@mkdir -p $(BUILD_DIR)
	@mkdir -p $(AUX_DIR)


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

	@test -f $(DUT_FILES) || \
		(echo "ERROR: No existe $(DUT_FILES)" && exit 1)

	@test -f Scripts/bus_if_prov.sv || \
		(echo "ERROR: No existe Scripts/bus_if_prov.sv" && exit 1)

	@test -f Scripts/Paquete.sv || \
		(echo "ERROR: No existe Scripts/Paquete.sv" && exit 1)

	@test -f $(TOP_FILE) || \
		(echo "ERROR: No existe $(TOP_FILE)" && exit 1)

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
		-Mdir=$(BUILD_DIR)/csrc \
		-l $(COMP_LOG) \
		-o $(SIMV) \
		$(ALL_FILES)

	@if [ -f ucli.key ]; then \
		mv -f ucli.key $(AUX_DIR)/; \
	fi

	@if [ -f vc_hdrs.h ]; then \
		mv -f vc_hdrs.h $(AUX_DIR)/; \
	fi

	@if [ -f tapi_xml_writer.log ]; then \
		mv -f tapi_xml_writer.log $(AUX_DIR)/; \
	fi

	@echo ""
	@echo "=== Compilacion lista ==="
	@echo "Ejecutable : $(SIMV)"
	@echo "Log        : $(COMP_LOG)"


# ============================================================
# Ejecutar simulacion
# ============================================================

run: comp
	@echo ""
	@echo "=== Corriendo $(TOP) ==="
	@echo "    Seed=$(SEED)"

	@if [ "$(TOP)" = "TestLatencia" ]; then \
		echo "    N_TXN=$(N_TXN)"; \
		echo "    MAX_CYCLES=$(MAX_CYCLES)"; \
		echo "    DRAIN_CYCLES=$(DRAIN_CYCLES)"; \
		echo "    CSV=$(CSV)"; \
	fi

	@echo ""

	$(SIMV) \
		$(RUN_ARGS) \
		-l $(RUN_LOG)

	@if [ -f ucli.key ]; then \
		mv -f ucli.key $(AUX_DIR)/; \
	fi

	@if [ -f vc_hdrs.h ]; then \
		mv -f vc_hdrs.h $(AUX_DIR)/; \
	fi

	@if [ -f tapi_xml_writer.log ]; then \
		mv -f tapi_xml_writer.log $(AUX_DIR)/; \
	fi

	@echo ""
	@echo "============================================================"
	@echo " Simulacion terminada"
	@echo "============================================================"
	@echo "TOP        : $(TOP)"
	@echo "Run log    : $(RUN_LOG)"

	@if [ "$(TOP)" = "TestLatencia" ] && [ -f "$(CSV)" ]; then \
		echo "CSV        : $(CSV)"; \
	fi

	@echo "Build      : $(BUILD_DIR)"
	@echo "============================================================"
	@echo ""
	@echo "Resumen:"

	@grep -E "ERRORES|RESULTADO|\[PASS\]|\[FAIL\]" \
		$(RUN_LOG) || true


# ============================================================
# Limpiar archivos de compilacion
#
# Conserva:
#   Reportes/*.log
#   Reportes/*.csv
#
# Elimina:
#   Reportes/build/
#   artefactos viejos de VCS en la raiz
# ============================================================

clean:
	@echo ""
	@echo "=== Limpiando archivos de compilacion ==="

	rm -rf $(BUILD_DIR)

	rm -rf csrc
	rm -rf simv*
	rm -rf *.daidir

	rm -rf ucli.key
	rm -rf vc_hdrs.h
	rm -rf tapi_xml_writer.log

	rm -rf DVEfiles
	rm -rf novas.conf
	rm -rf novas.rc
	rm -rf verdiLog

	rm -rf core
	rm -rf core.*

	@echo ""
	@echo "=== Limpieza terminada ==="
	@echo "Los logs y CSV dentro de $(REPORT_DIR) NO fueron eliminados."


# ============================================================
# Eliminar absolutamente todos los reportes
# ============================================================

clean_reports:
	@echo ""
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
	@echo "PRUEBAS FUNCIONALES"
	@echo ""
	@echo "  make run TOP=TestGeneral"
	@echo "  make run TOP=TestTP1"
	@echo "  make run TOP=TestTP2"
	@echo "  make run TOP=TestTP3"
	@echo "  make run TOP=TestTP4"
	@echo "  make run TOP=TestTP5"
	@echo ""
	@echo "PRUEBA DE LATENCIA"
	@echo ""
	@echo "  make run TOP=TestLatencia"
	@echo ""
	@echo "  make run TOP=TestLatencia N_TXN=100"
	@echo ""
	@echo "  make run TOP=TestLatencia N_TXN=100 SEED=20"
	@echo ""
	@echo "  make run TOP=TestLatencia \\"
	@echo "       CSV=Reportes/latencias_seed20.csv"
	@echo ""
	@echo "OTROS COMANDOS"
	@echo ""
	@echo "  make check TOP=TestTP1"
	@echo "      Verificar archivos."
	@echo ""
	@echo "  make comp TOP=TestTP1"
	@echo "      Solo compilar."
	@echo ""
	@echo "  make clean"
	@echo "      Eliminar archivos de compilacion."
	@echo "      Conserva logs y CSV."
	@echo ""
	@echo "  make clean_reports"
	@echo "      Eliminar toda la carpeta Reportes."
	@echo ""
	@echo "ARCHIVOS GENERADOS"
	@echo ""
	@echo "  Logs      -> $(REPORT_DIR)/"
	@echo "  CSV       -> $(REPORT_DIR)/"
	@echo "  Build VCS -> $(BUILD_DIR)/"
	@echo ""
	@echo "============================================================"