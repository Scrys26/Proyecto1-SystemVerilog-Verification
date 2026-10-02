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

