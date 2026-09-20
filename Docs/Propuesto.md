# Parámetros del DUT

Resumen de los parámetros del modulo **bus generator sin árbitro central** que se utilizará como referencia para el proyecto.

## Resumen de parámetros

| Parámetro | Valor por defecto | Función |
|---|---:|---|
| `bits` | `1` | Número de buses seriales independientes generados |
| `drvrs` | `4` | Número de dispositivos o interfaces conectados al bus |
| `pckg_sz` | `16` | Tamaño total del paquete en bits |
| `broadcast` | `8'hFF` | Identificador reservado para mensajes broadcast |

Todos estos parámetros forman parte de la configuración estructural del DUT y se establecen antes de ejecutar la simulación.

## 1. Parámetro `bits`

### Declaración

```systemverilog
parameter bits = 1
```

### Función

En `bs_gnrtr_n_rbtr`, `bits` controla la cantidad de instancias independientes del bus:

```systemverilog
for(b=0; b < bits; b=b+1)
begin: BUS
```

También aparece en las dimensiones externas:

```systemverilog
input  pndng[bits-1:0][drvrs-1:0];
output push[bits-1:0][drvrs-1:0];
output pop[bits-1:0][drvrs-1:0];
```

Por lo tanto, en este módulo `bits` determina cuántos buses seriales se generan, para el desarrollo del proyecto haremos uso de un solo bus de datos, por lo cual el parámetro `bits` estará siempre en 1.


## 2. Parámetro `drvrs`

### Declaración

```systemverilog
parameter drvrs = 4
```

### Función

`drvrs` determina el número de interfaces o dispositivos conectados al bus.

El módulo genera `drvrs` instancias de `bs_ntrfs_n_rbtr`:

```systemverilog
for (i=0; i < drvrs; i=i+1)
begin: ID
  bs_ntrfs_n_rbtr #(pckg_sz,i,broadcast,drvrs) ntrfs (...);
end
```
El valor de `i` se utiliza como identificador de cada interfaz.


## 3. Parámetro `pckg_sz`

### Declaración

```systemverilog
parameter pckg_sz = 16
```

### Función

`pckg_sz` determina el ancho completo del paquete que entra y sale de cada interfaz:

```systemverilog
input  [pckg_sz-1:0] D_pop;
output [pckg_sz-1:0] D_push;
```

### Campo de destino

El código usa los 8 bits más significativos del paquete como identificador de destino:

```systemverilog
D_in[pckg_sz-1:pckg_sz-8]
```

Por lo tanto, la organización conceptual del paquete es:

```text
             MSB                LSB

      Destino: 8 bits  | Payload: pckg_sz - 8     

```

Para `pckg_sz = 16`:

```text
15              8 7                       0

| Destino (8)    | Payload (8)             |

```

 Cambiar el valor del pckg_sz implica una nueva configuración de compilación/elaboración.

## 4. Parámetro `broadcast`

### Declaración

```systemverilog
parameter broadcast = {8{1'b1}}
```

Esto equivale a:

```systemverilog
8'b1111_1111
```

es decir:

```systemverilog
8'hFF
```

### Función esperada

El parámetro representa el identificador especial para un mensaje dirigido a todas las terminales.

Ejemplo con `drvrs = 4`:

```text
IDs normales: 0, 1, 2, 3
Broadcast:    8'hFF
```

## 5. Observación importante sobre `broadcast`

Aunque `broadcast` se declara como parámetro, en `ntrfs_cntrl_n_rbtr` la comprobación encontrada es:

```systemverilog
bdcst = (D_in[pckg_sz-1:pckg_sz-8]=={8{1'b1}})
        ? {1'b1}
        : {1'b0};
```

La comparación se realiza directamente contra `8'hFF` y no contra el parámetro `broadcast`.

Es necersio verificar experimentalmente si modificar `broadcast` realmente modifica el identificador reconocido por el DUT.


# Interfaz externa del DUT

## Módulo analizado

```systemverilog
module bs_gnrtr_n_rbtr #(
  parameter bits = 1,
  parameter drvrs = 4,
  parameter pckg_sz = 16,
  parameter broadcast = {8{1'b1}}
) (
  input clk,
  input reset,
  input  pndng[bits-1:0][drvrs-1:0],
  output push[bits-1:0][drvrs-1:0],
  output pop[bits-1:0][drvrs-1:0],
  input  [pckg_sz-1:0] D_pop[bits-1:0][drvrs-1:0],
  output [pckg_sz-1:0] D_push[bits-1:0][drvrs-1:0]
);
```

## Resumen de señales

| Señal | Dirección respecto al DUT | Ancho por terminal | Función |
|---|---|---:|---|
| `clk` | Input | 1 bit | Reloj principal |
| `reset` | Input | 1 bit | Reinicio del sistema |
| `pndng` | Input | 1 bit | Indica que existe un paquete pendiente para transmitir |
| `D_pop` | Input | `pckg_sz` bits | Paquete presentado al DUT desde la terminal origen |
| `pop` | Output | 1 bit | Indica que el DUT consumió el paquete de la terminal origen |
| `D_push` | Output | `pckg_sz` bits | Paquete entregado por el DUT a una terminal destino |
| `push` | Output | 1 bit | Indica que `D_push` contiene un paquete que debe recibirse/almacenarse |


El módulo utiliza señales de control como clk que funciona como el reloj principal del sistema y sincroniza los controladores, contadores y máquinas de estados internas. Por su parte, reset se utiliza para reiniciar el funcionamiento del DUT y, de acuerdo con los bloques empleados en fifo.sv, se maneja como una señal activa en alto. La señal pndng indica si una terminal tiene datos pendientes por transmitir.

En cuanto al movimiento de datos, D_pop contiene el paquete que una terminal desea enviar hacia el DUT, mientras que pop indica que ese paquete ya fue consumido y puede retirarse de la FIFO de origen. Del lado de recepción, D_push contiene el paquete que el DUT entrega a la terminal destino y push indica que dicho dato es válido y debe almacenarse. 

## 1. Flujo de transmisión

Ejemplo:

```text
Origen  = dispositivo 0
Destino = dispositivo 2
bits    = 1
```

El ambiente presenta:

```text
D_pop[0][0] = paquete
pndng[0][0] = 1
```

Flujo conceptual:

```text
FIFO / ambiente origen
        |
        | D_pop[0][0]
        | pndng[0][0]
        v
+---------------------+
|      DUT / BUS      |
+---------------------+
        |
        | pop[0][0]      -> confirma consumo en origen
        |
        | D_push[0][2]
        | push[0][2]     -> entrega en destino
        v
FIFO / ambiente destino
```


## 2. Identificación del destino

En `ntrfs_cntrl_n_rbtr` se comparan los 8 bits más significativos del paquete con el ID de la interfaz:

```systemverilog
rd_cmp_a = D_in[pckg_sz-1:pckg_sz-8];
rd_cmp_b = ntrfs_id;
rd_cmp_out = (rd_cmp_a == rd_cmp_b);
```

Cada interfaz realiza conceptualmente:

```text
Destino del paquete == mi ID ?
```

Ejemplo para destino `2`:

```text
Interfaz 0 -> no coincide
Interfaz 1 -> no coincide
Interfaz 2 -> coincide
Interfaz 3 -> no coincide
```

## 3. Broadcast

El controlador detecta broadcast mediante los 8 bits más significativos:

```systemverilog
bdcst = (D_in[pckg_sz-1:pckg_sz-8] == {8{1'b1}});
```

Con el valor por defecto:

```text
Destino = 8'hFF
```

el paquete se reconoce como broadcast.

Debe confirmarse mediante simulación qué terminales generan `push` y si el origen recibe o no su propio broadcast.





