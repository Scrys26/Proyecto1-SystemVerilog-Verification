# Parámetros del DUT

Resuemen de los parametros del modulo **bus generator sin árbitro central** que se utilizará como referencia para el proyecto.

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

Por lo tanto, en este módulo `bits` determina cuántos buses seriales se generan.


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

Es necersio verificar de forma experimentalmente si modificar `broadcast` realmente modifica el identificador reconocido por el DUT.

