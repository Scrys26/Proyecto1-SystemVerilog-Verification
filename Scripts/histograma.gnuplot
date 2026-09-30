# ============================================================
# Histograma de latencia
# ============================================================

set datafile separator ","

# Crear archivo de frecuencias
set table FREQ_FILE
plot CSV_FILE using 8:(1) smooth frequency
unset table

# El archivo de frecuencias usa espacios
unset datafile separator

# Salida PNG
set terminal pngcairo size 1200,700 enhanced font "Arial,12"
set output OUTPUT_FILE

set title "Histograma de Latencia de Paquetes"
set xlabel "Latencia (ciclos de reloj)"
set ylabel "Cantidad de paquetes"

set xrange [*:*]
set yrange [0:*]

set offsets graph 0.03, graph 0.03, graph 0.10, graph 0

# Rango vertical automatico
set yrange [0:*]

# Dejar 10% de espacio arriba para las etiquetas
set offsets graph 0, graph 0, graph 0.10, graph 0

set xtics 5
set ytics 20

set grid ytics

set boxwidth 0.8
set style fill solid 0.7 border -1

set key off

plot FREQ_FILE using 1:2 with boxes, \
     "" using 1:2:(sprintf("%.0f",$2)) with labels offset char 0,1

unset output
