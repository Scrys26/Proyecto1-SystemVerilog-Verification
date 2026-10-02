## 1. Preparación

Ubicarse en la carpeta principal del proyecto, donde se encuentra el
`Makefile`.
Limpiar compilaciones anteriores:

``` bash
make clean
```

`make clean` elimina los archivos de compilación pero conserva los `.csv`,
los `.png` y los `.log` dentro de `Reportes/`. Para borrar absolutamente
todo se usa `make clean_reports`.

## 2. Parámetros de las pruebas

Para que las pruebas sean comparables se recomienda mantener:

  Parámetro                                        Valor
  ---------------------------------------- -------------
  Cantidad de transacciones por terminal     `N_TXN=100`
  Semilla aleatoria                            `SEED=20`
  Terminales                                           4
  Transacciones totales                              400

La cantidad total esperada es:

``` text
4 terminales × 100 transacciones = 400 transacciones
```

Los parámetros que se modifican entre pruebas son:

-   `PCKG_SZ`: tamaño del paquete.
-   `MIN_DELAY`: delay mínimo.
-   `MAX_DELAY`: delay máximo.
-   `MAX_CYCLES` y `DRAIN_CYCLES`: límites de simulación. Deben crecer
    con `PCKG_SZ`, porque el bus es serial y cada paquete ocupa del
    orden de `PCKG_SZ` ciclos.

Los límites recomendados son:

  Paquete   `MAX_CYCLES`   `DRAIN_CYCLES`
  --------- -------------- ----------------
  16 bits          40000            20000
  32 bits          60000            30000
  64 bits         120000            60000

Si el log muestra `drenaje AGOTADO` o `DEATH_TIME`, la corrida quedó
incompleta y el CSV resultante está truncado. Lo esperado es
`bus drenado tras N ciclos`.

## 3. Pruebas de 16 bits

### Delay 0--5 ciclos

Ejecutar:

``` bash
make run TOP=TestLatencia \
PCKG_SZ=16 \
MIN_DELAY=0 \
MAX_DELAY=5 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=40000 \
DRAIN_CYCLES=20000 \
CSV=Reportes/latencias_16b_delay0_5.csv
```

Generar el histograma:

``` bash
make plot CSV=Reportes/latencias_16b_delay0_5.csv
```

### Delay 5--20 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=16 \
MIN_DELAY=5 \
MAX_DELAY=20 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=40000 \
DRAIN_CYCLES=20000 \
CSV=Reportes/latencias_16b_delay5_20.csv
```

Luego:

``` bash
make plot CSV=Reportes/latencias_16b_delay5_20.csv
```

### Delay 20--100 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=16 \
MIN_DELAY=20 \
MAX_DELAY=100 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=40000 \
DRAIN_CYCLES=20000 \
CSV=Reportes/latencias_16b_delay20_100.csv
```

Luego:

``` bash
make plot CSV=Reportes/latencias_16b_delay20_100.csv
```

## 4. Pruebas de 32 bits

Se repite el mismo procedimiento cambiando `PCKG_SZ=32` y subiendo los
límites de simulación.

### Delay 0--5 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=32 \
MIN_DELAY=0 \
MAX_DELAY=5 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=60000 \
DRAIN_CYCLES=30000 \
CSV=Reportes/latencias_32b_delay0_5.csv
```

``` bash
make plot CSV=Reportes/latencias_32b_delay0_5.csv
```

### Delay 5--20 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=32 \
MIN_DELAY=5 \
MAX_DELAY=20 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=60000 \
DRAIN_CYCLES=30000 \
CSV=Reportes/latencias_32b_delay5_20.csv
```

``` bash
make plot CSV=Reportes/latencias_32b_delay5_20.csv
```

### Delay 20--100 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=32 \
MIN_DELAY=20 \
MAX_DELAY=100 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=60000 \
DRAIN_CYCLES=30000 \
CSV=Reportes/latencias_32b_delay20_100.csv
```

``` bash
make plot CSV=Reportes/latencias_32b_delay20_100.csv
```

## 5. Pruebas de 64 bits

Se cambia `PCKG_SZ=64`.

### Delay 0--5 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=64 \
MIN_DELAY=0 \
MAX_DELAY=5 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=120000 \
DRAIN_CYCLES=60000 \
CSV=Reportes/latencias_64b_delay0_5.csv
```

``` bash
make plot CSV=Reportes/latencias_64b_delay0_5.csv
```

### Delay 5--20 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=64 \
MIN_DELAY=5 \
MAX_DELAY=20 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=120000 \
DRAIN_CYCLES=60000 \
CSV=Reportes/latencias_64b_delay5_20.csv
```

``` bash
make plot CSV=Reportes/latencias_64b_delay5_20.csv
```

### Delay 20--100 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=64 \
MIN_DELAY=20 \
MAX_DELAY=100 \
N_TXN=100 \
SEED=20 \
MAX_CYCLES=120000 \
DRAIN_CYCLES=60000 \
CSV=Reportes/latencias_64b_delay20_100.csv
```

``` bash
make plot CSV=Reportes/latencias_64b_delay20_100.csv
```

## 6. Resumen de las 9 pruebas

  Paquete   Delay
  --------- ---------
  16 bits   0--5
  16 bits   5--20
  16 bits   20--100
  32 bits   0--5
  32 bits   5--20
  32 bits   20--100
  64 bits   0--5
  64 bits   5--20
  64 bits   20--100

En cada caso se deben conservar el archivo `.csv` y el histograma
generado.

### Ejecución automática de las nueve pruebas

En lugar de ejecutar los comandos uno por uno, se pueden correr las nueve
pruebas con sus histogramas desde la carpeta principal del proyecto:

``` bash
for cfg in "16 0 5 40000 20000" \
           "16 5 20 40000 20000" \
           "16 20 100 40000 20000" \
           "32 0 5 60000 30000" \
           "32 5 20 60000 30000" \
           "32 20 100 60000 30000" \
           "64 0 5 120000 60000" \
           "64 5 20 120000 60000" \
           "64 20 100 120000 60000"; do
  set -- $cfg
  CSV="Reportes/latencias_${1}b_delay${2}_${3}.csv"
  echo "=== ${1} bits, delay ${2}-${3} ==="
  make run TOP=TestLatencia PCKG_SZ=$1 MIN_DELAY=$2 MAX_DELAY=$3 \
       N_TXN=100 SEED=20 MAX_CYCLES=$4 DRAIN_CYCLES=$5 CSV="$CSV"
  make plot CSV="$CSV"
done
```

Al terminar conviene verificar que ninguna corrida se haya quedado corta:

``` bash
grep -l "AGOTADO\|DEATH_TIME" Reportes/run_TestLatencia_p*.log
```

Si el comando no devuelve nada, las nueve corridas drenaron correctamente.

Si los `.csv` ya existen y solo se necesitan regenerar los histogramas:

``` bash
for f in Reportes/latencias_*.csv; do make plot CSV="$f"; done
```

## 7. Importante para comparar resultados

Mantener `N_TXN=100` y `SEED=20` en las nueve pruebas.

Esto permite que las pruebas se realicen bajo las mismas condiciones de
cantidad de tráfico y semilla aleatoria, modificando únicamente el
tamaño de paquete y el rango de delay.

Los valores por defecto del `Makefile` son `N_TXN=50` y `SEED=1`, es
decir 200 transacciones totales con otra semilla. Por esa razón **sí** es
necesario escribir `N_TXN=100 SEED=20` en las nueve pruebas de latencia.

### Ejemplo de ejecucion corriente

``` bash
make run TOP=TestLatencia
```

Este comando usa los valores por defecto y escribe en
`Reportes/latencias.csv`. Sirve para una corrida rápida, no para las
nueve pruebas comparables.

Para las pruebas funcionales basta con cambiar el nombre:

``` bash
make run TOP=TestGeneral
make run TOP=TestTP1
make run TOP=TestTP2
make run TOP=TestTP3
make run TOP=TestTP4
make run TOP=TestTP5
```

Estas pruebas no generan CSV ni histogramas: su resultado es el veredicto
`PASS` o `FAIL` que aparece al final del log.

## 8. Visualización de ondas con Verdi

Las formas de onda permiten revisar el comportamiento ciclo a ciclo del
bus y documentar las pruebas dirigidas.

### 8.1 Generar el archivo de ondas

El volcado está desactivado por defecto para que las corridas normales no
paguen su costo. Se activa con `WAVES=1`:

``` bash
make run TOP=TestTP1 WAVES=1
```

Esto genera `Reportes/ondas_TestTP1_p16.fsdb`. En el log debe aparecer la
línea:

``` text
[WAVE] volcando ondas en Reportes/ondas_TestTP1_p16.fsdb
```

Para `TestLatencia` conviene reducir la carga, ya que un archivo con 400
paquetes de 64 bits resulta muy pesado y difícil de navegar:

``` bash
make run TOP=TestLatencia WAVES=1 N_TXN=5 PCKG_SZ=16
```

### 8.2 Abrir Verdi

``` bash
make verdi TOP=TestTP1
```

El nombre del archivo depende de `TOP` y de `PCKG_SZ`, por lo que ambos
deben coincidir con los de la corrida. Por ejemplo:

``` bash
make run   TOP=TestTP1 WAVES=1 PCKG_SZ=32
make verdi TOP=TestTP1         PCKG_SZ=32
```

### 8.3 Agregar señales

Al abrir Verdi la ventana de ondas aparece vacía. El procedimiento es:

1.  En el panel **Instance**, expandir `TestTP1` y seleccionar la
    instancia `vif` (la interfaz `bus_if`). Las entradas `drv_cb` y
    `mon_cb` son los *clocking blocks*, no contienen señales.
2.  Clic derecho sobre `vif` → **Add to Waveform** →
    **Add Signals of Current Scope**.
3.  Expandir los arreglos con el `+` que aparece junto a cada nombre.
    Son arreglos de dos dimensiones, por lo que puede ser necesario
    expandir dos veces: primero `[0:0]` y luego `[3:0]`.
4.  Eliminar con **Delete** las señales que no se necesiten.
5.  Clic derecho sobre `D_pop` y `D_push` → **Radix → Hexadecimal**.

Una vez acomodadas las señales, **File → Save Signal File** guarda la
configuración. Para las demás pruebas se usa **File → Restore Signal
File** y solo se cambian los índices.

### 8.4 Navegar y medir

-   Tecla **F**: ajustar la vista a toda la actividad.
-   Teclas **I** y **O**: acercar y alejar.
-   Botones **◄ ►**: saltar al cambio anterior o siguiente de la señal
    seleccionada. Es la forma más rápida de llegar al primer `pop`.
-   Clic: colocar el cursor principal.
-   **Ctrl + clic**: colocar el marcador secundario. La diferencia entre
    ambos aparece en la barra superior y permite medir la latencia.

La escala está en picosegundos. Puede cambiarse desde
**Waveform → Time Unit**.

### 8.5 Señales recomendadas por prueba

  Prueba   Señales                                                                   Qué se observa
  -------- ------------------------------------------------------------------------- ------------------------------------------
  TP-01    `pndng[0][0]`, `D_pop[0][0]`, `pop[0][0]`, `push[0][2]`, `D_push[0][2]`   Handshake completo y latencia mínima
  TP-03    `pndng[0][0..3]`, `pop[0][0..3]`                                          Arbitraje round-robin entre terminales
  TP-04    `pop[0][0]`, `push[0][0..3]`, `D_push[0][1]`                              Difusión simultánea a tres terminales
  TP-05    `pop[0][0]`, `D_pop[0][0]`, `push[0][0..3]`                               Descarte sin entrega

En todos los casos conviene incluir `clk` y `reset`.

### 8.6 Exportar las capturas

**File → Print** desde la ventana de ondas (nWave), eligiendo:

-   **Print to File**, formato PNG.
-   **White background** o **Reverse color**, ya que el fondo negro
    queda mal impreso.
-   Rango **Current View**, para exportar únicamente lo visible.

Si la exportación falla sobre VNC, puede tomarse una captura de pantalla
de la región de ondas, maximizando antes la ventana para ganar
resolución y guardando siempre en PNG.

### 8.7 Limpieza

Los archivos `.fsdb` ocupan bastante espacio y no deben versionarse.
Están incluidos en el `.gitignore` del proyecto. Para eliminarlos:

``` bash
rm -f Reportes/*.fsdb
```
