# Proyecto 1  Verificación funcional del bus bs_gnrtr_n_rbtr

Ambiente de verificación aleatorizado en SystemVerilog para el módulo
bs_gnrtr_n_rbtr, un bus serial con arbitraje distribuido.

Curso EL5811  Verificación funcional de circuitos integrados
Instituto Tecnológico de Costa Rica
Prof. Dr.-Ing. Ronny García Ramírez

**Integrantes:** Josué Campos Herrera, Randy Fernández Aguilar, Jesús Vargas Arias

---

## 1. Descripción

El DUT es un bus serial de #DRVRS terminales. Cada terminal puede ofrecer
un paquete de PCKG_SZ bits; el bus arbitra entre las terminales que tienen
tráfico pendiente y entrega cada paquete a su destino.

El ambiente construido genera tráfico aleatorio, modela el comportamiento
esperado del bus, verifica cada entrega contra ese modelo y mide la latencia
de extremo a extremo de cada paquete.

### Protocolo

| Señal | Significado |
|---|---|
| pndng[0][i] | La terminal *i* tiene un paquete listo |
| D_pop[0][i] | Paquete que ofrece la terminal *i* |
| pop[0][i] | El bus consumió el paquete de la terminal *i* |
| push[0][i] | El bus entrega un paquete a la terminal *i* |
| D_push[0][i] | Paquete que recibe la terminal *i* |


---

## 2. Estructura del repositorio

```
.
+-- Makefile
+-- DUT/
¦   +-- Referencias/
¦       +-- DUT.sv              Módulo bajo prueba (provisto por el curso)
+-- Scripts/
¦   +-- bus_if_prov.sv          Interfaz bus_if (modports DRV, MON, DUT)
¦   +-- Paquete.sv              Paquete que incluye todas las clases
¦   +-- bus_config.svh          Configuración global 
¦   +-- bus_txn.svh             Transacción generada por el agente
¦   +-- bus_mon_txn.svh         Transacción observada por el monitor
¦   +-- bus_expec_item.svh      Entrega esperada 
¦   +-- driver.svh              Driver y FIFOs de entrada por terminal
¦   +-- Monitor.sv              Monitor pasivo y sus hijos por terminal
¦   +-- Agente.sv               Generador de tráfico aleatorio
¦   +-- Scoreboard.svh          Modelo de referencia del bus
¦   +-- Checker.svh             Comparación, métricas y reporte CSV
¦   +-- Ambiente.sv             Integración y conexión de componentes
¦   +-- histograma.gnuplot      Script de GNUplot para los histogramas
+-- TestBench/
¦   +-- TestGeneral.sv          Tráfico aleatorio general
¦   +-- TestTP1.sv  TestTP5.sv Pruebas dirigidas
¦   +-- TestLatencia.sv         Medición de latencia con salida CSV
+-- Reportes/                   Generado: logs, CSV, histogramas y build
```

### Arquitectura del ambiente **Falta agregar foto



- **Agente**: genera transacciones aleatorias según los pesos de bus_config.
- **Driver**: mantiene una FIFO por terminal, presenta pndng/D_pop y
  detecta pop sobre FIFO vacía.
- **Monitor**: observa el bus de forma pasiva y cuenta pop y push por terminal.
- **Scoreboard**: modelo de referencia; a partir de cada transacción genera las
  entregas esperadas (una por destino, o DRVRS-1 en caso de broadcast).
- **Checker**: compara lo observado contra lo esperado, calcula latencias y
  escribe el CSV.


---

## 3. Requisitos

- Synopsys VCS (con soporte -sverilog)
- GNU Make
- GNUplot (solo para generar los histogramas)

---

## 4. Uso

### Pruebas funcionales

```bash
make run TOP=TestGeneral
make run TOP=TestTP1
make run TOP=TestTP2
make run TOP=TestTP3
make run TOP=TestTP4
make run TOP=TestTP5
```

### Prueba de latencia

```bash
make run TOP=TestLatencia \
  PCKG_SZ=16 MIN_DELAY=0 MAX_DELAY=5 \
  N_TXN=100 SEED=20 \
  MAX_CYCLES=40000 DRAIN_CYCLES=20000 \
  CSV=Reportes/latencias_16b_delay0_5.csv

make plot CSV=Reportes/latencias_16b_delay0_5.csv
```

### Otros objetivos

| Objetivo | Acción |
|---|---|
| make check | Verifica que existan los archivos fuente |
| make comp | Solo compila |
| make run | Compila y simula (objetivo por defecto) |
| make plot | Genera el histograma a partir de un CSV |
| make clean | Borra artefactos de compilación; conserva logs, CSV y PNG |
| make clean_reports | Borra la carpeta Reportes/ completa |
| make help | Muestra la ayuda |

---

## 5. Parámetros

| Variable | Por defecto | Descripción |
|---|---|---|
| TOP | TestGeneral | Prueba a ejecutar |
| BITS | 1 | Buses en paralelo |
| DRVRS | 4 | Terminales por bus |
| PCKG_SZ | 16 | Ancho del paquete en bits |
| BROADCAST | 255 | Dirección de difusión |
| N_TXN | 50 | Transacciones por terminal (solo TestLatencia) |
| SEED | 1 | Semilla aleatoria |
| MIN_DELAY / MAX_DELAY | 0 / 5 | Rango de retardo entre inyecciones |
| MAX_CYCLES | 10000 | Límite de simulación (*death time*) |
| DRAIN_CYCLES | 5000 | Límite de espera al drenar el bus |
| CSV | Reportes/latencias.csv | Archivo de salida de latencias |

> **Importante.** El bus es serial: cada paquete ocupa del orden de PCKG_SZ
> ciclos. Los valores por defecto de MAX_CYCLES y DRAIN_CYCLES son
> insuficientes para 400 transacciones con paquetes de 32 o 64 bits. Usar como
> referencia:
>
> | PCKG_SZ | MAX_CYCLES | DRAIN_CYCLES |
> |---|---|---|
> | 16 | 40 000 | 20 000 |
> | 32 | 60 000 | 30 000 |
> | 64 | 120 000 | 60 000 |
>
> Si el log muestra drenaje AGOTADO o DEATH_TIME, la corrida quedó
> incompleta y el CSV resultante está truncado. Lo esperado es
> bus drenado tras N ciclos.

---

## 6. Pruebas

| Prueba | Escenario | Criterio principal |
|---|---|---|
| TestGeneral | Tráfico aleatorio, destinos válidos, carga variable por terminal | Sin pérdida, duplicación ni alteración de contenido |
| TestTP1 | Transferencia dirigida de una terminal a otra | Todos los paquetes llegan al destino correcto |
| TestTP2 | Cobertura de todas las rutas origendestino | Se ejercitan las DRVRS × (DRVRS-1) rutas |
| TestTP3 | Contención: todas las terminales transmiten con delay 0 | El arbitraje atiende a todas sin inanición |
| TestTP4 | Broadcast | Cada paquete produce DRVRS-1 entregas |
| TestTP5 | Destino inválido | El paquete se descarta sin generar entregas |
| TestLatencia | Medición de latencia con tráfico sostenido | Genera el CSV y valida integridad del tráfico |

Cada prueba evalúa seis criterios (C1C6) e imprime un veredicto final
PASS / FAIL junto con un diagnóstico cuando falla.

---

## 7. Salidas

Todo se escribe en Reportes/:

- comp_<TOP>_p<PCKG_SZ>.log  log de compilación
- run_<TOP>_p<PCKG_SZ>.log  log de simulación, con el veredicto
- latencias_*.csv  latencias por paquete (solo TestLatencia)
- histograma_*.png  histogramas generados con GNUplot
- build/  artefactos de VCS (no versionar)
