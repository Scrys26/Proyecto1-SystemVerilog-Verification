
## 1. Preparación

Ubicarse en la carpeta principal del proyecto, donde se encuentra el
`Makefile`.
Limpiar compilaciones anteriores:
``` bash
make clean
```
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

## 3. Pruebas de 16 bits
### Delay 0--5 ciclos

Ejecutar:

``` bash
make run TOP=TestLatencia  PCKG_SZ=16 MIN_DELAY=0 \
MAX_DELAY=5 \
N_TXN=100 \
SEED=20 \
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
CSV=Reportes/latencias_16b_delay20_100.csv
```

Luego:

``` bash
make plot CSV=Reportes/latencias_16b_delay20_100.csv
```

## 4. Pruebas de 32 bits

Se repite el mismo procedimiento cambiando `PCKG_SZ=32`.

### Delay 0--5 ciclos

``` bash
make run TOP=TestLatencia \
PCKG_SZ=32 \
MIN_DELAY=0 \
MAX_DELAY=5 \
N_TXN=100 \
SEED=20 \
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


## 7. Importante para comparar resultados

Mantener `N_TXN=100` y `SEED=20` en las nueve pruebas.

Esto permite que las pruebas se realicen bajo las mismas condiciones de
cantidad de tráfico y semilla aleatoria, modificando únicamente el
tamaño de paquete y el rango de delay.

No es necesario escribir `N_TXN` y `SEED` si el `Makefile` ya tiene esos
valores por defecto, si estos espacios no se especifican la prueba se realizará con 200 paquetes por defecto.

